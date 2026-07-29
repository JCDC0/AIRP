# AIRP Dead Code and Documentation Inventory

Audit date: 2026-07-29. Against commit `e40fac7` (`0.7.26`), branch `main`.

> **Status: largely actioned.** The lorebook was retired (option "purge dead
> machinery only"), the unambiguous orphans were deleted, the documentation was
> restructured under `docs/`, and the README lorebook chapter was rewritten.
> See "Resolution" at the end for what was done and what remains.

Third document in the 0.8 set, after `AUDIT-0.8.md` (defects) and
`AUDIT-0.8-ADDENDUM.md` (defects, performance, features). This one covers orphaned
code left behind by removed features, and the state of the documentation files.

Note on method: `flutter analyze` is clean and `unused_element` is active in the
default `flutter_lints` set, so there are **zero unused private members** in the
codebase. Everything listed here is public API or cross-file surface, which the
analyzer cannot flag. That is precisely why it accumulated unnoticed.

---

## 1. Confirmed: the lorebook removal was intentional

Your recollection is correct. Verified with
`git log -S "evaluateLorebooks" --all` and `git show 8f9158e`:

```
commit 8f9158e  [0.6.11.1] - Reformat Depth prompt and world lore
Date:   Sun Apr 26 12:39:52 2026 +0800

Replaced the legacy lorebook injection path with current-input lore recognition.
Added matched lore preview glow below the chat input and persisted the
recognizer glow color.
```

The diff deletes `ChatProvider._evaluateLorebooks(List<String> recentMessages)` and
adds `recognizeLoreEntriesFromInput(String input)` in its place. The replacement
method carries this doc comment, written at the time:

```dart
/// Returns lore entries whose keywords match [input] directly.
///
/// This powers the input recognizer flow and intentionally ignores
/// history-based matching.
```

So this was a deliberate design change, not a wiring accident. Section 1 of
`AUDIT-0.8-ADDENDUM.md` has been corrected to say so.

What the commit did **not** do is remove the machinery it orphaned. The result is
the largest single block of dead code in the project, inventoried below.

---

## 2. Dead code inventory

### 2.1 Lorebook engine residue (largest block)

The current live path is `recognizeLoreEntriesFromInput` calling
`LorebookService.evaluateEntries(recentMessages: [trimmed])`, a one-element list.
Everything below serves the removed path.

| Item | Location | Status |
|---|---|---|
| `PromptPipelineService.evaluateLorebooks()` | `prompt_pipeline_service.dart:148` | No caller in `lib/`. Tests only. |
| `ChatProvider._lastLorebookEvalResult` | `chat_provider.dart:254` | Only ever assigned the empty constant. |
| `ChatProvider.lastLorebookEvalResult` getter | `chat_provider.dart:268` | Consumed by one widget, always empty. See 2.2. |
| `buildSystemInstruction` positional branch | `prompt_pipeline_service.dart:30` | `lorebookResult` is always null or empty, so every position case is unreachable. |
| Positional enum values | `lorebook_models.dart` | `beforeCharDefs`, `afterCharDefs`, `emTop`, `emBottom`, `anTop`, `anBottom`, `outlet` never selected at runtime. |
| `lorebook_state_service.dart` (222 lines) | whole file | `LorebookSessionState` appears only as an optional nullable parameter inside `lorebook_service.dart`. Nothing in `lib/` ever constructs one or passes one. |
| Timed effects state machine | `lorebook_service.dart` | Delay, sticky, and cooldown depend on `sessionState`, which is always null. Structurally cannot fire. |
| `scanDepth`, `tokenBudget`, `recursionSteps`, `caseSensitive`, `matchWholeWords` | `lorebook_models.dart:11-18` | Parsed from imported cards, persisted, never read by a live code path and exposed by no UI. |
| `ChatProvider.globalLorebook` getter | `chat_provider.dart:267` | No consumer anywhere. |
| `ChatProvider.setGlobalLorebook()` | `chat_provider.dart:541` | No caller outside its own file. There is no global lorebook editor UI; the only way to populate one is importing a config pack that already contains it. |
| `ChatProvider.lastRecognizedLoreEntries` getter | added by `8f9158e` | No consumer. The input glow uses `previewRecognizedLoreEntry` instead. |
| `ChatProvider.enableLorebook` getter | `chat_provider.dart` | Shadowed by `SettingsProvider.enableLorebook`, which is the live one. See 2.5. |

Test code held against the dead engine: `lorebook_service_test.dart` (935 lines),
`lorebook_models_test.dart` (302 lines), and the `evaluateLorebooks` groups in
`prompt_pipeline_test.dart` (roughly 150 of its 816 lines). All passing, none
exercising a production path.

**Rough total: ~1,300 lines of production code plus ~1,400 lines of test code
serving a path that cannot execute.**

### 2.2 A settings panel that renders an always-empty diagnostic

`character_card_panel.dart:264`:

```dart
_buildLorebookSection(card, themeProvider, scaleProvider,
    chatProvider.lastLorebookEvalResult.traceByEntryId),
```

`_buildLorebookSection` (line 309) accepts the traces map as its fourth parameter
and **never references it**. The map is always empty anyway, since
`_lastLorebookEvalResult` only ever holds the hardcoded empty constant.

So the "Evaluation Tracing" feature the README documents is dead twice over: no data
reaches it, and the widget would ignore the data if it did. Drop the parameter, or
restore both ends.

### 2.3 Fully removed subsystem, one comment left behind

The regex-scripts and formatting-template subsystem introduced in `0.5.12.8` is
gone: `RegexScript`, `FormattingTemplate`, `combineActiveScripts`, `macroContext`,
`activeRegexScripts`, `characterRegexScripts`, `applyRegexScripts`, and
`MessageBubble._applyDisplayTransforms` no longer exist anywhere.

One artifact survives, `chat_provider.dart:599`:

```dart
// accessed via getters (characterLorebook, characterRegexScripts), so
// automatically when _settings!.enableCharacterCard and _settings!.enableLorebook/_enableRegex
```

Every identifier this comment names (`characterLorebook`, `characterRegexScripts`,
`_enableRegex`) has been deleted. Delete the comment.

### 2.4 Superseded export path

`0.7.22` moved the settings library to `ConfigPackService`. The predecessor was left
in place:

- `LibraryService.exportLibraryAsync()`, `library_service.dart:40`, no callers.
- `class ExportOptions`, `library_service.dart:11`, exists only to parameterise it.

That is roughly 90 of the 228 lines in `library_service.dart`.
`LibraryService.importLibrary` and `exportCharacterCard` are still live, so the file
stays, but these two go.

### 2.5 Duplicated ownership of two preference keys

`airp_enable_lorebook` and `airp_enable_character_card` are each written by two
providers:

- `SettingsProvider` at `settings_provider.dart:153` and `:106` (load and save).
- `ChatProvider._saveSillyTavernState` at `chat_provider.dart:577` and the character
  card equivalent at `:565`.

`ChatProvider` writes `_settings!.enableLorebook`, which is `SettingsProvider`'s own
value, so the two writers currently agree and this is a redundant write rather than
a live conflict. It is still two owners for one key, and the next divergence in
either path becomes a silent last-writer-wins bug. Remove the `ChatProvider` writes.

### 2.6 Dead constants

All seven are declared in `lib/utils/constants.dart` and referenced nowhere else:

| Constant | Why it is dead |
|---|---|
| `prefEnableImageGen` | Sole surviving trace of a removed image-generation feature. No other reference in `lib/`, `test/`, or any doc. |
| `prefModelMimo` | `AUDIT-0.8.md` 2.3: MiMo model selection is never saved or loaded. |
| `prefVertexAiEndpoint`, `prefOpenAiCompatibleEndpoint`, `prefOllamaEndpoint` | `AUDIT-0.8.md` 2.1: the three endpoint fields never persist. |
| `prefListVertexAi`, `prefListOpenAiCompatible` | `AUDIT-0.8-ADDENDUM.md` 4: these two providers are absent from `StrategyResolver._strategies` and fall through to the fallback, which synthesises `airp_list_${provider.name}`. The synthesised key differs from the declared one in casing (`airp_list_vertexAi` versus `airp_list_vertexai`). |

The first is genuinely deletable. The other six are symptoms of open bugs in the
first two documents; fix those and the constants become live rather than removed.

### 2.7 Miscellaneous dead public members

- `CharacterCardService.validate()`, `character_card_service.dart:138`. No callers.
  Worth wiring into the import path rather than deleting: it is validation logic that
  currently does nothing while card import accepts anything.
- `FileIOHelper.saveString()` (`:138`) and `FileIOHelper.writeBytes()` (`:203`). No
  callers on either platform implementation.
- `ChatProvider.isCancelled` getter, `chat_provider.dart:54`. Every internal call
  site uses `_streamingCoordinator.isCancelled(streamSessionId)` directly.

### 2.8 Root-level orphan files

- `package.json` contains exactly `{}`. `package-lock.json` contains an empty
  `packages` map. Both are untracked leftovers from the `.kilo` tooling and are
  meaningless in a Flutter project. Delete them, and add them to `.gitignore` if the
  tool recreates them.
- `.gitignore` ignores `suggested_features.md`, which no longer exists.
- `.kilo/` contains a full `node_modules` tree. Correctly untracked via its own
  `.gitignore`, so this is disk noise rather than repo noise, but worth knowing it
  is there.

---

## 3. Documentation

### 3.1 Governance: only one of five documents is tracked

| File | Git status | Problem |
|---|---|---|
| `README.md` | tracked | The only tracked doc. Also the most drifted (3.2). |
| `CLAUDE.md` | **untracked** | Accurate and current, but invisible to collaborators and lost on a fresh clone. |
| `GEMINI.md` | **gitignored** | Explicitly listed in `.gitignore`. Contains the full historical roadmap that exists nowhere else. |
| `docs/AUDIT-0.8.md` | untracked | |
| `docs/*` (this file, the addendum) | untracked | |

The roadmap table in `GEMINI.md` is the single most detailed record of what each
version actually changed, and it is one `git clean` away from gone.

**Recommendation.** Track `CLAUDE.md` and `docs/`. For `GEMINI.md`, pick one:

1. Track it as-is. Simplest, but you then maintain two agent files that already
   disagree (3.3).
2. Move its roadmap table into `docs/CHANGELOG.md`, track that, and let `GEMINI.md`
   stay a thin gitignored local file. This is the better option: the roadmap is
   project history, not agent instructions, and it is currently filed under the
   wrong kind of document.

### 3.2 README drift

The `## Lorebook System` chapter (README lines 260 to 305) describes the pre-0.6.11.1
system in full. Against current behaviour:

| README claim | Reality |
|---|---|
| "the lorebook engine scans recent messages for keyword matches" | Scans only the message currently being typed. |
| "injected into the AI's prompt at their configured insertion position" | All matches go to one fixed location. Positions are inert. |
| "Located in the Settings Drawer under Character Card > Lorebook" | A read-only `ExpansionTile` listing entry names and keys. |
| "Configure global settings: Scan Depth, Token Budget, Case Sensitive, Match Whole Words, Recursion Steps" | None of these have any UI. |
| "Scan Depth ... (default: 2)" | The model default is 15 (`lorebook_models.dart:34`). |
| "View Diagnostics: Review the visual Evaluation Tracing data" | Always empty, and the widget ignores the parameter (2.2). |
| "Tap the + button to add entries, or Import a lorebook JSON file" | No add button and no standalone lorebook import exist. |
| "Position: 8 positions matching SillyTavern" | Dead since 0.6.11.1. |
| "Timed Effects: Delay, Sticky, Cooldown" | Structurally cannot fire (2.1). |
| "Standalone JSON: Import/export lorebook JSON files directly from the lorebook section" | No such UI. |

Roughly 80 percent of that chapter documents software that is not there. Character
card import with an embedded `character_book` does work, and so does the input
recognizer with its glow preview, and neither is documented.

Other README items, some already in `AUDIT-0.8.md` section 6:

- "36+ built-in AI-generated backgrounds". There are exactly 26. Verified: 26 files
  in `assets/`, 26 entries in `kAssetBackgrounds`, no mismatch between them.
- README declares MIT; there is no `LICENSE` file.
- `## Advanced Generation Controls` lists temperature, top P, top K, and max output
  tokens, which is accurate. Add stop sequences and repetition penalties here when
  `AUDIT-0.8-ADDENDUM.md` 5.1 and 5.2 land.

### 3.3 GEMINI.md versus CLAUDE.md

`CLAUDE.md` is the more accurate file. `GEMINI.md` still carries errors that
`CLAUDE.md` has already corrected:

- "Sessions are stored as JSON files." They are one `shared_preferences` string
  under `airp_sessions`. `CLAUDE.md` states this correctly.
- `google_generative_ai` described as the Gemini implementation. Since `0.7.17` it
  is used only for `countTokens`; generation goes through raw REST in
  `chat_api_service.dart`. `CLAUDE.md` says "for Gemini token counting".
- The service list omits `StreamingCoordinatorService`, `ConfigPackService`, and
  `LorebookService`'s current role.

Both files describe `LorebookService` as "keyword-triggered context injection
(SillyTavern parity)" without noting that history scanning was removed in 0.6.11.1.
Whichever file survives needs that qualifier.

### 3.4 Workflow

`.github/workflows/deploy.yml` builds the web app to GitHub Pages on every push to
`main`. It pins `subosito/flutter-action@v2` with `channel: 'stable'` and no
`flutter-version`, so the deployed build tracks whatever stable is on the day it
runs. Pin a version to make the deployment reproducible. `AUDIT-0.8.md` 4.7 already
notes there is no APK release workflow.

---

## 4. Recommendations, on top of `alt=sse` and the lorebook decision

Ordered by value-to-effort. The first item is a prerequisite for the second.

**4.1 Decide restore-or-retire on the lorebook, then make the code say so.**
This is the gate. The current state is the worst of both: the engine is too large
and well-tested to be obviously dead, and too disconnected to work. Two coherent
end states:

- *Restore.* Rewire `evaluateLorebooks` per `AUDIT-0.8-ADDENDUM.md` section 1, then
  build the missing UI (global lorebook editor, scan depth, token budget, entry
  add/edit). This is the larger job, and the README already promises it.
- *Retire.* Delete `lorebook_state_service.dart`, `evaluateLorebooks`, the
  positional branch in `buildSystemInstruction`, the unreachable enum values, the
  associated tests, and rewrite the README chapter around what the input recognizer
  actually does. Roughly 2,500 lines lighter, and the docs become true.

Retire is the honest default given 0.6.11.1 was a deliberate simplification. Restore
is right only if the positional and timed-effects behaviour is something you
actually want back.

**4.2 Track `CLAUDE.md` and `docs/`, and rescue the roadmap out of `GEMINI.md`.**
Cheapest high-value item in this document. One `git add`, one file move. Removes the
risk of losing the only detailed per-version history the project has.

**4.3 Rewrite the README lorebook chapter to match 4.1's outcome.** Whichever way
4.1 goes, this chapter is currently the most misleading thing in the repository. It
is also what a new reader judges the project by.

**4.4 Delete the unambiguous orphans.** No decision required, no behaviour change:
`LibraryService.exportLibraryAsync` and `ExportOptions`, `FileIOHelper.saveString`
and `writeBytes`, `ChatProvider.isCancelled`, the stale comment at
`chat_provider.dart:599`, `prefEnableImageGen`, `package.json`,
`package-lock.json`, and the `suggested_features.md` line in `.gitignore`.

**4.5 Wire up `CharacterCardService.validate()` rather than deleting it.** Card
import currently accepts malformed input silently. The validation already exists.

**4.6 Fix the always-empty diagnostics panel.** Either drop the unused `traces`
parameter from `_buildLorebookSection`, or restore both ends as part of 4.1's
restore branch. Do not leave a settings section that renders nothing.

**4.7 Collapse the duplicated `airp_enable_lorebook` and
`airp_enable_character_card` ownership** into `SettingsProvider` alone. Small, and
it removes a latent last-writer-wins bug before it fires.

**4.8 Pin the Flutter version in `deploy.yml`.** One line, makes web deploys
reproducible.

**4.9 Add a `LICENSE` file** matching the MIT declaration already in the README.

---

## 5. Where this sits in the work order

Slotting into `AUDIT-0.8-ADDENDUM.md` section 7:

1. Gemini `alt=sse`.
2. **Lorebook restore-or-retire decision** (4.1). Gates items 3 and 4 here, and
   replaces "lorebook history evaluation" as step 2 in the addendum's order.
3. Data integrity (addendum 2.1 and 2.2).
4. **Documentation: track the agent files, rescue the roadmap, rewrite the README
   chapter** (4.2, 4.3). Do this immediately after the lorebook decision, while the
   reasoning is fresh.
5. **Delete the unambiguous orphans** (4.4). Good low-risk work to interleave.
6. The rest of the addendum order, unchanged.

---

## 6. Resolution

Actioned on 2026-07-29, on top of `e40fac7`. `flutter analyze` clean,
140 tests passing (was 167; roughly 55 dead-feature tests removed, 28 added).
Net change across `lib/` and `test/`: **-1,561 lines**.

### Done

**Lorebook retired (option: purge dead machinery only).**

- Deleted `lib/services/lorebook_state_service.dart` (222 lines).
- Deleted `PromptPipelineService.evaluateLorebooks`.
- Deleted the positional injection branches in `buildSystemInstruction`
  (`beforeCharDefs`, `afterCharDefs`, `emTop`, `emBottom`, `anTop`, `anBottom`,
  `outlet`) and its `lorebookResult` parameter.
- Deleted the `atDepth` branch and `lorebookResult` parameter from
  `collectDepthEntries`, which now handles only the character card's depth prompt
  and post-history instructions.
- Deleted `LorebookEvalResult`, `LorebookActivationTrace`,
  `LorebookActivationReason`, and the timed-effects gate (`_passTimedEffects`).
- `LorebookService.evaluateEntries` became `matchEntries({lorebook, text,
  characterName})`, returning a flat `List<LorebookEntry>` sorted by order.
- Removed from `ChatProvider`: `_lastLorebookEvalResult`,
  `lastLorebookEvalResult`, `lastRecognizedLoreEntries`, `globalLorebook`,
  `characterLorebook`, `enableLorebook`, `setGlobalLorebook`, `setEnableLorebook`,
  and the hardcoded empty `LorebookEvalResult` in `sendMessage`.
- Removed the dead `traces` parameter from
  `character_card_panel._buildLorebookSection` (section 2.2).

**Deliberately kept**, contrary to the initial plan in section 4.1. `Lorebook`'s
`scanDepth`, `tokenBudget`, `recursionSteps`, `caseSensitive`, `matchWholeWords`
and `LorebookEntry`'s `position`, `depth`, `role`, `sticky`, `cooldown`, `delay`,
`preventRecursion`, `excludeRecursion` are SillyTavern V2 `character_book` spec
fields. The app re-exports imported cards via `LibraryService.exportCharacterCard`
and config pack export, so deleting them would silently destroy that data on
round-trip and break the card import that was explicitly retained. They are now
pure serialization data. A regression test in `test/prompt_pipeline_test.dart`
(`entry round-trips spec fields the engine no longer reads`) guards this.

**Other orphans deleted (section 4.4).**

- `LibraryService.exportLibraryAsync` and `ExportOptions` (~86 lines, superseded
  by `ConfigPackService` in 0.7.22).
- `FileIOHelper.saveString` and `FileIOHelper.writeBytes`.
- `ChatProvider.isCancelled`.
- `ApiConstants.prefEnableImageGen`, plus the orphaned `@Deprecated` annotation
  that had been sitting above it (removing the constant alone would have left the
  annotation attached to `prefDisableSafety`, whose deprecation message is about
  image generation and does not apply).
- The stale regex/formatting comment at `chat_provider.dart:599` (section 2.3).
- `package.json` and `package-lock.json`.
- The `suggested_features.md` line in `.gitignore`.

**Duplicated pref ownership (section 2.5).** `ChatProvider._saveSillyTavernState`
no longer writes `airp_enable_lorebook`; `SettingsProvider` is now the sole owner.
Documented in the method doc comment.

**Documentation (sections 3.1 to 3.3, items 4.2 and 4.3).**

```
docs/agents/ARCHITECTURE.md   canonical agent guide (merged, corrected)
docs/agents/CHANGELOG.md      version history rescued out of gitignored GEMINI.md
docs/audits/                  this file, AUDIT-0.8.md, AUDIT-0.8-ADDENDUM.md
CLAUDE.md  AGENTS.md  GEMINI.md   thin root pointers
```

Root pointers are deliberate: agent tools auto-discover their instruction file at
the repository root, so moving `CLAUDE.md` into a subfolder would stop Claude Code
loading it. `CLAUDE.md` uses the `@docs/agents/ARCHITECTURE.md` import; the other
two use ordinary links. `AGENTS.md` was added as the cross-tool convention.
`GEMINI.md` was removed from `.gitignore`, so the roadmap is now tracked.

The README's `## Lorebook System` chapter was replaced with `## Lore Recognition`,
describing what the code does. The stale "Selective Export" section was rewritten
around Config Packs. "36+ backgrounds" corrected to 26. A `LICENSE` file was added
to match the MIT declaration (item 4.9).

### Not done

- **`CharacterCardService.validate()`** (section 2.7, item 4.5) is still dead.
  Wiring it in would start rejecting cards that currently import successfully,
  which is a behaviour change rather than a cleanup. Left for a deliberate call.
- **`ChatProvider.setEnableCharacterCard`** is dead in the same way
  `setEnableLorebook` was; the settings drawer calls
  `SettingsProvider.setEnableCharacterCard` instead. The `ChatProvider` version
  additionally calls `initializeModel()` for Gemini, so deleting it may be
  hiding a real gap rather than removing dead weight. Needs a look before either
  removing it or routing the UI through it.
- **Item 4.8**, pinning the Flutter version in `deploy.yml`, was left alone as it
  changes CI behaviour.
- ~~The version was **not** bumped.~~ Released as `0.7.27` together with the
  Gemini `alt=sse` fix.
- Everything in `AUDIT-0.8.md` and `AUDIT-0.8-ADDENDUM.md` remains open **except**
  `AUDIT-0.8.md` section 1 (the Gemini `alt=sse` bug), fixed in `0.7.27`.
