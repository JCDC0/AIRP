// ----------------------------------------------------------------------
// GLOBAL HELPERS & CONSTANTS
// ----------------------------------------------------------------------
const Map<String, String> kModelDisplayNames = {
  // Gemini 3 Series
  'models/gemini-3-pro-preview': '⭐Gemini 3 Pro Preview (Expensive)',
  'models/gemini-3-flash-preview': '⭐Gemini 3 Flash Preview (Fast)',
  // Gemini 2.5 Series
  'models/gemini-2.5-pro': '⭐Gemini 2.5 Pro (Middle ground)',
  'models/gemini-flash-latest': '⭐Gemini 2.5 Flash Latest (Cheap)',
  'models/gemini-flash-lite-latest': '⭐Gemini 2.5 Flash Latest Lite (Cheaper)',
  // Gemini 2.0 Series
  'models/gemini-2.0-flash': '⭐Gemini 2.0 Flash',
  'models/gemini-2.0-flash-lite': '⭐Gemini 2.0 Flash Lite',
  // Gemma 3 Series
  'models/gemma-3-27b-it': '⭐Gemma 3 27B (Desktop Class)',
  'models/gemma-3-12b-it': '⭐Gemma 3 12B (Efficient)',
  'models/gemma-3-4b-it': '⭐Gemma 3 4B (Lightweight)',
  'models/gemma-3-2b-it': '⭐Gemma 3 2B (Small)',
  'models/gemma-3-1b-it': '⭐Gemma 3 1B (Tiny)',
    // OpenRouter Models (Free)
  'allenai/olmo-3.1-32b-think:free': '⭐Olmo 3.1 32B Think (OpenRouter Free)',
  'cognitivecomputations/dolphin-mistral-24b-venice-edition:free': '⭐Dolphin Mistral 24B Venice (OpenRouter Free)',
  'deepseek/deepseek-r1-0528:free': '⭐DeepSeek R1 (OpenRouter Free)',
  'google/gemma-3-27b-it:free': '⭐Gemma 3 27B It (OpenRouter Free)',
  'google/gemini-2.0-flash-exp:free': '⭐Gemini 2.0 Flash Exp (OpenRouter Free)',
  'meta-llama/llama-3.1-405b-instruct:free': '⭐Llama 3.1 405B Instruct (OpenRouter Free)',
  'meta-llama/llama-3.3-70b-instruct:free': '⭐Llama 3.3 70B Instruct (OpenRouter Free)',
  'mistralai/devstral-2512:free': '⭐DevStral 25B (OpenRouter Free)',
  'mistralai/mistral-7b-instruct:free': '⭐Mistral 7B Instruct (OpenRouter Free)',
  'mistralai/mistral-small-3.1-24b-instruct:free': '⭐Mistral Small 3.1 24B Instruct (OpenRouter Free)',
  'nex-agi/deepseek-v3.1-nex-n1:free': '⭐DeepSeek V3.1 NEX-N1 (OpenRouter Free)',
  'openai/gpt-oss-120b:free': '⭐GPT-OSS 120B (OpenRouter Free)',
  'openai/gpt-oss-20b:free': '⭐GPT-OSS 20B (OpenRouter Free)',
  'qwen/qwen3-coder:free': '⭐Qwen3 Coder (OpenRouter Free)',
  'tngtech/deepseek-r1t-chimera:free': '⭐DeepSeek R1T Chimera (OpenRouter Free)',
  'tngtech/deepseek-r1t2-chimera:free': '⭐DeepSeek R1T2 Chimera (OpenRouter Free)',
  'tngtech/tng-r1t-chimera:free': '⭐TNG R1T Chimera (OpenRouter Free)',
  'xiaomi/mimo-v2-flash:free': '⭐Mimo V2 Flash (OpenRouter Free)',
  // OpenRouter Models (Paid)
  'deepseek/deepseek-chat-v3-0324': '⭐⭐ ⚠️DeepSeek Chat V3 (OpenRouter Paid)',
  'tngtech/deepseek-r1t2-chimera': '⭐⭐ ⚠️DeepSeek R1T2 Chimera (OpenRouter Paid)',
  'tngtech/deepseek-r1t-chimera': '⭐⭐ ⚠️DeepSeek R1T Chimera (OpenRouter Paid)',
  'tngtech/tng-r1t-chimera': '⭐⭐⭐ ⚠️TNG R1T Chimera (OpenRouter Paid)',
  'deepseek/deepseek-chat-v3.1-0528': '⭐⭐ ⚠️DeepSeek Chat V3.1 (OpenRouter Paid)',
  'deepseek/deepseek-v3.1-terminus': '⭐⭐⭐ ⚠️DeepSeek V3.1 Terminus (OpenRouter Paid)',
  'deepseek/deepseek-v3.2': '⭐⭐⭐ ⚠️DeepSeek V3.2 (OpenRouter Paid)',
  'deepseek/deepseek-v3.2-exp': '⭐ ⚠️DeepSeek V3.2 Exp (OpenRouter Paid)',
  'google/gemini-2.5-flash': '⭐ ⚠️Gemini 2.5 Flash (OpenRouter Paid)',
  'google/gemini-3-flash-preview': '⭐⭐ ⚠️Gemini 3 Flash Preview (OpenRouter Paid)',
  'google/gemini-3-pro-preview': '⭐⭐ ⚠️Gemini 3 Pro Preview (OpenRouter Paid)',
  'x-ai/grok-4.1-fast': '⭐⭐⭐ ⚠️Grok 4.1 Fast (OpenRouter Paid)',
  'z-ai/glm-4.5-air': '⭐⭐ ⚠️GLM-4.5-AIR (OpenRouter Paid)',
  'z-ai/glm-4.6':'⭐⭐⭐ ⚠️GLM-4.6 (OpenRouter Paid)',
  'z-ai/glm-4.7': '⭐⭐⭐ ⚠️GLM-4.7 (OpenRouter Paid)',
};

