# AIRP Roadmap & Suggested Features

This document outlines the planned progression for AIRP, transitioning from its current state toward a highly customizable, "Silly Tavern" inspired roleplay client.

---

## 🚀 Version Roadmap

### ✅ v0.5.8 - Enhanced Model Selection, Metadata & Pricing UI [COMPLETE]
*Focus: Introduced comprehensive model discovery and pricing transparency.*

- **Enhanced ModelSelector:** Dynamic model listing with metadata and pricing information from OpenRouter.
- **Cost Sorting:** Users can sort models by cost for budget-conscious selection.
- **Model Metadata UI:** Display context length, cost per token, and provider information.

### ✅ v0.5.9 - Enhanced Model Selector & Response Versioning [COMPLETE]
*Focus: Advanced model interaction and conversation management.*

- **Improved Model Selection UX:** Refined model picker with better discoverability and filtering.
- **Response Versioning:** Fork conversations and regenerate responses with version tracking.
- **Dynamic Context Management:** Better handling of token limits and context allocation.
- **Loading Animations:** Randomized loading border animations and UI polish.

### 📦 v0.5.10 - Expanded Web Search (BYOK) [COMPLETE]
*Focus: Providing privacy-focused, flexible web search capabilities that bypass costly provider-native tools.*

- **Web Search Panel:** A new settings section under the Settings Drawer (beneath "Generation Parameters"). [COMPLETE]
- **Tiered Search Systems:** [COMPLETE]
    - **Provider (default):** Delegates to the AI provider's native grounding (Gemini Search, OpenRouter web plugin). No change to existing behaviour.
    - **Brave Web Search:** High-quality results with a Bring Your Own Key (BYOK) system. Secure key storage. [COMPLETE]
    - **Tavily:** AI-optimised search with pre-summarised results. BYOK with secure key storage. 1 000 free searches/month. [COMPLETE]
    - **Serper.dev:** Google Search results in clean JSON. BYOK with secure key storage. 2 500 free searches included. [COMPLETE]
    - **SearXNG:** Support for self-hosted SearXNG instance URLs with IP:port normalisation and a live validation button. [COMPLETE]
    - **DDG Scraping:** A free fallback using DuckDuckGo HTML scraping (no key required). Warning displayed in UI. [COMPLETE]
- **Context Injection:** Search results are formatted as a `[WEB_CONTEXT]` block and prepended to the user message before sending to the AI. This ensures per-message freshness and works uniformly across all backends (Gemini streaming and OpenAI-compatible). Native provider grounding is only used when the backend is set to "Provider". [COMPLETE]
- **Max Results slider:** User can configure 1–10 results per query. [COMPLETE]

### ✅ v0.5.11 - Light Mode System [COMPLETE]
*Focus: Full light/dark mode theming across the entire application.*

- **Light Mode Toggle:** Added to Visuals & Atmosphere tab above Global Interface Font, persisted via SharedPreferences. [COMPLETE]
- **Semantic Color System:** 20+ adaptive color getters in ThemeProvider (textColor, surfaceColor, dropdownColor, borderColor, containerFillColor, etc.) that swap between light and dark palettes. [COMPLETE]
- **Full Codebase Coverage:** Replaced ~170 hardcoded color references across 21 files (screens, widgets, settings panels) with semantic getters. [COMPLETE]
- **Settings Integration:** Light mode state included in export/import and reset-to-defaults flows. [COMPLETE]
- **Icon Consistency Fix:** Applied circular `inputFillColor` backgrounds with static borders to attachment, scroll-to-top, scroll-to-bottom, and zoom buttons matching the style of image gen, web search, and reasoning toggles. Converted send button from `IconButton.filled` to Container-based circular styling with proper light/dark mode color adaptation. [COMPLETE]

### 📦 v0.5.12 - The "Silly Tavern" Era [IN PROGRESS]
*Focus: Advanced roleplay features, SillyTavern-compatible data formats, and deep immersion systems. Builds four subsystems on a shared macro engine foundation.*

