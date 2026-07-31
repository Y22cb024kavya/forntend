import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/style_board/saved_board_card.dart';
import 'package:myapp/style_board/editorial_board_renderer.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/theme_tokens.dart';

const _accent = AccentPalette(
  primary: Color(0xFFFF8EC7),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

void main() {
  testWidgets('saved board title stays above the canonical canvas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: [AppThemeTokens.light(_accent)],
        ),
        home: const Scaffold(
          body: SizedBox(
            width: 300,
            height: 520,
            child: SavedBoardCard(
              source: {
                'title': 'Refined Ease',
                'occasion': 'Work',
                'description': 'Balanced tailoring for a polished day.',
                'items': [
                  {
                    'item_id': 'top-1',
                    'name': 'Shirt',
                    'role': 'top',
                    'image_url': 'https://example.test/top.png',
                  },
                  {
                    'item_id': 'bottom-1',
                    'name': 'Trousers',
                    'role': 'bottom',
                    'image_url': 'https://example.test/bottom.png',
                  },
                  {
                    'item_id': 'shoe-1',
                    'name': 'Loafers',
                    'role': 'footwear',
                    'image_url': 'https://example.test/shoe.png',
                  },
                ],
              },
              wardrobeById: {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final title = find.byKey(const ValueKey('saved-board-title'));
    final canvas = find.byKey(const ValueKey('saved-board-canvas'));
    expect(title, findsOneWidget);
    expect(canvas, findsOneWidget);
    expect(find.byType(EditorialBoardCanvas), findsOneWidget);
    expect(tester.getTopLeft(title).dy, lessThan(tester.getTopLeft(canvas).dy));
    expect(tester.takeException(), isNull);
  });
}
