import 'package:flutter_test/flutter_test.dart';
import 'package:airp/utils/constants.dart';

void main() {
  test('cleanModelName formats provider ids', () {
    final result = cleanModelName('meta-llama/llama-3.1:free');
    expect(result, 'Llama 3.1 (Free)');
  });

  test('NVIDIA provider models endpoint is configured', () {
    expect(
      ApiConstants.nvidiaBaseUrl,
      'https://integrate.api.nvidia.com/v1/models',
    );
  });
}
