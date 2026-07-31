import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/base_theme.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/widgets/chat_cards/visual_packing_checklist_card.dart';

const _accent = AccentPalette(
  primary: Color(0xFFFF8EC7),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

Map<String, dynamic> _card({
  List<Map<String, dynamic>>? items,
  List<dynamic>? actions,
}) => {
  'type': 'visual_packing_checklist',
  'title': 'Carry-on Checklist',
  'subtitle': 'Three days',
  'visual_sections': [
    {
      'id': 'tech',
      'title': 'Tech & Power',
      'items':
          items ??
          [
            {'id': 'charger', 'label': 'Charger'},
            {'id': 'passport', 'label': 'Passport', 'packed': true},
          ],
    },
  ],
  if (actions != null) 'actions': actions,
};

void main() {
  test('plural image_urls wins over singular image_url', () {
    expect(
      packingImageUrlForItem({
        'image_urls': ['https://example.test/plural.png'],
        'image_url': 'https://example.test/singular.png',
      }),
      'https://example.test/plural.png',
    );
  });

  test('singular image_url is the fallback when plural is empty', () {
    expect(
      packingImageUrlForItem({
        'image_urls': [],
        'image_url': 'https://example.test/singular.png',
      }),
      'https://example.test/singular.png',
    );
  });

  test('asset_key and rich packing icon aliases are preserved', () {
    expect(
      packingAssetKeyForItem({
        'asset_key': 'assets/images/plan_card_women.jpg',
      }),
      'assets/images/plan_card_women.jpg',
    );
    expect(packingIconForKey('passport'), Icons.badge_outlined);
    expect(packingSectionIconForKey('Tech & Power'), Icons.power_rounded);
    expect(
      packingSectionIconForKey('Unknown Section'),
      Icons.inventory_2_rounded,
    );
  });

  testWidgets('no-image payload uses the section icon fallback', (
    tester,
  ) async {
    await tester.pumpWidget(_app(VisualPackingChecklistCard(card: _card())));
    expect(find.textContaining('Tech & Power'), findsOneWidget);
    expect(find.text('Charger'), findsOneWidget);
    expect(find.byIcon(Icons.power_outlined), findsAtLeastNWidgets(1));
    expect(find.text('1 of 2 packed'), findsOneWidget);
  });

  testWidgets('asset_key renders Image.asset when no backend image exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        VisualPackingChecklistCard(
          card: _card(
            items: [
              {
                'label': 'Local plan image',
                'asset_key': 'assets/images/plan_card_women.jpg',
              },
            ],
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('CTA action is rendered and sends its label', (tester) async {
    String? sent;
    await tester.pumpWidget(
      _app(
        VisualPackingChecklistCard(
          card: _card(
            actions: const [
              {'label': 'Weather prep'},
            ],
          ),
          onAction: (value) => sent = value,
        ),
      ),
    );
    await tester.tap(find.text('Weather prep'));
    expect(sent, 'Weather prep');
  });
}

Widget _app(Widget child) {
  final tokens = AppThemeTokens.light(_accent);
  return MaterialApp(
    theme: BaseTheme.light.copyWith(extensions: [tokens]),
    home: Scaffold(body: child),
  );
}
