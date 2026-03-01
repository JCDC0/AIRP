# AIRP - Roleplay Chatbot

**AIRP** is a highly customizable, privacy-focused AI chat client built with Flutter. It serves as a unified interface for **Google's Gemini** models, the **OpenRouter** ecosystem (Claude, DeepSeek, Llama, and more), and 6 additional providers. It features a full SillyTavern-compatible roleplay engine with lorebooks, regex post-processing, formatting templates, and a macro system — all built on importable character cards with V2 spec parity. Includes a BYOK web search system with 6 backends, full light/dark mode theming, deep visual customization, and persistent local history with search capabilities.

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Gemini](https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=google&logoColor=white)

## Key Features

* **Multi-Provider Support**: Seamlessly switch between Google Gemini, OpenRouter, OpenAI, HuggingFace, ArliAI, NanoGPT, Groq, or Local.
* **High-Performance Streaming**: Optimized streaming engine eliminates UI lag by updating only the active message bubble, ensuring silky-smooth performance even on lower-end devices.
* **Background Streaming**: Send a message, switch to another conversation, and the response continues generating in the background. The conversation drawer shows a spinner on active streams and displays a notification card when the background stream completes.
* **Dynamic Model Lists**: Fetch the latest available models directly from all API providers with pricing metadata (OpenRouter, NanoGPT).
* **Intelligent Model Selector**: A powerful, searchable dialog with a **Bookmarking System** to pin favorites, real-time model counters per provider, raw API ID subtitles, and cost sorting.
* **BYOK Web Search**: Provider-agnostic web search with 6 backends — Brave, Tavily, Serper, SearXNG, DuckDuckGo, and Provider-native grounding. Results are injected as context blocks that work across all AI providers, not just Gemini.
* **Light & Dark Mode**: Full light/dark mode toggle with 20+ semantic color getters that adapt the entire UI.
* **Response Versioning**: Regenerated responses are preserved as versions. Navigate between them with prev/next arrows and a version counter (e.g., "2/3") on each message bubble.
* **Conversation Forking**: Fork a conversation from any AI message to create a new branch while preserving the original.
* **Image Generation**: Toggle inline image generation (DALL-E/Flux) via a dedicated input bar button for compatible providers.
* **Usage Stats**: Per-message token usage display (prompt + completion = total) toggled from the input bar.
* **SillyTavern Character Cards (V2)**: Import character cards from PNG (V1/V2 tEXt/iTXt chunk parsing) or JSON files. Full V2 spec editor with 11+ fields including post-history instructions, alternate greetings, creator notes, depth prompt, and tags. Embedded lorebooks and regex scripts are auto-loaded on import. Export to JSON with round-trip fidelity.
* **Lorebook System**: Full SillyTavern Character Book V2 parity. Keyword-triggered context injection with primary/secondary key filtering, AND/NOT logic, probability rolls, timed effects (delay, sticky, cooldown), inclusion group conflict resolution, recursive scanning, and token budget enforcement. 8 insertion positions matching SillyTavern.
* **Regex Engine**: Post-processing pipeline with 3 modes — permanent (modifies stored text), display-only (render-time only), and prompt-only (alters sent prompt). Targets user input, AI output, world info, and reasoning independently. Supports macro-resolved patterns.
* **Formatting Templates**: Template-based output styling with ordered rules for dialogue, thought, narration, and character name wrapping. Macro placeholders (`{{char}}`, `{{match}}`, etc.) are resolved at render time.
* **Macro Engine**: Shared foundation powering lorebooks, regex, and formatting. 25+ macros across identity (`{{char}}`, `{{user}}`), time (`{{date}}`, `{{isotime}}`), randomization (`{{roll::2d6}}`, `{{pick::a::b}}`), variables (`{{getvar}}`, `{{setvar}}`), and utility (`{{newline}}`, `{{trim}}`). Recursive resolution with depth cap.
* **Preset System**: Import and export configuration packs bundling system prompt, generation settings, lorebook entries, regex scripts, and formatting templates. Partial SillyTavern preset import with auto-extraction of compatible fields.
* **Save & Load Library**: Export and import your entire setup as `.airp` files with per-category toggles: Conversations, System Prompt, Advanced System Prompt, Generation Parameters, Layout & Scaling, Visuals & Atmosphere, Character Card, and Lorebook/Regex/Formatting. Intelligent merge on import.
* **Searchable History**: Quickly find past conversations with integrated search. Star conversations to pin them in a dedicated "Starred" section at the top of the drawer.
* **Developer Friendly**: Full Markdown support with **syntax highlighting** for code blocks and one-click code copying.
* **Message Management**: Edit, copy, delete, or regenerate specific messages within a chat.
* **Deep Visual Customization**: Independent color pickers for user bubble, user text, AI bubble, and AI text colors. Separate opacity sliders for background dimmer and message bubbles. 16 thematic font presets.
* **Atmospheric Effects**: Toggle "Bloom" for a glow dependent on your chosen color, or enable environmental effects like **Floating Motes**, **Rain**, or **Fireflies** — each with configurable density/intensity sliders.
* **System Prompt Library**: Save and load custom personas and roleplay instructions. Export/import structured presets (JSON) bundling system prompt, advanced prompt, generation settings, lorebook entries, regex scripts, and formatting templates.
* **Advanced Prompting Engine**: Create, edit, and toggle individual "tweaks" that stack on top of your main persona. Full SillyTavern-compatible character card import/export with lorebook, regex, and formatting subsystems.
* **Multimodal Support**: Send images to compatible models.
* **File Attachment Support**: Attach PDFs and text-based files (txt, md, dart, etc.) to your messages for AI analysis.
* **Token Counting**: Persistent, real-time context usage display in the app header with color-coded indicators (green → yellow → orange → red) as the context window fills.
* **Enhanced Zoom Controls**: Pinch-to-zoom the conversation for better readability. Desktop includes a floating zoom-mode toggle, while mobile shows the reset button when zoomed.
* **Quick Input Toggles**: A row of feature toggle buttons directly in the input area — Web Search, Image Gen, Usage Stats, and Reasoning (cycles none → low → medium → high) — with contextual hint text that changes based on active mode.
* **Inline Typing Indicator**: A three-dots typing animation is rendered inside the active AI bubble as a fallback loading indicator (when border/loading animations are disabled), then disappears as soon as response text/reasoning appears.
* **Keyboard Shortcut Send**: Supports **Ctrl+Enter** (Windows/Linux) and **Cmd+Enter** (macOS) to send quickly from hardware keyboards.
* **Scroll Navigation**: Scroll-to-top and scroll-to-bottom buttons for quick navigation in long conversations.
* **Secure Key Storage**: API keys are stored in platform-encrypted secure storage rather than plain text, with automatic migration from legacy storage.
* **Auto-Save**: Conversations auto-save with a debounced timer after every change.
* **Scalability & Multi-Device Support**: Optimized for Phones, Tablets, and Desktops/Laptops with intelligent auto-detection on first install and a first-run glow indicator guiding users to configure scaling.

