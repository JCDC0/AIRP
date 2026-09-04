# AIRP Agent Guide

Canonical instructions for any LLM or coding agent working in this repository.
The root `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` are thin pointers to this file,
so tool-specific entry points stay auto-discoverable while the content lives in
one place. Edit this file, not the pointers.

AIRP is a highly customizable, privacy-focused AI chat client built with Flutter.
It is a unified interface for multiple AI providers (Gemini, OpenRouter, NVIDIA,
Ollama, and others) with a focus on roleplay features and modular architecture.

Current version: `0.7.30.5` (`pubspec.yaml` `0.7.30+16`). Target: `0.8.0` release.

## Project overview

*   **Stack:** Flutter (Dart), `Provider` for state management, custom
    REST/streaming for every provider including Gemini. There is deliberately no
    vendor SDK: `google_generative_ai` was dropped in `0.7.30.2` after its last
    real caller disappeared. An SDK concatenates Gemini's `thought` parts into
    the answer text, which is exactly the boundary reasoning display needs.
*   **Orchestration:** `ChatProvider` is the central state hub
    (`lib/providers/chat_provider.dart`, ~2,500 lines).
*   **Services:**
    *   `PromptPipelineService`: stateless prompt assembly (pure functions).
    *   `ChatApiService`: low-level API communication (Gemini raw REST and
        OpenAI-compatible).
    *   `StrategyResolver`: strategy-pattern registry for multi-provider support.
    *   `SessionService`: conversation persistence and background streaming state.
    *   `StreamingCoordinatorService`: owns active stream subscriptions across sessions.
    *   `ModelRegistryService`: provider-specific model discovery and metadata.
    *   `ApiKeyService`: secure storage for API credentials with legacy migration.
    *   `ConfigPackService`: named settings bundles, SillyTavern preset import.
    *   `LorebookService`: current-input lore recognition. See "Lore recognition" below.
*   **Persistence:** `shared_preferences` for settings AND sessions. Sessions are a
    single JSON string under the `airp_sessions` key, not separate files.
    `flutter_secure_storage` for API keys.

## Building and running

*   **Install dependencies:** `flutter pub get`
*   **Run:** `flutter run` (Android, iOS, Web, Windows, macOS, Linux)
*   **Test:** `flutter test` (308 tests, all passing)
*   **Analyze:** `flutter analyze` (clean)
*   **Release APK:** `flutter build apk --release`

Always run `flutter analyze` and `flutter test` before committing. Both are
currently clean and must stay that way.

## Development conventions

### Architecture and logic

*   **Service isolation:** keep business logic inside services. Services should be
    stateless or managed by a provider.
*   **Prompt construction:** all prompt assembly MUST reside in or be coordinated
    by `PromptPipelineService`.
*   **Provider strategies:** to add an AI provider, implement a new
    `AiProviderStrategy` and register it in `StrategyResolver`.
*   **Streaming:** responses are Dart `Stream<String>`. Use
    `StreamingCoordinatorService` to manage active streams across sessions.

### Coding standards

*   **Linting:** `package:flutter_lints/flutter.yaml`. Verify with `flutter analyze`.
*   **State:** use `context.read<ChatProvider>()` or `Consumer<ChatProvider>`.
*   **Async:** prefer `async`/`await`. Use `Stream` for real-time output.
*   **Safety:** never log or print API keys. Use `ApiKeyService` for all credentials.
*   **Comments:** no single-line explanatory comments unless asked. Doc comments
    (`///`) on public APIs are welcome.
*   **Formatting:** no em dashes in code, comments, or docs.

### Commits

*   Version-prefixed format: `0.7.X: Description`.
*   **Versioning:** `pubspec.yaml` `version:` must be three-component semver `X.Y.Z`
    plus an optional build number (`0.7.19+1`). Four-component like `0.7.19.2` is
    INVALID in pubspec. The human-readable patch label is used ONLY in
    `lib/utils/version.dart` (`appVersion`, a free string in the settings header)
    and in commit messages. When bumping, update BOTH files.

### Testing

*   New features and bug fixes should include tests in `test/`.
*   Service unit tests are well covered. `ChatProvider` is thinly tested against
    ~2,600 lines and is the main coverage gap.
