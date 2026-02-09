import 'package:flutter/material.dart';

// ----------------------------------------------------------------------
// GLOBAL HELPERS & CONSTANTS
// ----------------------------------------------------------------------
String cleanModelName(String rawId) {
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

class AppColors {
  static const Color defaultAppTheme = Colors.white;
  static const Color defaultUserBubble = Color.fromARGB(
    204,
    0,
    70,
    70,
  ); // 0.8 opacity
  static const Color defaultUserText = Colors.white;
  static const Color defaultAiBubble = Color.fromARGB(
    204,
    44,
    44,
    44,
  ); // 0.8 opacity
  static const Color defaultAiText = Colors.white;
}

// ----------------------------------------------------------------------
// API CONSTANTS
// ----------------------------------------------------------------------
class ApiConstants {
  // Base URLs
  static const String geminiBaseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models";
  static const String openRouterBaseUrl = "https://openrouter.ai/api/v1/models";
  static const String arliAiBaseUrl = "https://api.arliai.com/v1/models";
  static const String nanoGptBaseUrl = "https://nano-gpt.com/api/v1/models";
  static const String openAiBaseUrl = "https://api.openai.com/v1/models";
  static const String huggingFaceBaseUrl =
      "https://huggingface.co/api/models?pipeline_tag=text-generation&sort=downloads&limit=100";
  static const String groqBaseUrl = "https://api.groq.com/openai/v1/models";

  // Preference Keys (Lists)
  static const String prefListGemini = 'airp_list_gemini';
  static const String prefListOpenRouter = 'airp_list_openrouter';
  static const String prefListArliAi = 'airp_list_arliai';
  static const String prefListNanoGpt = 'airp_list_nanogpt';
  static const String prefListOpenAi = 'airp_list_openai';
  static const String prefListHuggingFace = 'airp_list_huggingface';
  static const String prefListGroq = 'airp_list_groq';

  // Preference Keys (API Keys)
  static const String prefKeyGemini = 'airp_key_gemini';
  static const String prefKeyOpenRouter = 'airp_key_openrouter';
  static const String prefKeyOpenAi = 'airp_key_openai';
  static const String prefKeyArliAi = 'airp_key_arliai';
  static const String prefKeyNanoGpt = 'airp_key_nanogpt';
  static const String prefKeyHuggingFace = 'airp_key_huggingface';
  static const String prefKeyGroq = 'airp_key_groq';

  // Preference Keys (Selected Models)
  static const String prefModelGemini = 'airp_model_gemini';
  static const String prefModelOpenRouter = 'airp_model_openrouter';
  static const String prefModelArliAi = 'airp_model_arliai';
  static const String prefModelNanoGpt = 'airp_model_nanogpt';
  static const String prefModelOpenAi = 'airp_model_openai';
  static const String prefModelHuggingFace = 'airp_model_huggingface';
  static const String prefModelGroq = 'airp_model_groq';
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
  'assets/trainer_office.jpg',
  'assets/turf.jpeg',
];
