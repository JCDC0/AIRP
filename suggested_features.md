# AIRP Roadmap & Suggested Features

This document tracks AIRP's version history and upcoming milestones.

---

## ✅ Completed Versions

### v0.5.8 — Model Selection, Metadata & Pricing UI

Enhanced ModelSelector with dynamic model listing, cost sorting, and metadata display from OpenRouter (context length, cost per token, provider info).

### v0.5.9 — Model Selector & Response Versioning

Improved model picker UX with filtering, response versioning with fork/regenerate and version navigation, dynamic context management, and loading border animations.

### v0.5.10 — Web Search (BYOK)

Provider-agnostic web search with 6 backends: Provider-native grounding, Brave, Tavily, Serper.dev, SearXNG (self-hosted), and DuckDuckGo (scraping fallback). Results injected as `[WEB_CONTEXT]` blocks prepended to user messages. Configurable max results slider (1–10).

### v0.5.11 — Light Mode System

Full light/dark mode toggle with 20+ semantic color getters in ThemeProvider. Replaced ~170 hardcoded color references across 21 files. Fixed icon consistency with circular styled backgrounds.

### v0.5.12 — The "Silly Tavern" Era

Major roleplay engine release building four subsystems on a shared macro engine:

- **Lorebook System** — SillyTavern Character Book V2 parity with keyword-triggered context injection, 8 insertion positions, timed effects, inclusion groups, recursive scanning, and token budgeting.
- **Regex Engine** — Post-processing pipeline with 3 modes (permanent, display-only, prompt-only) targeting user input, AI output, world info, and reasoning independently.
- **Formatting Templates** — Template-based output wrapping for dialogue, thought, narration, and character name styling with macro resolution.
- **Macro Engine** — Shared foundation with 25+ macros (identity, time, randomization, variables, conditionals, utility).
- **Preset System** — Importable config packs bundling system prompt, generation settings, lorebook, regex, and formatting. Partial SillyTavern preset import.
- **Character Card V2** — Full spec editor with 11+ fields, embedded lorebook auto-loading, PNG/JSON import/export with round-trip fidelity.
- **Infrastructure** — Split monolithic panels into 5 focused widgets, fixed 7 bugs, expanded settings drawer to 12 tiles, normalized SharedPreferences keys.

### v0.5.13 — Web Compatibility & Device Detection

- Centralized `FileIOHelper` with conditional imports eliminating all `dart:io` from UI/service layers for web compatibility.
- Improved device detection using `defaultTargetPlatform` + Material Design `shortestSide` breakpoints.
- Updated layout defaults for phone/tablet/desktop scaling.
- Pending: Image gen render pipeline, attachment pipeline fixes.

### v0.5.14 — Multi-Provider Integration

Integrated 10 new API providers (Vertex AI, Blackbox AI, Minimax, OpenAI Compatible, Deepseek, Ollama, Qwen, xAI, Z.ai, Mistral) using existing OpenAI-compatible pipeline. Added endpoint configurations for custom hostings. Fixed system prompt persistence on web reload. Refined fork feature to spawn single-message conversations. Patch releases (0.5.14.1–0.5.14.8) streamlined provider/model settings, fixed text input bugs, added starred providers, expanded model details display, and fixed conversation bookmark/deletion persistence.

---

## 🚀 v0.6 — Architecture, Feature Maturity & Library System

*Focus: Decompose the god class, fix lorebook evaluation, establish per-subsystem libraries, rename ST-derived features for AIRP identity, and merge redundant configuration systems.*

### Phase 1: ChatProvider Decomposition

The 3,292-line `ChatProvider` god class must be broken into focused services:

- **SessionService** — Session CRUD, auto-save, merge, fork, switch.
- **ModelRegistryService** — Model list state, fetching, deserialization. Remove 10 empty `fetch*Models()` stubs.
- **ApiKeyService** — Secure storage migration and provider key management.
- **WebSearchOrchestrator** — Search provider selection and BYOK dispatch.
- **ImageGenService** — Image generation routing, download, and base64 storage.
- Break `sendMessage()` into focused helper methods with clear separation of grounding, streaming, and post-processing phases.

### Phase 2: Lorebook Engine Fix & Enhancement

Fix the core keyword matching bug (default `scanDepth=2` is too small — most keywords never appear in a 2-message window):

- Increase default scan depth to 10–20 messages.
- Add activation debug logging (show which entries activated and why in a debug panel).
- Add match-highlighting feedback in the lorebook entry list.
- Test with real character cards containing 10+ entries across varied keywords.
- Consider semantic/fuzzy keyword matching as an optional enhancement.

