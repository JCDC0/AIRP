# AIRP 0.8 Pre-Release Audit

Audit date: 2026-07-27. Against commit `e40fac7` (`0.7.26`), branch `main`.

Baseline verified at audit time:

- `flutter analyze` clean, no issues.
- `flutter test` 167 tests, all passing.
- `flutter build apk --release` succeeds, produces an 81.0 MB APK.

Scope decision: this is a personal project with no public release yet. The Android
packaging blockers in section 4 are therefore DEFERRED. Sections 1 through 3 are
the active work, since those affect the app in daily use.

---

## 1. Confirmed bug: Gemini and Gemma streaming returns nothing

> **RESOLVED in `0.7.27`.** `alt=sse` added. URL construction extracted to
> `ChatApiService.buildGeminiStreamUrl` and guarded by
> `test/gemini_stream_url_test.dart`. The empty-stream fallback suggested below
> also landed as `ChatApiService.emptyGeminiStreamNotice`, which reports
> `blockReason` / `finishReason` instead of rendering a blank bubble.
> Still open from this section: moving the key out of the query string into an
> `x-goog-api-key` header (three call sites, only one of which was touched here).
> The original finding is preserved below.

**Status: reproduced on device.** Sent a message on Gemma 4 31B IT, spinner ran
about 10 seconds, then an empty bubble. Context counter read `270 / 262,144`,
which proves the API key and network path are fine, because the counter goes
through a separate `countTokens` SDK call.

**File:** `lib/services/chat_api_service.dart`, in `streamGeminiResponse`, around line 162.

**Cause.** The request URL is:

```dart
'https://generativelanguage.googleapis.com/v1beta/models/$modelId:streamGenerateContent?key=${apiKey.trim()}'
```

The parser then does:

```dart
if (!line.startsWith('data: ')) continue;
```

Without `alt=sse`, `streamGenerateContent` returns a pretty-printed JSON array,
not Server-Sent Events. No line begins with `data: `, so every line is skipped,
the stream completes with an empty accumulator, and the bubble stays blank. There
is no error because the HTTP status is 200.

`git log -S "alt=sse" --all` returns nothing, so this has never been correct. The
raw REST path was introduced in `f4d50ec` (`0.7.17`), which means Gemini and Gemma
streaming has been silently dead for nine versions.

**Fix.**

```dart
'https://generativelanguage.googleapis.com/v1beta/models/$modelId:streamGenerateContent?alt=sse&key=${apiKey.trim()}'
```

**Follow-ups worth doing in the same pass.**

- Add a regression test asserting the built URL contains `alt=sse`.
- Consider moving the key from the query string to the `x-goog-api-key` header so
  it stops appearing in any URL logging.
- The `else` branch that yields `**Error ${statusCode}:** $errorBody` works, but a
  200 response that produces zero chunks currently surfaces as silence. Emitting a
  fallback message when `fullText` is empty at stream close would have caught this
  years earlier.

---

## 2. Persistence bugs

All four are the same root cause: provider state is duplicated across eight-plus
call sites in `ChatProvider`, and each of these was missed in one or more of them.

### 2.1 Three endpoint fields never persist

`lib/utils/constants.dart` declares:

- `prefVertexAiEndpoint` = `airp_vertexai_endpoint`
- `prefOpenAiCompatibleEndpoint` = `airp_openai_compatible_endpoint`
- `prefOllamaEndpoint` = `airp_ollama_endpoint`

A repo-wide search shows all three are referenced only at their own declaration.
`ChatProvider.saveSettings()` never writes them, `_loadSettings()` never reads
them, and `exportSettingsMap()` / `importSettingsMap()` omit them.

Effect: anyone using the OpenAI Compatible or Vertex AI providers retypes their
base URL on every app launch, and the values are absent from config packs and
`.airp` backups.

Fix: add reads to `_loadSettings()`, writes to `saveSettings()`, and both
directions in the export/import maps.

### 2.2 The Ollama endpoint field is entirely non-functional

`setOllamaEndpoint()` updates `_ollamaEndpoint` in memory and nothing else reads
it. All three places that construct `customUrl` handle only `local`,
`openAiCompatible`, and `vertexAi`:

