import 'package:flutter/foundation.dart';

/// The available AI providers supported by the application.
enum AiProvider {
  gemini,
  openRouter,
  openAi,
  local,
  arliAi,
  nanoGpt,
  nanoGptImage,
  huggingFace,
  groq,
  vertexAi,
  blackboxAi,
  minimax,
  openAiCompatible,
  deepseek,
  ollama,
  qwen,
  xAi,
  zAi,
  mistral,
}

/// Data structure representing a saved chat session.
class ChatSessionData {
  /// Unique identifier for the session.
  final String id;

  /// The user-defined or auto-generated title for the session.
  final String title;

  /// The list of messages in this session.
  final List<ChatMessage> messages;

  /// The name of the model used in this session.
  final String modelName;

  /// Total token count for the session.
  final int tokenCount;

  /// The system instruction used during the session.
  final String systemInstruction;

  /// Path to the background image, if any.
  final String? backgroundImage;

  /// The AI provider used for this session.
  final String provider;

  /// Whether the session is marked as a favorite.
  final bool isBookmarked;

  ChatSessionData({
    required this.id,
    required this.title,
    required this.messages,
    required this.modelName,
    required this.tokenCount,
    required this.systemInstruction,
    this.backgroundImage,
    this.provider = 'gemini',
    this.isBookmarked = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'modelName': modelName,
    'tokenCount': tokenCount,
    'systemInstruction': systemInstruction,
    'backgroundImage': backgroundImage,
    'provider': provider,
    'isBookmarked': isBookmarked,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatSessionData.fromJson(Map<String, dynamic> json) =>
      ChatSessionData(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] ?? "Untitled",
        messages:
            (json['messages'] as List?)
                ?.map((m) => ChatMessage.fromJson(m))
                .toList() ??
            [],
        modelName: json['modelName'] ?? 'models/gemini-3-flash-preview',
        tokenCount: json['tokenCount'] ?? 0,
        systemInstruction: json['systemInstruction'] ?? "",
        backgroundImage: json['backgroundImage'],
        provider: json['provider'] ?? 'gemini',
        isBookmarked: json['isBookmarked'] ?? false,
      );
}

/// Represents a single message within a chat session.
class ChatMessage {
  /// The textual content of the message.
  final String text;

  /// Whether the message was sent by the user.
  final bool isUser;

  /// List of file paths for images attached to the message.
  final List<String> imagePaths;

  /// Base64 encoded string of an AI-generated image.
  final String? aiImage;

  /// The name of the model that generated the response.
  final String? modelName;

  /// Token usage statistics for this message.
  final Map<String, dynamic>? usage;

  /// A signature for reasoning-capable models to maintain context.
  final String? thoughtSignature;

  /// A notifier for streaming message content.
  final ValueNotifier<String>? contentNotifier;

  /// List of all regeneration versions of this AI response (for AI messages only).
  /// Each version contains the full response text.
  final List<String> regenerationVersions;

