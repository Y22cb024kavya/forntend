import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/style_board/board_models.dart';
import 'package:myapp/style_board/editorial_board_layout_engine.dart';

StyleBoardItem _item(String id, BoardItemRole role) => StyleBoardItem(
  id: id,
  name: id,
  imageUrl: 'https://example.test/$id.png',
  category: role.name,
  role: role,
  source: 'wardrobe',
);

StyleBoardData _board(int count, {bool dress = false, bool outerwear = false}) {
  final roles = <BoardItemRole>[
    if (dress) BoardItemRole.dress,
    if (outerwear) BoardItemRole.outerwear,
    BoardItemRole.top,
    BoardItemRole.bottom,
    BoardItemRole.footwear,
    for (var i = 0; i < count; i++) BoardItemRole.accessory,
  ];
  return StyleBoardData(
    boardId: 'premium-$count',
    revision: 1,
    title: 'Premium $count',
    items: [for (var i = 0; i < count; i++) _item('item-$i', roles[i])],
  );
}

bool _overlaps(BoardItemPlacement a, BoardItemPlacement b) =>
    a.x < b.x + b.width - 0.5 &&
    a.x + a.width > b.x + 0.5 &&
    a.y < b.y + b.height - 0.5 &&
    a.y + a.height > b.y + 0.5;

void main() {
  const width = 390.0;
  const height = 265.0;

  test('uses a deliberate template for every supported item count', () {
    final expectedModes = <EditorialLayoutMode>[
      EditorialLayoutMode.premiumOneItem,
      EditorialLayoutMode.premiumTwoItem,
      EditorialLayoutMode.premiumThreeItem,
      EditorialLayoutMode.premiumFourItem,
      EditorialLayoutMode.premiumFiveItem,
      EditorialLayoutMode.premiumSixItem,
      EditorialLayoutMode.premiumSevenItem,
      EditorialLayoutMode.premiumEightItem,
    ];

    for (var count = 1; count <= 8; count++) {
      final result = EditorialBoardLayoutEngine.resolve(
        _board(count),
        width: width,
        height: height,
      );

      expect(result.mode, expectedModes[count - 1]);
      expect(result.placements, hasLength(count));
      expect(
        result.placements.map((placement) => placement.item.id).toSet(),
        hasLength(count),
      );
      for (final placement in result.placements) {
        expect(placement.x, greaterThanOrEqualTo(0));
        expect(placement.y, greaterThanOrEqualTo(0));
        expect(placement.x + placement.width, lessThanOrEqualTo(width));
        expect(placement.y + placement.height, lessThanOrEqualTo(height));
      }
    }
  });

  test('one item is dominant and two items use primary/secondary scale', () {
    final one = EditorialBoardLayoutEngine.resolve(
      _board(1),
      width: width,
      height: height,
    ).placements.single;
    final two = EditorialBoardLayoutEngine.resolve(
      _board(2),
      width: width,
      height: height,
    ).placements;

    expect(one.width / width, greaterThan(0.60));
    expect(two.first.width, greaterThan(two.last.width));
  });

  test('dress and outerwear retain dominant role-aware regions', () {
    final dressPlacements = EditorialBoardLayoutEngine.resolve(
      _board(4, dress: true),
      width: width,
      height: height,
    ).placements;
    final dress = dressPlacements.singleWhere(
      (placement) => placement.item.role == BoardItemRole.dress,
    );
    final layeredPlacements = EditorialBoardLayoutEngine.resolve(
      _board(5, outerwear: true),
      width: width,
      height: height,
    ).placements;
    final outerwear = layeredPlacements.singleWhere(
      (placement) => placement.item.role == BoardItemRole.outerwear,
    );

    expect(dress.width / width, greaterThan(0.70));
    expect(outerwear.width / width, greaterThan(0.50));
    expect(
      dressPlacements.map((placement) => placement.item.role),
      containsAll(<BoardItemRole>[
        BoardItemRole.dress,
        BoardItemRole.top,
        BoardItemRole.bottom,
        BoardItemRole.footwear,
      ]),
    );
    expect(
      layeredPlacements.map((placement) => placement.item.role),
      containsAll(<BoardItemRole>[
        BoardItemRole.outerwear,
        BoardItemRole.top,
        BoardItemRole.bottom,
        BoardItemRole.footwear,
        BoardItemRole.accessory,
      ]),
    );
  });

  test(
    'seven and eight item boards stay tappable without rectangle collisions',
    () {
      for (final count in [7, 8]) {
        final placements = EditorialBoardLayoutEngine.resolve(
          _board(count),
          width: width,
          height: height,
        ).placements;

        for (var i = 0; i < placements.length; i++) {
          for (var j = i + 1; j < placements.length; j++) {
            expect(
              _overlaps(placements[i], placements[j]),
              isFalse,
              reason:
                  'count=$count items=${placements[i].item.id},${placements[j].item.id}',
            );
          }
        }
      }
    },
  );

  test('more than eight items are bounded in canonical order', () {
    final result = EditorialBoardLayoutEngine.resolve(
      _board(12),
      width: width,
      height: height,
    );

    expect(result.placements, hasLength(8));
    expect(
      result.placements.map((placement) => placement.item.id).toSet(),
      containsAll(<String>{
        'item-0',
        'item-1',
        'item-2',
        'item-3',
        'item-4',
        'item-5',
        'item-6',
        'item-7',
      }),
    );
  });

  test('zero items retain the existing placeholder mode', () {
    final result = EditorialBoardLayoutEngine.resolve(
      _board(0),
      width: width,
      height: height,
    );

    expect(result.mode, EditorialLayoutMode.empty);
    expect(result.placements, isEmpty);
  });
}