*   **Unit tests cannot detect an unwired service.** The lorebook engine carried
    ~1,400 lines of passing tests for a path with no production caller for nine
    versions. A send-path integration test is the recommended guard.
*   **One field standing in for many values must repaint when the value it
    stands for changes.** The API key box serves all eight providers. A focus
    guard added to stop a caret jump also froze it across a provider switch, so
    it displayed the previous provider's key while the new provider's slot was
    empty, and the send went out as `Authorization: Bearer ` with nothing after
    it. A provider switch overrides the guard and drops focus. Guarded by
    `test/api_key_panel_provider_switch_test.dart`.
*   **Text fields are a recurring defect site.** Never trim inside `onChanged`
    and never assign `controller.text` while the field has focus. Both feed a
    changed string back through the provider into the panel's resync, and
    assigning that property collapses the selection to the end of the value, so
    the caret jumps mid-edit. Trim on read instead. Never construct a
    `TextEditingController` in `build()`. Persist through
    `ChatProvider.saveSettingsDebounced`, not `saveSettings`, which issues
    around twenty awaited writes plus an autosave. Guarded by
    `test/system_prompt_panel_caret_test.dart`.

## Providers

Eight providers ship: `gemini`, `openRouter`, `nanoGpt`, `nvidia`, `deepseek`,
`ollama`, `openAiCompatible`, `local`. `0.7.30` retired ArliAI, Blackbox AI,
Groq, HuggingFace, Minimax, Mistral, OpenAI, Qwen, Vertex AI, Xiaomi MiMo and
Z.ai; `0.7.30.1` retired xAI. Do not reintroduce one without a user asking.

A retired provider name in a stored session or config pack is not an error.
`ChatProvider._providerFromName` maps an unknown name to Gemini, and
`GlobalSettingsService._decodeProviders` skips unknown starred providers, so old
data degrades instead of throwing. Keep that property.

### Adding or changing a provider

Provider state in `ChatProvider` is still duplicated. When touching providers,
check ALL of these or state will silently fail to persist:

1.  `AiProvider` enum in `lib/models/chat_models.dart`
2.  Private field + public getter in `ChatProvider`
3.  `_getProviderModel()` / `_setProviderModel()` switches
4.  `_loadSettings()` prefs read and `saveSettings()` prefs write
5.  `exportSettingsMap()` / `importSettingsMap()`
6.  `_customEndpointFor()`, if the provider talks to a user-owned endpoint
7.  `ApiKeyService._getSecureKeyForAiProvider()` and `_getPrefsKeyForAiProvider()`
8.  `StrategyResolver._strategies` map
9.  `AiProviderInfo.displayName` / `needsApiKey` in `lib/models/chat_models.dart`,
    and `ChatAppBar._buildModelSelector()`
10. `ApiSettingsPanel._getApiKey()` (and the endpoint switches, if applicable)
11. Constants in `lib/utils/constants.dart` (`prefList*`, `prefKey*`, `secureKey*`,
    `prefModel*`, base URL)

This duplication has caused real bugs. See `docs/audits/AUDIT-0.8.md`. Collapsing it
into a map-driven `ProviderState` is still the recommended refactor.

### Endpoints and model discovery

Providers that talk to a server the user owns (`local`, `openAiCompatible`,
`ollama`) resolve their base through `ChatProvider._customEndpointFor`, which
feeds both `AiProviderStrategy.getStreamUrl` and `getModelsUrl`. There is
exactly one copy of that chain; the three inlined copies it replaced were the
reason Ollama streamed against `localhost:11434` no matter what the user typed.
Both endpoint values persist (`airp_ollama_endpoint`,
`airp_openai_compatible_endpoint`), export, and travel in config packs; add new
keys to `LibraryService.importLibrary`'s whitelist as well or an import drops
them.

`OllamaStrategy` accepts a bare root, a `/v1` root, or a full completions URL
and normalizes all three. It lists models over the native `/api/tags`, not
`/v1/models`, because only the former reports family, parameter size and
quantization.

`NvidiaStrategy` filters catalogue entries that have no `/chat/completions`
route (embedding, reranking, `nvclip`, retriever-parse). Selecting one produced
a 404 that looked like an authentication failure.

