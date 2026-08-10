import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Daily Wear conversational Style uses canonical continuity contract',
    () {
      final source = File('lib/daily_wear.dart').readAsStringSync();

      expect(source, contains('BackendService().sendModuleChat('));
      expect(source, contains("domain: 'style'"));
      expect(source, contains('message: userText'));
      expect(
        source,
        contains('chatHistory: List<Map<String, String>>.from(history)'),
      );
      expect(source, contains("'conversation_id': _currentSessionId"));
      expect(source, contains("'session_id': _currentSessionId"));
      expect(source, contains("'surface': 'daily_wear'"));
      expect(
        source,
        contains("'current_outfit': Map<String, dynamic>.from(currentOutfit)"),
      );
      expect(source, contains("'weather_context': _weatherContext"));
      expect(source, isNot(contains('BackendService().sendChatQuery(')));
      expect(source, isNot(contains("'Current outfit:")));
    },
  );

  test('Daily Wear keeps the pending Style loader neutral', () {
    final source = File('lib/daily_wear.dart').readAsStringSync();
    final messages = source.substring(source.indexOf('Widget _chatMessages()'));

    expect(messages, contains('return const _TypingBubble();'));
    expect(
      messages,
      isNot(contains('AhviProcessingContext.styleRecommendation')),
    );
    expect(messages, isNot(contains('Curating your look')));
  });

  test('Daily Wear clears pending state and hides backend errors', () {
    final source = File('lib/daily_wear.dart').readAsStringSync();
    final request = source.substring(
      source.indexOf('Future<void> _callBackendStylist'),
      source.indexOf('void _speakMessage'),
    );

    expect(request, contains('if (!mounted) return;'));
    expect(request, contains('_isTyping = false;'));
    expect(request, isNot(contains('style request failed')));
    expect(request, contains("I'm having a moment - try again."));
  });

  test('pending loader is independent of prior visual board responses', () {
    final source = File('lib/daily_wear.dart').readAsStringSync();
    final messages = source.substring(source.indexOf('Widget _chatMessages()'));

    expect(messages, contains('_messages.length + (_isTyping ? 1 : 0)'));
    expect(messages, contains('return const _TypingBubble();'));
    expect(messages, isNot(contains('styleBoard')));
  });
}
