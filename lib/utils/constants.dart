import 'package:flutter/material.dart';

/// DISCLAIMER: AI-Generated Assets
/// ================================
/// The background images and visual assets referenced in this file were generated
/// using ComfyUI with the model: novaAnimeXL_ilV160.safetensors
/// These images are AI-generated and retain no copyrighted material from third parties.
/// Model source: https://huggingface.co/
/// Created with: ComfyUI (https://github.com/comfyanonymous/ComfyUI)

/// Cleans and formats a raw model ID into a user-friendly display name.
///
/// This removes vendor prefixes, handles special suffixes like ':free',
/// and converts snake_case or kebab-case to Title Case.
String cleanModelName(String rawId) {
  if (rawId.contains("local")) return "Local / Home AI";

  String name = rawId;

  if (name.contains('/')) {
    name = name.split('/').last;
  }

  name = name.replaceAll(':free', ' (Free)');

  name = name.replaceAll('-', ' ').replaceAll('_', ' ').replaceAll('.', ' .');

  List<String> words = name.split(' ');
  for (int i = 0; i < words.length; i++) {
    if (words[i].isNotEmpty) {
      words[i] = words[i][0].toUpperCase() + words[i].substring(1);
    }
  }
  name = words.join(' ');
  name = name.replaceAll(' .', '.');

  return name;
}

/// Default color palette for the application.
class AppColors {
  static const Color defaultAppTheme = Colors.white;
  static const Color defaultUserBubble = Color.fromARGB(204, 0, 70, 70);
  static const Color defaultUserText = Colors.white;
  static const Color defaultAiBubble = Color.fromARGB(204, 44, 44, 44);
  static const Color defaultAiText = Colors.white;
}

/// Default configuration for visual effects.
class AppDefaults {
  static const double backgroundOpacity = 0.7;
  static const int motesDensity = 75;
  static const int rainIntensity = 100;
  static const int firefliesCount = 50;
}

/// Default parameters for AI chat interactions.
class ChatDefaults {
  static const double temperature = 1.0;
  static const double topP = 0.95;
  static const int topK = 40;
  static const int maxOutputTokens = 8192;
  static const int historyLimit = 500;
  static const int sessionTitleMaxLength = 25;
  static const String localIp = 'http://192.168.1.15:1234/v1';
  static const Duration autoSaveDebounce = Duration(milliseconds: 600);
}

/// Default durations and values for UI animations.
class AnimationDefaults {
  static const Duration drawerDuration = Duration(milliseconds: 300);
  static const Duration zoomResetDuration = Duration(milliseconds: 300);
  static const Duration zoomButtonDuration = Duration(milliseconds: 400);
  static const double drawerDragDivisor = 360.0;
  static const double endDrawerDragDivisor = 370.0;
  static const double drawerVelocityThreshold = 365.0;
}

/// API endpoints and configuration keys.
class ApiConstants {
  static const String geminiBaseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models";
  static const String openRouterBaseUrl = "https://openrouter.ai/api/v1/models";
  static const String arliAiBaseUrl = "https://api.arliai.com/v1/models";
  static const String nanoGptBaseUrl = "https://nano-gpt.com/api/v1/models?detailed=true";
  static const String openAiBaseUrl = "https://api.openai.com/v1/models";
  static const String huggingFaceBaseUrl =
      "https://huggingface.co/api/models?pipeline_tag=text-generation&sort=downloads&limit=100";
  static const String groqBaseUrl = "https://api.groq.com/openai/v1/models";

  static const String prefListGemini = 'airp_list_gemini';
  static const String prefListOpenRouter = 'airp_list_openrouter';
  static const String prefListArliAi = 'airp_list_arliai';
  static const String prefListNanoGpt = 'airp_list_nanogpt';
  static const String prefListOpenAi = 'airp_list_openai';
  static const String prefListHuggingFace = 'airp_list_huggingface';
  static const String prefListGroq = 'airp_list_groq';

  static const String prefKeyGemini = 'airp_key_gemini';
  static const String prefKeyOpenRouter = 'airp_key_openrouter';
  static const String prefKeyOpenAi = 'airp_key_openai';
  static const String prefKeyArliAi = 'airp_key_arliai';
  static const String prefKeyNanoGpt = 'airp_key_nanogpt';
  static const String prefKeyHuggingFace = 'airp_key_huggingface';
  static const String prefKeyGroq = 'airp_key_groq';

  static const String secureKeyGemini = 'secure_airp_key_gemini';
  static const String secureKeyOpenRouter = 'secure_airp_key_openrouter';
  static const String secureKeyOpenAi = 'secure_airp_key_openai';
  static const String secureKeyArliAi = 'secure_airp_key_arliai';
  static const String secureKeyNanoGpt = 'secure_airp_key_nanogpt';
  static const String secureKeyHuggingFace = 'secure_airp_key_huggingface';
  static const String secureKeyGroq = 'secure_airp_key_groq';

  static const String prefModelGemini = 'airp_model_gemini';
  static const String prefModelOpenRouter = 'airp_model_openrouter';
  static const String prefModelArliAi = 'airp_model_arliai';
  static const String prefModelNanoGpt = 'airp_model_nanogpt';
  static const String prefModelOpenAi = 'airp_model_openai';
  static const String prefModelHuggingFace = 'airp_model_huggingface';
  static const String prefModelGroq = 'airp_model_groq';

  static const String prefLocalIp = 'airp_local_ip';
  static const String prefLocalModelName = 'airp_local_model_name';
  static const String prefEnableGrounding = 'airp_enable_grounding';
  static const String prefEnableImageGen = 'airp_enable_image_gen';
  static const String prefDisableSafety = 'airp_disable_safety';

