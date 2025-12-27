import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_models.dart';

class ChatApiService {
  // We use a singleton pattern or just static methods, but let's keep it simple with static helpers 
  // so you don't have to manage an instance.

  // ==============================================================================
  // 1. GEMINI STREAMING
  // ==============================================================================
  static Stream<String> streamGeminiResponse({
    required ChatSession chatSession, // The active Gemini SDK session
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
    required List<ChatMessage> history, // Current chat history
    required String systemInstruction,
    required String userMessage,
    required List<String> imagePaths,
    // Settings
    double temperature = 1.0,
    double topP = 0.95,
    int topK = 40,
    int maxTokens = 32768,
    bool enableGrounding = false, // specific to OpenRouter
    Map<String, String>? extraHeaders,
  }) async* {
    
    final cleanKey = apiKey.trim();

    // 1. Build Payload
    List<Map<String, dynamic>> messagesPayload = [];
    
    if (systemInstruction.isNotEmpty) {
      messagesPayload.add({"role": "system", "content": systemInstruction});
    }

    // Convert History
    // Note: We usually skip the very last message in 'history' if it was just added to UI 
    // but hasn't been sent yet. Assuming 'history' passed here EXCLUDES the current new message.
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
      if (userMessage.isNotEmpty) contentParts.add({"type": "text", "text": userMessage});
      for (String path in imagePaths) {
        final bytes = await File(path).readAsBytes();
        final base64Img = base64Encode(bytes);
        contentParts.add({
          "type": "image_url", 
          "image_url": {"url": "data:image/jpeg;base64,$base64Img"}
        });
      }
      messagesPayload.add({"role": "user", "content": contentParts});
    }

    // 2. Request Body
    final bodyMap = {
      "model": model.trim(),
      "messages": messagesPayload,
      "temperature": temperature,
      "stream": true, // We force stream true for this method
      "top_p": topP,
      "top_k": topK,
      "max_tokens": maxTokens,
    };

    if (enableGrounding) {
      bodyMap["plugins"] = ["web_search"];
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
      // We assume standard "data: {...}" format used by OpenAI/OpenRouter/LocalAI
      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
            
        if (line.startsWith("data: ")) {
          final dataStr = line.substring(6).trim();
          if (dataStr == "[DONE]") break;

          try {
            final json = jsonDecode(dataStr);
            final choices = json['choices'] as List;
            if (choices.isNotEmpty) {
              final delta = choices[0]['delta'];
              // Some providers wrap content differently, but standard is delta['content']
              if (delta != null && delta['content'] != null) {
                yield delta['content'].toString();
              }
              // Fallback for non-standard APIs that might use 'text'
              else if (choices[0]['text'] != null) {
                yield choices[0]['text'].toString();
              }
            }
          } catch (e) {
            // Ignore parse errors on partial chunks
          }
        }
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
    // This is a REST call, not streaming, matching your original logic
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
}