- `ChatProvider.sendMessage()`, around line 1590
- `ChatProvider._runWebSearchToolLoop()`, around line 938
- `ChatProvider._oneShotGenerate()`, around line 2078

So Ollama always resolves to `ApiConstants.ollamaDefaultBaseUrl`, which is
`http://localhost:11434/v1`. On a phone that means the phone itself, not the PC
running Ollama. The settings field and the README instructions both imply it works.

Fix: add an `AiProvider.ollama` branch to all three `customUrl` blocks, and persist
the value per 2.1. Better: extract the `customUrl` resolution into a single helper
so there is only one place to update.

### 2.3 MiMo model selection is never saved or loaded

`ApiConstants.prefModelMimo` is declared and never used. `_mimoModel` is missing from:

- `_loadSettings()` (every other provider is read there, MiMo is not)
- `saveSettings()` (the write list stops at `prefModelMistral`)
- `exportSettingsMap()` (the `models` map has 18 entries, MiMo absent)
- `importSettingsMap()` (same)

`_getProviderModel()` and `_setProviderModel()` DO handle MiMo, which is why the
selection appears to work until you restart.

Fix: add MiMo to all four.

### 2.4 Export and import maps are drifting

`exportSettingsMap()` is the source for config packs and `.airp` backups. It
already omits the three endpoints and MiMo. This will keep happening. Consider
deriving the map from the provider registry rather than hand-listing entries, so
adding a provider cannot silently skip export.

---

## 3. Recommended refactor: collapse duplicated provider state

This is the highest-value structural change and it directly prevents the entire
class of bug in section 2.

**Current shape.** `ChatProvider` carries, per provider:

- a `_xModel` field and an `xModel` getter (19 of each)
- an `xModelsList` getter delegating to `ModelRegistryService` (19)
- an `xKey` getter delegating to `ApiKeyService` (19)
- an `isLoadingXModels` getter (8, inconsistently, only some providers have one)

Plus three hand-written string-to-enum chains:

- `_loadSettings()` provider parsing, about 40 lines of `else if`
- `loadSession()` provider parsing, about 90 lines of `else if`
- `_getProviderModel()` / `_setProviderModel()` switches

Both string chains can be replaced by `AiProvider.values.byName(name)` inside a
try/catch, which is roughly five lines total and cannot fall out of sync.

**Target shape.** A `Map<AiProvider, ProviderState>` where `ProviderState` holds
the selected model, the endpoint override (nullable), and the pref key set.
Loading and saving become a single loop over `AiProvider.values`. Export and import
become a single map comprehension.

Estimated reduction: roughly 400 lines out of 2670, and adding a provider goes from
eleven touch points to two.

**Sequencing.** Do this AFTER the section 2 fixes land and are verified, not
before. Fix the bugs against the current structure so the behaviour is known-good,
then refactor with tests as the safety net. Doing it in the other order means you
cannot tell whether a regression came from the refactor or was already there.

---

## 4. Deferred: Android release blockers

None of these affect development. `flutter run` and debug builds include the
INTERNET permission automatically, which is exactly why item 4.1 has gone unnoticed.
Address them when cutting a public APK.

### 4.1 The release APK has no network access at all

Verified from the merged release manifest at
`build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`.
The only `uses-permission` present is the auto-generated
`DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.

`android.permission.INTERNET` exists only in `android/app/src/debug/AndroidManifest.xml`,
which is Flutter's template default and does not merge into release builds. None of
the current plugins declare it either.

Fix: add `<uses-permission android:name="android.permission.INTERNET"/>` to
`android/app/src/main/AndroidManifest.xml`. This is the single hard blocker.

### 4.2 Release builds are signed with the debug keystore

`android/app/build.gradle.kts` still carries the template:

```kotlin
release {
    signingConfig = signingConfigs.getByName("debug")
}
```

Anyone can resign the APK, and switching to a real key later forces users to
uninstall before upgrading.

### 4.3 Placeholder application ID

`applicationId = "com.example.airp_chat"`, still carrying the template TODO. This
is permanent for upgrade purposes once published.

### 4.4 Cleartext HTTP is blocked

No `usesCleartextTraffic` and no `network_security_config.xml`. Android has blocked
plain HTTP by default since API 28. This breaks the Local / LM Studio provider
(`http://192.168.1.15:1234/v1`), Ollama (`http://localhost:11434`), and self-hosted
SearXNG. Prefer a scoped `network_security_config.xml` permitting private ranges
over a blanket `usesCleartextTraffic="true"`.

