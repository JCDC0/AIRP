AIRP - Gemini & OpenRouter Chat Client
AIRP is a highly customizable, privacy-focused AI chat client built with Flutter. It serves as a unified interface for Google's Gemini models and the OpenRouter ecosystem (Claude, DeepSeek, Llama, and more), featuring deep visual customization and a robust system prompt library.
![alt text](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)

![alt text](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)

![alt text](https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=google&logoColor=white)
✨ Features
Multi-Provider Support: Switch seamlessly between Google Gemini (native) and OpenRouter (access to 100+ models).
Visual Customization: Change chat bubble colors, text colors, interface fonts, and set custom background wallpapers with dimming/opacity controls.
System Prompt Library: Save, load, and manage custom roleplay personas or system instructions.
Multimodal Support: Send images to compatible models (e.g., Gemini 1.5 Flash, GPT-4o via OpenRouter).
Google Search Grounding: Enable real-time web search integration for Gemini models.
Chat History: Auto-saves conversation history locally.
Token Counting: Real-time token usage estimation.
🚀 Getting Started
Prerequisites
Flutter SDK installed.
An IDE (VS Code or Android Studio).
Installation
Clone the repository:
code
Bash
git clone https://github.com/your-username/airp-chat.git
cd airp-chat
Install dependencies:
code
Bash
flutter pub get
Run the app:
code
Bash
flutter run
🔑 API Configuration
This app follows a BYOK (Bring Your Own Key) architecture. Your keys are stored locally on your device and never sent to a third-party server other than the AI providers themselves.
1. Google Gemini (Google AI Studio)
Best for: Free tier usage, high speed, large context window.
How to get a key:
Go to Google AI Studio.
Click "Get API key" in the sidebar.
Click "Create API key" (you can create one in a new or existing project).
Copy the string starting with AIza....
2. OpenRouter (Universal API)
Best for: Accessing models like DeepSeek, Claude 3.5 Sonnet, Llama 3, etc.
How to get a key:
Go to OpenRouter.ai.
Sign up or Log in.
Go to Keys in the profile menu.
Click "Create Key".
Name it "AIRP Chat" (optional) and copy the key starting with sk-or....
Note: Some OpenRouter models are free, but most require you to add valid credits ($5 minimum) to your account.
⚙️ Usage Guide
Saving Settings (IMPORTANT)
When entering API keys or changing settings in the Drawer:
Paste your API Key.
YOU MUST PRESS THE "APPLY & SAVE" BUTTON. 🚨
If you do not press this button, the key will not be saved to disk, and the chat engine will not update to use the new credentials.
Switching Models
Gemini: Select from the dropdown list in Settings.
OpenRouter:
Enter your API Key and press APPLY & SAVE.
Click the "Load Model List" button (cloud icon).
Once fetched, select your desired model from the dropdown.
Press APPLY & SAVE again to confirm the model choice.
Custom Backgrounds
Open the Settings Drawer.
Scroll to "Visuals & Atmosphere".
Click the Add Photo icon to pick an image from your gallery.
Long-press a custom image to delete it.
⚠️ Disclaimer & "Vibe Coding"
This project was "Vibe Coded" ⚡.
What does that mean?
It was built rapidly to satisfy specific personal needs and aesthetic preferences.
It utilizes AI assistance (LLMs) heavily in its development process for boilerplate and logic generation.
While functional and tested, it is intended as a personal project/portfolio piece rather than enterprise-grade software.
Use at your own risk. The developer is not responsible for API costs incurred via OpenRouter or Google Cloud.
📄 License
This project is open-source and available under the MIT License.