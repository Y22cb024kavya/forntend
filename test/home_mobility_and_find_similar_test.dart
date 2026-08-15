// Build 2012 regressions:
//   - Home's Mobility chip pushed DailyWearScreen (copy-paste from the Wear
//     chip) instead of the Workout/Move screen.
//   - Home's two "+" entry points overrode showAhviLensSheet's canonical
//     Find Similar / Visual Search defaults with a Coming Soon stub instead
//     of reusing the same flow Style Me's "+" already uses.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home Mobility chip opens the Workout/Move screen, not Daily Wear', () {
    final source = File('lib/home.dart').readAsStringSync();
    final mobilityChip = source.substring(
      source.indexOf('MOBILITY CHIP'),
      source.indexOf('WEATHER CHIP'),
    );

    expect(mobilityChip, contains('WorkoutStudioScreen'));
    expect(mobilityChip, isNot(contains('DailyWearScreen')));
  });

  test('Home Wear card/chip still opens Daily Wear (unaffected by the Mobility fix)', () {
    final source = File('lib/home.dart').readAsStringSync();
    expect(source, contains('page: DailyWearScreen()'));
  });

  test('Home plus-menu lens sheet reuses the canonical Find Similar flow', () {
    final source = File('lib/home.dart').readAsStringSync();
    final plusMenu = source.substring(
      source.indexOf('void _openPlusMenu'),
      source.indexOf('void _closePlusMenu'),
    );

    expect(plusMenu, contains('onVisualSearch: null'));
    expect(plusMenu, contains('onFindSimilar: null'));
    expect(plusMenu, isNot(contains('onFindSimilar: () => _showComingSoon()')));
  });

  test('Home chat bar lens sheet reuses the canonical Find Similar flow', () {
    final source = File('lib/home.dart').readAsStringSync();
    final chatWrap = source.substring(
      source.indexOf('Widget _buildChatWrap()'),
      source.indexOf('ChatGPT-style plus menu'),
    );

    expect(chatWrap, contains('onVisualSearch: null'));
    expect(chatWrap, contains('onFindSimilar: null'));
    expect(chatWrap, isNot(contains('onFindSimilar: () => _showComingSoon()')));
  });
}
