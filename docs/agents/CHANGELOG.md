# AIRP Version History

Per-version scope for the 0.7.x line and the 0.8.0 release.

This table previously lived only in `GEMINI.md`, which was gitignored. It was the
most detailed record of what each version changed and existed nowhere else in the
repository. It is tracked here so it survives a fresh clone.

`WS` is the workstream label used during the 0.8 refactor planning.

| Version | WS | Scope | Status |
|---|---|---|---|
| 0.7.18 | F | Clickable markdown links (`url_launcher` + `onTapLink`); remove deprecated long-press 4-icon menu; bubbles unfrozen; keep `MessageBubbleActions` (regen/copy/edit/delete/branch/version picker) | done |
| 0.7.19 | E | Inline API & Model panels (drop `ExpansionTile` wrappers); BYOK copy/paste; Load/Refresh Models button next to BYOK; removed header reload button | done |
| 0.7.19.1 | E | Replace header texts with `Divider`; dynamic Load-vs-Refresh label (empty list to Load, else Refresh); drop per-provider `Refresh Model List` button; spacing 4px | done |
| 0.7.19.2 | E | Remove duplicate divider (SettingsHeader already has one); spacing 4 to 2; local/ollama refresh fallback (endpoint-adjacent Load/Refresh button); sync `version.dart` | done |
| 0.7.20 | C | Remove reasoning storage toggles (efficiency/persist/developer/raw-edit/restore-backup); reasoning ALWAYS displayed via per-bubble "Show Thought Process", ALWAYS stripped from OUTBOUND payload, persisted in session JSON. Removed `_shouldStripReasoningFromStorage`, `_normalizeReasoningStorageMode`, `_applyReasoningStoragePolicyGlobally`, `SessionService.applyReasoningStoragePolicyGlobally`, backup keys, `ChatMessage.sanitizeForStorage`. `editMessage` always re-prepends reasoning; `getEditableMessageText`/`getReadOnlyReasoningForEdit` always split. Keeps `enableReasoning` + effort dropdown (outbound request control). Fixes both-enabled bug + completion-truncation bug. | done |
| 0.7.21 | D | Drop `WebSearchMode` (Smart/Eager) enum + dropdown + `prefKeyWebSearchMode`; single unified always-on hint (`buildWebSearchSystemHint({maxRounds, resultCount})`) with both max searches + max results injected + a light RP guardrail. Fix thinking-blocks-disappear-when-web-search-on: non-streamed direct answers now wrap `det.reasoning` in think tags via `_composeDirectAnswer` + carry `reasoningRecovered` through `_WebSearchLoopResult` and the fast-path `copyWith`. | done |
| 0.7.22 | A | Unified `ConfigPack` (`lib/models/config_pack.dart` + `lib/services/config_pack_service.dart`) capturing ALL settings-drawer state except conversations + API keys (chat+settings+theme+vfx+scale export maps, `sessions` stripped); in-app named packs (`airp_config_packs` SharedPreferences, newest-first) with tap-to-apply (overwrite, confirm) / rename / delete / export-to-file / import-from-file; tolerant SillyTavern Chat-Completion preset IMPORT-only (`importSillyTavernPreset`: ordered `prompts`+`prompt_order` to systemInstruction, generation fields to generation bucket, `sourceFormat='sillytavern'`). Removed per-rule CRUD + `airp_custom_rules` store, `SystemPreset` model + `preset_model.dart`, `LibraryService.exportPreset`/`_importCustomRules`. Removed `SizedBox(height:2000)` pit (now responsive `MediaQuery.height*0.6` + per-tab `SingleChildScrollView`). | done |
| 0.7.23 | B | Snapshots tab to embedded conversation list; each entry shows created-timestamp subtitle (parsed from session `id` epoch-millis) + message count, with per-conversation export (`.airp`) + delete, plus "Import .airp" (merges via `LibraryService.importLibrary`) and "Export All" (conversations-only `.airp`); dropped the full-state category toggles (ConfigPack handles settings now). Fixed `sessions` preview-path bug (`data['settings']['sessions']` to top-level `data['sessions']`). | done |
| 0.7.24 | G | Search drawer: magnifying-glass icon on the leftmost header (next to menu) + Ctrl/Cmd+F; `SearchProvider` computes matches (one `SearchMatch` per occurrence across `chatProvider.messages`); find-bar overlay (`ChatSearchBar`) slides down from under the AppBar with "x / y" count + prev/next + Esc to close; matches highlighted on `MessageBubble` via `isSearchCurrent`/`isSearchMatch` (border + bloom glow); current match auto-scrolled into view via `Scrollable.ensureVisible` (per-message `GlobalKey` map in `ChatMessagesListState.scrollToMessage`); Ctrl/Cmd+G = next, Shift/Cmd-alt variants = prev; query persists while open, clears on close; `ChatMessagesList` converted StatelessWidget to StatefulWidget; `themeProvider.bloomGlowColor` reused as the highlight accent. | done |
| 0.7.25 | H | Summarize drawer: `Icons.compress` tab on the leftmost header (3rd icon); `SummarizeDrawer` slides from left with two editable monospace prompt fields (compress + voice samples, defaults `SummarizeDefaults.defaultCompressPrompt`/`defaultVoiceSamplesPrompt`, persisted via `airp_summarize_compress_prompt`/`airp_summarize_voice_prompt`/`airp_summarize_pair_count` SharedPreferences) and a 1-20 slider (default 5, counts assistant-turn pairs anchored on the assistant side); **Compress** issues two sequential one-shot LLM calls via `ChatProvider._oneShotGenerate` (Gemini uses `performGeminiFunctionDetection` with empty functionDecls; OpenAI-compatible uses `requestOpenAiCompatibleWithToolDetection` with empty tools; uses active strategy/key/url/model; generation settings passed through) producing a narrative summary + voice samples; appends both as `**[Summary]**`/`**[Voice Samples]**` AI messages to the current chat; creates a fresh `ChatSessionData` = [summary]+[voices]+[last N pairs] (walks backwards anchoring on assistant turns, copies preceding user turns) via `_sessionService.prependSession`; auto-switches to it; original conversation left intact (only appended-to). `SummarizeDrawer` shows inline status; closes on success. | done |
| 0.7.26 | I | Header layout, title bug, word highlight, context counter, timestamps | done |
| 0.7.27 | J | **Fix Gemini/Gemma streaming (`alt=sse`).** `streamGenerateContent` was requested without `alt=sse`, so it returned a pretty-printed JSON array instead of Server-Sent Events; no line carried the `data: ` prefix the parser looks for, every line was skipped, and the stream completed empty behind an HTTP 200. Gemini and Gemma streaming had been silently dead since `0.7.17` (nine versions). URL construction extracted to `ChatApiService.buildGeminiStreamUrl` and guarded by `test/gemini_stream_url_test.dart`. Added an empty-stream notice (`emptyGeminiStreamNotice`) so a 200-with-no-content reports `blockReason`/`finishReason` instead of rendering a blank bubble; reasoning-only responses are left to the existing `StreamingCoordinatorService` recovery path. Also lands the lorebook retirement: purge the machinery orphaned by `0.6.11.1`. Deleted `lorebook_state_service.dart`, `PromptPipelineService.evaluateLorebooks`, positional injection in `buildSystemInstruction`, `LorebookEvalResult` + activation traces, timed effects, and the always-empty diagnostics panel. `LorebookService.evaluateEntries` became `matchEntries` returning a flat order-sorted list. SillyTavern V2 spec fields retained for import/export fidelity. Also removed `ExportOptions` + `LibraryService.exportLibraryAsync` (superseded by ConfigPack in 0.7.22), `FileIOHelper.saveString`/`writeBytes`, `ChatProvider.isCancelled`, `prefEnableImageGen`, and the stale regex/formatting comment. Docs restructured under `docs/`; `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `LICENSE` now tracked. | done |
| 0.8.0 | — | Target release. Remaining scope in `docs/audits/`. | in progress |

## Key decisions

Preserve these across context compaction.

*   **Reasoning:** persist in session JSON for redisplay; strip the thinking tag
    ONLY from the outbound LLM payload, never from displayed or stored text. The
    per-bubble "Show Thought Process" chip stays; no new input-area control.
*   **Summarize branching:** the new conversation is [narrative summary] + [voice
    samples] + [last N assistant/user pairs]. The slider counts assistant turns and
    pairs are anchored on the assistant side. The original conversation is untouched.
*   **Config Packs:** capture ALL settings-drawer state except conversations and API
    keys. SillyTavern support is IMPORT-ONLY. The old per-rule store was discarded
    with no migration.
*   **Web search:** no Smart/Eager modes. Tell the LLM it has the tool with the
    configured limits and let it decide. Reasoning must remain visible during tool
    calls.
*   **Lore:** history scanning was removed deliberately in `0.6.11.1` and is not
    coming back without an explicit decision. Current-input recognition is the whole
    feature. See the lore section in `ARCHITECTURE.md`.
