// ----------------------------------------------------------------------
// GLOBAL HELPERS & CONSTANTS
// ----------------------------------------------------------------------
const Map<String, String> kModelDisplayNames = {};

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