## Scalability & Multi-Device Support

AIRP is designed to be your companion across all your devices. Whether you are on a mobile phone, a large tablet, or a desktop computer, the interface adapts to provide the best experience.

* **Auto-Detection**: On first install, AIRP detects your device type and applies optimized scaling presets.
* **Scale Settings**: Located in the Settings Drawer, the new **Scale Settings** panel allows for granular control:
  * **Presets**: Quickly switch between **Phone**, **Tablet**, and **Desktop** layouts.
  * **Granular Controls**: Manually adjust Font Sizes, Icon Sizes, Drawer Widths, and the Chat Input Area height to perfectly fit your screen and preferences.

## Getting Started

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
* An IDE (VS Code or Android Studio).

### Installation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/JCDC0/AIRP
   cd AIRP
   ```

2. **Install dependencies**:

   ```bash
   flutter pub get
   ```

3. **Run the app**:

   ```bash
   flutter run
   ```

---

## Configuration & API Keys

This app follows a **BYOK (Bring Your Own Key)** architecture. API keys are stored in platform-encrypted secure storage on your device.

### 1. Google Gemini

1. Obtain an API key from [Google AI Studio](https://aistudio.google.com/).
2. Select **Gemini** from the top dropdown.
3. Open the **Settings Drawer** (slide from right or click the gear icon).
4. Paste your key into the API Key field.
5. **Important:** Click the **Floating Save Button** (cyan circle) that appears at the bottom right.

### 2. OpenRouter

1. Obtain an API key from [OpenRouter.ai](https://openrouter.ai/).
2. Select **OpenRouter** from the top dropdown.
3. Open the **Settings Drawer**.
4. Paste your key.
5. **Important:** Click the **Floating Save Button**.

### 3. OpenAI

1. Obtain an API key from [OpenAI Platform](https://platform.openai.com/).
2. Select **OpenAI** from the top dropdown.
3. Open the **Settings Drawer**.
4. Paste your key.
5. **Important:** Click the **Floating Save Button**.

### 4. HuggingFace (Serverless Inference)

1. Obtain an Access Token from [HuggingFace Settings](https://huggingface.co/settings/tokens).
2. Select **HuggingFace** from the top dropdown.
3. Open the **Settings Drawer**.
4. Paste your token.
5. **Important:** Click the **Floating Save Button**.

### 5. ArliAI

1. Obtain an API key from [ArliAI](https://arliai.com/).
2. Select **ArliAI** from the top dropdown.
3. Open the **Settings Drawer**.
4. Paste your key.
5. **Important:** Click the **Floating Save Button**.

### 6. NanoGPT

1. Obtain an API key from [NanoGPT](https://nano-gpt.com/).
2. Select **NanoGPT** from the top dropdown.
3. Open the **Settings Drawer**.
4. Paste your key.
5. **Important:** Click the **Floating Save Button**.

### 7. Groq

1. Obtain an API key from [Groq Console](https://console.groq.com/).
2. Select **Groq** from the top dropdown.
3. Open the **Settings Drawer**.
4. Paste your key.
5. **Important:** Click the **Floating Save Button**.

### 8. Local Network AI (LM Studio / Ollama)

Connect to an LLM running on your own computer or home server.

1. **Prepare your Server**:
   * **LM Studio**: Start the Local Server. Ensure "Cross-Origin-Resource-Sharing (CORS)" is enabled and the server is listening on your local network IP (not just localhost).
   * **Ollama**: Run `OLLAMA_HOST=0.0.0.0 ollama serve`.
2. **Find your IP**: Get the IPv4 address of your computer (e.g., `192.168.1.15` and add the port number next to it that comes with your local AI service).
3. **Configure AIRP**:
   * Select **Local** from the top dropdown.
   * Open the **Settings Drawer**.
   * Enter the URL in the **Local Server Address** field.
     * Format: `http://<YOUR_PC_IP>:<PORT>/v1`
     * Example: `http://192.168.1.15:1234/v1`
   * (Optional) Enter a specific model ID if your server requires it.
   * Click the **Floating Save Button**.

