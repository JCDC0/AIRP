import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_models.dart';

/// A service class that handles communication with various AI provider APIs.
///
/// This service provides methods for streaming chat responses, performing
/// web-grounded searches, and generating images across multiple providers.
class ChatApiService {
  static void _logWarning(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Streams a response from Google Gemini, handling text content and various
  /// file attachments (images, PDFs, and text-based source files).
  static Stream<String> streamGeminiResponse({
    required ChatSession chatSession,
    required String message,
    required List<String> imagePaths,
    required String modelName,
  }) async* {
    final List<Part> parts = [];
    String accumulatedText = message;

    if (imagePaths.isNotEmpty) {
      for (String path in imagePaths) {
        final String ext = path.split('.').last.toLowerCase();

        if ([
          'txt',
          'md',
          'json',
          'dart',
          'js',
          'py',
          'html',
          'css',
          'csv',
          'c',
          'cpp',
          'java',
        ].contains(ext)) {
          try {
            final String fileContent = await File(path).readAsString();
            accumulatedText +=
                "\n\n--- Attached File: ${path.split('/').last} ---\n$fileContent\n--- End File ---\n";
          } catch (e) {
            _logWarning('Failed to read attachment: $path ($e)');
          }
        } else {
          try {
            final bytes = await File(path).readAsBytes();
            String? mimeType;
            if (['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'].contains(ext)) {
              mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
            } else if (ext == 'pdf') {
              mimeType = 'application/pdf';
            }

            if (mimeType != null) parts.add(DataPart(mimeType, bytes));
          } catch (e) {
            _logWarning('Failed to read binary attachment: $path ($e)');
          }
        }
      }
    }

    if (accumulatedText.isNotEmpty) parts.insert(0, TextPart(accumulatedText));
    final userContent = parts.isNotEmpty
        ? Content.multi(parts)
        : Content.text(accumulatedText);

    final stream = chatSession.sendMessageStream(userContent);

    await for (final dynamic response in stream) {
      try {
        String? text;
        try {
          text = response.text;
        } catch (e) {
          _logWarning('Failed to extract response text: $e');
        }
        if (text != null) {
          yield text;
        }

        String? tryExtractSignature(dynamic r) {
          try {
            if (r == null) return null;
            if (r is Map) {
              return r['thought_signature']?.toString() ??
                  r['thoughtSignature']?.toString();
            }
            try {
              final sig = r.thoughtSignature;
              if (sig != null) return sig.toString();
            } catch (_) {}
            try {
              final json = r.toJson();
              if (json is Map) {
                return json['thought_signature']?.toString() ??
                    json['thoughtSignature']?.toString();
              }
            } catch (_) {}
          } catch (_) {}
          return null;
        }

        final sig = tryExtractSignature(response);
        if (sig != null && sig.isNotEmpty) {
          yield '[[THOUGHT_SIG:$sig]]';
        }
      } catch (e) {
        _logWarning('Failed to extract thought signature: $e');
      }
    }
  }

  /// Streams responses from OpenAI-compatible endpoints (OpenRouter, Groq, etc.).
  /// Supports multimodal inputs by converting images to base64 and appending
  /// text file contents directly to the prompt.
  static Stream<String> streamOpenAiCompatible({
    required String apiKey,
    required String baseUrl,
    required String model,
    required List<ChatMessage> history,
    required String systemInstruction,
    required String userMessage,
    required List<String> imagePaths,
    double? temperature,
    double? topP,
    int? topK,
    int? maxTokens,
    bool enableGrounding = false,
    String? reasoningEffort,
    Map<String, String>? extraHeaders,
    bool includeUsage = false,
    List<Map<String, dynamic>>? depthMessages,
  }) async* {
    final cleanKey = apiKey.trim();
    List<Map<String, dynamic>> messagesPayload = [];

    if (systemInstruction.isNotEmpty) {
      messagesPayload.add({"role": "system", "content": systemInstruction});
    }

    for (var msg in history) {
      messagesPayload.add({
        "role": msg.isUser ? "user" : "assistant",
        "content": msg.text,
      });
    }

    if (imagePaths.isEmpty) {
      messagesPayload.add({"role": "user", "content": userMessage});
    } else {
      List<Map<String, dynamic>> contentParts = [];

      if (userMessage.isNotEmpty) {
        contentParts.add({"type": "text", "text": userMessage});
      }

      for (String path in imagePaths) {
        final String ext = path.split('.').last.toLowerCase();

        if ([
          'txt',
          'md',
          'json',
          'dart',
          'js',
          'py',
          'html',
          'css',
          'csv',
          'c',
          'cpp',
          'java',
          'xml',
          'yaml',
          'yml',
        ].contains(ext)) {
          try {
            final String fileContent = await File(path).readAsString();
            contentParts.add({
              "type": "text",
              "text":
                  "\n\n--- Attached File: ${path.split('/').last} ---\n$fileContent\n--- End File ---\n",
            });
          } catch (e) {
            _logWarning('Failed to read attachment: $path ($e)');
          }
        } else if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext)) {
          try {
            final bytes = await File(path).readAsBytes();
            final base64Img = base64Encode(bytes);
            String mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
            if (ext == 'webp') mimeType = 'image/webp';
            if (ext == 'gif') mimeType = 'image/gif';

            contentParts.add({
              "type": "image_url",
              "image_url": {"url": "data:$mimeType;base64,$base64Img"},
            });
          } catch (e) {
            _logWarning('Failed to read image attachment: $path ($e)');
          }
        }
      }
      messagesPayload.add({"role": "user", "content": contentParts});
    }