  /// The current version index being displayed (0-based).
  /// If message has 3 versions, this would be 0, 1, or 2.
  final int currentVersionIndex;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imagePaths = const [],
    this.aiImage,
    this.modelName,
    this.usage,
    this.thoughtSignature,
    this.contentNotifier,
    this.regenerationVersions = const [],
    this.currentVersionIndex = 0,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'imagePaths': imagePaths,
    'aiImage': aiImage,
    'modelName': modelName,
    'usage': usage,
    'thoughtSignature': thoughtSignature,
    'regenerationVersions': regenerationVersions,
    'currentVersionIndex': currentVersionIndex,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] ?? "",
    isUser: json['isUser'] ?? false,
    imagePaths: List<String>.from(json['imagePaths'] ?? []),
    aiImage: json['aiImage'],
    modelName: json['modelName'],
    usage: json['usage'],
    thoughtSignature: json['thoughtSignature'],
    regenerationVersions: List<String>.from(json['regenerationVersions'] ?? []),
    currentVersionIndex: json['currentVersionIndex'] ?? 0,
  );

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    List<String>? imagePaths,
    String? aiImage,
    String? modelName,
    Map<String, dynamic>? usage,
    String? thoughtSignature,
    ValueNotifier<String>? contentNotifier,
    bool clearContentNotifier = false,
    List<String>? regenerationVersions,
    int? currentVersionIndex,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      imagePaths: imagePaths ?? this.imagePaths,
      aiImage: aiImage ?? this.aiImage,
      modelName: modelName ?? this.modelName,
      usage: usage ?? this.usage,
      thoughtSignature: thoughtSignature ?? this.thoughtSignature,
      contentNotifier: clearContentNotifier ? null : (contentNotifier ?? this.contentNotifier),
      regenerationVersions: regenerationVersions ?? this.regenerationVersions,
      currentVersionIndex: currentVersionIndex ?? this.currentVersionIndex,
    );
  }
}

/// A notification shown when a background AI response completes.
class BackgroundNotification {
  /// Title of the conversation that completed.
  final String sessionTitle;

  /// Preview of the AI response message.
  final String messagePreview;

  /// The model that generated the response.
  final String modelName;

  /// When the notification was created.
  final DateTime timestamp;

  BackgroundNotification({
    required this.sessionTitle,
    required this.messagePreview,
    required this.modelName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Data structure for a saved system prompt preset.
class SystemPromptData {
  /// The title of the prompt preset.
  final String title;

  /// The content of the system instruction.
  final String content;

  SystemPromptData({required this.title, required this.content});

  Map<String, dynamic> toJson() => {'title': title, 'content': content};

  factory SystemPromptData.fromJson(Map<String, dynamic> json) {
    return SystemPromptData(
      title: json['title'] ?? "Untitled",
      content: json['content'] ?? "",
    );
  }
}

/// Detailed information about an AI model.
class ModelInfo {
  final String id;
  final String name;
  final String description;
  final String contextLength;
  final String pricing; // e.g. "0.01 / 0.03 per 1M"
  final int? created; // Unix timestamp
  final Map<String, dynamic>? rawData;

  /// Whether this model is an image generation model.
  final bool isImageGen;

  ModelInfo({
    required this.id,
    required this.name,
    this.description = "",
    this.contextLength = "",
    this.pricing = "",
    this.created,
    this.rawData,
    this.isImageGen = false,
  });

  /// Returns true if the given model ID or rawData indicates an image-gen model.
  ///
  /// Checks OpenRouter's `architecture.modality == "image"` first, then falls
  /// back to substring matching against known image model name fragments.
  static bool detectImageGen(String modelId, Map<String, dynamic>? rawData) {
    // OpenRouter metadata check
    try {
      final modality = rawData?['architecture']?['modality'];
      if (modality != null && modality.toString().contains('image')) return true;
    } catch (_) {}

    // Substring fallback for providers without metadata
    final lower = modelId.toLowerCase();
    const fragments = [
      'imagen',
      'dall-e',
      'flux',
      'stable-diffusion',
      'sdxl',
      'recraft',
      'ideogram',
      'midjourney',
      'nano-banana',
      'nano-flux',
      'nano-imagen',
    ];
    return fragments.any((f) => lower.contains(f));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'contextLength': contextLength,
    'pricing': pricing,
    'created': created,
    'rawData': rawData,
    'isImageGen': isImageGen,
  };

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    final rawData = json['rawData'] as Map<String, dynamic>?;
    final id = json['id'] as String? ?? '';
    return ModelInfo(
      id: id,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      contextLength: json['contextLength']?.toString() ?? '',
      pricing: json['pricing'] as String? ?? '',
      created: json['created'] as int?,
      rawData: rawData,
      isImageGen: json['isImageGen'] as bool? ?? ModelInfo.detectImageGen(id, rawData),
    );
  }
}