---

## Interface & Controls

### Top Bar & Status

The header area is interactive and displays vital session info:

* **Context Monitor**: Real-time token usage is pinned to the top (e.g., `Context: 2048 / 1,048,576`) so you never lose track of your remaining memory.
* **Provider Switcher**: Tap the main title ("AIRP - Provider") to instantly toggle between Gemini, OpenRouter, Local, etc.
* **Current Model**: The active model's name is displayed in the subtitle.

### Conversation Management (Left Drawer)

Slide from the **left** edge of the screen or tap the **Menu** icon to access your history.

* **Search**: Use the text field at the top of the drawer to filter conversations by title in real-time.
* **Starred Conversations**: Tap the star icon on any conversation to pin it to a dedicated "Starred" section at the top of the drawer.
* **Navigation**: Tap any conversation to load it immediately.
* **Background Activity**: Conversations with active background streams display a spinner indicator.
* **Deletion**: **Long-press** any conversation tile to bring up the delete confirmation dialog.
* **New Chat**: Tap "New Conversation" to clear the current context and start fresh.

### Chat Controls (Main Screen)

Interact with the message stream using gestures.

* **Message Options**: **Long-press** any message bubble (User or AI) to open the context menu:
  * **Copy**: Copies the message text to the clipboard.
  * **Edit**: Modify the message content.
  * **Retry**: Regenerate the response. Previous versions are preserved and navigable with prev/next arrows and a version counter (e.g., "2/3").
  * **Fork**: Create a new conversation branching from any AI message, preserving all prior context.
  * **Delete**: Remove the message from the history.
