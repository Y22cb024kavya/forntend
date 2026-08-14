import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/backend_service.dart';

Map<String, String> _row(int index, {String role = 'assistant'}) => {
  'role': role,
  'content': 'message-$index',
};

void main() {
  group('module chat outbound history', () {
    test('A. copies history without mutating local conversation state', () {
      final local = [_row(1)];

      final outbound = buildModuleChatHistoryForRequest(local, 'current');

      expect(local, [_row(1)]);
      expect(outbound, isNot(same(local)));
      expect(outbound.last, {'role': 'user', 'content': 'current'});
    });

    test('B. appends the current query when the final row is absent', () {
      final outbound = buildModuleChatHistoryForRequest([
        _row(1),
        _row(2, role: 'user'),
      ], 'current');

      expect(outbound.last, {'role': 'user', 'content': 'current'});
      expect(outbound, hasLength(3));
    });

    test('C. does not duplicate an exact final current user row', () {
      final history = [
        _row(1),
        {'role': 'user', 'content': 'current'},
      ];

      final outbound = buildModuleChatHistoryForRequest(history, 'current');

      expect(outbound, history);
      expect(outbound, hasLength(2));
    });

    test('D. same content with a non-user role still appends current user', () {
      final outbound = buildModuleChatHistoryForRequest([
        const {'role': 'assistant', 'content': 'current'},
      ], 'current');

      expect(outbound, hasLength(2));
      expect(outbound.last, {'role': 'user', 'content': 'current'});
    });

    test('E. tails long history to the newest 20 rows', () {
      final history = List.generate(25, _row);

      final outbound = buildModuleChatHistoryForRequest(history, 'current');

      expect(outbound, hasLength(moduleChatHistoryLimit));
      expect(outbound.first, _row(6));
      expect(outbound.last, {'role': 'user', 'content': 'current'});
    });

    test('F. preserves an exact final current row while tailing', () {
      final history = [
        ...List.generate(24, _row),
        const {'role': 'user', 'content': 'current'},
      ];

      final outbound = buildModuleChatHistoryForRequest(history, 'current');

      expect(outbound, hasLength(moduleChatHistoryLimit));
      expect(outbound.first, _row(5));
      expect(outbound.last, {'role': 'user', 'content': 'current'});
      expect(
        outbound.where(
          (row) => row['role'] == 'user' && row['content'] == 'current',
        ),
        hasLength(1),
      );
    });
  });

  test(
    'G. transport fallback remains displayable but is not semantic history',
    () {
      final fallback = <String, dynamic>{
        'message_text': 'Please try again.',
        'meta': {'used_local_fallback': true},
      };
      final backendReply = <String, dynamic>{
        'message_text': 'Here is your answer.',
        'meta': {'used_local_fallback': false},
      };

      expect(fallback['message_text'], 'Please try again.');
      expect(
        shouldAppendModuleChatResponseToSemanticHistory(fallback),
        isFalse,
      );
      expect(
        shouldAppendModuleChatResponseToSemanticHistory(backendReply),
        isTrue,
      );
      expect(
        shouldAppendModuleChatResponseToSemanticHistory({'message_text': 'ok'}),
        isTrue,
      );

      final stylist = File(
        'lib/widgets/ahvi_stylist_chat.dart',
      ).readAsStringSync();
      final legacy = File('lib/chat.dart').readAsStringSync();
      final dailyWear = File('lib/daily_wear.dart').readAsStringSync();
      expect(
        stylist,
        contains('shouldAppendModuleChatResponseToSemanticHistory(response)'),
      );
      expect(
        legacy,
        contains('shouldAppendModuleChatResponseToSemanticHistory(response)'),
      );
      expect(
        dailyWear,
        contains('.where((m) => !m.excludeFromSemanticHistory)'),
      );
      expect(
        dailyWear,
        contains('!shouldAppendModuleChatResponseToSemanticHistory(response)'),
      );
    },
  );
}
