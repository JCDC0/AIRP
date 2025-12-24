enum AiProvider { gemini, openRouter, openAi, local }

class ChatSessionData {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final String modelName;
  final int tokenCount;
  final String systemInstruction;
  final String? backgroundImage;
  final String provider; // Added this field so save/load works correctly

  ChatSessionData({
    required this.id,
    required this.title,
    required this.messages,
    required this.modelName,
    required this.tokenCount,
    required this.systemInstruction,
    this.backgroundImage,
    this.provider = 'gemini',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'modelName': modelName,
    'tokenCount': tokenCount,
    'systemInstruction': systemInstruction,
    'backgroundImage': backgroundImage,
    'provider': provider,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatSessionData.fromJson(Map<String, dynamic> json) => ChatSessionData(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title'] ?? "Untitled",
    messages: (json['messages'] as List?)
        ?.map((m) => ChatMessage.fromJson(m))
        .toList() ?? [],
    modelName: json['modelName'] ?? 'models/gemini-flash-lite-latest',
    tokenCount: json['tokenCount'] ?? 0,
    systemInstruction: json['systemInstruction'] ?? "",
    backgroundImage: json['backgroundImage'],
    provider: json['provider'] ?? 'gemini',
  );
}

class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> imagePaths;
  final String? aiImage;
  final String? modelName;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imagePaths = const [],
    this.aiImage,
    this.modelName,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'imagePaths': imagePaths,
    'aiImage': aiImage,
    'modelName': modelName,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] ?? "",
    isUser: json['isUser'] ?? false,
    imagePaths: List<String>.from(json['imagePaths'] ?? []),
    aiImage: json['aiImage'],
    modelName: json['modelName'],
  );
}

class SystemPromptData {
  final String title;
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