`local` resolves to `OpenAiCompatibleStrategy`, so it lists models over
`/v1/models` like any other OpenAI-compatible server; llama.cpp and LM Studio
both serve that. A blank Target Model ID means Auto and is resolved by
`ChatProvider.effectiveLocalModel` to the first discovered model, falling back
to `local-model`. Never send the blank string itself: some servers answer a
missing `model` field with a 400.

`ChatProvider.missingCredentialError` runs before every send and reports a
missing key, or a missing endpoint for the providers that need one, into the
reply bubble. Nothing should let an empty credential reach the wire:
`ChatApiService.streamOpenAiCompatible` sets `Authorization: Bearer $cleanKey`
unconditionally, and a gateway answers a bare `Bearer ` with a flat 401 that
reads as a rejected key rather than an absent one. `AiProvider.needsApiKey` is
the single answer to which providers carry a credential; `AiProvider.displayName`
is the single source for the user-facing name. Both live in
`lib/models/chat_models.dart`.

Do not treat a successful model fetch as proof a key works. OpenRouter's
`/api/v1/models` is public and answers in full without any credential.

A model fetch that fails records `ModelRegistryService.lastError(provider)` and
the API panel renders it. Do not go back to swallowing the error in a
`debugPrint`: an empty list after entering a key is indistinguishable from the
key having been ignored. Entering a key or endpoint also schedules a debounced
fetch (`ChatProvider._scheduleModelAutoFetch`), so credentials produce a request
without hunting for the refresh button.

### No vendor SDK, and no `initializeModel`

`ChatProvider.initializeModel` built a `GenerativeModel` plus a `ChatSession`
from the full conversation, reading every attached image off disk to do it, and
ran on session load, provider switch, message edit, delete, regenerate and every
send. Nothing consumed the result: `GeminiStrategy.streamResponse` received the
session as `providerSession` and ignored it, streaming over raw REST from
`history` and `systemInstruction` instead. It also appended a prompt telling
Gemini to wrap its thoughts in `<think>` tags, which never reached a request
because the send path builds its own instruction from
`PromptPipelineService`. All of it was removed in `0.7.30.2` along with the
`google_generative_ai` dependency and the `providerSession` parameter.

If Gemini needs per-request state again, add it to the REST builders in
`ChatApiService`, not to a parallel SDK object.

## Reasoning / thinking handling

AIRP normalizes reasoning output by wrapping reasoning content in `<think>` tags,
parsed by `ReasoningUtils` in `lib/services/reasoning_utils.dart`. Provider-specific
request formats live in `AiProviderStrategy.applyReasoningEffort()`:

`ThinkingFormat` selects the request shape for OpenAI-compatible bodies.
`AiProviderStrategy.applyThinkingFormat` is the single implementation;
`ChatApiService` calls it rather than keeping copies of the switch.

*   `reasoningEffort` emits `reasoning_effort` and OMITS the field when the
    user disables reasoning. Correct only where an absent field means off.
*   `reasoningEffortAlways` emits it on every request including the literal
    `none`. Required where an absent field means default-on.
*   `thinkingObject` emits `thinking: {"type": "enabled"|"disabled"}` plus
    `reasoning_effort` when enabled.
*   `none` sends nothing.

Per provider, verified against vendor docs in `0.7.30.1`:

*   **Gemini / Gemma** do NOT use `reasoning_effort`. Reasoning is requested via
    `generationConfig.thinkingConfig`, built by
    `ChatApiService.buildGeminiThinkingConfig`. Gemini 3+ takes a
    `thinkingLevel` enum (`minimal|low|medium|high`); Gemini 2.x takes a
    `thinkingBudget` in tokens (`0` disables, `-1` is dynamic, and 2.5 Pro
    cannot disable so it gets `-1`). Thought parts are only returned when
    `includeThoughts` is true. Anything that is not a `gemini-<n>` id gets
    `includeThoughts` alone. Nothing is sent at all unless the user has
    reasoning enabled, which preserves each model's own default.
*   **OpenRouter** emits `reasoning_effort`, plus `reasoning: {effort: ...}` for
    the `Max` (`xhigh`) level.
*   **NanoGPT** documents `reasoning_effort` as both the depth control and the
    reasoning-mode signal, `none` through `xhigh`; sent always.