### 4.5 App label

`android:label="airp_chat"` shows that string on the launcher instead of `AIRP`.

### 4.6 APK size

81.0 MB. Contributors:

- `assets/` is 27.8 MB across 26 PNG backgrounds, several over 1.3 MB each.
  Converting to WebP at roughly q85 should bring that to about 4 MB.
- No `--split-per-abi`, so all three ABIs of the Flutter engine ship together.
- No `isMinifyEnabled` or `shrinkResources` in the release build type.

Together these should land around 20 to 25 MB per ABI.

### 4.7 No APK release workflow

`.github/workflows/deploy.yml` only builds and deploys the web app to GitHub Pages.
Nothing builds or attaches an APK to a GitHub release.

---

## 5. Robustness notes, not blocking

- **No timeout on any LLM HTTP call.** Only `web_search_service.dart` uses
  `.timeout()`. A stalled local server hangs the bubble indefinitely. Cancel works,
  but a timeout with a clear message is better.
- **Sessions live in one SharedPreferences string.** `airp_sessions` holds every
  conversation as a single JSON blob, which Android reads fully into memory at
  startup. `SessionService.persistSessions()` already has quota-exhaustion fallback
  logic that strips regeneration history, which suggests the ceiling has been hit.
  Moving to per-session files under `path_provider` would fix it properly, and
  matches what the docs already claim.
- **Image attachments store `image_picker` cache paths.** `ChatMessage.imagePaths`
  keeps raw paths into a cache directory Android is free to purge, so older
  conversations lose their images. Copy attachments into app documents on attach.
- **`_messages.last` race in streaming callbacks.** `onUpdate`, `onDone`,
  `onError`, and `onThoughtSignature` all assume the last element of `_messages`
  is still the streaming placeholder. Deleting a message or regenerating mid-stream
  writes onto the wrong bubble. Capturing the target index or a message ID at
  registration time would make this safe.
- **`regenerateResponse` drops `attachmentBytes`.** It calls
  `sendMessage(textToResend, imagesToResend)` with no bytes, so regenerating a
  message with attachments loses them on web.
- **`file_io_helper.dart` uses `dart.library.html`** for its conditional import.
  That is the legacy guard and does not work under Wasm. `dart.library.js_interop`
  is the current form.

---

## 6. Documentation and housekeeping

- **No LICENSE file** despite the README declaring MIT.
- **README says "36+ built-in AI-generated backgrounds".** `kAssetBackgrounds` has
  26 entries and `assets/` has 26 PNGs.
- **GEMINI.md says "Sessions are stored as JSON files".** They are stored in
  SharedPreferences under `airp_sessions`. Corrected in `CLAUDE.md`.
- **`package.json` and `package-lock.json` are untracked in the repo root**, left
  over from `.kilo` tooling. Add to `.gitignore` or remove.
- **`GEMINI.md` is gitignored**, so the roadmap is local-only. Decide whether
  `CLAUDE.md` should be tracked. Recommendation: track it, since it is project
  documentation that benefits collaborators and future sessions.
- **`OpenRouter` refresh sends `HTTP-Referer: https://airp-chat.com`**, a domain
  that does not appear to exist. Harmless but worth pointing at the GitHub repo.
- **Test coverage gap.** Services are well covered. `ChatProvider` has two small
  tests against roughly 2670 lines. The section 2 fixes are a natural place to add
  persistence round-trip tests.

---

## Suggested order of work

1. Fix the Gemini `alt=sse` bug. One line, unblocks the flagship provider, verify
   on device immediately.
2. Fix the four persistence bugs in section 2, with round-trip tests.
3. Refactor provider state per section 3, leaning on those tests.
4. Documentation cleanup from section 6.
5. Release blockers in section 4, only when a public APK is actually wanted.