    // Inject depth-positioned messages (lorebook at-depth, depth prompt, etc.)
    // Depth 0 = just before the final user message, depth N = N messages back.
    if (depthMessages != null && depthMessages.isNotEmpty) {
      for (final dm in depthMessages) {
        final depth = dm['depth'] as int? ?? 0;
        final content = dm['content'] as String? ?? '';
        final role = dm['role'] as String? ?? 'system';
        if (content.isEmpty) continue;

        // Insert position: count back from the end of messagesPayload.
        // depth 0 → second-to-last (before the final user message).
        final insertIdx =
            (messagesPayload.length - depth).clamp(1, messagesPayload.length);
        messagesPayload.insert(insertIdx, {'role': role, 'content': content});
      }
    }

    final Map<String, dynamic> bodyMap = {
      "model": model.trim(),
      "messages": messagesPayload,
      "stream": true,
    };

    if (temperature != null) bodyMap["temperature"] = temperature;
    if (topP != null) bodyMap["top_p"] = topP;
    if (topK != null) bodyMap["top_k"] = topK;
    if (maxTokens != null) bodyMap["max_tokens"] = maxTokens;
    if (includeUsage) bodyMap["stream_options"] = {"include_usage": true};

    if (baseUrl.contains("openrouter.ai")) {
      bodyMap["include_reasoning"] = true;
    }

    if (reasoningEffort != null && reasoningEffort != "none") {
      bodyMap["reasoning_effort"] = reasoningEffort;
    }

    if (enableGrounding) {
      bodyMap["plugins"] = baseUrl.contains("openrouter.ai")
          ? [
              {"id": "web"},
            ]
          : ["web_search"];
    }

