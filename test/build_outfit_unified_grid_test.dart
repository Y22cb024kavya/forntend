import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/base_theme.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/wardrobe.dart';
import 'package:myapp/widgets/ahvi_unified_outfit_grid.dart';
import 'package:myapp/widgets/build_outfit_screen.dart';

const _accent = AccentPalette(
  primary: Color(0xFF6B91FF),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

void main() {
  testWidgets('Build Outfit compatibility screen reaches canonical grid', (
    tester,
  ) async {
    final items = [
      _item('anchor', 'White shirt', 'top'),
      _item('bottom', 'Black trousers', 'bottom'),
      _item('shoe', 'Leather shoes', 'footwear'),
      _item('bag', 'Structured bag', 'accessory'),
      _item('jacket', 'Navy blazer', 'outerwear'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: BaseTheme.light.copyWith(
          extensions: [AppThemeTokens.light(_accent)],
        ),
        home: BuildOutfitScreen(selectedItem: items.first, allItems: items),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.byType(AhviUnifiedOutfitGrid), findsOneWidget);
    expect(find.byKey(AhviUnifiedOutfitGrid.gridKey), findsOneWidget);
    expect(find.byKey(const ValueKey('anchor')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

WardrobeItem _item(String id, String name, String category) => WardrobeItem(
  id: id,
  name: name,
  cat: category,
  occasions: const ['casual', 'office', 'evening'],
  maskedUrl: 'https://example.test/$id.png',
);
