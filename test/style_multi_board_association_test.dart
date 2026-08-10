import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/feature/chat/widgets/blocks/visual_directions/ahvi_outfit_board_card.dart';
import 'package:myapp/feature/chat/widgets/blocks/visual_directions/visual_direction_carousel.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/base_theme.dart';
import 'package:myapp/theme/theme_tokens.dart';

const _accent = AccentPalette(
  primary: Color(0xFFFF8EC7),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

Map<String, dynamic> _item(String id, String role) => {
  'item_id': id,
  'name': id,
  'role': role,
  'slot': role,
  'source': 'wardrobe',
  'image_url': 'https://example.test/$id.png',
  'masked_url': 'https://example.test/$id-cutout.png',
  'board_image_url': 'https://example.test/$id-board.png',
  'board_status': 'cutout_ready',
  'position': {
    'x': .1,
    'y': .1,
    'width': .3,
    'height': .3,
    'rotation': 0,
    'z': 1,
  },
};

Map<String, dynamic> _board(String id, String title) => {
  'board_id': id,
  'revision': 1,
  'scenario': 'build_outfit',
  'source_policy': 'wardrobe',
  'shuffle_available': true,
  'title': title,
  'occasion': title,
  'board_items': [
    _item('$id-top', 'top'),
    _item('$id-bottom', 'bottom'),
    _item('$id-shoe', 'footwear'),
  ],
};

void main() {
  testWidgets('selecting the second carousel board owns the action state', (
    tester,
  ) async {
    Map<String, dynamic>? selected;
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: BaseTheme.light.copyWith(
          extensions: [AppThemeTokens.light(_accent)],
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: VisualDirectionCarousel(
              directions: [
                _board('dinner', 'Dinner'),
                _board('office', 'Office'),
              ],
              curationReveal: false,
              onBoardStateChanged: (board) => selected = board,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final officeCard = find.byKey(
      const ValueKey('vd-board-office-1'),
    );
    await tester.ensureVisible(officeCard);
    await tester.tap(
      find.descendant(of: officeCard, matching: find.byType(OutfitContextStrip)),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(selected?['board_id'], 'office');
    expect(selected?['revision'], 1);
  });
}
