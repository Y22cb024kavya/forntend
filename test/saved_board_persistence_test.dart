import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/style_board/saved_board_images.dart';
import 'package:myapp/style_board/saved_board_persistence.dart';

void main() {
  final shuffledItems = <Map<String, dynamic>>[
    {
      'item_id': 'bottom-2',
      'role': 'bottom',
      'masked_url': 'https://test/wardrobe_bottom-2_cutout_v2.png',
      'source_kind': 'validated_cutout',
    },
    {
      'item_id': 'top-4',
      'role': 'top',
      'normalized_url': 'https://test/catalog_top-4.png',
      'source_kind': 'catalog_fallback',
    },
  ];

  Map<String, dynamic> liveBoard() => canonicalSavedBoard(
    direction: const {
      'board_id': 'board-stable-1',
      'revision': 3,
      'source_policy': 'wardrobe',
      'layout': {'template': 'editorial-2'},
    },
    title: 'Office polish',
    occasion: 'office',
    outfitDescription: 'Sharp and balanced.',
    itemIds: const ['bottom-2', 'top-4'],
    items: shuffledItems,
  );

  test('legacy payload contains only deployed attributes', () {
    final payload = savedBoardLegacyPayload(
      userId: 'user-1',
      occasion: 'Office',
      imageUrl: 'https://test/cover.png',
      emoji: '*',
      itemIds: const ['bottom-2', 'top-4'],
      board: liveBoard(),
    );

    expect(payload.keys.toSet(), savedBoardAcceptedFields);
    expect(payload, isNot(contains('boardCategory')));
    expect(payload, isNot(contains('thumbnailUrl')));
    expect(payload, isNot(contains('board_payload')));
  });

  test('legacy reopen reconstructs the current shuffled board exactly', () {
    final live = liveBoard();
    final payload = savedBoardLegacyPayload(
      userId: 'user-1',
      occasion: 'Office',
      imageUrl: 'https://test/cover.png',
      emoji: '*',
      itemIds: const ['bottom-2', 'top-4'],
      board: live,
    );

    final reopened = expandSavedBoardData(payload);

    expect(reopened['board_id'], live['board_id']);
    expect(reopened['revision'], live['revision']);
    expect(reopened['source_policy'], 'wardrobe');
    expect(reopened['layout'], live['layout']);
    expect(reopened['items'], shuffledItems);
    expect(reopened['itemIds'], const ['bottom-2', 'top-4']);
    expect(reopened['outfitDescription'], 'Sharp and balanced.');
  });

  test('image provenance and catalogue fallback survive reopen', () {
    final payload = savedBoardLegacyPayload(
      userId: 'user-1',
      occasion: 'Office',
      imageUrl: 'https://test/cover.png',
      emoji: '*',
      itemIds: const ['bottom-2', 'top-4'],
      board: liveBoard(),
    );
    final reopened = expandSavedBoardData(payload);
    final items = (reopened['items'] as List).cast<Map<String, dynamic>>();

    expect(items.first['source_kind'], 'validated_cutout');
    expect(items.last['source_kind'], 'catalog_fallback');
    expect(extractSavedBoardImages(payload), [
      'https://test/wardrobe_bottom-2_cutout_v2.png',
      'https://test/catalog_top-4.png',
    ]);
  });
}
