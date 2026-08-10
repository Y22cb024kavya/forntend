import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/widgets/ahvi_stylist_chat.dart').readAsStringSync();
  final chatSource = File('lib/chat.dart').readAsStringSync();

  test('Style request trace includes provenance and correlation fields', () {
    expect(source, contains('AHVI_STYLE_REQUEST'));
    expect(source, contains(r'request_id=$requestId'));
    expect(
      source,
      contains(r'conversation_id=${_styleTraceValue(_currentSessionId)}'),
    );
    expect(source, contains(r'message_count=${_chatHistory.length}'));
    expect(
      source,
      contains(r"board_id=${_styleTraceValue(mutationState?['board_id'])}"),
    );
    expect(
      source,
      contains(
        r"board_revision=${_styleTraceValue(mutationState?['revision'])}",
      ),
    );
    expect(source, contains(r'frontend_sha=${_styleTraceValue(Env.gitSha)}'));
    expect(source, contains(r'build=${_styleTraceValue(Env.appBuildVersion)}'));
  });

  test('Style response trace is bounded to diagnostic fields', () {
    expect(source, contains('AHVI_STYLE_RESPONSE'));
    for (final field in [
      'response_mode=',
      'requires_clarification=',
      'has_board=',
      'board_id=',
      'board_revision=',
      'resolved_date=',
      'resolved_activity=',
      'activity_type=',
      'occasion=',
      'referent_type=',
      'fallback=',
    ]) {
      expect(source, contains(field));
    }
    expect(source, isNot(contains("'message': response")));
    expect(source, isNot(contains("'messages': _chatHistory")));
  });

  test('Legacy ChatScreen Style path emits the same bounded traces', () {
    expect(chatSource, contains('AHVI_STYLE_REQUEST'));
    expect(chatSource, contains('AHVI_STYLE_RESPONSE'));
    expect(
      chatSource,
      contains(r'conversation_id=${_styleTraceValue(_currentSessionId)}'),
    );
    expect(
      chatSource,
      contains(r"board_id=${_styleTraceValue(mutationState?['board_id'])}"),
    );
    expect(
      chatSource,
      contains(
        r"board_revision=${_styleTraceValue(mutationState?['revision'])}",
      ),
    );
    expect(
      chatSource,
      contains(r'frontend_sha=${_styleTraceValue(Env.gitSha)}'),
    );
    expect(
      chatSource,
      contains(r'build=${_styleTraceValue(Env.appBuildVersion)}'),
    );
    expect(chatSource, isNot(contains("'message': response")));
    expect(chatSource, isNot(contains("'messages': _chatHistory")));
  });
}