- **Scaffolding & Bug Fixes:** [PENDING]
    - Split monolithic `system_prompt_panel.dart` (1401 lines, 3 merged sections) into 5 focused panel widgets: Main System Prompt, Character Card, Presets, Regex, Formatting.
    - Fix double JSON export in character card and preset export handlers.
    - Fix `_cardSaveTimer` not cancelled in `dispose()` (race condition).
    - Remove dead kaomoji migration code.
    - Decouple Rules Preset dropdown from Main Prompt's `savedSystemPrompts` list.
    - Fix `enable_character_card` toggle not persisting across restarts.
    - Add `iTXt` compressed chunk support to PNG character card parser for V2 card compatibility.
    - Normalize inconsistent SharedPreferences keys to `airp_` prefix convention.
    - Settings drawer expanded from 8 to 12 top-level ExpansionTiles.
    - Update `GEMINI.md` stale references and `pubspec.yaml` version sync.
- **Data Models (3 new model files):** [PENDING]
    - `lorebook_models.dart` — Full SillyTavern Character Book V2 spec parity. `Lorebook` container (name, scanDepth, tokenBudget, recursionSteps) and `LorebookEntry` with all spec fields plus ST extensions: keys, secondary keys (optional filter), content, strategy (constant/triggered), insertion position (8 positions matching ST: beforeCharDefs, afterCharDefs, ANTop, ANBottom, atDepth, EMTop, EMBottom, outlet), depth/role, probability, inclusion groups with weight-based scoring, sticky/cooldown/delay timers, recursion controls. Import handles both V2 spec field names and SillyTavern internal names (keys↔key, secondary_keys↔keysecondary, insertion_order↔order, enabled↔!disable). Nullable booleans preserved for global default inheritance.
    - `regex_models.dart` — `RegexScript` matching ST's `RegexScriptData`: id, name, findPattern, replaceWith, trimStrings (List), scope (global/scoped/preset), placement-based targeting (userInput, aiResponse, worldInfo, reasoning), ephemerality (displayOnly, promptOnly), depth range, macro mode (none/raw/escaped), sortOrder. Import converts ST's numeric `placement[]` array and inverted `disabled` flag.
    - `formatting_models.dart` — `FormattingTemplate` and `FormattingRule` for dialogue/thought/narration/characterName wrapping with `{{macro}}` placeholder support.
    - `CharacterCard` model updated with missing V2 spec fields: `creatorNotes`, `tags`, and `characterBook` (the embedded lorebook, parsed from `data.character_book`). Round-trip fidelity for all spec fields. `extensions.depth_prompt` explicitly parsed for depth-based prompt injection.
- **Macro Engine (shared foundation for all subsystems):** [PENDING]
    - `macro_service.dart` — Static `MacroService.resolve()` with recursive `{{...}}` token parser (depth-capped at 20). Core macros: `{{char}}`, `{{user}}`, `{{description}}`, `{{personality}}`, `{{scenario}}`, `{{persona}}`, `{{mesExamples}}`. Time macros: `{{time}}`, `{{date}}`, `{{weekday}}`, `{{isotime}}`, `{{isodate}}`, `{{datetimeformat::FORMAT}}`. Variable macros: `{{getvar}}`, `{{setvar}}`, `{{incvar}}`, `{{decvar}}`. Conditionals, randomization (`{{random::a::b}}`, `{{roll::NdM}}`), utility (`{{newline}}`, `{{trim}}`). Legacy aliases: `<USER>` → `{{user}}`, `<BOT>` → `{{char}}`. Variables persisted via SharedPreferences.
- **Lorebook Service (keyword-triggered context injection):** [PENDING]
    - `lorebook_service.dart` — Static `LorebookService.evaluateEntries()`: scans last N messages for keyword matches (primary keys + optional secondary filter with AND/NOT logic), applies probability rolls, character filters, inclusion group conflict resolution (weight-based), recursive entry scanning. Returns activated entries grouped by insertion position for prompt construction.
    - `lorebook_state_service.dart` — Per-session state tracking for sticky counters, cooldown timers, delay thresholds, activation history. Persisted to SharedPreferences keyed by session ID.
    - `parseFromCharacterBook()` / `toCharacterBook()` — SillyTavern V2 `data.character_book` round-trip serialization with field name normalization.