* **Model Identification**: The specific model used to generate a response is displayed in a tag above the AI's message bubble.
* **Zoom & Pan**: **Pinch-to-zoom** anywhere on the chat history to get a closer look at text or images. On desktop, a floating zoom button toggles zoom mode; on mobile, the reset button appears when zoomed.
* **Scroll Navigation**: Scroll-to-top and scroll-to-bottom buttons for quick jumps in long conversations.
* **Quick Toggles**: The input bar provides one-tap access to Web Search, Image Generation, Usage Stats, and Reasoning Mode without opening the settings drawer. The input placeholder dynamically updates ("Search web...", "Describe image...", "Add a caption...", "Message...").
* **Typing Feedback**: During generation waits (with border/loading animations disabled), the AI bubble shows an inline animated three-dots typing state and removes it once output starts.
* **Keyboard Send Shortcut**: Use **Ctrl+Enter / Cmd+Enter** to send messages from supported hardware keyboards.

### Model Selection (Right Drawer)

Slide from the **right** edge or tap the **Settings** icon.

1. Ensure you have entered your API Key and saved.
2. Locate the **Model Selection** section.
3. Press the **Refresh Model List** button. The app will fetch the specific list of models available for your API key. A counter will display the total number of models found (e.g., "150 Models").
4. **Tap the Selector**: This opens the new **Model Manager Dialog**.
   * **Search**: Type in the top bar to filter instantly (e.g., "flash", "llama").
   * **Bookmark**: Tap the bookmark icon on the right of any model to pin it to the top of the list forever.
   * **Subtitles**: Every model now displays its raw API ID underneath the clean name, so you know exactly what you are selecting (crucial for OpenRouter).
5. Select your desired model. The list automatically cleans raw IDs (e.g., `models/gemini-3-pro-preview`) into readable titles (e.g., `Gemini 3 Pro Preview`).
6. The **Floating Save Button** will appear. Click it to confirm your selection.

### System Prompting & Personas

**AIRP** features a layered prompting system designed for complex roleplay and character consistency.

1. **Main System Prompt**:
   * **Toggle**: Enable or disable the entire System Prompt section with a single switch.
   * This is your "World Rulebook" or "Main Persona".
   * Type directly into the large text box in the settings drawer.
   * **Save/Load**: Use the dropdown menu to save your prompt to a local library for later use.
   * **Export/Import Presets**: Export structured presets as JSON files containing system prompt, advanced prompt, generation settings, and optionally lorebook entries, regex scripts, and formatting templates. Import merges rules intelligently (dedup by label).

2. **Advanced Tweaks (Character Cards)**:
   * Below the main prompt, expand the **"Advanced System Prompt"** section.
   * **Toggle**: Enable or disable all advanced tweaks with a single switch.
   * **Create Rules**: Add small, specific instructions (e.g., "Always speak in rhymes", "User is an enemy", "Enable Kaomoji").
   * **Toggle**: Each rule has a switch. You can turn them ON or OFF dynamically between turns without deleting the text.
   * **Edit**: Tap the **Pencil Icon** to modify a rule's name or content.
   * **Stacking**: Active rules are automatically prepended to the Main System Prompt when sending the request to the AI.

