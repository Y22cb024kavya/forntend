import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/style_board/style_board_network_image.dart';
import 'package:myapp/util/wardrobe_image_resolver.dart';

// Image.network has no HTTP in the test harness, so every candidate "fails" and
// the widget walks the whole chain — exactly the runtime-failure path.
ResolvedWardrobeImage _cand(String url, String field,
        {bool transparent = true}) =>
    ResolvedWardrobeImage(
      url: url,
      field: field,
      sourceKind: transparent ? 'validated_cutout' : 'catalog_fallback',
      tier: transparent ? 0 : 3,
      expectedTransparent: transparent,
      validated: transparent,
      shouldFrame: !transparent,
    );

Widget _harness(
  List<ResolvedWardrobeImage> candidates,
  List<String> seen, {
  String itemId = 'i1',
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: StyleBoardNetworkImage(
            candidates: candidates,
            itemId: itemId,
            placeholder: const Text('PLACEHOLDER'),
            builder: (context, current, image) {
              seen.add(current.field);
              return image;
            },
          ),
        ),
      ),
    );

void main() {
  testWidgets('walks candidates in order then shows placeholder', (t) async {
    final seen = <String>[];
    await t.pumpWidget(_harness([
      _cand('https://x/a.png', 'cutout_url'),
      _cand('https://x/b.png', 'masked_url'),
      _cand('https://x/c.png', 'normalized_url', transparent: false),
    ], seen));

    expect(seen, ['cutout_url']); // first candidate attempted
    await t.pump();
    await t.pump(); // errorBuilder -> post-frame advance
    expect(seen.last, 'masked_url');
    await t.pump();
    await t.pump();
    expect(seen.last, 'normalized_url');
    await t.pump();
    await t.pump(); // last fails -> placeholder
    expect(find.text('PLACEHOLDER'), findsOneWidget);
  });

  testWidgets('malformed/empty candidates are skipped', (t) async {
    final seen = <String>[];
    await t.pumpWidget(_harness([
      _cand('', 'empty'),
      _cand('not-a-url', 'bad'),
      _cand('https://x/ok.png', 'cutout_url'),
    ], seen));
    // only the http candidate is usable
    expect(seen, ['cutout_url']);
  });

  testWidgets('all invalid -> placeholder immediately', (t) async {
    final seen = <String>[];
    await t.pumpWidget(_harness([_cand('', 'empty')], seen));
    expect(find.text('PLACEHOLDER'), findsOneWidget);
    expect(seen, isEmpty);
  });

  testWidgets('changing itemId resets fallback to the first candidate',
      (t) async {
    final seen = <String>[];
    final a = [
      _cand('https://x/a.png', 'a0'),
      _cand('https://x/a2.png', 'a1'),
    ];
    await t.pumpWidget(_harness(a, seen, itemId: 'A'));
    await t.pump();
    await t.pump(); // advance to a1
    expect(seen.last, 'a1');

    seen.clear();
    await t.pumpWidget(_harness([
      _cand('https://x/b.png', 'b0'),
      _cand('https://x/b2.png', 'b1'),
    ], seen, itemId: 'B'));
    expect(seen.first, 'b0'); // reset to first for the new item
  });

  testWidgets('does not loop past the last candidate', (t) async {
    final seen = <String>[];
    await t.pumpWidget(_harness([_cand('https://x/only.png', 'only')], seen));
    for (var i = 0; i < 6; i++) {
      await t.pump();
    }
    // one attempt, then placeholder — no unbounded rebuild
    expect(seen, ['only']);
    expect(find.text('PLACEHOLDER'), findsOneWidget);
  });
}
