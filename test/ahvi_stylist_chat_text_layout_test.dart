import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/base_theme.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';

const _accent = AccentPalette(
  primary: Color(0xFFFF8EC7),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

const _longCoffeeAdvice = '''For a coffee date, keep the hero piece relaxed and
polished: pair the clean top with a neutral bottom, then add one practical
layer for the weather. Keep the footwear simple and let the final accessory
echo the main color without competing with it.

The result should feel intentional, comfortable, and easy to move in.''';

const _longPairingAdvice = '''The white shirt works best when the surrounding
pieces add texture rather than more brightness. Try a deeper neutral bottom,
one structured layer, and a low-contrast shoe. Roll the sleeves only if the
occasion is casual enough, and keep the accessory line restrained.''';

void main() {
  testWidgets('coffee-date advice remains visible on a narrow surface', (
    tester,
  ) async {
    await _pumpFixture(tester, _longCoffeeAdvice);
    expect(find.text(_longCoffeeAdvice), findsOneWidget);
    expect(tester.takeException(), isNull);
    _expectInsideSurface(tester, find.text(_longCoffeeAdvice));
  });

  testWidgets(
    'white-shirt pairing advice remains visible on a narrow surface',
    (tester) async {
      await _pumpFixture(tester, _longPairingAdvice);
      expect(find.text(_longPairingAdvice), findsOneWidget);
      expect(tester.takeException(), isNull);
      _expectInsideSurface(tester, find.text(_longPairingAdvice));
    },
  );
}

Future<void> _pumpFixture(WidgetTester tester, String text) async {
  await tester.binding.setSurfaceSize(const Size(320, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: BaseTheme.light.copyWith(
        extensions: [AppThemeTokens.light(_accent)],
      ),
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [ahviStyleTextLayoutFixture(text: text)],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectInsideSurface(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(320));
  expect(rect.bottom, lessThanOrEqualTo(720));
}
