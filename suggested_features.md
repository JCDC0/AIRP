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

### 📦 v0.5.12 - Total Codebase Overhaul: Optimization & High Efficiency
*Focus: Deep architectural restructuring, addressing technical debt, eliminating redundancies, and maximizing app-wide performance.*

- **Comprehensive State Refactoring:** Move beyond just breaking up the 2000+ line `ChatProvider.dart`. Re-evaluate all top-level providers (`ChatProvider`, `ThemeProvider`, `ScaleProvider`), extracting heavy complex logic into precise, atomic services (e.g., `ConversationService`, `WebSearchManager`, `TokenTrackingService`, `AIStreamingOrchestrator`). [PENDING]
- **API & Networking Efficiency:** Consolidate HTTP, streaming logic, and serialization across all AI APIs and web search endpoints. Implement aggressive deduplication of request formatting and unified retry/error pipelines (rate limits, bot challenges like DDG blocking). [PENDING]
- **Widget-Tree Optimization & Rebuild Isolation:** Audit the entire UI layer (`screens/`, `widgets/`, `settings_panels/`) to strictly eliminate unnecessary deep-tree rebuilds. Transition monolithic `Consumer` and `StatefulWidget` states over to fine-grained `Selector` models for pure UI responsiveness. [PENDING]
- **VFX Optimization:** Consolidate `EffectsOverlay` logic to use a single `CustomPainter` or a lightweight particle system for better performance on mobile. [COMPLETE - Uses CustomPainter]
- **Data Persistence Strategy & File I/O:** Complete overhaul of secure storage and SharedPreferences I/O. Decouple storage read/writes from the main UI thread via batched operations yielding zero-lag interactions. [PENDING]

### 📦 v0.6.0 - The "Silly Tavern" Era
*Focus: Advanced roleplay features and deep immersion.*

- **Lorebooks (World Info):** Implement a keyword-triggered system to inject world details and lore into the AI's context. [PENDING]
- **Enhanced Character Support:** Full support for Character Card V2 specs, including deep metadata and multi-message examples. [DATA MODEL COMPLETE]
- **Regex Scripting:** Allow users to define post-processing rules to clean up or reformat AI output. [PENDING]
- **Advanced Formatting Templates:** Customizable templates for wrapping dialogue, thoughts, and character names. [PENDING]

---
 **Phased Instructions:**
1. **[COMPLETE] Phase 1 (v0.5.8-v0.5.9):** Enhanced ModelSelector with refresh button, long-press descriptions, and cost sorting using OpenRouter metadata. Response versioning and conversation forking implemented.
2. **[COMPLETE] Phase 2 (v0.5.10):** Built `WebSearchService` implementing Brave, Tavily, Serper.dev, SearXNG, and DDG backends. Added `WebSearchSettingsPanel` beneath Generation Parameters in the drawer. Context injected as `[WEB_CONTEXT]` blocks prepended to user message before AI calls.
3. **Phase 3 (v0.5.11):** Light mode system with full codebase color adaptation.
4. **Phase 4 (v0.5.12):** Execute a complete codebase efficiency overhaul. Break apart God-classes (`ChatProvider.dart`, monolithic UI components) into atomic, decoupled services. Audit the entire project for duplicated logic, streamline API and networking code, minimize widget rebuilds with granular `Selector` models, and decouple storage I/O from state updates for zero-lag interactions.
5. **Phase 5 (v0.6.0):** Implement a `LorebookParser` and `RegexEngine`. Update the prompt construction logic to inject Lorebook entries based on recent message keywords. Note: `CharacterCard` model already supports V2 specs.

**Constraint:** Ensure all UI changes respect `ScaleProvider` and `ThemeProvider` for consistent Material 3 styling and responsive scaling.

**Commit Message Format**
- **Title Header** - Read util/version.dart for the version number and input a header title that summarizes what is created, create the title in the format version number and your title
- **Format** - Example if version reads 1.0.0 then output as: 1.0.0 - your title

- **Content Summary** - Outline all the changes made or all the features implemented, for better understanding, use git diff or other methods to find the changes or additions in the codebase in the terminal for an understanding of all changes or all features implemented
- **No Markdown Formatting** - Don't use markdown formatting with bullet points, asterisks, this is to make the text more easily copy pastable.
