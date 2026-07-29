# AIRP Agent Guide

Canonical instructions for any LLM or coding agent working in this repository.
The root `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` are thin pointers to this file,
so tool-specific entry points stay auto-discoverable while the content lives in
one place. Edit this file, not the pointers.

AIRP is a highly customizable, privacy-focused AI chat client built with Flutter.
It is a unified interface for multiple AI providers (Gemini, OpenRouter, Groq, and
others) with a focus on roleplay features and modular architecture.

Current version: `0.7.28` (`pubspec.yaml` `0.7.28+4`). Target: `0.8.0` release.

## Project overview

*   **Stack:** Flutter (Dart), `Provider` for state management, `google_generative_ai`
    for Gemini token counting only, custom REST/streaming for all generation.
*   **Orchestration:** `ChatProvider` is the central state hub
    (`lib/providers/chat_provider.dart`, ~2,600 lines).
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
*   **Test:** `flutter test` (174 tests, all passing)
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

## Adding or changing a provider

Provider state in `ChatProvider` is duplicated across eight-plus places. When
touching providers, check ALL of these or state will silently fail to persist:

1.  `AiProvider` enum in `lib/models/chat_models.dart`
2.  Private field + public getter in `ChatProvider`
3.  `_getProviderModel()` switch
4.  `_setProviderModel()` switch
5.  `_loadSettings()` prefs read
6.  `saveSettings()` prefs write
7.  `exportSettingsMap()` / `importSettingsMap()`
8.  `loadSession()` provider-name if/else chain
9.  `ApiKeyService._getSecureKeyForAiProvider()` and `_getPrefsKeyForAiProvider()`
10. `StrategyResolver._strategies` map
11. Constants in `lib/utils/constants.dart` (`prefList*`, `prefKey*`, `secureKey*`,
    `prefModel*`, base URL)

This duplication has caused real bugs. See `docs/audits/AUDIT-0.8.md`. Collapsing it
into a map-driven `ProviderState` is the recommended refactor.

## Reasoning / thinking handling

AIRP normalizes reasoning output by wrapping reasoning content in `<think>` tags,
parsed by `ReasoningUtils` in `lib/services/reasoning_utils.dart`. Provider-specific
request formats live in `AiProviderStrategy.applyReasoningEffort()`:

*   **OpenAI-compatible** providers use `reasoning_effort: low|medium|high`.
*   **xAI Grok** sends `reasoning_effort: none|low|medium|high`.
*   **OpenRouter** supports `reasoning_effort` and emits `reasoning: {effort: ...}`
    for the `Max` (`xhigh`) level.
*   **Qwen** uses `enable_thinking`; **Z.AI** uses `thinking: {type: ...}`.
*   **DeepSeek / Mistral / MIMO** reasoning models reason automatically; no input
    parameter is sent.
*   **Gemini / Gemma** thinking content is parsed from raw `v1beta`
    `streamGenerateContent` responses where parts carry `thought: true`.

Reasoning is persisted in session JSON for redisplay. The thinking tag is stripped
ONLY from the outbound LLM payload, never from displayed or stored text.

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

The highest-priority open items are the two that cause permanent, unrecoverable
data loss, both in `AUDIT-0.8-ADDENDUM.md` section 2:

*   **2.1** a corrupt `airp_sessions` blob wipes every conversation, and the next
    autosave overwrites it.
*   **2.2** background stream completions are never written to disk.

Version history lives in `docs/agents/CHANGELOG.md`.
