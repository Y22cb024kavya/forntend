import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/feature/chat/widgets/blocks/visual_directions/ahvi_outfit_board_card.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';
import 'package:myapp/widgets/try_on_coming_soon.dart';

void main() {
  test('only the CTA sentinel opens Coming Soon', () {
    expect(isTryOnComingSoonAction(tryOnComingSoonAction), isTrue);
    expect(isTryOnComingSoonAction('build_outfit'), isFalse);
    expect(isTryOnComingSoonAction('build me an outfit'), isFalse);
    expect(isTryOnComingSoonAction('Try-On'), isFalse);
    expect(isTryOnComingSoonAction('Style This'), isFalse);
    expect(resolveOutfitBoardTitle({'title': 'Build Outfit'}), 'Try-On');
    expect(
      actionChipsForTesting({
        'chips': [
          {'label': 'Build Outfit', 'value': 'build_outfit'},
        ],
      }).single,
      {'label': 'Try-On', 'value': tryOnComingSoonAction},
    );
  });

  testWidgets('Coming Soon dialog has no execution controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TryOnComingSoonDialog())),
    );

    expect(find.text('Try-On'), findsOneWidget);
    expect(
      find.text('See how your looks come together on you.'),
      findsOneWidget,
    );
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Build Outfit'), findsNothing);
  });
}
