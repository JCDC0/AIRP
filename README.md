# AIRP - Roleplay Chatbot

**AIRP** is a highly customizable, privacy-focused AI chat client built with Flutter. It serves as a unified interface for **Google's Gemini** models, the **OpenRouter** ecosystem (Claude, DeepSeek, Llama, and more), and 6 additional providers. It features a robust system prompt library with SillyTavern-compatible character cards, a BYOK web search system with 6 backends, full light/dark mode theming, deep visual customization, and persistent local history with search capabilities.

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
* **SillyTavern Character Cards**: Import character cards from PNG (V1/V2 tEXt chunk parsing) or JSON files. In-app editor with 7 fields (Name, Description, Personality, Scenario, First Message, Example Dialogue, System Prompt). Export to JSON.
* **Save & Load Library**: Export and import your entire setup as `.airp` files with per-category toggles: Conversations, System Prompt, Advanced System Prompt, Generation Parameters, Layout & Scaling, Visuals & Atmosphere. Intelligent merge on import.
* **Searchable History**: Quickly find past conversations with integrated search. Star conversations to pin them in a dedicated "Starred" section at the top of the drawer.
* **Developer Friendly**: Full Markdown support with **syntax highlighting** for code blocks and one-click code copying.
* **Message Management**: Edit, copy, delete, or regenerate specific messages within a chat.
* **Deep Visual Customization**: Independent color pickers for user bubble, user text, AI bubble, and AI text colors. Separate opacity sliders for background dimmer and message bubbles. 16 thematic font presets.
* **Atmospheric Effects**: Toggle "Bloom" for a glow dependent on your chosen color, or enable environmental effects like **Floating Motes**, **Rain**, or **Fireflies** — each with configurable density/intensity sliders.
* **System Prompt Library**: Save and load custom personas and roleplay instructions. Export/import structured presets (JSON) with system prompt, advanced prompt, custom rules, and generation settings.
* **Advanced Prompting Engine**: Create, edit, and toggle individual "tweaks" that stack on top of your main persona. SillyTavern-compatible character card import/export.
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
   * **Export/Import Presets**: Export structured presets as JSON files containing system prompt, advanced prompt, custom rules, and generation settings. Import merges rules intelligently (dedup by label).

2. **Advanced Tweaks (Character Cards)**:
   * Below the main prompt, expand the **"Advanced System Prompt"** section.
   * **Toggle**: Enable or disable all advanced tweaks with a single switch.
   * **Create Rules**: Add small, specific instructions (e.g., "Always speak in rhymes", "User is an enemy", "Enable Kaomoji").
   * **Toggle**: Each rule has a switch. You can turn them ON or OFF dynamically between turns without deleting the text.
   * **Edit**: Tap the **Pencil Icon** to modify a rule's name or content.
   * **Stacking**: Active rules are automatically prepended to the Main System Prompt when sending the request to the AI.

3. **SillyTavern Character Cards**:
   * **Import**: Load character cards from **PNG files** (V1/V2 tEXt chunk parsing) or **JSON files** with full SillyTavern spec compatibility.
   * **In-App Editor**: Edit 7 character fields — Name, Description, Personality, Scenario, First Message, Example Dialogue, and System Prompt.
   * **Export**: Save character cards to JSON for sharing or backup.
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
* **Intelligent Import**: Import preview with the same category toggles. Conversations are merged by ID, system prompts by title — no duplicates.

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