  // Web Search (BYOK)
  static const String prefKeySearchProvider = 'airp_search_provider';
  static const String prefKeyBraveApiKey = 'airp_key_brave_search';
  static const String secureKeyBraveApiKey = 'secure_airp_key_brave_search';
  static const String prefKeyTavilyApiKey = 'airp_key_tavily_search';
  static const String secureKeyTavilyApiKey = 'secure_airp_key_tavily_search';
  static const String prefKeySerperApiKey = 'airp_key_serper_search';
  static const String secureKeySerperApiKey = 'secure_airp_key_serper_search';
  static const String prefKeySearXNGUrl = 'airp_searxng_url';
  static const String prefSearchResultCount = 'airp_search_result_count';
}

/// The web search backend to use when the grounding toggle is active.
///
/// - [provider]  : Delegate to the AI provider's native grounding feature
///                 (e.g. Gemini Search, OpenRouter web plugin).
/// - [brave]     : Brave Search API (BYOK).
/// - [tavily]    : Tavily Search API — AI-optimised results (BYOK).
/// - [serper]    : Serper.dev — Google Search results via clean JSON (BYOK).
/// - [searxng]   : Self-hosted SearXNG instance.
/// - [duckduckgo]: DuckDuckGo HTML scraping — free but may be unreliable.
enum SearchProvider { provider, brave, tavily, serper, searxng, duckduckgo }

/// Path to the default background asset.
const String kDefaultBackground = 'assets/Minimalist_MoonlightBeachAlt_Portrait.png';

/// List of available background image assets.
/// All images are AI-generated using ComfyUI with novaAnimeXL_ilV160.safetensors model.
const List<String> kAssetBackgrounds = [
  'assets/Apocalyptic_DesertCamp_Landscape.png',
  'assets/Apocalyptic_DesertCamp_Portrait.png',
  'assets/Apocalyptic_OvergrownCity_Landscape.png',
  'assets/Apocalyptic_OvergrownCity_Portrait.png',
  'assets/Castle_Library_Landscape.png',
  'assets/Castle_Library_Portrait.png',
  'assets/Castle_ThroneRoom_Landscape.png',
  'assets/Castle_ThroneRoom_Portrait.png',
  'assets/ComfyUI_00003_.png',
  'assets/ComfyUI_00004_.png',
  'assets/Cyberpunk_Apartment_Landscape.png',
  'assets/Cyberpunk_Apartment_Portrait.png',
  'assets/DnD_Cavern_Landscape.png',
  'assets/DnD_Cavern_Portrait.png',
  'assets/DnD_DragonsHoard_Landscape.png',
  'assets/DnD_DragonsHoard_Portrait.png',
  'assets/Fantasy_CrystalForest_Landscape.png',
  'assets/Fantasy_CrystalForest_Portrait.png',
  'assets/Fantasy_Tavern_Landscape.png',
  'assets/Fantasy_Tavern_Portrait.png',
  'assets/Horror_Graveyard_Landscape.png',
  'assets/Horror_Graveyard_Portrait.png',
  'assets/Horror_Mansion_Landscape.png',
  'assets/Horror_Mansion_Portrait.png',
  'assets/Japan_Shrine_Landscape.png',
  'assets/Japan_Shrine_Portrait.png',
  'assets/Japan_Village_Landscape.png',
  'assets/Japan_Village_Portrait.png',
  'assets/Liminal_DarkHallway_Landscape.png',
  'assets/Liminal_DarkHallway_Portrait.png',
  'assets/Liminal_YellowHallway_Landscape.png',
  'assets/Liminal_YellowHallway_Portrait.png',
  'assets/Minimalist_AnimeSky_Landscape.png',
  'assets/Minimalist_AnimeSky_Portrait.png',
  'assets/Minimalist_BlurredClassroom_Landscape.png',
  'assets/Minimalist_BlurredClassroom_Portrait.png',
  'assets/Minimalist_DarkStarfield_Landscape.png',
  'assets/Minimalist_DarkStarfield_Portrait.png',
  'assets/Minimalist_EmptyZenRoom_Landscape.png',
  'assets/Minimalist_EmptyZenRoom_Portrait.png',
  'assets/Minimalist_MoonlightBeach_Landscape.png',
  'assets/Minimalist_MoonlightBeach_Portrait.png',
  'assets/Minimalist_MoonlightBeachAlt_Landscape.png',
  'assets/Minimalist_MoonlightBeachAlt_Portrait.png',
  'assets/Minimalist_PastelFlower_Landscape.png',
  'assets/Minimalist_PastelFlower_Portrait.png',
  'assets/Minimalist_SciFiWhiteRoom_Landscape.png',
  'assets/Minimalist_SciFiWhiteRoom_Portrait.png',
  'assets/Minimalist_SunsetBeach_Landscape.png',
  'assets/Minimalist_SunsetBeach_Portrait.png',
  'assets/Modern_Bedroom_Landscape.png',
  'assets/Modern_Bedroom_Portrait.png',
  'assets/Modern_SchoolRooftop_Landscape.png',
  'assets/Modern_SchoolRooftop_Portrait.png',
  'assets/Sakura_Tree_Clouds_Landscape.png',
  'assets/Sakura_Tree_Clouds_Portrait.png',
  'assets/Sakura_Tree_Landscape.png',
  'assets/Sakura_Tree_Portrait.png',
  'assets/Space_AlienPlanet_Landscape.png',
  'assets/Space_AlienPlanet_Portrait.png',
  'assets/Space_SpaceshipBridge_Landscape.png',
  'assets/Space_SpaceshipBridge_Portrait.png',
  'assets/Steampunk_ClockworkCity_Landscape.png',
  'assets/Steampunk_ClockworkCity_Portrait.png',
  'assets/Steampunk_Workshop_Landscape.png',
  'assets/Steampunk_Workshop_Portrait.png',
];