    final request = http.Request('POST', Uri.parse(baseUrl));
    request.headers.addAll({
      "Authorization": "Bearer $cleanKey",
      "Content-Type": "application/json",
      ...?extraHeaders,
    });
    request.body = jsonEncode(bodyMap);

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        yield "\n\n**Error ${streamedResponse.statusCode}:** $errorBody";
        return;
      }

      bool hasEmittedThinkStart = false;
      bool hasEmittedThinkEnd = false;

      await for (final line
          in streamedResponse.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.startsWith("data: ")) {
          final dataStr = line.substring(6).trim();
          if (dataStr == "[DONE]") break;

          try {
            final json = jsonDecode(dataStr);

            if (includeUsage && json['usage'] != null) {
              yield "[[USAGE:${jsonEncode(json['usage'])}]]";
            }

            final choices = json['choices'] as List;
            if (choices.isNotEmpty) {
              final delta = choices[0]['delta'];
              final reasoningChunk =
                  delta['reasoning_content'] ?? delta['reasoning'];
              final contentChunk = delta['content'];

              if (reasoningChunk != null &&
                  reasoningChunk.toString().isNotEmpty) {
                if (!hasEmittedThinkStart) {
                  yield "<think>\n";
                  hasEmittedThinkStart = true;
                }
                yield reasoningChunk.toString();
              }

              if (contentChunk != null && contentChunk.toString().isNotEmpty) {
                if (hasEmittedThinkStart && !hasEmittedThinkEnd) {
                  yield "\n</think>\n";
                  hasEmittedThinkEnd = true;
                }
                yield contentChunk.toString();
              }

              if (delta == null && choices[0]['text'] != null) {
                yield choices[0]['text'].toString();
              }
            }
          } catch (e) {
            _logWarning('Stream chunk parse warning: $e');
          }
        }
      }
      if (hasEmittedThinkStart && !hasEmittedThinkEnd) yield "\n</think>\n";
    } catch (e) {
      yield "\n\n**Connection Error:** $e";
    } finally {
      client.close();
    }
  }

  /// Handles Google Gemini's grounding (web search) feature.
  /// This requires a non-streaming call to include grounding metadata.
  static Future<Map<String, dynamic>?> performGeminiGrounding({
    required String apiKey,
    required String model,
    required List<ChatMessage> history,
    required String userMessage,
    required String systemInstruction,
    bool disableSafety = true,
    String? thoughtSignature,
  }) async {
    final modelId = model.replaceAll('models/', '');
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey',
    );

    final List<Map<String, dynamic>> contents = [];
    for (var msg in history) {
      contents.add({
        "role": msg.isUser ? "user" : "model",
        "parts": [
          {"text": msg.text},
        ],
      });
    }
    contents.add({
      "role": "user",
      "parts": [
        {"text": userMessage},
      ],
    });

    final Map<String, dynamic> bodyMap = {
      "contents": contents,
      "tools": [
        {"google_search": {}},
      ],
      "system_instruction": systemInstruction.isNotEmpty
          ? {
              "parts": [
                {"text": systemInstruction},
              ],
            }
          : null,
      "safetySettings": disableSafety
          ? [
              {
                "category": "HARM_CATEGORY_HARASSMENT",
                "threshold": "BLOCK_NONE",
              },
              {
                "category": "HARM_CATEGORY_HATE_SPEECH",
                "threshold": "BLOCK_NONE",
              },
              {
                "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "threshold": "BLOCK_NONE",
              },
              {
                "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                "threshold": "BLOCK_NONE",
              },
            ]
          : [],
    };

    // Pass back thought signature if available (Required for Gemini 3+)
    if (thoughtSignature != null && thoughtSignature.isNotEmpty) {
      bodyMap["thought_signature"] = thoughtSignature;
    }

    final body = jsonEncode(bodyMap);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null &&
            (data['candidates'] as List).isNotEmpty) {
          final candidate = data['candidates'][0];
          final parts = candidate['content']['parts'] as List;
          String fullText = "";
          for (var part in parts) {
            if (part['text'] != null) fullText += part['text'];
          }

          if (candidate['groundingMetadata'] != null) {
            fullText += "\n\n--- \n**Sources Found:**\n";
            final metadata = candidate['groundingMetadata'];
            if (metadata['groundingChunks'] != null) {
              for (var chunk in metadata['groundingChunks']) {
                if (chunk['web'] != null) {
                  fullText +=
                      "- [${chunk['web']['title']}](${chunk['web']['uri']})\n";
                }
              }
            }
          }

          // Extract new thought signature if present
          String? newSignature;
          if (data['thought_signature'] != null) {
            newSignature = data['thought_signature'];
          } else if (candidate['thought_signature'] != null) {
            newSignature = candidate['thought_signature'];
          }

          return {"text": fullText, "thoughtSignature": newSignature};
        }
      }
    } catch (e) {
      return {"text": "Grounding Error: $e"};
    }
    return null;
  }

  /// Generates an image based on a text prompt using an OpenAI-compatible
  /// images endpoint (OpenAI DALL-E, OpenRouter image models, NanoGPT).
  ///
  /// Returns the image as a base64-encoded string on success,
  /// or an error message string starting with "Error:" on failure.
  static Future<String?> generateImage({
    required String apiKey,
    required String prompt,
    required String model,
    String provider = 'openai',
    String size = '1024x1024',
  }) async {
    final String url;
    switch (provider) {
      case 'openrouter':
        url = 'https://openrouter.ai/api/v1/images/generations';
      case 'nanogpt':
        url = 'https://nano-gpt.com/api/v1/images/generations';
      case 'openai':
      default:
        url = 'https://api.openai.com/v1/images/generations';
    }

    final body = jsonEncode({
      'model': model,
      'prompt': prompt,
      'n': 1,
      'size': size,
      'response_format': 'url',
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['data']?[0]?['url'];
        if (imageUrl == null) return 'Error: No URL in response';
        return await _downloadImageAsBase64(imageUrl);
      } else {
        return 'Error: ${response.statusCode} – ${response.body}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Downloads an image from [url] and returns it as a base64-encoded string.
  ///
  /// Returns null if the download fails.
  static Future<String?> _downloadImageAsBase64(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return base64Encode(response.bodyBytes);
      }
    } catch (e) {
      _logWarning('Image download failed: $e');
    }
    return null;
  }

  /// Generates an image using Google's Imagen 3 model via the Gemini REST API.
  ///
  /// Returns the image as a base64-encoded string on success,
  /// or an error message string starting with "Error:" on failure.
  static Future<String?> generateImageGemini({
    required String apiKey,
    required String prompt,
    String model = 'imagen-3.0-generate-002',
    String aspectRatio = '1:1',
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:predict?key=$apiKey',
    );
    final body = jsonEncode({
      'instances': [
        {'prompt': prompt},
      ],
      'parameters': {
        'sampleCount': 1,
        'aspectRatio': aspectRatio,
      },
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final b64 =
            data['predictions']?[0]?['bytesBase64Encoded'] as String?;
        return b64; // Already base64 — no download needed.
      } else {
        return 'Error: ${response.statusCode} – ${response.body}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Fetches a list of available models from a provider's API.
  static Future<List<ModelInfo>> fetchModels({
    required String url,
    Map<String, String>? headers,
    required List<ModelInfo> Function(dynamic json) parser,
  }) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          throw Exception('Empty response from server');
        }
        final data = jsonDecode(response.body);
        final List<ModelInfo> models = parser(data);
        return models;
      } else {
        throw Exception('Failed to fetch models: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching models: $e');
    }
  }
}