### Phase 3: Feature Identity Pass

Rename ST-derived subsystems to establish AIRP's own identity while maintaining import compatibility:

- Lorebook → **World Lore** (or Context Library)
- Regex Scripts → **Text Transforms**
- Formatting Templates → **Style Rules**
- Custom Rules & Presets → **Config Packs** (merged — see Phase 5)
- Update all UI labels, SharedPreferences keys (with migration), and documentation.

### Phase 4: Per-Subsystem Library System

Add an in-app library for each subsystem so users can **swap resources instantly** without file import/export. All entries are stored locally and accessible via a quick-select list:

#### Character Card Library

- Save any loaded character card to the local library with one tap.
- Quick-swap cards from a selectable list in the Character Card panel (dropdown or list view).
- Each stored card includes its embedded lorebook, alternate greetings, and depth prompt.
- Delete cards from the library individually.

#### World Lore Library (Lorebook)

- Save/load named lorebook sets from a local library.
- Quick-swap between different world contexts (e.g., "Fantasy Kingdom," "Sci-Fi Station").
- Merge lorebook sets when applying (add new entries, skip duplicates by key match).

#### Text Transform Library (Regex)

- Save/load named regex script sets.
- Quick-apply curated transform packs from the library.
- Built-in starter packs (e.g., "Clean Markdown," "Roleplay Enhancer").

#### Style Rules Library (Formatting)

- Save/load named formatting templates.
- Quick-swap visual styling with a single tap.
- Built-in defaults beyond the current pass-through templates (bold character names, italic thoughts, styled dialogue).

### Phase 5: Merge Config Packs & Save/Load Library

Currently two overlapping systems exist:

- **Custom Rules & Presets (CRP)** — Targets generation parameters, system prompt, custom rules, and optional lorebook/regex/formatting.
- **Save & Load Library (SLL)** — Exports/imports the entire app state as `.airp` files with per-category toggles.

**Merge plan:**

**Config Packs** (formerly CRP) handles targeted, shareable configuration:

- Bundles: system prompt, generation settings (temperature, top_p, top_k, max_tokens), custom rules, and optionally attached lorebook/regex/formatting from the library.
- Quick-apply from a local pack list — no file picker needed.
- Import/export as `.json` for sharing.
- Custom rules remain as toggle-able text directives stacked on the advanced prompt.

**Full Backup** (formerly SLL) handles complete app state:

- Single unified `.airp` file containing: conversations, system prompt, advanced prompt, generation parameters, layout scaling, visuals, character card + all library entries (character cards, lorebooks, regex sets, formatting templates, config packs), model history, and provider settings.
- Smart import system handles the god JSON: per-category toggle on import preview, conversation merge by ID, prompt merge by title, library entries merged by name (no duplicates).
- Export/import flow simplified: one button to export everything, one to import with a category picker.

### Phase 6: Widget Decomposition & UI Cleanup

- Split `message_bubble.dart` (1,217 lines) into: markdown renderer, image viewer, version navigator, context menu.
- Split `chat_input_area.dart` (1,313 lines) into: toggle bar, attachment handler, input field.
- Remove per-field copy/paste buttons from Character Card panel (24+ redundant buttons). Replace with a single "Copy Card JSON" action.
- Extract lorebook sub-section from `character_card_panel.dart` into its own widget.
- Deduplicate particle effects in `effects_overlay.dart` into a shared `ParticleEffect<T>` base.
- Audit `Consumer<ChatProvider>` over-rebuilds and migrate to fine-grained `Selector` patterns.

### Phase 7: Pending v0.5.13 Completion

- Fix image gen render pipeline (download bytes → base64 → `aiImage` field → `Image.memory()`).
- Fix PDF/doc/docx silent drop in attachment pipeline (surface errors via snackbar).
- Add provider capability guards for image gen (disable button when provider doesn't support it).
- Fix DDG query URL encoding.
- Add explicit unsupported-format feedback.

### Phase 8: Documentation & Polish

- Rewrite `README.md` with renamed features and updated architecture.
- Update `GEMINI.md` to reflect new service boundaries.
- Add inline code documentation for all new services.

---

## Commit Message Format

- **Title**: `[version] - [title]` (read `lib/utils/version.dart` for current version)
- **Content**: Plain-text summary of all changes (no markdown formatting)
- **Source**: Use `git diff` to identify all changes
