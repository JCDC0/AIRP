import 'package:flutter_test/flutter_test.dart';
import 'package:airp/utils/constants.dart';

void main() {
  test('cleanModelName formats provider ids', () {
    final result = cleanModelName('meta-llama/llama-3.1:free');
    expect(result, 'Llama 3.1 (Free)');
  });

  test('all provider model endpoints are configured and valid URIs', () {
    const endpoints = <String, String>{
      'gemini': ApiConstants.geminiBaseUrl,
      'openRouter': ApiConstants.openRouterBaseUrl,
      'arliAi': ApiConstants.arliAiBaseUrl,
      'nanoGpt': ApiConstants.nanoGptBaseUrl,
      'nvidia': ApiConstants.nvidiaBaseUrl,
      'openAi': ApiConstants.openAiBaseUrl,
      'huggingFace': ApiConstants.huggingFaceBaseUrl,
      'groq': ApiConstants.groqBaseUrl,
      'blackboxAi': ApiConstants.blackboxAiBaseUrl,
      'minimax': ApiConstants.minimaxBaseUrl,
      'deepseek': ApiConstants.deepseekBaseUrl,
      'qwen': ApiConstants.qwenBaseUrl,
      'xAi': ApiConstants.xAiBaseUrl,
      'zAi': ApiConstants.zAiBaseUrl,
      'mistral': ApiConstants.mistralBaseUrl,
      'ollamaDefault': ApiConstants.ollamaDefaultBaseUrl,
    };

    for (final entry in endpoints.entries) {
      final uri = Uri.tryParse(entry.value);
      expect(uri, isNotNull, reason: '${entry.key} endpoint must be a URI');
      expect(uri!.hasScheme, isTrue,
          reason: '${entry.key} endpoint must include scheme');
      expect(uri.host.isNotEmpty, isTrue,
          reason: '${entry.key} endpoint must include host');
    }
  });

  test('provider endpoint constants match expected values', () {
    expect(ApiConstants.geminiBaseUrl,
        'https://generativelanguage.googleapis.com/v1beta/models');
    expect(ApiConstants.openRouterBaseUrl, 'https://openrouter.ai/api/v1/models');
    expect(ApiConstants.arliAiBaseUrl, 'https://api.arliai.com/v1/models');
    expect(ApiConstants.nanoGptBaseUrl,
        'https://nano-gpt.com/api/v1/models?detailed=true');
    expect(ApiConstants.nvidiaBaseUrl,
      'https://integrate.api.nvidia.com/v1/models');
    expect(ApiConstants.openAiBaseUrl, 'https://api.openai.com/v1/models');
    expect(ApiConstants.huggingFaceBaseUrl,
        'https://huggingface.co/api/models?pipeline_tag=text-generation&sort=downloads&limit=100');
    expect(ApiConstants.groqBaseUrl, 'https://api.groq.com/openai/v1/models');
    expect(ApiConstants.blackboxAiBaseUrl, 'https://api.blackbox.ai/api/models');
    expect(ApiConstants.minimaxBaseUrl, 'https://api.minimax.chat/v1/models');
    expect(ApiConstants.deepseekBaseUrl, 'https://api.deepseek.com/v1/models');
    expect(ApiConstants.qwenBaseUrl,
        'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/models');
    expect(ApiConstants.xAiBaseUrl, 'https://api.x.ai/v1/models');
    expect(ApiConstants.zAiBaseUrl, 'https://api.z.ai/api/paas/v4/models');
    expect(ApiConstants.mistralBaseUrl, 'https://api.mistral.ai/v1/models');
    expect(ApiConstants.ollamaDefaultBaseUrl, 'http://localhost:11434/v1');
  });
}
