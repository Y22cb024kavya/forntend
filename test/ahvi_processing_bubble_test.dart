import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/feature/chat/services/ahvi_processing_message.dart';
import 'package:myapp/feature/chat/widgets/ahvi_processing_bubble.dart';

Future<void> _pump(
  WidgetTester tester,
  String message, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: disableAnimations),
            child: AhviProcessingBubble(message: message),
          ),
        ),
      ),
    ),
  );
  await tester.pump(); // one frame; controller repeats so never pumpAndSettle
}

void main() {
  group('ahviProcessingMessage resolver', () {
    test('general → AHVI is thinking', () {
      expect(ahviProcessingMessage(AhviProcessingContext.general),
          'AHVI is thinking');
    });
    test('style recommendation → Curating your look', () {
      expect(ahviProcessingMessage(AhviProcessingContext.styleRecommendation),
          'Curating your look');
    });
    test('style this includes the anchor item name', () {
      expect(
        ahviProcessingMessage(AhviProcessingContext.styleThis,
            itemName: 'Pink Shirt'),
        'Styling around your Pink Shirt',
      );
    });
    test('style this without an item name falls back', () {
      expect(ahviProcessingMessage(AhviProcessingContext.styleThis),
          'AHVI is thinking');
      expect(
        ahviProcessingMessage(AhviProcessingContext.styleThis, itemName: '  '),
        'AHVI is thinking',
      );
    });
    test('wardrobe → Checking your wardrobe', () {
      expect(ahviProcessingMessage(AhviProcessingContext.wardrobe),
          'Checking your wardrobe');
    });
    test('build outfit → Putting the outfit together', () {
      expect(ahviProcessingMessage(AhviProcessingContext.buildOutfit),
          'Putting the outfit together');
    });
    test('shuffle → Refreshing unlocked pieces', () {
      expect(ahviProcessingMessage(AhviProcessingContext.shuffle),
          'Refreshing unlocked pieces');
    });
    test('calendar → Preparing your plan', () {
      expect(ahviProcessingMessage(AhviProcessingContext.calendar),
          'Preparing your plan');
    });
    test('arranging board → Arranging your Style Board', () {
      expect(ahviProcessingMessage(AhviProcessingContext.arrangingBoard),
          'Arranging your Style Board');
    });
  });

  group('AhviProcessingBubble', () {
    testWidgets('shows the message', (tester) async {
      await _pump(tester, 'Styling around your Pink Shirt');
      expect(find.text('Styling around your Pink Shirt'), findsOneWidget);
      expect(find.text('✦'), findsOneWidget);
    });

    // Scope to the bubble subtree — the MaterialApp page transition
    // (ZoomPageTransition) has its own ScaleTransition we must not count.
    Finder bubbleScale() => find.descendant(
          of: find.byType(AhviProcessingBubble),
          matching: find.byType(ScaleTransition),
        );

    testWidgets('animates (pulsing sparkle) when animations enabled',
        (tester) async {
      await _pump(tester, 'Curating your look');
      expect(bubbleScale(), findsOneWidget);
    });

    testWidgets('renders a static indicator when animations are disabled',
        (tester) async {
      await _pump(tester, 'Curating your look', disableAnimations: true);
      // No pulsing sparkle → static indicator.
      expect(bubbleScale(), findsNothing);
      expect(find.text('Curating your look'), findsOneWidget);
      expect(find.text('✦'), findsOneWidget);
    });

    testWidgets('disposes its controller without error', (tester) async {
      await _pump(tester, 'AHVI is thinking');
      // Replace with an empty tree — State.dispose must tear the controller
      // down cleanly (no "ticker was active at dispose" throw).
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
