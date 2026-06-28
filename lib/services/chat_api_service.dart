import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_models.dart';
import 'file_io_helper.dart';
import 'reasoning_utils.dart';
import 'strategies/ai_provider_strategy.dart';

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
    Map<String, Uint8List>? attachmentBytes,
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
            String fileContent;
            final webBytes = attachmentBytes?[path];
            if (webBytes != null) {
              fileContent = utf8.decode(webBytes);
            } else {
              fileContent = await FileIOHelper.readString(path);
            }
            accumulatedText +=
                "\n\n--- Attached File: ${path.split('/').last} ---\n$fileContent\n--- End File ---\n";
          } catch (e) {
            _logWarning('Failed to read attachment: $path ($e)');
          }
        } else {
          try {
            Uint8List bytes;
            final webBytes = attachmentBytes?[path];
            if (webBytes != null) {
              bytes = webBytes;
            } else {
              bytes = await FileIOHelper.readBytes(path);
            }
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
    ThinkingFormat thinkingFormat = ThinkingFormat.reasoningEffort,
    Map<String, String>? extraHeaders,
    bool includeUsage = false,
    List<Map<String, dynamic>>? depthMessages,
    Map<String, Uint8List>? attachmentBytes,
    List<Map<String, dynamic>>? extraMessages,
  }) async* {
    final cleanKey = apiKey.trim();
    List<Map<String, dynamic>> messagesPayload = [];

    if (systemInstruction.isNotEmpty) {
      messagesPayload.add({"role": "system", "content": systemInstruction});
    }

    for (var msg in history) {
      messagesPayload.add({
        "role": msg.isUser ? "user" : "assistant",
        "content": msg.isUser
            ? msg.text
            : ReasoningUtils.stripThinkBlocks(msg.text),
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
            String fileContent;
            final webBytes = attachmentBytes?[path];
            if (webBytes != null) {
              fileContent = utf8.decode(webBytes);
            } else {
              fileContent = await FileIOHelper.readString(path);
            }
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
            Uint8List bytes;
            final webBytes = attachmentBytes?[path];
            if (webBytes != null) {
              bytes = webBytes;
            } else {
              bytes = await FileIOHelper.readBytes(path);
            }
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
        final insertIdx = (messagesPayload.length - depth).clamp(
          1,
          messagesPayload.length,
        );
        messagesPayload.insert(insertIdx, {'role': role, 'content': content});
      }
    }

    // Append any extra messages (e.g. assistant tool_calls + tool results from
    // a prior web_search tool round). These must follow the user message so
    // the model can produce its final answer grounded in the tool output.
    if (extraMessages != null && extraMessages.isNotEmpty) {
      messagesPayload.addAll(extraMessages);
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

    // OpenRouter exposes the model's internal reasoning trace when requested.
    if (baseUrl.contains("openrouter.ai")) {
      bodyMap["include_reasoning"] = true;
    }

    // Apply the provider-correct reasoning request field per official docs.
    final bool reasoningEnabled =
        reasoningEffort != null && reasoningEffort != "none";
    switch (thinkingFormat) {
      case ThinkingFormat.none:
        // Provider's reasoning models reason automatically; no request field.
        break;
      case ThinkingFormat.reasoningEffort:
        if (reasoningEnabled) {
          bodyMap["reasoning_effort"] = reasoningEffort;
        }
        break;
      case ThinkingFormat.enableThinking:
        bodyMap["enable_thinking"] = reasoningEnabled;
        break;
      case ThinkingFormat.thinkingObject:
        bodyMap["thinking"] = {
          "type": reasoningEnabled ? "enabled" : "disabled",
        };
        break;
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
      final msgText = msg.isUser
          ? msg.text
          : ReasoningUtils.stripThinkBlocks(msg.text);
      contents.add({
        "role": msg.isUser ? "user" : "model",
        "parts": [
          {"text": msgText},
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

  // ─────────────────────────────────────────────────────────────────────────
  // Web Search Tool-Call Detection (non-streaming)
  // ─────────────────────────────────────────────────────────────────────────

  /// Sends a NON-streaming request to an OpenAI-compatible endpoint with the
  /// `web_search` function tool attached, and inspects the response to decide
  /// whether the model wants to call the tool or has produced a final answer.
  ///
  /// [extraMessages] is appended to the assembled payload and is used to carry
  /// prior assistant `tool_calls` messages and `role:"tool"` result messages
  /// across multiple search rounds.
  ///
  /// On a final answer, returns `{type:'text', text, reasoning}`. On a tool
  /// request, returns `{type:'tool_call', toolCallId, toolName, toolArguments}`.
  /// On HTTP/parse failure, returns `{type:'error', text}`.
  static Future<ToolDetectionResult> requestOpenAiCompatibleWithToolDetection({
    required String apiKey,
    required String baseUrl,
    required String model,
    required List<ChatMessage> history,
    required String systemInstruction,
    required String userMessage,
    required List<Map<String, dynamic>> tools,
    List<Map<String, dynamic>>? extraMessages,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? reasoningEffort,
    ThinkingFormat thinkingFormat = ThinkingFormat.reasoningEffort,
    Map<String, String>? extraHeaders,
    int maxRoundsLeft = 1,
    http.Client? client,
  }) async {
    final cleanKey = apiKey.trim();
    final List<Map<String, dynamic>> messagesPayload = [];

    if (systemInstruction.isNotEmpty) {
      messagesPayload.add({'role': 'system', 'content': systemInstruction});
    }

    for (var msg in history) {
      messagesPayload.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.isUser
            ? msg.text
            : ReasoningUtils.stripThinkBlocks(msg.text),
      });
    }

    if (userMessage.isNotEmpty) {
      messagesPayload.add({'role': 'user', 'content': userMessage});
    }

    if (extraMessages != null && extraMessages.isNotEmpty) {
      messagesPayload.addAll(extraMessages);
    }

    final Map<String, dynamic> bodyMap = {
      'model': model.trim(),
      'messages': messagesPayload,
      'stream': false,
      'tools': tools,
      // 'auto' lets the model decide; we only attach the tool when a search
      // is still permitted this turn.
      'tool_choice': maxRoundsLeft > 0 ? 'auto' : 'none',
    };

    if (temperature != null) bodyMap['temperature'] = temperature;
    if (topP != null) bodyMap['top_p'] = topP;
    if (maxTokens != null) bodyMap['max_tokens'] = maxTokens;
    final bool reasoningEnabled =
        reasoningEffort != null && reasoningEffort != 'none';
    switch (thinkingFormat) {
      case ThinkingFormat.none:
        break;
      case ThinkingFormat.reasoningEffort:
        if (reasoningEnabled) {
          bodyMap['reasoning_effort'] = reasoningEffort;
        }
        break;
      case ThinkingFormat.enableThinking:
        bodyMap['enable_thinking'] = reasoningEnabled;
        break;
      case ThinkingFormat.thinkingObject:
        bodyMap['thinking'] = {
          'type': reasoningEnabled ? 'enabled' : 'disabled',
        };
        break;
    }

    final request = http.Request('POST', Uri.parse(baseUrl));
    request.headers.addAll({
      'Authorization': 'Bearer $cleanKey',
      'Content-Type': 'application/json',
      ...?extraHeaders,
    });
    request.body = jsonEncode(bodyMap);

    try {
      final http.Client activeClient = client ?? http.Client();
      final bool ownsClient = client == null;
      try {
        final response = await activeClient.send(request);
        final body = await response.stream.bytesToString();

        if (response.statusCode != 200) {
          return ToolDetectionResult(
            type: 'error',
            text: 'Error ${response.statusCode}: $body',
          );
        }

        final data = jsonDecode(body);
        final choices = data['choices'] as List?;
        if (choices == null || choices.isEmpty) {
          return ToolDetectionResult(
            type: 'error',
            text: 'No choices in response: $body',
          );
        }
        final choice = choices[0];
        final message = choice['message'] ?? choice['delta'] ?? {};
        final reasoning = (message['reasoning_content'] ?? message['reasoning'])
                ?.toString() ??
            '';
        final toolCalls = message['tool_calls'] as List?;

        if (toolCalls != null && toolCalls.isNotEmpty) {
          final tc = toolCalls[0];
          final id = (tc['id'] ?? '').toString();
          final fn = tc['function'] ?? {};
          final name = (fn['name'] ?? '').toString();
          final args = (fn['arguments'] ?? '').toString();
          return ToolDetectionResult(
            type: 'tool_call',
            toolCallId: id,
            toolName: name,
            toolArguments: args,
            reasoning: reasoning,
          );
        }

        final content = (message['content'] ?? '').toString();
        return ToolDetectionResult(
          type: 'text',
          text: content,
          reasoning: reasoning,
        );
      } finally {
        if (ownsClient) activeClient.close();
      }
    } catch (e) {
      return ToolDetectionResult(type: 'error', text: 'Connection Error: $e');
    }
  }

  /// Sends a NON-streaming Gemini request with a `functionDeclarations` tool
  /// and inspects the response for a function call or a final text answer.
  ///
  /// Mirrors [performGeminiGrounding] but swaps `google_search` for the
  /// caller-provided function declarations (used for BYOK web search).
  static Future<ToolDetectionResult> performGeminiFunctionDetection({
    required String apiKey,
    required String model,
    required List<ChatMessage> history,
    required String userMessage,
    required String systemInstruction,
    required List<Map<String, dynamic>> functionDeclarations,
    List<Map<String, dynamic>>? extraMessages,
    bool disableSafety = true,
    String? thoughtSignature,
    int maxRoundsLeft = 1,
    http.Client? client,
  }) async {
    final modelId = model.replaceAll('models/', '');
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey',
    );

    final List<Map<String, dynamic>> contents = [];
    for (var msg in history) {
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.isUser ? msg.text : ReasoningUtils.stripThinkBlocks(msg.text)},
        ],
      });
    }
    if (userMessage.isNotEmpty) {
      contents.add({
        'role': 'user',
        'parts': [{'text': userMessage}],
      });
    }
    if (extraMessages != null) {
      for (final em in extraMessages) {
        contents.add(em);
      }
    }

    final Map<String, dynamic> bodyMap = {
      'contents': contents,
      'tools': [
        if (maxRoundsLeft > 0)
          {'functionDeclarations': functionDeclarations}
        else
          {'functionDeclarations': const []},
      ],
      'system_instruction': systemInstruction.isNotEmpty
          ? {'parts': [{'text': systemInstruction}]}
          : null,
      'safetySettings': disableSafety
          ? [
              {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
              {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
              {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
              {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
            ]
          : [],
    };

    if (thoughtSignature != null && thoughtSignature.isNotEmpty) {
      bodyMap['thought_signature'] = thoughtSignature;
    }

    try {
      final http.Client activeClient = client ?? http.Client();
      final bool ownsClient = client == null;
      http.Response response;
      try {
        response = await activeClient.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(bodyMap),
        );
      } finally {
        if (ownsClient) activeClient.close();
      }

      if (response.statusCode != 200) {
        return ToolDetectionResult(
          type: 'error',
          text: 'Error ${response.statusCode}: ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return ToolDetectionResult(type: 'error', text: 'No candidates: ${response.body}');
      }
      final candidate = candidates[0];
      final parts = candidate['content']?['parts'] as List? ?? [];

      // Look for a functionCall part first.
      for (final part in parts) {
        if (part['functionCall'] != null) {
          final fc = part['functionCall'];
          final name = (fc['name'] ?? '').toString();
          final args = fc['args'] ?? {};
          return ToolDetectionResult(
            type: 'tool_call',
            toolName: name,
            // Gemini returns args as a JSON object; serialise for uniformity.
            toolArguments: jsonEncode(args),
          );
        }
      }

      // Otherwise concatenate text parts.
      String fullText = '';
      for (final part in parts) {
        if (part['text'] != null) fullText += part['text'].toString();
      }
      return ToolDetectionResult(type: 'text', text: fullText);
    } catch (e) {
      return ToolDetectionResult(type: 'error', text: 'Connection Error: $e');
    }
  }

  /// Builds the Gemini `contents` entry for a tool result, suitable for
  /// appending to [extraMessages] in a subsequent [performGeminiFunctionDetection]
  /// call. Gemini expects the function response under `role: "user"` with a
  /// `functionResponse` part keyed by the function name.
  static Map<String, dynamic> geminiToolResultContent({
    required String functionName,
    required String resultText,
  }) {
    return {
      'role': 'user',
      'parts': [
        {
          'functionResponse': {
            'name': functionName,
            'response': {'result': resultText},
          },
        },
      ],
    };
  }
}

/// Result of a non-streaming tool-detection request.
///
/// Either the model produced a final answer ([type] == 'text') or it
/// requested to call the `web_search` tool ([type] == 'tool_call').
class ToolDetectionResult {
  final String type; // 'text' | 'tool_call' | 'error'
  final String text;
  final String reasoning;
  final String toolCallId;
  final String toolName;
  final String toolArguments; // raw JSON string

  const ToolDetectionResult({
    required this.type,
    this.text = '',
    this.reasoning = '',
    this.toolCallId = '',
    this.toolName = '',
    this.toolArguments = '',
  });

  bool get isToolCall => type == 'tool_call';
  bool get isError => type == 'error';
}
