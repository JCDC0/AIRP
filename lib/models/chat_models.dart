import 'package:flutter/foundation.dart';

/// The available AI providers supported by the application.
enum AiProvider {
  gemini,
  openRouter,
  openAi,
  local,
  arliAi,
  nanoGpt,
  huggingFace,
  groq,
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

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imagePaths = const [],
    this.aiImage,
    this.modelName,
    this.usage,
    this.thoughtSignature,
    this.contentNotifier,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'imagePaths': imagePaths,
    'aiImage': aiImage,
    'modelName': modelName,
    'usage': usage,
    'thoughtSignature': thoughtSignature,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] ?? "",
    isUser: json['isUser'] ?? false,
    imagePaths: List<String>.from(json['imagePaths'] ?? []),
    aiImage: json['aiImage'],
    modelName: json['modelName'],
    usage: json['usage'],
    thoughtSignature: json['thoughtSignature'],
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
