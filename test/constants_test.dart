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
      'nanoGpt': ApiConstants.nanoGptBaseUrl,
      'nvidia': ApiConstants.nvidiaBaseUrl,
      'deepseek': ApiConstants.deepseekBaseUrl,
      'xAi': ApiConstants.xAiBaseUrl,
      'ollamaDefault': ApiConstants.ollamaDefaultEndpoint,
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
    expect(ApiConstants.nanoGptBaseUrl,
        'https://nano-gpt.com/api/v1/models?detailed=true');
    expect(ApiConstants.nvidiaBaseUrl,
      'https://integrate.api.nvidia.com/v1/models');
    expect(ApiConstants.deepseekBaseUrl, 'https://api.deepseek.com/models');
    expect(ApiConstants.xAiBaseUrl, 'https://api.x.ai/v1/models');
    expect(ApiConstants.ollamaDefaultEndpoint, 'http://localhost:11434');
  });

  test('every live provider resolves a distinct model-cache pref key', () {
    const prefKeys = <String>{
      ApiConstants.prefListGemini,
      ApiConstants.prefListOpenRouter,
      ApiConstants.prefListNanoGpt,
      ApiConstants.prefListNvidia,
      ApiConstants.prefListOpenAiCompatible,
      ApiConstants.prefListDeepseek,
      ApiConstants.prefListOllama,
      ApiConstants.prefListXAi,
      ApiConstants.prefListLocal,
    };
    expect(prefKeys.length, 9);
  });
}
