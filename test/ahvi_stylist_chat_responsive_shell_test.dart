import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/base_theme.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_chat_prompt_bar.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accent = AccentPalette(
  primary: Color(0xFFFF8EC7),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const deviceSizes = <String, Size>{
    '360x640': Size(360, 640),
    '360x800': Size(360, 800),
    '412x915': Size(412, 915),
  };

  for (final entry in deviceSizes.entries) {
    testWidgets(
      'modal chat shell renders without overflow and keeps the composer '
      'reachable at ${entry.key}',
      (tester) async {
        await _openModalChat(tester, size: entry.value);

        expect(tester.takeException(), isNull);
        expect(find.byType(AhviChatPromptBar), findsOneWidget);
        expect(find.text('My medicines today'), findsOneWidget);
        _expectInsideSurface(
          tester,
          find.byType(AhviChatPromptBar),
          entry.value,
        );
      },
    );
  }

  testWidgets(
    'modal chat shell keeps the composer above the keyboard without overflow',
    (tester) async {
      const size = Size(360, 800);
      await _openModalChat(tester, size: size);

      final devicePixelRatio = tester.view.devicePixelRatio;
      tester.view.viewInsets = FakeViewPadding(bottom: 260 * devicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      _expectInsideSurface(tester, find.byType(AhviChatPromptBar), size);
      expect(
        tester.getBottomRight(find.byType(AhviChatPromptBar)).dy,
        lessThanOrEqualTo(size.height - 260),
      );
    },
  );

  testWidgets(
    'modal chat shell survives a large text scale factor without overflow',
    (tester) async {
      const size = Size(360, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _openModalChat(tester, size: size);

      expect(tester.takeException(), isNull);
      _expectInsideSurface(tester, find.byType(AhviChatPromptBar), size);
    },
  );

  testWidgets('full-screen chat shell renders without overflow at 412x915', (
    tester,
  ) async {
    const size = Size(412, 915);
    await _openModalChat(tester, size: size, moduleContext: 'style');

    expect(tester.takeException(), isNull);
    expect(find.byType(AhviChatPromptBar), findsOneWidget);
    _expectInsideSurface(tester, find.byType(AhviChatPromptBar), size);
  });
}

Future<void> _openModalChat(
  WidgetTester tester, {
  required Size size,
  String moduleContext = 'medi',
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final tokens = AppThemeTokens.light(_accent);
  await tester.pumpWidget(
    MaterialApp(
      theme: BaseTheme.light.copyWith(extensions: [tokens]),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('open-chat'),
              onPressed: () => showAhviStylistChatSheet(
                context,
                moduleContext: moduleContext,
              ),
              child: const Text('Open chat'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const ValueKey('open-chat')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

// Sub-pixel slack absorbs devicePixelRatio rounding in the test surface —
// it does not mask real overflow, which throws a RenderFlex exception.
const _subPixelTolerance = 1.0;

void _expectInsideSurface(WidgetTester tester, Finder finder, Size size) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(-_subPixelTolerance));
  expect(rect.right, lessThanOrEqualTo(size.width + _subPixelTolerance));
  expect(rect.bottom, lessThanOrEqualTo(size.height + _subPixelTolerance));
}