3. **SillyTavern Character Cards (V2)**:
   * **Import**: Load character cards from **PNG files** (V1/V2 tEXt/iTXt compressed chunk parsing) or **JSON files** with full SillyTavern V2 spec compatibility. Embedded `character_book` lorebooks and scoped regex scripts are auto-loaded.
   * **In-App Editor**: Edit 11+ character fields — Name, Description, Personality, Scenario, First Message, Example Dialogue, System Prompt, Post-History Instructions, Creator Notes, Creator, and Character Version.
   * **Alternate Greetings**: Manage multiple first messages that can be cycled.
   * **Depth Prompt**: Configure text injected at a specific depth in the message history with role assignment (system/user/assistant).
   * **Tags**: View and manage character tags for organization.
   * **Embedded Lorebook**: View and edit the character's embedded lorebook entries directly within the character card panel.
   * **Export**: Save character cards to JSON with full V2 round-trip fidelity.
   * **Clear Card**: Remove the active character card without losing your custom rules.

---

## Web Search (BYOK)

AIRP includes a provider-agnostic web search system that works across all AI backends, not just Gemini. Accessed via the Web Search toggle in the input bar or configured in the Settings Drawer under **Web Search**.

* **Provider (default)**: Delegates to the AI provider's native grounding feature (Gemini Search, OpenRouter web plugin). Uses the provider's own billing.
* **Brave Search**: High-quality search results with a BYOK API key. ~2,000 free queries/month.
* **Tavily**: AI-optimized search with pre-summarized results. 1,000 free searches/month. Best for AI/RAG use cases.
* **Serper.dev**: Google Search results in clean JSON. 2,500 free searches included.
* **SearXNG**: Connect to a self-hosted SearXNG instance. Supports IP:port URL format with a live validation button. Completely free and private.
* **DuckDuckGo (Scraping)**: Free fallback using DuckDuckGo HTML scraping. No API key required but may be unreliable.

Search results are formatted as a `[WEB_CONTEXT]` block and prepended to your message before sending to the AI. This ensures per-message freshness and works uniformly across all backends. A **Max Results** slider (1-10) controls how many results are injected per query.

---

## Save & Load Library

Export and import your entire AIRP configuration using `.airp` files. Located in the Settings Drawer under **Library**.

* **Selective Export**: Choose which categories to include with per-category toggles:
  * Conversations
  * System Prompt
  * Advanced System Prompt
  * Generation Parameters
  * Layout & Scaling
  * Visuals & Atmosphere
  * Character Card
  * Lorebook / Regex / Formatting
* **Intelligent Import**: Import preview with the same category toggles. Conversations are merged by ID, system prompts by title — no duplicates. Character card, lorebook, regex scripts, and formatting templates are restored from the imported file.

---

## Lorebook System

The Lorebook is a keyword-triggered context injection system with full SillyTavern Character Book V2 parity. It dynamically injects relevant world-building information into the AI's context based on what's being discussed. Located in the Settings Drawer under **Character Card > Lorebook**.

### How It Works

1. When you send a message, the lorebook engine scans recent messages for keyword matches.
2. Entries whose keywords are found become candidates for activation.
3. Activated entries are injected into the AI's prompt at their configured insertion position.
4. The AI sees this contextual information alongside your conversation, resulting in more consistent and lore-accurate responses.

### Setting Up a Lorebook

1. Open the **Settings Drawer** and expand **Character Card**.
2. Scroll to the **Lorebook** sub-section and expand it.
3. Configure global settings:
   * **Scan Depth**: How many recent messages to scan for keywords (default: 2).
   * **Token Budget**: Maximum tokens allocated to lorebook content (default: 2048).
   * **Case Sensitive**: Whether keyword matching is case-sensitive.
   * **Match Whole Words**: Whether keywords must match as whole words.
   * **Recursion Steps**: How many times activated entries are re-scanned for more keyword matches (0 = no recursion).
