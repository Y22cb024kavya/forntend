import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Daily Wear conversational Style uses canonical continuity contract',
    () {
      final source = File('lib/daily_wear.dart').readAsStringSync();
      final request = source.substring(
        source.indexOf('Future<void> _callBackendStylist'),
        source.indexOf('void _speakMessage'),
      );

      expect(request, contains('BackendService().sendModuleChat('));
      expect(request, contains("domain: 'daily_wear'"));
      expect(request, isNot(contains("domain: 'style'")));
      expect(request, contains('message: userText'));
      expect(
        request,
        contains('chatHistory: List<Map<String, String>>.from(history)'),
      );
      expect(request, contains("'conversation_id': _currentSessionId"));
      expect(request, contains("'session_id': _currentSessionId"));
      expect(request, contains("'surface': 'daily_wear'"));
      expect(
        request,
        contains("'current_outfit': Map<String, dynamic>.from(currentOutfit)"),
      );
      expect(request, contains("'weather_context': _weatherContext"));
      expect(request, isNot(contains('BackendService().sendChatQuery(')));
      expect(request, isNot(contains("'Current outfit:")));
    },
  );

  test('Daily Board generation retains the style domain', () {
    final source = File('lib/services/backend_service.dart').readAsStringSync();
    final request = source.substring(
      source.indexOf('Future<Map<String, dynamic>?> getDailyBoard'),
      source.indexOf('// --- ACCOUNT & PROFILE ---'),
    );

    expect(request, contains("domain: 'style'"));
    expect(request, contains("'request': 'daily_board'"));
  });

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

  test('Daily Wear board items use canonical StyleBoardItem parsing', () {
    final source = File('lib/daily_wear.dart').readAsStringSync();
    final mapper = source.substring(
      source.indexOf('StyleBoardItem _styleBoardItemFromMap'),
      source.indexOf('/// Builds the Style Board', source.indexOf('StyleBoardItem _styleBoardItemFromMap')),
    );

    expect(mapper, contains('return StyleBoardItem.fromJson(item);'));
    expect(mapper, isNot(contains("item['img']")));
    expect(mapper, isNot(contains("item['photo_url']")));
  });

  test('pending loader is independent of prior visual board responses', () {
    final source = File('lib/daily_wear.dart').readAsStringSync();
    final messages = source.substring(source.indexOf('Widget _chatMessages()'));

    expect(messages, contains('_messages.length + (_isTyping ? 1 : 0)'));
    expect(messages, contains('return const _TypingBubble();'));
    expect(messages, isNot(contains('styleBoard')));
  });
}