- **Regex Engine Service (post-processing pipeline):** [PENDING]
    - `regex_service.dart` — Static `RegexService` with target-filtered script application. Three modes: `applyPermanent()` (modifies stored text), `applyDisplayOnly()` (render-time only, stored text unchanged), `applyPromptOnly()` (alters sent prompt, stored text unchanged). Macro-resolved patterns via MacroService. Dart RegExp flag mapping (caseSensitive, dotAll, multiLine, unicode).
- **Formatting Service (template-based output wrapping):** [PENDING]
    - `formatting_service.dart` — Static `FormattingService.applyTemplates()` applying ordered `FormattingRule` pattern matches with macro-resolved template strings. Built-in defaults for dialogue, thought, narration, and character name styling.
- **Preset System (importable configuration packs):** [PENDING]
    - Extended `SystemPreset` with optional lorebook entries, regex scripts, and formatting template fields.
    - AIRP-native preset import/export with full fidelity. Partial SillyTavern preset import: extracts temperature, top_p, top_k, max_tokens, main prompt, and post-history content from ST OpenAI presets; discards incompatible `prompts[]`/`prompt_order[]` structure with user warning.
    - Replaces "Custom Rules & Presets" section. Existing custom rules data migrated on first load.
- **ChatProvider Integration (prompt pipeline modifications):** [PENDING]
    - New state: global/character lorebooks, global/scoped regex scripts, formatting template, enable toggles. All persisted via SharedPreferences.
    - `_buildSystemInstruction()` modified: lorebook entries injected at correct positions relative to character card block. `extensions.depth_prompt` injected at specified depth. `atDepth` entries returned separately for message-level splicing.
    - `sendMessage()` modified: pre-send user input regex, at-depth lorebook entry injection into message history (OpenAI path: spliced as system-role messages; Gemini path: system instruction addenda), streaming display-only regex on `contentNotifier`, post-stream permanent regex on stored text.
    - `MessageBubble._buildBubble()` modified: formatting templates and display-only regex applied to visible text before Markdown rendering.
    - Character card import auto-loads embedded `character_book` as character-scoped lorebook and `extensions.regex_scripts` as scoped regex scripts.
- **UI Panels (5 new/refactored panel widgets):** [PENDING]
    - Character Card Panel with collapsible Lorebook sub-section: global settings (scan depth, token budget, case sensitivity, whole-word, recursion steps), entry list with title/key badges/strategy icons/enabled switches, full entry editor (tabbed: Basic, Filters, Position, Priority, Groups, Character Filter, Timed Effects, Recursion). Import/export lorebook JSON. UI for `postHistoryInstructions`, `alternateGreetings`, and `creatorNotes`.
    - Regex Panel: master toggle, `ReorderableListView` with drag handles, per-script edit dialog (find/replace inputs, trim strings, affects checkboxes, scope, flag chips, ephemerality, depth range, macro mode), test panel with live preview, import/export regex sets.
    - Formatting Panel: master toggle, rule list with type icons, edit dialog with pattern/template inputs and macro helper buttons, preview panel, import/export templates.
    - Preset Panel: import `.json` files, list with apply/delete/export, auto-set system prompt + generation params + optional lorebook/regex. Backward-compatible custom rules sub-section.
    - All panels use `ThemeProvider` semantic colors and `ScaleProvider` font sizing consistently.
- **Persistence & Serialization:** [PENDING]
    - Library export/import (`.airp` format) extended with lorebook, regex scripts, and formatting template sections.
    - Character card JSON export embeds `character_book` and scoped regex into V2 format. Import round-trips all spec fields.

### 📦 v1.0.0 - Total Codebase Overhaul: Optimization, High Efficiency & Release [PENDING]
*Focus: Deep architectural restructuring, addressing technical debt, eliminating redundancies, and maximizing app-wide performance. Final release version.*