4. Tap the **+** button to add entries, or **Import** a lorebook JSON file.

### Lorebook Entries

Each entry has these configurable fields:

* **Keys** (Primary): Comma-separated keywords that trigger this entry. Example: `dragon, wyrm, drake`.
* **Content**: The text injected into the prompt when activated.
* **Secondary Keys**: Optional additional filter with AND or NOT logic. AND mode requires both primary and secondary keys to match. NOT mode excludes the entry if secondary keys are found.
* **Strategy**: `Triggered` (activates on keyword match) or `Constant` (always active regardless of keywords).
* **Position**: Where content is inserted — 8 positions matching SillyTavern: Before Character Definitions, After Character Definitions, Author's Note Top/Bottom, At Depth, Examples Top/Bottom, or Outlet.
* **Depth & Role**: For "At Depth" position, how deep in message history to inject and what role (system/user/assistant).
* **Probability**: Chance of activation per match (0-100%). Useful for variety.
* **Inclusion Groups**: Group entries so only the highest-weight entry in a group activates, preventing conflicting information.
* **Timed Effects**: Delay (matches needed before first trigger), Sticky (forced re-activation for N turns after trigger), Cooldown (turns before re-activation after sticky expires).

### Importing Lorebooks

* **From Character Cards**: When importing a SillyTavern PNG/JSON character card with an embedded `character_book`, the lorebook entries are automatically loaded as character-scoped entries.
* **Standalone JSON**: Import/export lorebook JSON files directly from the lorebook section.

---

## Regex Engine

The Regex Engine is a post-processing pipeline that applies pattern-based text transformations. It supports three processing modes and can target different parts of the conversation independently. Located in the Settings Drawer under **Regex Scripts**.

### Processing Modes

* **Permanent**: Modifies the stored text. The original message is changed in your conversation history.
* **Display-Only**: Transforms text at render time only. The stored message remains unchanged — useful for styling without altering history.
* **Prompt-Only**: Modifies text only when sent to the AI. The displayed text remains unchanged — useful for behind-the-scenes prompt manipulation.

### Targets

Each regex script can independently target any combination of:
* **User Input**: Applied to your messages.
* **AI Output**: Applied to AI responses.
* **World Info**: Applied to lorebook content.
* **Reasoning**: Applied to AI thinking/reasoning blocks.

### Managing Regex Scripts

1. Open the **Settings Drawer** and expand **Regex Scripts**.
2. Use the master **Enable Regex** toggle to turn the entire system on/off.
3. Tap **+** to create a new script, or **Import** a JSON set.
4. Each script has:
   * **Find Pattern**: A regular expression pattern (supports case-insensitive, dot-all, multiline, unicode flags).
   * **Replace With**: The replacement string (supports capture groups like `$1`, `$2`).
   * **Trim Strings**: Optional strings to strip from matches.
   * **Macro Mode**: None, Raw (macros in pattern), or Escaped (macros resolved before regex compilation).
5. **Drag handles** let you reorder scripts — they execute in order from top to bottom.
6. Use the **Test Panel** to preview regex matches and replacements on sample text before enabling.

### Import/Export

* Import SillyTavern regex scripts from JSON — AIRP automatically converts ST's numeric `placement[]` arrays and inverted `disabled` flag.
* Export your regex scripts as JSON for sharing or backup.

---

## Formatting Templates

Formatting Templates apply styled wrapping to different types of text in AI responses — dialogue, thoughts, narration, and character names. Located in the Settings Drawer under **Formatting**.

### How It Works

1. Each formatting rule defines a regex **pattern** that matches specific text (e.g., text in quotes for dialogue, text in asterisks for actions).
2. When a match is found, the matched text is wrapped using the rule's **template** string.
3. The `{{match}}` placeholder in the template is replaced with the captured text.
4. Macro tokens (`{{char}}`, `{{user}}`, etc.) are resolved in templates.
5. Rules execute in order — output of one rule feeds into the next.