*   **NVIDIA NIM** validates `reasoning_effort` against `low|medium|high` and
    returns 400 for anything else, so `xhigh` is never offered. Nemotron models
    additionally gate reasoning on a `detailed thinking on|off` system prompt,
    which AIRP does not inject because it would overwrite the user's own.
*   **DeepSeek** V4 defaults thinking ON at `high`. It takes
    `thinking: {type: ...}` and a `low|high|max` ladder with no `medium`, so its
    `reasoningEffortOptions` are overridden to match.
*   **Ollama** maps `reasoning_effort` onto its native `think` parameter and
    auto-enables thinking when the field is absent, so it is sent always. It
    accepts `none|low|medium|high` and rejects `xhigh`.
*   **OpenAI Compatible / Local** point at endpoints AIRP cannot introspect;
    they use the conservative omit-when-disabled form.

`GenerationSettingsPanel._effectiveReasoningEffort` steps a stored level down to
the nearest one the active provider accepts, so switching providers does not
silently read as Disabled.

**Do not** add a `ThinkingFormat` member without a provider that implements it,
and do not assume a new provider uses `reasoning_effort` without checking its
docs. Three of the eight do not.

Reasoning is persisted in session JSON for redisplay. The thinking tag is stripped
ONLY from the outbound LLM payload, never from displayed or stored text.

When BYOK web search is on, OpenAI-compatible providers go through
`ChatApiService.streamOpenAiCompatibleWithToolDetection`: the tool is attached to
a STREAMED request and the response is classified from its first deltas. Tool
call fragments mean search; content or reasoning means the model answered and the
live socket is handed to `StreamingCoordinatorService` unchanged. Do not put a
non-streaming round back in front of this — that is what made reasoning stop
streaming whenever web search was enabled. Gemini still uses non-streamed
detection (`performGeminiFunctionDetection`), which splits `thought: true` parts
out via `splitGeminiThoughtParts`.

## Fonts

`lib/utils/app_fonts.dart` is the font catalogue. `ThemeProvider` resolves
through it and the text designer generates its menu from it; do not add a face
to one without the other, which is the bug the table replaced.

`AppFont.key` is persisted under `app_font_style` and travels in config packs.
Never rename a key or repoint one at a different face: it silently resets a
user's font. `AppFonts.resolve` falls back to the system default for unknown
keys, so a config pack from a newer build degrades instead of crashing.

Faces are fetched by `google_fonts` at first use, not bundled.

## Markdown colours

Only three markdown elements are user-tintable: paragraph, italic and bold.
Roleplay prose is narration plus `"dialogue"` plus `*actions*`, with bold for
emphasis; nothing else appears in it often enough to earn a picker.

Everything else still RENDERS. `markdownStructureColor` (headings, list bullets,
strikethrough) tracks `textColor`, `markdownBlockquoteColor` tracks
`subtitleColor`, and `markdownLinkColor` stays distinct because web search
answers are full of links. Do not remove those getters believing the elements
are unused: the Summarize drawer's default voice-samples prompt asks the model
for "Markdown headings per character, with a bulleted list of samples below each
heading", so first-party output depends on headings and lists painting.

`ThemeProvider.updateMarkdownColor` ignores an unknown type rather than
throwing, so a config pack written while the ten retired pickers existed still
applies. Their `color_md_*` prefs keys are left on disk untouched rather than
deleted.

## Token accounting

`lib/utils/token_utils.dart` is the single source for token math. Nothing else
should hand-roll a heuristic; `LorebookService` and the context meter share it so
a budget is spent in the unit the meter reports.

The context meter is anchored, not measured. `ChatProvider._recordUsage` stores
the `prompt_tokens` the provider actually reported and the message count it
covered; `updateTokenCount` estimates only the text added since that anchor and
scales that delta by a per-provider calibration ratio persisted under
`airp_token_calibration`. The delta is allowed to go negative so deleting a
message shrinks the meter. There is deliberately no local tokenizer and no
`countTokens` round trip: AIRP targets a dozen providers with different
tokenizers, a vocab asset would be correct for only one of them, and the round
trip cost a request per turn and failed silently.

Two rules keep the estimate honest:

*   Estimate the prompt that is actually sent. Use the assembled instruction
    from `PromptPipelineService.buildSystemInstruction`, never the raw
    `_systemInstruction` field, and window messages by `historyLimit` exactly as
    `_limitedHistory` does.
