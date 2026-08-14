import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/base_theme.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accent = AccentPalette(
  primary: Color(0xFFFF8EC7),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('clear removes visible, semantic, persisted, and board context', (
    tester,
  ) async {
    const savedBoard = '[{"board_id":"saved-board"}]';
    await _pumpChat(
      tester,
      history: _historyWithBoard(),
      savedBoards: savedBoard,
    );

    expect(find.text('Old conversation'), findsOneWidget);
    await _confirmClear(tester);

    expect(find.text('Old conversation'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('ahvi_chat_history_style')!) as List;
    expect(stored, isEmpty);
    expect(prefs.getString('ahvi.saved_boards.v1'), savedBoard);
    expect(find.text('Clear this conversation?'), findsNothing);
  });

  testWidgets('cancel leaves the current conversation intact', (tester) async {
    await _pumpChat(tester, history: _historyWithBoard());

    await tester.tap(find.byTooltip('Chat options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Old conversation'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ahvi_chat_history_style'), isNotNull);
  });

  testWidgets('cleared conversation does not return after reopening the chat', (
    tester,
  ) async {
    await _pumpChat(tester, history: _historyWithBoard());
    await _confirmClear(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _openChat(tester);
    expect(find.text('Old conversation'), findsNothing);
  });

  test(
    'all active chat surfaces clear transient state without changing the cap',
    () {
      final stylist = _read('lib/widgets/ahvi_stylist_chat.dart');
      final legacy = _read('lib/chat.dart');
      final dailyWear = _read('lib/daily_wear.dart');

      expect(stylist, contains('_chatHistory.clear();'));
      expect(stylist, contains('_activeBoardMutationState = null;'));
      expect(legacy, contains('_chatHistory.clear();'));
      expect(legacy, contains('_activeBoardMutationState = null;'));
      expect(dailyWear, contains('_messages.clear();'));
      expect(
        stylist,
        contains('chatHistory: List<Map<String, String>>.from(_chatHistory)'),
      );
      expect(
        legacy,
        contains('chatHistory: List<Map<String, String>>.from(_chatHistory)'),
      );
      expect(dailyWear, contains("'conversation_id': _currentSessionId"));
      expect(
        _read('lib/services/backend_service.dart'),
        contains('moduleChatHistoryLimit'),
      );
    },
  );
}

String _read(String path) => File(path).readAsStringSync();

List<Map<String, dynamic>> _historyWithBoard() => [
  {
    'id': 'current-session',
    'title': 'Old conversation',
    'createdAt': '2026-08-14T12:00:00.000Z',
    'messages': [
      {
        'text': 'Old conversation',
        'textKey': null,
        'isUser': true,
        'boardPayload': {
          'cards': [
            {'board_id': 'transient-board', 'board_items': const []},
          ],
          'renderedBoards': const [],
          'outfits': const [],
          'boardId': 'transient-board',
          'styleState': {'board_id': 'transient-board'},
        },
        'moduleCards': const [],
        'actionChips': const [],
      },
    ],
  },
];

Future<void> _pumpChat(
  WidgetTester tester, {
  required List<Map<String, dynamic>> history,
  String? savedBoards,
}) async {
  SharedPreferences.setMockInitialValues({
    'ahvi_chat_history_style': jsonEncode(history),
    if (savedBoards != null) 'ahvi.saved_boards.v1': savedBoards,
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: BaseTheme.light.copyWith(
        extensions: [AppThemeTokens.light(_accent)],
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () =>
                showAhviStylistChatSheet(context, moduleContext: 'style'),
            child: const Text('Open chat'),
          ),
        ),
      ),
    ),
  );
  await _openChat(tester);
}

Future<void> _openChat(WidgetTester tester) async {
  if (find.text('Open chat').evaluate().isNotEmpty) {
    await tester.tap(find.text('Open chat'));
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

Future<void> _confirmClear(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Chat options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Clear chat'));
  await tester.pumpAndSettle();
  expect(find.text('Clear this conversation?'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, 'Clear chat'));
  await tester.pumpAndSettle();
}
