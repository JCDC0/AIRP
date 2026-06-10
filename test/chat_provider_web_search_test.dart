import 'package:airp/providers/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('composeUserMessageWithWebContext prepends web context block', () {
    const webContext = '[WEB_CONTEXT — 1 result for "airp"]\n1. Example\n[/WEB_CONTEXT]';
    const userText = 'Tell me about AIRP.';

    final composed = ChatProvider.composeUserMessageWithWebContext(
      userText,
      webContext,
    );

    expect(composed, startsWith(webContext));
    expect(composed, contains('\n\n---\n\n$userText'));
  });

  test('composeUserMessageWithWebContext leaves plain text unchanged', () {
    const userText = 'Just answer normally.';

    final composed = ChatProvider.composeUserMessageWithWebContext(
      userText,
      null,
    );

    expect(composed, userText);
  });
}