*   Normalize usage at the boundary. Providers disagree on shape: Gemini emits
    camelCase `usageMetadata` whose `candidatesTokenCount` excludes thoughts,
    some gateways emit `input_tokens`/`output_tokens`, and reasoning and cache
    figures sit inside `*_details` objects. `TokenUtils.normalizeUsage` maps all
    of them onto `prompt_tokens` / `completion_tokens` / `total_tokens`, and is
    applied on read as well as on write so older sessions still render.

## Lore recognition (formerly the lorebook)

**Read this before touching anything named "lorebook".**

`0.6.11.1` deliberately replaced history-based lorebook injection with
current-input lore recognition. `0.8.0` purged the machinery that removal
orphaned. What exists now:

*   `ChatProvider.recognizeLoreEntriesFromInput(String input)` scans **only the
    message currently being typed**, not conversation history.
*   `LorebookService.matchEntries()` returns a flat list sorted by
    `LorebookEntry.order`. Matching supports keywords, secondary AND/NOT keys,
    constant entries, probability, character filters, inclusion groups, recursion,
    and a token budget.
*   Matches are injected into the system instruction as a single
    `--- Recognized World Lore ---` block by
    `PromptPipelineService.buildSystemInstruction`.
*   A glow preview under the chat input shows the first match. The colour is
    user-configurable.

What was removed and must NOT be reintroduced casually:

*   Positional injection (`beforeCharDefs`, `afterCharDefs`, `emTop`, `emBottom`,
    `anTop`, `anBottom`, `atDepth`, `outlet`).
*   Timed effects (sticky, cooldown, delay) and `LorebookSessionState`.
*   `LorebookEvalResult`, activation traces, and the diagnostics panel.
*   `PromptPipelineService.evaluateLorebooks`.

**Serialization fields are deliberately retained.** `Lorebook.scanDepth`,
`tokenBudget`, `recursionSteps`, `caseSensitive`, `matchWholeWords` and
`LorebookEntry.position`, `depth`, `role`, `sticky`, `cooldown`, `delay`,
`preventRecursion`, `excludeRecursion` are part of the SillyTavern V2
`character_book` spec. The engine ignores most of them, but they must survive an
import/export cycle. Do not delete them as "unused". `test/prompt_pipeline_test.dart`
guards this.

`collectDepthEntries` now handles only the character card's `depthPromptText` and
`postHistoryInstructions`.

## Key files

*   `lib/main.dart`: entry point and Provider setup.
*   `lib/providers/chat_provider.dart`: main state and orchestration.
*   `lib/services/chat_api_service.dart`: raw Gemini REST + OpenAI-compatible streaming.
*   `lib/services/prompt_pipeline_service.dart`: prompt engineering core.
*   `lib/services/strategies/`: strategy implementations per provider.
*   `lib/services/model_registry_service.dart`: model discovery, caching, fetch errors.
*   `lib/models/`: data models for chat, lorebooks, and character cards.
*   `lib/utils/constants.dart`: pref keys, base URLs, defaults, asset lists.

## Open work

`docs/audits/` holds the 0.8 pre-release audit set:

*   `AUDIT-0.8.md`: original defect audit. Gemini streaming bug, four persistence
    bugs, deferred Android release blockers.
*   `AUDIT-0.8-ADDENDUM.md`: data-integrity bugs, streaming performance profile,
    feature backlog.
*   `DEAD-CODE-AND-DOCS.md`: orphan inventory and documentation state.

`AUDIT-0.8.md` section 1 (the Gemini `alt=sse` bug) was FIXED in `0.7.27` and is
guarded by `test/gemini_stream_url_test.dart`. Everything else in all three
documents remains open.

The highest-priority open item is the remaining cause of permanent,
unrecoverable data loss, in `AUDIT-0.8-ADDENDUM.md` section 2:

*   **2.1** a corrupt `airp_sessions` blob wipes every conversation, and the next
    autosave overwrites it.

**2.2** (background stream completions never written to disk) was FIXED in
`0.7.29` and is guarded by `test/session_service_background_persist_test.dart`.

Version history lives in `docs/agents/CHANGELOG.md`.
