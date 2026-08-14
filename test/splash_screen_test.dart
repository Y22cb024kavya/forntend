import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/splash_screen.dart';

void main() {
  testWidgets('uses the redesigned launch visual without overflowing', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(onFinished: () {})),
      );
      await tester.pump(const Duration(milliseconds: 1800));

      expect(find.text('STYLE • PREP • PLAN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('finishes at the approved two second gate only once', (
    tester,
  ) async {
    var finishes = 0;
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onFinished: () => finishes++)),
    );

    await tester.pump(const Duration(milliseconds: 1999));
    expect(finishes, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(finishes, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(finishes, 1);
  });

  test('keeps the release startup contract outside the visual port', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('OfflineSyncBootstrap(child: AuthWrapper())'));
    expect(main, contains('Navigator.of(context).pushReplacement'));
    expect(main, contains('_maybeNavigate();'));
  });

  test('uses bundled Anton and completes animation before release', () {
    final source = File('lib/splash_screen.dart').readAsStringSync();
    expect(source, contains("fontFamily: 'Anton'"));
    expect(source, isNot(contains('GoogleFonts.anton')));
    expect(source, contains('Duration(milliseconds: 1800)'));
  });
}
