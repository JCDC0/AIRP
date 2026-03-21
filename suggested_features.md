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

*Focus: Establish per-subsystem libraries, integrate user-requested features/revisions, and finalize optimizations (Widget and God Class decomposition) sequentially safely at the end.*

### ✅ Phase 1: Lorebook Engine Fix & Enhancement (Completed in v0.6.2)
- Added activation debug logging (Evaluation Tracing) and matched-highlighting feedback.
- Migrated SharedPreferences keys cleanly.

### ✅ Phase 2: Character Card V3 Base Support (Completed in v0.6.3)
- Implemented `kCharacterCardV3Schema` for exports.
- Maintained legacy V2 UI backward compatibility via dynamic wrapper deserialization.

### ✅ Phase 3: Feature Identity Pass & Library Merge (Completed) 
- Unified "Custom Rules & Presets" and "Save & Load Library" into the single **Settings Library** drawer panel.
- Established consistent layout for Config Packs and Snapshots.

### Phase 4: Per-Subsystem Library System
Add an in-app library for each subsystem so users can **swap resources instantly** without file import/export. All entries are stored locally and accessible via a quick-select list:
- **Character Card Library**: Save/load/swap loaded character cards and their embedded elements natively.
- **Lorebook Library**: Save/load/merge named lorebook sets instantly.
- **Regex/Formatting Library**: Modular swap functionality for regex and formatting rules.
- **UI Button Cleanup**: Remove the redundant and unnecessary individual copy/paste buttons found across almost every single field in the Character Card panel and Settings Library modules to drastically declutter the UI.

### Phase 5: Pending Features, Revisions, & Removals
- Finalize any pending user-requested features, mechanics tweaks, or functionality removals.
- Fix image gen render pipeline (download bytes → base64 → `aiImage` field).
- Fix PDF/doc/docx silent drop in attachment pipeline (surface errors via snackbar).
- Refine overall chat UX based on targeted revisions before entering final optimization sweeps.

### Phase 6: Widget Decomposition & UI Cleanup (Optimization)
- Split `message_bubble.dart` (1,217 lines) into smaller sub-widgets: markdown renderer, image viewer, version navigator, context menu.
- Split `chat_input_area.dart` (1,313 lines) into smaller pieces: toggle bar, attachment handler, input field.
- Extract lorebook sub-section from `character_card_panel.dart` into its own widget.
- Audit `Consumer<ChatProvider>` over-rebuilds and migrate to fine-grained `Selector` patterns.

### Phase 7: Documentation & README Polish (Second Last)
- Perform a comprehensive final review and rewrite of `README.md` to perfectly capture all v0.6 features, UI interactions, and provider updates.
- Remove deprecated mechanics from the documentation.

### Phase 8: ChatProvider God Class Decomposition (Final Phase - High Risk)
The 3,292-line `ChatProvider` god class must be broken into focused services:
- **SessionService** — Session CRUD, auto-save, merge, fork, switch.
- **ModelRegistryService** — Model list state, fetching, deserialization. 
- **ApiKeyService** — Secure storage migration and provider key management.
- **WebSearchOrchestrator** & **ImageGenService**.
- Extract massive logic out of `sendMessage()` into separated streaming and post-processing pipelines.

---

## Commit Message Format

- **Title**: `[version] - [title]` (read `lib/utils/version.dart` for current version)
- **Content**: Plain-text summary of all changes (no markdown formatting)
- **Source**: Use `git diff` to identify all changes
