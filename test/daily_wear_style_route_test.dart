import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Daily Wear conversational Style uses canonical continuity contract', () {
    final source = File('lib/daily_wear.dart').readAsStringSync();

    expect(source, contains('BackendService().sendModuleChat('));
    expect(source, contains("domain: 'style'"));
    expect(source, contains('message: userText'));
    expect(source, contains('chatHistory: List<Map<String, String>>.from(history)'));
    expect(source, contains("'conversation_id': _currentSessionId"));
    expect(source, contains("'session_id': _currentSessionId"));
    expect(source, contains("'surface': 'daily_wear'"));
    expect(source, contains("'current_outfit': Map<String, dynamic>.from(currentOutfit)"));
    expect(source, contains("'weather_context': _weatherContext"));
    expect(source, isNot(contains('BackendService().sendChatQuery(')));
    expect(source, isNot(contains("'Current outfit:")));
  });
}
