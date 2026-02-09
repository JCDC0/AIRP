# AIRP - Roleplay Chatbot

**AIRP** is a highly customizable, privacy-focused AI chat client built with Flutter. It serves as a unified interface for **Google's Gemini** models and the **OpenRouter** ecosystem (Claude, DeepSeek, Llama, and more). It features a robust system prompt library, deep visual customization, and a persistent local history with search capabilities.

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Gemini](https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=google&logoColor=white)

## Key Features

*   **Multi-Provider Support**: Seamlessly switch between Google Gemini, OpenRouter, OpenAI, HuggingFace, ArliAI, NanoGPT, Groq, or Local.
*   **High-Performance Streaming**: Optimized streaming engine eliminates UI lag by updating only the active message bubble, ensuring silky-smooth performance even on lower-end devices.
*   **Dynamic Model Lists**: Fetch the latest available models directly from all API providers.
*   **Model Counters**: Real-time display of available models for each provider, now conveniently located next to the model selector in the Chat Header.
*   **Intelligent Model Selector**: A powerful, searchable dialog for managing large model lists. Features a clean, space-efficient layout and a **Bookmarking System** to pin your favorites to the top.
*   **Searchable History**: Quickly find past conversations using the integrated search bar.
*   **Developer Friendly**: Full Markdown support with **syntax highlighting** for code blocks and one-click code copying.
*   **Message Management**: Edit, copy, delete, or regenerate specific messages within a chat.
*   **Deep Visual Customization**: Control global accent colors, bubble colors, opacity, and choose from thematic font presets.
*   **Atmospheric Effects**: Toggle "Bloom" for a glow dependent on your chosen color, or enable environmental effects like **Floating Motes**, **Rain**, or **Fireflies**.
*   **System Prompt Library**: Save and load custom personas and roleplay instructions.
*   **Advanced Prompting Engine**: Create, edit, and toggle individual "tweaks" or "character cards" (Advanced System Prompts) that stack on top of your main persona.
*   **Multimodal Support**: Send images to compatible models.
*   **File Attachment Support**: Attach PDFs and text-based files (txt, md, dart, etc.) to your messages for AI analysis.
*   **Google Search Grounding**: Toggle real-time web search integration for Gemini models.
*   **Token Counting**: Persistent, real-time context usage display in the app header to track limits.
*   **Enhanced Zoom Controls**: Pinch-to-zoom the conversation for better readability. An animated reset button appears for easy navigation.
*   **Scalability & Multi-Device Support**: Optimized for Phones, Tablets, and Desktops/Laptops with intelligent auto-detection on first install.
*   **Web & Computer Capability**: Moving towards integrated web browsing and broader computer-use capabilities.

## Scalability & Multi-Device Support

AIRP is designed to be your companion across all your devices. Whether you are on a mobile phone, a large tablet, or a desktop computer, the interface adapts to provide the best experience.

*   **Auto-Detection**: On first install, AIRP detects your device type and applies optimized scaling presets.
*   **Scale Settings**: Located in the Settings Drawer, the new **Scale Settings** panel allows for granular control:
    *   **Presets**: Quickly switch between **Phone**, **Tablet**, and **Desktop** layouts.
    *   **Granular Controls**: Manually adjust Font Sizes, Icon Sizes, Drawer Widths, and the Chat Input Area height to perfectly fit your screen and preferences.

## Getting Started

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
*   An IDE (VS Code or Android Studio).

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/JCDC0/AIRP
    cd airp-chat
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the app**:
    ```bash
    flutter run
    ```

---
## Configuration & API Keys

This app follows a **BYOK (Bring Your Own Key)** architecture. Keys are stored locally on your device.

