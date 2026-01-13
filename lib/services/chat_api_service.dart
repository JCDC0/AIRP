import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_models.dart';

class ChatApiService {
  // ==============================================================================
  // 1. GEMINI STREAMING
  // ==============================================================================
  static Stream<String> streamGeminiResponse({
    required ChatSession chatSession,
    required String message,
    required List<String> imagePaths,
    required String modelName,
  }) async* {
    
    // 1. Prepare Content
    final List<Part> parts = [];
    String accumulatedText = message;

    // Handle Attachments
    if (imagePaths.isNotEmpty) {
      for (String path in imagePaths) {
        final String ext = path.split('.').last.toLowerCase();
        // Text Files
        if (['txt', 'md', 'json', 'dart', 'js', 'py', 'html', 'css', 'csv', 'c', 'cpp', 'java'].contains(ext)) {
          try {
            final String fileContent = await File(path).readAsString();
            accumulatedText += "\n\n--- Attached File: ${path.split('/').last} ---\n$fileContent\n--- End File ---\n";
          } catch (e) { 
             // Error handling usually goes to logs
          }
        } 
        // Binary Files (Images/PDF)
        else {
          final bytes = await File(path).readAsBytes();
          String? mimeType;
          if (['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'].contains(ext)) {
            mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
          } else if (ext == 'pdf') mimeType = 'application/pdf';
          
          if (mimeType != null) parts.add(DataPart(mimeType, bytes));
        }
      }
    }

    if (accumulatedText.isNotEmpty) parts.insert(0, TextPart(accumulatedText));
    final userContent = parts.isNotEmpty ? Content.multi(parts) : Content.text(accumulatedText);

    // 2. Stream
    final stream = chatSession.sendMessageStream(userContent);

    await for (final response in stream) {
      if (response.text != null) {
        yield response.text!;
      }
    }
  }