### Setting Up Formatting

1. Open the **Settings Drawer** and expand **Formatting**.
2. Use the master **Enable Formatting** toggle.
3. Tap **Load Defaults** to start with built-in rules for dialogue, thought, narration, and character name styling.
4. Each rule shows:
   * **Type icon**: Quote (dialogue), Brain (thought), Book (narration), Person (character name), Tune (custom).
   * **Label**: Human-readable name.
   * **Pattern**: The regex used to match text.
   * **Template**: The replacement with `{{match}}` placeholder.
5. Tap any rule to edit its pattern and template.
6. **Import/Export** templates as JSON to share formatting setups.

### Rule Types

* **Dialogue**: Matches quoted text (e.g., `"Hello"`) and applies styling.
* **Thought**: Matches italicized or asterisked text for internal monologue.
* **Narration**: Matches plain narrative text outside dialogue/action.
* **Character Name**: Matches character name occurrences for highlighting.
* **Custom**: User-defined rules with arbitrary patterns and templates.

---

## Macro System

The Macro Engine is the shared foundation powering lorebooks, regex scripts, and formatting templates. Any text field that supports macros will resolve `{{token}}` placeholders at runtime.

### Available Macros

| Category | Macros | Description |
|----------|--------|-------------|
| **Identity** | `{{char}}`, `{{user}}` | Character and user names from the active card |
| **Character** | `{{description}}`, `{{personality}}`, `{{scenario}}`, `{{persona}}`, `{{mesExamples}}` | Character card fields |
| **Model** | `{{model}}` | Currently active model name |
| **Time** | `{{time}}`, `{{date}}`, `{{weekday}}`, `{{isotime}}`, `{{isodate}}` | Current date/time values |
| **Time Format** | `{{datetimeformat::FORMAT}}` | Custom date format (e.g., `{{datetimeformat::yyyy-MM-dd}}`) |
| **Random** | `{{random::a::b}}` | Random integer between a and b |
| **Dice** | `{{roll::NdM}}` | Roll N dice with M sides (e.g., `{{roll::2d6}}`) |
| **Pick** | `{{pick::a::b::c}}` | Random selection from a list |
| **Variables** | `{{getvar::name}}`, `{{setvar::name::value}}` | Get/set persistent variables |
| **Math** | `{{incvar::name}}`, `{{decvar::name}}` | Increment/decrement numeric variables |
| **Utility** | `{{newline}}`, `{{trim}}` | Insert newline or trim whitespace |
| **Legacy** | `<USER>`, `<BOT>` | Aliases for `{{user}}` and `{{char}}` |

Variables set with `{{setvar}}` persist across sessions via local storage.

---

## Preset System

Presets are importable configuration packs that bundle multiple settings together. Located in the Settings Drawer under **Presets**.

### What's in a Preset

A preset can include any combination of:
* **System Prompt**: Main persona/instructions.
* **Advanced Prompt**: Tweaks and overrides.
* **Generation Settings**: Temperature, Top P, Top K, Max Tokens.
* **Post-History Instructions**: Text injected after the conversation history.
* **Lorebook Entries**: World-building entries bundled with the preset.
* **Regex Scripts**: Text processing rules bundled with the preset.
* **Formatting Template**: Output formatting rules bundled with the preset.

### Using Presets

1. Open the **Settings Drawer** and expand **Presets**.
2. **Import**: Tap the import button to load a `.json` preset file.
   * AIRP-native presets import with full fidelity.
   * SillyTavern OpenAI presets are partially supported — temperature, top_p, top_k, max_tokens, main prompt, and post-history content are extracted. Incompatible ST-specific fields are discarded with a warning.
3. **Apply**: Tap a preset to apply it. The system prompt, generation parameters, and any bundled lorebook/regex/formatting are loaded.
4. **Export**: Save your current configuration as a preset for sharing or backup.
5. **Delete**: Remove presets you no longer need.