- **Comprehensive State Refactoring:** Move beyond just breaking up the 2000+ line `ChatProvider.dart`. Re-evaluate all top-level providers (`ChatProvider`, `ThemeProvider`, `ScaleProvider`), extracting heavy complex logic into precise, atomic services (e.g., `ConversationService`, `WebSearchManager`, `TokenTrackingService`, `AIStreamingOrchestrator`). [PENDING]
- **API & Networking Efficiency:** Consolidate HTTP, streaming logic, and serialization across all AI APIs and web search endpoints. Implement aggressive deduplication of request formatting and unified retry/error pipelines (rate limits, bot challenges like DDG blocking). [PENDING]
- **Widget-Tree Optimization & Rebuild Isolation:** Audit the entire UI layer (`screens/`, `widgets/`, `settings_panels/`) to strictly eliminate unnecessary deep-tree rebuilds. Transition monolithic `Consumer` and `StatefulWidget` states over to fine-grained `Selector` models for pure UI responsiveness. [PENDING]
- **VFX Optimization:** Consolidate `EffectsOverlay` logic to use a single `CustomPainter` or a lightweight particle system for better performance on mobile. [COMPLETE - Uses CustomPainter]
- **Data Persistence Strategy & File I/O:** Complete overhaul of secure storage and SharedPreferences I/O. Decouple storage read/writes from the main UI thread via batched operations yielding zero-lag interactions. [PENDING]
- **GitHub Release Build:** Finalize APK/AAB and desktop builds for public distribution as a v1.0.0 release. [PENDING]

---
 **Phased Instructions:**
1. **[COMPLETE] Phase 1 (v0.5.8-v0.5.9):** Enhanced ModelSelector with refresh button, long-press descriptions, and cost sorting using OpenRouter metadata. Response versioning and conversation forking implemented.
2. **[COMPLETE] Phase 2 (v0.5.10):** Built `WebSearchService` implementing Brave, Tavily, Serper.dev, SearXNG, and DDG backends. Added `WebSearchSettingsPanel` beneath Generation Parameters in the drawer. Context injected as `[WEB_CONTEXT]` blocks prepended to user message before AI calls.
3. **[COMPLETE] Phase 3 (v0.5.11):** Light mode system with full codebase color adaptation. Implemented 20+ semantic color getters in ThemeProvider, replaced ~170 hardcoded color references across 21 files. Fixed icon consistency (circular backgrounds with static borders for attachment, scroll, zoom, and send buttons).
4. **[IN PROGRESS] Phase 4 (v0.5.12):** Implement Lorebook system with full SillyTavern Character Book V2 parity, Regex Engine with ephemeral modes, Macro Engine as shared foundation, Advanced Formatting templates, and importable Preset packs. Update `CharacterCard` model with missing V2 spec fields (`creatorNotes`, `tags`, `characterBook`). Parse `data.character_book` (not `extensions.world`) for embedded lorebooks. Split `system_prompt_panel.dart` into 5 panel widgets. Fix 7 existing bugs. Settings drawer expands to 12 tiles. Incremental commits per subsystem (0.5.12.1 through 0.5.12.10).
5. **Phase 5 (v1.0.0):** Execute a complete codebase efficiency overhaul. Break apart God-classes (`ChatProvider.dart`, monolithic UI components) into atomic, decoupled services. Audit the entire project for duplicated logic, streamline API and networking code, minimize widget rebuilds with granular `Selector` models, and decouple storage I/O from state updates for zero-lag interactions. Produce final release build for GitHub distribution.

**Constraint:** Ensure all UI changes respect `ScaleProvider` and `ThemeProvider` for consistent Material 3 styling and responsive scaling.

**Commit Message Format**
- **Title Header** - Read util/version.dart for the version number and input a header title that summarizes what is created, create the title in the format version number and your title
- **Format** - Example if version reads 1.0.0 then output as: 1.0.0 - your title

- **Content Summary** - Outline all the changes made or all the features implemented, for better understanding, use git diff or other methods to find the changes or additions in the codebase in the terminal for an understanding of all changes or all features implemented
- **No Markdown Formatting** - Don't use markdown formatting with bullet points, asterisks, this is to make the text more easily copy pastable.

- **FOR THE LLM READING THIS** - Please ensure that the commit message is concise yet comprehensive, providing a clear overview of the changes made. The title should be brief and to the point, while the content summary should give enough detail to understand the scope and impact of the changes without needing to refer back to the code. Avoid using technical jargon or abbreviations that may not be universally understood, and focus on the practical implications of the changes for users and developers alike. Do not perform any git operations, just generate the commit message based on the changes made in the codebase.