import 'package:flutter_test/flutter_test.dart';
import 'package:airp/utils/constants.dart';

void main() {
  test('cleanModelName formats provider ids', () {
    final result = cleanModelName('meta-llama/llama-3.1:free');
    expect(result, 'Llama 3.1 (Free)');
  });
}
