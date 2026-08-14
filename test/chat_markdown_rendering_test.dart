import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/widgets/basic_markdown_text.dart';

void main() {
  testWidgets('renders assistant bullets, bold, italic, and line breaks', (
    tester,
  ) async {
    const markdown = '* **Focus on formality:**\n'
        '* **Elevate your bottom:** Add *tailored* trousers.\n'
        '* **Refine your footwear:**';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BasicMarkdownText(markdown)),
      ),
    );

    expect(find.textContaining('Focus on formality:'), findsOneWidget);
    expect(find.textContaining('Elevate your bottom:'), findsOneWidget);
    expect(find.textContaining('Refine your footwear:'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('• '), findsOneWidget);

    final richText = tester.widget<RichText>(find.byType(RichText).last);
    final flattened = richText.text.toPlainText();
    expect(flattened, contains('• Focus on formality:'));
    expect(flattened, contains('\n• Elevate your bottom: Add tailored trousers.'));
  });
}
