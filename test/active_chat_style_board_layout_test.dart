import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/feature/chat/widgets/blocks/visual_directions/ahvi_outfit_board_card.dart';
import 'package:myapp/style_board/editorial_board_renderer.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/base_theme.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';
import 'package:myapp/widgets/ahvi_unified_outfit_grid.dart';
import 'package:myapp/widgets/basic_markdown_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accent = AccentPalette(
  primary: Color(0xFF6B91FF),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

void main() {
  testWidgets('active chat board preserves responsive approved canvas', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 384.0, 390.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await _pumpSeededStyleChat(tester, itemCount: 5);

      final surface = find.byKey(
        const ValueKey('active-chat-style-board-surface'),
      );
      final card = find.byKey(const ValueKey('active-chat-outfit-board-card'));
      expect(surface, findsOneWidget);
      expect(card, findsOneWidget);
      expect(find.byType(AhviUnifiedOutfitGrid), findsOneWidget);
      expect(find.byKey(AhviUnifiedOutfitGrid.gridKey), findsOneWidget);
      expect(find.byType(EditorialBoardCanvas), findsNothing);

      // The chat ListView owns the only horizontal page inset (16 px/side).
      expect(tester.getSize(surface).width, closeTo(width - 32, 0.1));
      expect(tester.getSize(card).width, closeTo(width - 32, 0.1));
      expect(tester.getSize(find.byType(AhviUnifiedOutfitGrid)).height, greaterThan(150));

      final assistantSparkle = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.auto_awesome_rounded &&
            widget.size == 24,
      );
      expect(assistantSparkle, findsOneWidget);
      expect(find.byType(BasicMarkdownText), findsOneWidget);

      final reasoning = find.byKey(
        const ValueKey('active-chat-board-reasoning'),
      );
      final actions = find.byType(OutfitActionBar);
      expect(reasoning, findsOneWidget);
      expect(actions, findsOneWidget);
      expect(
        tester.getTopLeft(actions).dy - tester.getBottomLeft(reasoning).dy,
        closeTo(0, 0.1),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('active 3-6 item canonical grid stays within phone bounds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final count in [3, 4, 5, 6]) {
      await _pumpSeededStyleChat(tester, itemCount: count);

      final grid = find.byType(AhviUnifiedOutfitGrid);
      expect(grid, findsOneWidget);
      expect(find.byType(EditorialBoardCanvas), findsNothing);
      final gridRect = tester.getRect(grid);
      for (var i = 0; i < count; i++) {
        final item = find.byKey(ValueKey<String>('item-$i'));
        expect(item, findsOneWidget);
        final itemRect = tester.getRect(item);
        expect(gridRect.inflate(0.1).contains(itemRect.topLeft), isTrue);
        expect(gridRect.inflate(0.1).contains(itemRect.bottomRight), isTrue);
        expect(itemRect.shortestSide, greaterThan(60));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

Future<void> _pumpSeededStyleChat(
  WidgetTester tester, {
  required int itemCount,
}) async {
  SharedPreferences.setMockInitialValues({
    'ahvi_chat_history_style': jsonEncode([
      {
        'id': 'active-board-session',
        'title': 'Dinner tomorrow',
        'createdAt': '2026-08-14T12:00:00.000Z',
        'messages': [
          {
            'text': 'Dinner tomorrow',
            'isUser': true,
            'moduleCards': const [],
            'actionChips': const [],
          },
          {
            'text': '**I pulled together** a dinner look.',
            'isUser': false,
            'visualDirectionPayload': {
              'directions': [_board(itemCount)],
              'styleState': null,
            },
            'moduleCards': const [],
            'actionChips': const [],
          },
        ],
      },
    ]),
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
  await tester.tap(find.text('Open chat'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.tap(find.byIcon(Icons.history_rounded));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(find.text('Dinner tomorrow'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2200));
}

Map<String, dynamic> _board(int itemCount) {
  const roles = [
    'top',
    'bottom',
    'footwear',
    'accessory',
    'accessory',
    'accessory',
  ];
  return {
    'board_id': '11111111-1111-4111-8111-111111111111',
    'revision': 1,
    'interaction_mode': 'recommendation',
    'title': 'Modern Romantic',
    'occasion': 'dinner',
    'why_it_works': 'Balanced color and proportion for dinner.',
    'styling_tip': 'Keep the finish polished.',
    'board_items': [
      for (var i = 0; i < itemCount; i++)
        {
          'item_id': 'item-$i',
          'name': 'Item $i',
          'slot': roles[i],
          'role': roles[i],
          'source': 'wardrobe',
          'image_url': 'https://example.test/original-$i.jpg',
          'board_image_url': 'https://example.test/item-$i.png',
          'board_status': 'cutout_ready',
        },
    ],
  };
}