  // ==============================================================================
  // 2. OPENAI-COMPATIBLE STREAMING (OpenRouter, ArliAI, NanoGPT, Local)
  // ==============================================================================
  static Stream<String> streamOpenAiCompatible({
    required String apiKey,
    required String baseUrl, // e.g., https://openrouter.ai/api/v1/chat/completions
    required String model,
    required List<ChatMessage> history,
    required String systemInstruction,
    required String userMessage,
    required List<String> imagePaths,

    // Settings
    double temperature = 1.0,
    double topP = 0.95,
    int topK = 40,
    int maxTokens = 8192,
    bool enableGrounding = false, 
    String reasoningEffort = "none", 
    Map<String, String>? extraHeaders,
    bool includeUsage = false,
  }) async* {
    
    final cleanKey = apiKey.trim();

    // 1. Build Payload
    List<Map<String, dynamic>> messagesPayload = [];
    
    if (systemInstruction.isNotEmpty) {
      messagesPayload.add({"role": "system", "content": systemInstruction});
    }

    // Convert History
    for (var msg in history) {
      messagesPayload.add({
        "role": msg.isUser ? "user" : "assistant",
        "content": msg.text
      });
    }

        // Current Message with Images
    if (imagePaths.isEmpty) {
      messagesPayload.add({"role": "user", "content": userMessage});
    } else {
      List<Map<String, dynamic>> contentParts = [];
      
      // 1. Add User's main text first
      if (userMessage.isNotEmpty) {
        contentParts.add({"type": "text", "text": userMessage});
      }

      // 2. Process Attachments
      for (String path in imagePaths) {
        final String ext = path.split('.').last.toLowerCase();
        
        // --- Case A: Text-based files (Code, logs, etc.) ---
        // Read as strings so the LLM can actually read due to unsuporrted file uploads
        if (['txt', 'md', 'json', 'dart', 'js', 'py', 'html', 'css', 'csv', 'c', 'cpp', 'java', 'xml', 'yaml', 'yml'].contains(ext)) {
          try {
            final String fileContent = await File(path).readAsString();
            contentParts.add({
              "type": "text", 
              "text": "\n\n--- Attached File: ${path.split('/').last} ---\n$fileContent\n--- End File ---\n"
            });
          } catch (e) {
            // Skip unreadable files
          }
        } 
        // --- Case B: Images (Vision) ---
        else if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext)) {
          try {
            final bytes = await File(path).readAsBytes();
            final base64Img = base64Encode(bytes);
            
            // Determine correct MIME type
            String mimeType = 'image/jpeg';
            if (ext == 'png') mimeType = 'image/png';
            if (ext == 'webp') mimeType = 'image/webp';
            if (ext == 'gif') mimeType = 'image/gif';

            contentParts.add({
              "type": "image_url", 
              "image_url": {"url": "data:$mimeType;base64,$base64Img"}
            });
          } catch (e) {
            // Error reading image
          }
        }
      }
      messagesPayload.add({"role": "user", "content": contentParts});
    }

    // 2. Request Body
    final bodyMap = {
      "model": model.trim(),
      "messages": messagesPayload,
      "temperature": temperature,
      "stream": true, 
      "top_p": topP,
      "top_k": topK,
      "max_tokens": maxTokens,
    };

    if (includeUsage) {
      bodyMap["stream_options"] = {"include_usage": true};
    }

    // Force OpenRouter to send reasoning in the dedicated field
    if (baseUrl.contains("openrouter.ai")) {
      bodyMap["include_reasoning"] = true;
    }

    // Apply Reasoning Effort if supported
    if (reasoningEffort != "none") {
      // 1. OpenRouter Standard (often uses 'reasoning' block or provider-specific parameters)
      bodyMap["reasoning_effort"] = reasoningEffort; 
      }

    if (enableGrounding) {
      // OpenRouter specific parameter for web search
      if (baseUrl.contains("openrouter.ai")) {
        bodyMap["plugins"] = [{"id": "web"}];
      } else {
        // Generic fallback or for providers that might support similar flags in the future
        bodyMap["plugins"] = ["web_search"]; 
      }
    }

    // 3. Prepare Request
    final request = http.Request('POST', Uri.parse(baseUrl));
    
    request.headers.addAll({
      "Authorization": "Bearer $cleanKey",
      "Content-Type": "application/json",
      ...?extraHeaders, // Spread extra headers if any (like HTTP-Referer)
    });

    request.body = jsonEncode(bodyMap);

    // 4. Send & Listen
    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        yield "\n\n**Error ${streamedResponse.statusCode}:** $errorBody";
        return;
      }

    // 5. Decode Stream (SSE Format)
    // Assume standard "data: {...}" format used by OpenAI/OpenRouter/LocalAI
      bool hasEmittedThinkStart = false;
      bool hasEmittedThinkEnd = false;

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
            
        if (line.startsWith("data: ")) {
          final dataStr = line.substring(6).trim();
          if (dataStr == "[DONE]") break;

          try {
            final json = jsonDecode(dataStr);

            // Handle Usage (Standard OpenAI 'stream_options: {include_usage: true}')
            if (json['usage'] != null) {
              final usage = json['usage'];
              final prompt = usage['prompt_tokens'] ?? 0;
              final completion = usage['completion_tokens'] ?? 0;
              final total = usage['total_tokens'] ?? 0;
              yield "\n\n`Usage: $prompt in + $completion out = $total total`";
            }

            final choices = json['choices'] as List;
            if (choices.isNotEmpty) {
              final delta = choices[0]['delta'];
              
              // Handle separate reasoning_content (common in DeepSeek R1 via OpenRouter)
              final reasoningChunk = delta['reasoning_content'] ?? delta['reasoning'];
              final contentChunk = delta['content'];

              // 1. Yield Reasoning (wrapped in tags if not already)
              if (reasoningChunk != null && reasoningChunk.toString().isNotEmpty) {
                 if (!hasEmittedThinkStart) {
                   yield "<think>\n";
                   hasEmittedThinkStart = true;
                 }
                 yield reasoningChunk.toString();
              }

              // 2. Yield Content
              if (contentChunk != null && contentChunk.toString().isNotEmpty) {
                if (hasEmittedThinkStart && !hasEmittedThinkEnd) {
                  yield "\n</think>\n";
                  hasEmittedThinkEnd = true;
                }
                yield contentChunk.toString();
              }
              
              // Fallback for non-standard APIs that might use 'text'
              if (delta == null && choices[0]['text'] != null) {
                 // Legacy completion endpoint style
                 yield choices[0]['text'].toString();
              }
            }
          } catch (e) {
            // Ignore parse errors on partial chunks
          }
        }
      }
      
      // Cleanup: Ensure reasoning tag is closed if stream ends
      if (hasEmittedThinkStart && !hasEmittedThinkEnd) {
        yield "\n</think>\n";
      }
    } catch (e) {
      yield "\n\n**Connection Error:** $e";
    } finally {
      client.close();
    }
  }

  // ==============================================================================
  // 3. GEMINI GROUNDING (Separate because it's unique)
  // ==============================================================================
  static Future<String?> performGeminiGrounding({
    required String apiKey,
    required String model,
    required List<ChatMessage> history,
    required String userMessage,
    required String systemInstruction,
    bool disableSafety = true,
  }) async {
    final modelId = model.replaceAll('models/', '');
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey');

    final List<Map<String, dynamic>> contents = [];
    for (var msg in history) {
      contents.add({
        "role": msg.isUser ? "user" : "model",
        "parts": [{"text": msg.text}]
      });
    }
    contents.add({"role": "user", "parts": [{"text": userMessage}]});

    final body = jsonEncode({
      "contents": contents,
      "tools": [ { "google_search": {} } ],
      "system_instruction": systemInstruction.isNotEmpty ? {
        "parts": [{"text": systemInstruction}]
      } : null,
      "safetySettings": disableSafety ? [
          {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
          {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
          {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
          {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
      ] : []
    });

    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && (data['candidates'] as List).isNotEmpty) {
          final candidate = data['candidates'][0];
          final parts = candidate['content']['parts'] as List;
          String fullText = "";
          for (var part in parts) { if (part['text'] != null) fullText += part['text']; }
          
          if (candidate['groundingMetadata'] != null) {
              fullText += "\n\n--- \n**Sources Found:**\n";
              final metadata = candidate['groundingMetadata'];
              if (metadata['groundingChunks'] != null) {
                for (var chunk in metadata['groundingChunks']) {
                  if (chunk['web'] != null) fullText += "- [${chunk['web']['title']}](${chunk['web']['uri']})\n";
                }
              }
          }
                    return fullText;
        }
      } 
    } catch (e) {
      return "Grounding Error: $e";
    }
    return null;
  }

  // ==============================================================================
  // 4. IMAGE GENERATION (DALL-E 3, Flux, etc.)
  // ==============================================================================
  static Future<String?> generateImage({
    required String apiKey,
    required String prompt,
    String provider = 'openai', // or 'openrouter'
  }) async {
    // 1. Setup the specific Image Gen URL
    // OpenAI: https://api.openai.com/v1/images/generations
    // OpenRouter: https://openrouter.ai/api/v1/images/generations (check their docs for specific models)
    
    final url = Uri.parse(provider == 'openai' 
        ? 'https://api.openai.com/v1/images/generations' 
        : 'https://openrouter.ai/api/v1/images/generations');

    // 2. The Payload is different from Chat!
    final body = jsonEncode({
      "model": provider == 'openai' ? "dall-e-3" : "stabilityai/stable-diffusion-xl-base-1.0", // Example models
      "prompt": prompt,
      "n": 1,
      "size": "1024x1024"
    });

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // They usually return a list of objects with a URL
        return data['data'][0]['url']; 
      } else {
        return "Error: ${response.body}";
      }
    } catch (e) {
      return "Connection Error: $e";
    }
  }
}