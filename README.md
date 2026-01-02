# AIRP - Chat Client

**AIRP** is a highly customizable, privacy-focused AI chat client built with Flutter. It serves as a unified interface for **Google's Gemini** models and the **OpenRouter** ecosystem (Claude, DeepSeek, Llama, and more). It features a robust system prompt library, deep visual customization, and a persistent local history with search capabilities.

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Gemini](https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=google&logoColor=white)

## Key Features

*   **Multi-Provider Support**: Seamlessly switch between Google Gemini, OpenRouter, ArliAI, NanoGPT, or Local.
*   **Dynamic Model Lists**: Fetch the latest available models directly from the API providers.
*   **Intelligent Model Selector**: A powerful, searchable dialog for managing large model lists. Features a **Bookmarking System** to pin your favorites to the top and smart sorting that prioritizes your bookmarks and featured models.
*   **Searchable History**: Quickly find past conversations using the integrated search bar.
*   **Developer Friendly**: Full Markdown support with **syntax highlighting** for code blocks and one-click code copying.
*   **Message Management**: Edit, copy, delete, or regenerate specific messages within a chat.
*   **Deep Visual Customization**: Control global accent colors, bubble colors, opacity, and choose from thematic font presets.
*   **Atmospheric Effects**: Toggle "Bloom" for a glow dependent on your chosen color, or enable environmental effects like **Floating Motes**, **Rain**, or **Fireflies**.
*   **System Prompt Library**: Save and load custom personas and roleplay instructions.
*   **Multimodal Support**: Send images to compatible models.
*   **File Attachment Support**: Attach PDFs and text-based files (txt, md, dart, etc.) to your messages for AI analysis.
*   **Google Search Grounding**: Toggle real-time web search integration for Gemini models.
*   **Token Counting**: Live token usage estimation to track context limits.
*   **Enhanced Zoom Controls**: Pinch-to-zoom the conversation for better readability. An animated reset button appears for easy navigation.

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
2.  Select **AIRP - Gemini** from the top dropdown.
3.  Open the **Settings Drawer** (slide from right or click the gear icon).
4.  Paste your key into the API Key field.
5.  **Important:** Click the **Floating Save Button** (cyan circle) that appears at the bottom right.

### 2. OpenRouter
1.  Obtain an API key from [OpenRouter.ai](https://openrouter.ai/).
2.  Select **AIRP - OpenRouter** from the top dropdown.
3.  Open the **Settings Drawer**.
4.  Paste your key.
5.  **Important:** Click the **Floating Save Button**.

### 3. ArliAI
1.  Obtain an API key from [ArliAI](https://arliai.com/).
2.  Select **AIRP - ArliAI** from the top dropdown.
3.  Open the **Settings Drawer**.
4.  Paste your key.
5.  **Important:** Click the **Floating Save Button**.

### 4. NanoGPT
1.  Obtain an API key from [NanoGPT](https://nano-gpt.com/).
2.  Select **AIRP - NanoGPT** from the top dropdown.
3.  Open the **Settings Drawer**.
4.  Paste your key.
5.  **Important:** Click the **Floating Save Button**.

### 5. Local Network AI (LM Studio / Ollama)
Connect to an LLM running on your own computer or home server.

1.  **Prepare your Server**:
    *   **LM Studio**: Start the Local Server. Ensure "Cross-Origin-Resource-Sharing (CORS)" is enabled and the server is listening on your local network IP (not just localhost).
    *   **Ollama**: Run `OLLAMA_HOST=0.0.0.0 ollama serve`.
2.  **Find your IP**: Get the IPv4 address of your computer (e.g., `192.168.1.15` and add the port number next to it that comes with your local AI service).
3.  **Configure AIRP**:
        *   Select **AIRP - Local** from the top dropdown.
    *   Open the **Settings Drawer**.
    *   Enter the URL in the **Local Server Address** field.
        *   Format: `http://<YOUR_PC_IP>:<PORT>/v1`
        *   Example: `http://192.168.1.15:1234/v1`
    *   (Optional) Enter a specific model ID if your server requires it.
    *   Click the **Floating Save Button**.

---

## Interface & Controls

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
3.  Press the **Refresh Model List** button. The app will fetch the specific list of models available for your API key.
4.  **Tap the Selector**: This opens the new **Model Manager Dialog**.
    *   **Search**: Type in the top bar to filter instantly (e.g., "flash", "llama").
    *   **Bookmark**: Tap the bookmark icon on the right of any model to pin it to the top of the list forever.
    *   **Subtitles**: Every model now displays its raw API ID underneath the clean name, so you know exactly what you are selecting (crucial for OpenRouter).
5.  Select your desired model. The list automatically cleans raw IDs (e.g., `models/gemini-3-pro-preview`) into readable titles (e.g., `Gemini 3 Pro Preview`).
6.  The **Floating Save Button** will appear. Click it to confirm your selection.

---

## Advanced Generation Controls

Fine-tune how the AI behaves using the **Settings Drawer**. All sliders support manual numeric input for precision.

*   **Temperature (Creativity)**: Controls randomness.
    *   **High (1.0 - 2.0)**: Creative, unpredictable, and diverse responses.
    *   **Low (0.0 - 0.5)**: Focused, deterministic, and logical responses.
*   **Top P (Nucleus Sampling)**: Limits the token selection to the top cumulative probability. Lower values (e.g., 0.9) make the text more coherent and less prone to "hallucinations."
*   **Top K (Vocabulary Size)**: Restricts the AI to choosing from the top `K` most likely next words.
*   **Max Output Tokens**: Sets the hard limit on response length. Increase this for longer stories or code generation.
*   **Context Memory Limit**: Controls how many past messages are sent to the AI.
    *   **Slider**: Adjusts the truncation window (e.g., last 20 messages).
    *   **Usage**: Lower this if you encounter "Context Window Exceeded" errors or want to reduce API costs.

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