### 1. Google Gemini
1.  Obtain an API key from [Google AI Studio](https://aistudio.google.com/).  
2.  Select **Gemini** from the top dropdown.
3.  Open the **Settings Drawer** (slide from right or click the gear icon).
4.  Paste your key into the API Key field.
5.  **Important:** Click the **Floating Save Button** (cyan circle) that appears at the bottom right.

### 2. OpenRouter
1.  Obtain an API key from [OpenRouter.ai](https://openrouter.ai/).
2.  Select **OpenRouter** from the top dropdown.
3.  Open the **Settings Drawer**.
4.  Paste your key.
5.  **Important:** Click the **Floating Save Button**.

### 3. OpenAI
1.  Obtain an API key from [OpenAI Platform](https://platform.openai.com/).
2.  Select **OpenAI** from the top dropdown.
3.  Open the **Settings Drawer**.
4.  Paste your key.
5.  **Important:** Click the **Floating Save Button**.

### 4. HuggingFace (Serverless Inference)
1.  Obtain an Access Token from [HuggingFace Settings](https://huggingface.co/settings/tokens).
2.  Select **HuggingFace** from the top dropdown.
3.  Open the **Settings Drawer**.
4.  Paste your token.
5.  **Important:** Click the **Floating Save Button**.

### 5. ArliAI
1.  Obtain an API key from [ArliAI](https://arliai.com/).
2.  Select **ArliAI** from the top dropdown.
3.  Open the **Settings Drawer**.
4.  Paste your key.
5.  **Important:** Click the **Floating Save Button**.

### 6. NanoGPT
1.  Obtain an API key from [NanoGPT](https://nano-gpt.com/).
2.  Select **NanoGPT** from the top dropdown.
3.  Open the **Settings Drawer**.
4.  Paste your key.
5.  **Important:** Click the **Floating Save Button**.

### 7. Groq
1.  Obtain an API key from [Groq Console](https://console.groq.com/).
2.  Select **Groq** from the top dropdown.
3.  Open the **Settings Drawer**.
4.  Paste your key.
5.  **Important:** Click the **Floating Save Button**.

### 8. Local Network AI (LM Studio / Ollama)
Connect to an LLM running on your own computer or home server.

1.  **Prepare your Server**:
    *   **LM Studio**: Start the Local Server. Ensure "Cross-Origin-Resource-Sharing (CORS)" is enabled and the server is listening on your local network IP (not just localhost).
    *   **Ollama**: Run `OLLAMA_HOST=0.0.0.0 ollama serve`.
2.  **Find your IP**: Get the IPv4 address of your computer (e.g., `192.168.1.15` and add the port number next to it that comes with your local AI service).
3.  **Configure AIRP**:
        *   Select **Local** from the top dropdown.
    *   Open the **Settings Drawer**.
    *   Enter the URL in the **Local Server Address** field.
        *   Format: `http://<YOUR_PC_IP>:<PORT>/v1`
        *   Example: `http://192.168.1.15:1234/v1`
    *   (Optional) Enter a specific model ID if your server requires it.
    *   Click the **Floating Save Button**.

---

## Interface & Controls

### Top Bar & Status
The header area is interactive and displays vital session info:
*   **Context Monitor**: Real-time token usage is pinned to the top (e.g., `Context: 2048 / 1,048,576`) so you never lose track of your remaining memory.
*   **Provider Switcher**: Tap the main title ("AIRP - Provider") to instantly toggle between Gemini, OpenRouter, Local, etc.
*   **Current Model**: The active model's name is displayed in the subtitle.

### Conversation Management (Left Drawer)
Slide from the **left** edge of the screen or tap the **Menu** icon to access your history.

*   **Search**: Use the text field at the top of the drawer to filter conversations by title in real-time.
*   **Navigation**: Tap any conversation to load it immediately.
*   **Deletion**: **Long-press** any conversation tile to bring up the delete confirmation dialog.
*   **New Chat**: Tap "New Conversation" to clear the current context and start fresh.

### Chat Controls (Main Screen)
Interact with the message stream using gestures.

*   **Message Options**: **Long-press** any message bubble (User or AI) to open the context menu:
    *   **Copy**: Copies the message text to the clipboard.
    *   **Edit**: Modify the message content.
    *   **Retry**: Regenerate the response (available on the latest exchange).
    *   **Delete**: Remove the message from the history.
*   **Model Identification**: The specific model used to generate a response is displayed in a tag above the AI's message bubble.
*   **Zoom & Pan**: **Pinch-to-zoom** anywhere on the chat history to get a closer look at text or images. When zoomed in, an animated button will appear in the top-right corner, allowing you to instantly reset the view to its default position.

### Model Selection (Right Drawer)
Slide from the **right** edge or tap the **Settings** icon.

1.  Ensure you have entered your API Key and saved.
2.  Locate the **Model Selection** section.
3.  Press the **Refresh Model List** button. The app will fetch the specific list of models available for your API key. A counter will display the total number of models found (e.g., "150 Models").
4.  **Tap the Selector**: This opens the new **Model Manager Dialog**.
    *   **Search**: Type in the top bar to filter instantly (e.g., "flash", "llama").
    *   **Bookmark**: Tap the bookmark icon on the right of any model to pin it to the top of the list forever.
    *   **Subtitles**: Every model now displays its raw API ID underneath the clean name, so you know exactly what you are selecting (crucial for OpenRouter).
5.  Select your desired model. The list automatically cleans raw IDs (e.g., `models/gemini-3-pro-preview`) into readable titles (e.g., `Gemini 3 Pro Preview`).
6.  The **Floating Save Button** will appear. Click it to confirm your selection.

### System Prompting & Personas

**AIRP** features a layered prompting system designed for complex roleplay and character consistency.

1.  **Main System Prompt**:
    *   **Toggle**: Enable or disable the entire System Prompt section with a single switch.
    *   This is your "World Rulebook" or "Main Persona".
    *   Type directly into the large text box in the settings drawer.
    *   **Save/Load**: Use the dropdown menu to save your prompt to a local library for later use.

2.  **Advanced Tweaks (Character Cards)**:
    *   Below the main prompt, expand the **"Advanced System Prompt"** section.
    *   **Toggle**: Enable or disable all advanced tweaks with a single switch.
    *   **Create Rules**: Add small, specific instructions (e.g., "Always speak in rhymes", "User is an enemy", "Enable Kaomoji").
    *   **Toggle**: Each rule has a switch. You can turn them ON or OFF dynamically between turns without deleting the text.
    *   **Edit**: Tap the **Pencil Icon** to modify a rule's name or content.
    *   **Stacking**: Active rules are automatically prepended to the Main System Prompt when sending the request to the AI.

---

## Advanced Generation Controls

Fine-tune how the AI behaves using the **Settings Drawer**. Each section can be toggled ON or OFF to simplify the interface or disable specific behaviors. All sliders support manual numeric input for precision.

*   **Message History**:
    *   **Toggle**: Enable or disable sending past messages to the AI.
    *   **Context Memory Limit**: Adjusts the truncation window (e.g., last 20 messages). Lower this if you encounter "Context Window Exceeded" errors.

*   **Reasoning Mode**:
    *   **Toggle**: Enable "Thinking" models (if supported by the provider).
    *   **Effort**: Set the depth of thought (Low, Medium, High).

*   **Generation Settings**:
    *   **Toggle**: Enable or disable manual control over Temperature, Top P, and Top K.
    *   **Temperature (Creativity)**: Controls randomness. High (1.0 - 2.0) for creativity, Low (0.0 - 0.5) for logic.
    *   **Top P (Nucleus Sampling)**: Limits token selection to top cumulative probability.
    *   **Top K (Vocabulary Size)**: Restricts the AI to the top `K` most likely next words.

*   **Max Output Tokens**:
    *   **Toggle**: Enable or disable the output token limit.
    *   **Slider**: Sets the hard limit on response length (up to 8192 tokens).

---

## Customization

### Visuals & Atmosphere
Located in the Settings Drawer under **Visuals & Atmosphere**. You have full control over the app's "Vibe":

*   **Global Theme**: Change the primary accent color of the entire application (borders, icons, glow effects).
*   **Backgrounds**: Choose from built-in assets or tap the **Add Photo** icon to use a custom image from your gallery.
*   **Thematic Fonts**: Switch between distinct typography styles:
    *   *Default* (System)
    *   *Roleplay* (Lora)
    *   *Terminal* (Space Mono)
    *   *Cyber* (Orbitron)
    *   *Modern Anime* (Quicksand)
    *   *Gothic* (Crimson Pro)
    *   *And more...*
*   **Bloom & Effects**: Toggle the "Bloom" switch for a dreamy glow effect on text and icons.
*   **Weather & Particles**: Enable dynamic overlays:
    *   **Floating Motes**: Dusty, ambient particles.
    *   **Rain**: A melancholic weather effect.
    *   **Fireflies**: Glowing orbs that pulse and move.
*   **Opacity Control**: Fine-tune the transparency of the background dimmer and message bubbles independently.

---

## Disclaimer

This project was developed with the assistance of AI tools. It is intended as a personal project and possibly as a portfolio piece. Use at your own risk; I am not responsible for API costs incurred via OpenRouter, Google Cloud, or other supporting platforms.

## License

This project is open-source and available under the MIT License.