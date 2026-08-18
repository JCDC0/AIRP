import 'dart:async';
import 'dart:convert';
import 'package:async/async.dart' show StreamQueue;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  /// Builds the `streamGenerateContent` URL for [modelName].
  ///
  /// `alt=sse` is required. Without it the endpoint returns a pretty-printed
  /// JSON array rather than Server-Sent Events, no line carries the `data: `
  /// prefix the parser expects, and the stream completes with an empty
  /// accumulator behind an HTTP 200.
  @visibleForTesting
  static Uri buildGeminiStreamUrl(String modelName, String apiKey) {
    final modelId = modelName.replaceAll('models/', '');
    return Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$modelId:streamGenerateContent?alt=sse&key=${apiKey.trim()}',
    );
  }

  /// Builds `generationConfig.thinkingConfig` for [modelName], or null when
  /// the user has reasoning switched off entirely.
  ///
  /// Gemini does not use `reasoning_effort`. Reasoning is requested through
  /// `thinkingConfig`, and thought parts are only returned when
  /// `includeThoughts` is true. AIRP sent neither before `0.7.30.1`, so the
  /// effort dropdown had no effect on Gemini at all.
  ///
  /// The two families take different fields: Gemini 3 and newer take a
  /// `thinkingLevel` enum, Gemini 2.x takes a `thinkingBudget` in tokens.
  /// Sending the wrong one degrades or rejects the request, so the family is
  /// read off the model id. Anything that is not a `gemini-<n>` id (Gemma, or
  /// a name this build has not seen) gets `includeThoughts` alone, which is
  /// accepted everywhere.
  ///
  /// Budget `0` disables thinking, but Gemini 2.5 Pro cannot disable it, so
  /// Pro ids fall back to `-1` (dynamic) instead of erroring.
  @visibleForTesting
  static Map<String, dynamic>? buildGeminiThinkingConfig(
    String modelName,
    String? effort,
  ) {
    if (effort == null || effort.isEmpty) return null;

    final id = modelName.replaceAll('models/', '').toLowerCase();
    final bool enabled = effort != 'none';
    final config = <String, dynamic>{'includeThoughts': enabled};

    final major = RegExp(r'gemini-(\d+)').firstMatch(id);
    if (major == null) return config;

    final version = int.tryParse(major.group(1)!) ?? 3;
    if (version >= 3) {
      config['thinkingLevel'] = const {
        'none': 'minimal',
        'low': 'low',
        'medium': 'medium',
        'high': 'high',
        'xhigh': 'high',
        'max': 'high',
      }[effort] ?? 'medium';
      return config;
    }

    if (!enabled) {
      config['thinkingBudget'] = id.contains('pro') ? -1 : 0;
      return config;
    }
    config['thinkingBudget'] = const {
      'low': 4096,
      'medium': 8192,
      'high': 24576,
      'xhigh': 24576,
      'max': 24576,
    }[effort] ?? 8192;
    return config;
  }

  /// Builds the message shown when a Gemini stream returns HTTP 200 but no
  /// answer text, attributing it to [blockReason] or [finishReason] when the
  /// response carried one.
  @visibleForTesting
  static String emptyGeminiStreamNotice(
    String? blockReason,
    String? finishReason,
  ) {
    if (blockReason != null && blockReason.isNotEmpty) {
      return '\n\n**Blocked:** the prompt was rejected by Gemini '
          '(`$blockReason`).';
    }
    // STOP with no text means the model genuinely returned nothing.
    if (finishReason != null &&
        finishReason.isNotEmpty &&
        finishReason != 'STOP') {
      return '\n\n**Empty response:** generation stopped early '
          '(`$finishReason`).';
    }
    return '\n\n**Empty response:** the model returned no content.';
  }

  /// Streams a response from Google Gemini via the raw `v1beta` REST API.
  ///
  /// This intentionally bypasses the `google_generative_ai` SDK because the SDK
  /// concatenates thinking (`thought`) parts and answer text into a single
  /// `response.text` string, which breaks reasoning display for Gemma and
  /// Gemini thinking models. The raw endpoint returns `thought` flags per part,
  /// letting us wrap reasoning in `<think>` tags.
  static Stream<String> streamGeminiResponse({
    required String apiKey,
    required String modelName,
    required List<ChatMessage> history,
    required String userMessage,
    required String systemInstruction,
    required List<String> imagePaths,
    Map<String, Uint8List>? attachmentBytes,
    double? temperature,
    double? topP,
    int? topK,
    int? maxTokens,
    bool includeUsage = false,
    List<Map<String, dynamic>>? depthMessages,
    List<Map<String, dynamic>>? extraMessages,
    bool disableSafety = true,
    String? reasoningEffort,
  }) async* {
    String accumulatedText = userMessage;
    final List<Map<String, dynamic>> inlineParts = [];

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

            if (mimeType != null) {
              inlineParts.add({
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Encode(bytes),
                },
              });
            }
          } catch (e) {
            _logWarning('Failed to read binary attachment: $path ($e)');
          }
        }
      }
    }

    if (accumulatedText.isNotEmpty) {
      inlineParts.insert(0, {'text': accumulatedText});
    }

    final List<Map<String, dynamic>> contents = [];
    for (var msg in history) {
      final parts = <Map<String, dynamic>>[
        {'text': msg.isUser ? msg.text : ReasoningUtils.stripThinkBlocks(msg.text)},
      ];
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': parts,
      });
    }

    contents.add({'role': 'user', 'parts': inlineParts});

    if (depthMessages != null && depthMessages.isNotEmpty) {
      for (final dm in depthMessages) {
        final depth = dm['depth'] as int? ?? 0;
        final content = dm['content'] as String? ?? '';
        final role = dm['role'] as String? ?? 'system';
        if (content.isEmpty) continue;
        final insertIdx = (contents.length - depth).clamp(1, contents.length);
        contents.insert(insertIdx, {
          'role': role == 'assistant' ? 'model' : 'user',
          'parts': [{'text': content}],
        });
      }
    }

    if (extraMessages != null && extraMessages.isNotEmpty) {
      for (final em in extraMessages) {
        final role = em['role']?.toString();
        final content = em['content'] ?? em['parts'];
        if (content == null) continue;
        if (content is String && content.isNotEmpty) {
          contents.add({
            'role': role == 'model' || role == 'assistant' ? 'model' : 'user',
            'parts': [{'text': content}],
          });
        } else if (content is List) {
          contents.add({
            'role': role == 'model' || role == 'assistant' ? 'model' : 'user',
            'parts': content,
          });
        }
      }
    }

    final url = buildGeminiStreamUrl(modelName, apiKey);

    final Map<String, dynamic> bodyMap = {
      'contents': contents,
      'safetySettings': disableSafety
          ? [
              {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
              {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
              {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
              {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
            ]
          : [],
    };

    if (systemInstruction.isNotEmpty) {
      bodyMap['system_instruction'] = {
        'parts': [{'text': systemInstruction}],
      };
    }

    final generationConfig = <String, dynamic>{};
    if (temperature != null) generationConfig['temperature'] = temperature;
    if (topP != null) generationConfig['topP'] = topP;
    if (topK != null) generationConfig['topK'] = topK;
    if (maxTokens != null) generationConfig['maxOutputTokens'] = maxTokens;
    final thinkingConfig = buildGeminiThinkingConfig(modelName, reasoningEffort);
    if (thinkingConfig != null) {
      generationConfig['thinkingConfig'] = thinkingConfig;
    }
    if (generationConfig.isNotEmpty) {
      bodyMap['generationConfig'] = generationConfig;
    }

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
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
      bool hasEmittedText = false;
      String? blockReason;
      String? finishReason;

      await for (final line
          in streamedResponse.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final dataStr = line.substring(6).trim();
        if (dataStr == '[DONE]') break;

        try {
          final json = jsonDecode(dataStr);

          if (includeUsage && json['usageMetadata'] != null) {
            yield "[[USAGE:${jsonEncode(json['usageMetadata'])}]]";
          }

          blockReason =
              json['promptFeedback']?['blockReason']?.toString() ?? blockReason;

          final signature = json['thought_signature']?.toString() ??
              (json['candidates'] as List?)?.firstOrNull?['thought_signature']
                  ?.toString();
          if (signature != null && signature.isNotEmpty) {
            yield '[[THOUGHT_SIG:$signature]]';
          }

          final candidates = json['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) continue;
          final candidate = candidates[0];
          finishReason =
              candidate['finishReason']?.toString() ?? finishReason;
          final content = candidate['content'];
          if (content == null) continue;
          final parts = content['parts'] as List?;
          if (parts == null) continue;

          for (final part in parts) {
            if (part is! Map) continue;
            final isThought = part['thought'] == true;
            final text = part['text']?.toString() ?? '';
            if (text.isEmpty) continue;

            if (isThought) {
              if (!hasEmittedThinkStart) {
                yield '<think>\n';
                hasEmittedThinkStart = true;
              }
              yield text;
            } else {
              if (hasEmittedThinkStart && !hasEmittedThinkEnd) {
                yield '\n</think>\n';
                hasEmittedThinkEnd = true;
              }
              hasEmittedText = true;
              yield text;
            }
          }
        } catch (e) {
          _logWarning('Gemini stream chunk parse warning: $e');
        }
      }

      if (hasEmittedThinkStart && !hasEmittedThinkEnd) {
        yield '\n</think>\n';
      }

      // A 200 that produced no answer text is otherwise silent: the bubble just
      // stays blank. Surface why instead, so this class of failure is visible.
      // Reasoning-only responses are left alone; StreamingCoordinatorService
      // already recovers those into the visible body.
      if (!hasEmittedText && !hasEmittedThinkStart) {
        yield emptyGeminiStreamNotice(blockReason, finishReason);
      }
    } catch (e) {
      yield "\n\n**Connection Error:** $e";
    } finally {
      client.close();
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
    void Function(Map<String, dynamic> body, String effort)? applyReasoningEffort,
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

    // Apply the provider-specific reasoning request field.
    if (reasoningEffort != null && reasoningEffort.isNotEmpty) {
      if (applyReasoningEffort != null) {
        applyReasoningEffort(bodyMap, reasoningEffort);
      } else {
        // Callers without a strategy callback share the strategy's rules
        // rather than keeping a second copy of the switch here.
        AiProviderStrategy.applyThinkingFormat(
          bodyMap,
          reasoningEffort,
          thinkingFormat,
        );
      }
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
    void Function(Map<String, dynamic> body, String effort)? applyReasoningEffort,
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

    // OpenRouter omits the reasoning trace unless it is asked for. Without
    // this the detection response carries no `reasoning` field and the answer
    // reaches the user with its thinking silently dropped.
    if (baseUrl.contains('openrouter.ai')) {
      bodyMap['include_reasoning'] = true;
    }

    if (reasoningEffort != null && reasoningEffort.isNotEmpty) {
      if (applyReasoningEffort != null) {
        applyReasoningEffort(bodyMap, reasoningEffort);
      } else {
        // Callers without a strategy callback share the strategy's rules
        // rather than keeping a second copy of the switch here.
        AiProviderStrategy.applyThinkingFormat(
          bodyMap,
          reasoningEffort,
          thinkingFormat,
        );
      }
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

  /// Sends a STREAMING OpenAI-compatible request with the `web_search` tool
  /// attached and classifies the response from its first deltas.
  ///
  /// A model either calls a tool or answers; it does not do both in one turn.
  /// So the first delta carrying tool call fragments means "search", and the
  /// first delta carrying content or reasoning means "this is the answer". By
  /// buffering only until that point, a direct answer streams live — reasoning
  /// included — instead of arriving as one blob from a non-streamed round.
  ///
  /// Returns once classified: either [ToolAwareStream.toolCall] is set (the
  /// socket is drained and closed), or [ToolAwareStream.textStream] replays the
  /// buffered chunks and then continues from the live socket.
  static Future<ToolAwareStream> streamOpenAiCompatibleWithToolDetection({
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
    int? topK,
    int? maxTokens,
    String? reasoningEffort,
    ThinkingFormat thinkingFormat = ThinkingFormat.reasoningEffort,
    void Function(Map<String, dynamic> body, String effort)?
    applyReasoningEffort,
    Map<String, String>? extraHeaders,
    bool includeUsage = false,
    int maxRoundsLeft = 1,
    http.Client? client,
  }) async {
    final cleanKey = apiKey.trim();
    final List<Map<String, dynamic>> messagesPayload = [];

    if (systemInstruction.isNotEmpty) {
      messagesPayload.add({'role': 'system', 'content': systemInstruction});
    }
    for (final msg in history) {
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
      'stream': true,
      'tools': tools,
      'tool_choice': maxRoundsLeft > 0 ? 'auto' : 'none',
    };

    if (temperature != null) bodyMap['temperature'] = temperature;
    if (topP != null) bodyMap['top_p'] = topP;
    if (topK != null) bodyMap['top_k'] = topK;
    if (maxTokens != null) bodyMap['max_tokens'] = maxTokens;
    if (includeUsage) bodyMap['stream_options'] = {'include_usage': true};
    if (baseUrl.contains('openrouter.ai')) {
      bodyMap['include_reasoning'] = true;
    }

    if (reasoningEffort != null && reasoningEffort.isNotEmpty) {
      if (applyReasoningEffort != null) {
        applyReasoningEffort(bodyMap, reasoningEffort);
      } else {
        // Callers without a strategy callback share the strategy's rules
        // rather than keeping a second copy of the switch here.
        AiProviderStrategy.applyThinkingFormat(
          bodyMap,
          reasoningEffort,
          thinkingFormat,
        );
      }
    }

    final request = http.Request('POST', Uri.parse(baseUrl));
    request.headers.addAll({
      'Authorization': 'Bearer $cleanKey',
      'Content-Type': 'application/json',
      ...?extraHeaders,
    });
    request.body = jsonEncode(bodyMap);

    final http.Client activeClient = client ?? http.Client();
    final bool ownsClient = client == null;

    try {
      final streamedResponse = await activeClient.send(request);
      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        if (ownsClient) activeClient.close();
        return ToolAwareStream(
          error: 'Error ${streamedResponse.statusCode}: $errorBody',
        );
      }

      final lines = StreamQueue(
        streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
      );

      final buffered = <String>[];
      final toolFragments = <int, Map<String, dynamic>>{};
      bool hasEmittedThinkStart = false;
      bool classifiedAsText = false;
      bool exhausted = false;

      // Phase 1: read until the response classifies itself.
      while (!classifiedAsText && await lines.hasNext) {
        final line = await lines.next;
        if (!line.startsWith('data: ')) continue;
        final dataStr = line.substring(6).trim();
        if (dataStr == '[DONE]') {
          exhausted = true;
          break;
        }

        try {
          final json = jsonDecode(dataStr);
          if (includeUsage && json['usage'] != null) {
            buffered.add('[[USAGE:${jsonEncode(json['usage'])}]]');
          }
          final choices = json['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final delta = choices[0]['delta'];
          if (delta == null) continue;

          final deltaToolCalls = delta['tool_calls'] as List?;
          if (deltaToolCalls != null && deltaToolCalls.isNotEmpty) {
            _accumulateToolCallFragments(deltaToolCalls, toolFragments);
            continue;
          }

          final reasoningChunk = delta['reasoning_content'] ?? delta['reasoning'];
          if (reasoningChunk != null && reasoningChunk.toString().isNotEmpty) {
            if (!hasEmittedThinkStart) {
              buffered.add('<think>\n');
              hasEmittedThinkStart = true;
            }
            buffered.add(reasoningChunk.toString());
            classifiedAsText = true;
          }

          final contentChunk = delta['content'];
          if (contentChunk != null && contentChunk.toString().isNotEmpty) {
            if (hasEmittedThinkStart) buffered.add('\n</think>\n');
            buffered.add(contentChunk.toString());
            classifiedAsText = true;
          }
        } catch (e) {
          _logWarning('Tool-aware stream chunk parse warning: $e');
        }
      }

      if (!classifiedAsText && toolFragments.isNotEmpty) {
        // The model wants to search. Drain and close; the caller runs the
        // search and issues a follow-up request with the results.
        await lines.cancel(immediate: true);
        if (ownsClient) activeClient.close();
        final fragment = toolFragments[toolFragments.keys.reduce(
          (a, b) => a < b ? a : b,
        )]!;
        return ToolAwareStream(
          toolCall: ToolDetectionResult(
            type: 'tool_call',
            toolCallId: (fragment['id'] ?? '').toString(),
            toolName: (fragment['name'] ?? '').toString(),
            toolArguments: (fragment['arguments'] ?? '').toString(),
          ),
        );
      }

      // Phase 2: hand back the buffered prefix followed by the live remainder.
      Stream<String> replay() async* {
        try {
          for (final chunk in buffered) {
            yield chunk;
          }
          if (exhausted) {
            if (hasEmittedThinkStart) yield '\n</think>\n';
            return;
          }

          bool thinkClosed = !hasEmittedThinkStart;
          while (await lines.hasNext) {
            final line = await lines.next;
            if (!line.startsWith('data: ')) continue;
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') break;

            try {
              final json = jsonDecode(dataStr);
              if (includeUsage && json['usage'] != null) {
                yield '[[USAGE:${jsonEncode(json['usage'])}]]';
              }
              final choices = json['choices'] as List?;
              if (choices == null || choices.isEmpty) continue;
              final delta = choices[0]['delta'];
              if (delta == null) continue;

              final reasoningChunk =
                  delta['reasoning_content'] ?? delta['reasoning'];
              if (reasoningChunk != null &&
                  reasoningChunk.toString().isNotEmpty) {
                yield reasoningChunk.toString();
              }

              final contentChunk = delta['content'];
              if (contentChunk != null && contentChunk.toString().isNotEmpty) {
                if (!thinkClosed) {
                  yield '\n</think>\n';
                  thinkClosed = true;
                }
                yield contentChunk.toString();
              }
            } catch (e) {
              _logWarning('Tool-aware stream chunk parse warning: $e');
            }
          }
          if (!thinkClosed) yield '\n</think>\n';
        } catch (e) {
          yield '\n\n**Connection Error:** $e';
        } finally {
          await lines.cancel(immediate: true);
          if (ownsClient) activeClient.close();
        }
      }

      return ToolAwareStream(textStream: replay());
    } catch (e) {
      if (ownsClient) activeClient.close();
      return ToolAwareStream(error: 'Connection Error: $e');
    }
  }

  /// Merges streamed `tool_calls` deltas into whole calls keyed by their index.
  ///
  /// Providers split a single call across deltas: the first carries `id` and
  /// `function.name`, later ones append `function.arguments` fragments.
  static void _accumulateToolCallFragments(
    List<dynamic> deltaToolCalls,
    Map<int, Map<String, dynamic>> into,
  ) {
    for (final tc in deltaToolCalls) {
      if (tc is! Map) continue;
      final index = tc['index'] is int ? tc['index'] as int : 0;
      final slot = into.putIfAbsent(
        index,
        () => <String, dynamic>{'id': '', 'name': '', 'arguments': ''},
      );
      if (tc['id'] != null) slot['id'] = tc['id'].toString();
      final fn = tc['function'];
      if (fn is Map) {
        if (fn['name'] != null) slot['name'] = fn['name'].toString();
        if (fn['arguments'] != null) {
          slot['arguments'] =
              '${slot['arguments']}${fn['arguments']}';
        }
      }
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
    double? temperature,
    double? topP,
    int? topK,
    int? maxTokens,
    String? reasoningEffort,
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

    final Map<String, dynamic> generationConfig = {
      'temperature': ?temperature,
      'topP': ?topP,
      'topK': ?topK,
      'maxOutputTokens': ?maxTokens,
    };
    final detectionThinking = buildGeminiThinkingConfig(model, reasoningEffort);
    if (detectionThinking != null) {
      generationConfig['thinkingConfig'] = detectionThinking;
    }
    if (generationConfig.isNotEmpty) {
      bodyMap['generationConfig'] = generationConfig;
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

      // Parts carrying `thought: true` are the model's reasoning trace, not
      // its answer. Split them out so they surface as a thinking block instead
      // of being concatenated into the visible text.
      final splitParts = splitGeminiThoughtParts(parts);
      final String reasoning = splitParts.reasoning;

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
            reasoning: reasoning,
          );
        }
      }

      return ToolDetectionResult(
        type: 'text',
        text: splitParts.content,
        reasoning: reasoning,
      );
    } catch (e) {
      return ToolDetectionResult(type: 'error', text: 'Connection Error: $e');
    }
  }

  /// Splits Gemini `parts` into the reasoning trace and the visible answer.
  ///
  /// Gemini marks thinking output with `thought: true` on the part rather than
  /// in a separate field. Concatenating every text part blindly splices the
  /// model's reasoning into its answer as plain prose.
  @visibleForTesting
  static ({String reasoning, String content}) splitGeminiThoughtParts(
    List<dynamic> parts,
  ) {
    final reasoning = StringBuffer();
    final content = StringBuffer();
    for (final part in parts) {
      final text = part is Map ? part['text'] : null;
      if (text == null) continue;
      final isThought = part is Map && part['thought'] == true;
      (isThought ? reasoning : content).write(text.toString());
    }
    return (
      reasoning: reasoning.toString().trim(),
      content: content.toString(),
    );
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

/// Result of a streaming request that had a tool attached.
///
/// Exactly one field is set. [toolCall] means the model asked to search and
/// nothing was streamed. [textStream] means the model answered and the stream
/// is already live. [error] means the request never got that far.
class ToolAwareStream {
  final ToolDetectionResult? toolCall;
  final Stream<String>? textStream;
  final String? error;

  const ToolAwareStream({this.toolCall, this.textStream, this.error});

  bool get isToolCall => toolCall != null;
  bool get isError => error != null;
}
