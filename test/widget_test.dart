import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_chat_prompt_bar.dart';

const _accent = AccentPalette(
  primary: Color(0xFFFF8EC7),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

void main() {
  testWidgets('AHVI prompt bar submits a trimmed message without bootstrap', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final sent = <String>[];
    final tokens = AppThemeTokens.light(_accent);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AhviChatPromptBar(
            controller: controller,
            focusNode: focusNode,
            hintText: 'Ask AHVI anything',
            surface: Colors.white,
            border: Colors.black12,
            accent: _accent.primary,
            accentSecondary: _accent.secondary,
            textHeading: Colors.black,
            textMuted: Colors.black54,
            shadowMedium: Colors.black12,
            onAccent: Colors.white,
            themeTokens: tokens,
            onSendMessage: sent.add,
            onPlusTap: () {},
            onVoiceTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Ask AHVI anything'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Plan my office look  ');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();

    expect(sent, ['Plan my office look']);
    expect(controller.text, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
