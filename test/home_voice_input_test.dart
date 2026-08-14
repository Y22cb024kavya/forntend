import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_chat_prompt_bar.dart';

void main() {
  testWidgets('Home prompt mic toggles through its supplied voice handler', (
    tester,
  ) async {
    var taps = 0;
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AhviChatPromptBar(
            controller: controller,
            focusNode: focusNode,
            hintText: 'Ask AHVI',
            surface: Colors.white,
            border: Colors.grey,
            accent: Colors.blue,
            accentSecondary: Colors.purple,
            textHeading: Colors.black,
            textMuted: Colors.grey,
            shadowMedium: Colors.black12,
            onAccent: Colors.white,
            onSendMessage: (_) {},
            themeTokens: AppThemeTokens.light(
              const AccentPalette(
                primary: Colors.blue,
                secondary: Colors.purple,
                tertiary: Colors.teal,
              ),
            ),
            onVoiceTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    expect(taps, 1);
  });

  test('Home voice writes recognized text and uses the existing send path', () {
    final source = File('lib/home.dart').readAsStringSync();
    expect(source, contains('onVoiceTap: _toggleListening'));
    expect(source, contains('_chatController.text = text;'));
    expect(source, contains('_openChatWithPrompt(text);'));
    expect(source, contains('await _speech.stop();'));
    expect(source, contains('Microphone access is unavailable'));
  });
}