---

## Advanced Generation Controls

Fine-tune how the AI behaves using the **Settings Drawer**. Each section can be toggled ON or OFF to simplify the interface or disable specific behaviors. All sliders support manual numeric input for precision.

* **Message History**:
  * **Toggle**: Enable or disable sending past messages to the AI.
  * **Context Memory Limit**: Adjusts the truncation window (e.g., last 20 messages). Lower this if you encounter "Context Window Exceeded" errors.

* **Reasoning Mode**:
  * **Toggle**: Enable "Thinking" models (if supported by the provider).
  * **Effort**: Set the depth of thought (Low, Medium, High).

* **Generation Settings**:
  * **Toggle**: Enable or disable manual control over Temperature, Top P, and Top K.
  * **Temperature (Creativity)**: Controls randomness. High (1.0 - 2.0) for creativity, Low (0.0 - 0.5) for logic.
  * **Top P (Nucleus Sampling)**: Limits token selection to top cumulative probability.
  * **Top K (Vocabulary Size)**: Restricts the AI to the top `K` most likely next words.

* **Max Output Tokens**:
  * **Toggle**: Enable or disable the output token limit.
  * **Slider**: Sets the hard limit on response length (up to 8192 tokens).

* **Safety Settings**:
  * **Disable Safety**: Toggle to remove Gemini harm category safety filters (harassment, hate speech, sexually explicit, dangerous content) for unrestricted creative writing.

---

## Customization

### Visuals & Atmosphere

Located in the Settings Drawer under **Visuals & Atmosphere**. You have full control over the app's "Vibe":

* **Global Theme**: Change the primary accent color of the entire application (borders, icons, glow effects).
* **Light / Dark Mode**: Toggle between light and dark themes. The entire UI adapts via 20+ semantic color getters.
* **Thematic Fonts**: Switch between 16 distinct typography styles:
  * *Default* (System), *Google* (Open Sans), *Apple* (Inter), *Claude* (Source Serif 4)
  * *Roleplay* (Lora), *Terminal* (Space Mono), *Manuscript* (EB Garamond)
  * *Cyber* (Orbitron), *Modern Anime* (Quicksand), *Anime Sub* (Kosugi Maru)
  * *Gothic* (Crimson Pro), *Journal* (Caveat), *Clean Thin* (Raleway)
  * *Stylized* (Playfair Display), *Fantasy* (Cinzel), *Typewriter* (Special Elite)
* **Bubble Colors**: Independent color pickers for user bubble background, user text, AI bubble background, and AI text — 4 separate controls plus individual opacity sliders for each bubble type.
* **Bloom & Effects**: Toggle the "Bloom" switch for a dreamy glow effect on text and icons.
* **Loading/Border Animations**: Toggle orbiting border/loading animations globally. Affects input field borders, toggle buttons, reasoning headers, and the zoom button. Each uses distinct animated arc patterns.
* **Weather & Particles**: Enable dynamic overlays with configurable density/intensity:
  * **Floating Motes**: Dusty, ambient particles (1–150 density slider).
  * **Rain**: A melancholic weather effect (1–200 intensity slider).
  * **Fireflies**: Glowing orbs that pulse and move (1–100 count slider).
* **Opacity Control**: Fine-tune the transparency of the background dimmer and message bubbles independently.
* **Custom Backgrounds**: Choose from 36+ built-in AI-generated backgrounds or add custom images from your gallery. Long-press custom images to remove them. Backgrounds persist per-session.
* **Reset to Defaults**: One-click reset for all visual settings with a confirmation dialog.

---

## Disclaimer

This project was developed with the assistance of AI tools. It is intended as a personal project and possibly as a portfolio piece. Use at your own risk; I am not responsible for API costs incurred via OpenRouter, Google Cloud, or other supporting platforms.

## License

This project is open-source and available under the MIT License.