String cleanModelName(String rawId) {
  // 1. Check if we have a manual override (The Dictionary)
  if (kModelDisplayNames.containsKey(rawId)) {
    return kModelDisplayNames[rawId]!;
  }

  // Quick local check
  if (rawId.contains("local")) return "Local / Home AI";

  // 2. Algorithmically Clean the Name
  String name = rawId;

  // Remove OpenRouter Vendor prefixes (e.g., "google/", "meta-llama/")
  if (name.contains('/')) {
    name = name.split('/').last; 
  }

  // Remove typical suffixes
  name = name.replaceAll(':free', ' (Free)');
  
  // Replace symbols with spaces
  name = name.replaceAll('-', ' ').replaceAll('_', ' ').replaceAll('.', ' .');

  // Capitalize Words (Title Case)
  List<String> words = name.split(' ');
  for (int i = 0; i < words.length; i++) {
    if (words[i].isNotEmpty) {
      words[i] = words[i][0].toUpperCase() + words[i].substring(1);
    }
  }
  name = words.join(' ');
  // Fix spacing before periods
  name = name.replaceAll(' .', '.');

  return name;
}

// ----------------------------------------------------------------------
// ASSET CONSTANTS
// ----------------------------------------------------------------------
const String kDefaultBackground = 'assets/default.jpg';

const List<String> kAssetBackgrounds = [ 
  'assets/67_horror.jpg',
  'assets/Backrooms_2.jpg',
  'assets/beach_morning.jpg',
  'assets/beach_night.jpg',
  'assets/building.jpg',
  'assets/cafe.jpg',
  'assets/city.jpg',
  'assets/classroom_afternoon.jpg',
  'assets/classroom_morning.jpg',
  'assets/classroom_night.png',
  'assets/dark_hallway.jpg',
  'assets/default.jpg',
  'assets/du_street.jpg',
  'assets/gym_pool.jpg',
  'assets/horror_dark.jpg',
  'assets/hoshinoBG.jpg',
  'assets/japan_river.jpg',
  'assets/judgement_hall.jpg',
  'assets/kivotos.png',
  'assets/military_park.jpg',
  'assets/minecraft_lake.jpg',
  'assets/nightsky.jpg',
  'assets/starrysky.jpg',
  'assets/soothingsea.jpg',
  'assets/soothingsky.jpg',
  'assets/still_waters.jpg',
  'assets/trainer_office.jpg',
  'assets/turf.jpeg',
];