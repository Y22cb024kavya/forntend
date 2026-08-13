import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/feature/chat/models/ahvi_response_block.dart';
import 'package:myapp/feature/chat/services/ahvi_block_response_parser.dart';
import 'package:myapp/util/wardrobe_image_resolver.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';

Map<String, dynamic> _board(String id) => {
  'board_id': id,
  'title': 'Board',
  'items': const [],
};

void main() {
  Map<dynamic, dynamic> adaptedItem(Map<String, dynamic> item) {
      final parsed = parseAhviResponse({
        'route': 'wardrobe_style',
        'rendered_boards': [
        {
          'board_id': 'provenance-board',
          'items': [item],
        },
      ],
    });
    final block = parsed.blocks.singleWhere(
      (item) => item.type == AhviBlockType.visualDirections,
    );
    final direction = (block.data['directions'] as List).single as Map;
    return (direction['board_items'] as List).single as Map;
  }

  group('Style Me board alias parsing', () {
    test('accepts root style_boards', () {
      final selected = selectStyleBoardAlias({
        'route': 'wardrobe_style',
        'style_boards': [_board('style')],
      });

      expect(selected.path, 'style_boards');
      expect(selected.boards.single['board_id'], 'style');
    });

    test('accepts root rendered_boards', () {
      final selected = selectStyleBoardAlias({
        'route': 'visual_inspiration',
        'rendered_boards': [_board('rendered')],
      });

      expect(selected.path, 'rendered_boards');
      expect(selected.boards.single['board_id'], 'rendered');
    });

    test('accepts data.style_boards', () {
      final selected = selectStyleBoardAlias({
        'route': 'wardrobe_style',
        'data': {
          'style_boards': [_board('nested-style')],
        },
      });

      expect(selected.path, 'data.style_boards');
      expect(selected.boards.single['board_id'], 'nested-style');
    });

    test('data.rendered_boards is the highest valid alias', () {
      final selected = selectStyleBoardAlias({
        'route': 'visual_inspiration',
        'cards': [_board('card')],
        'style_boards': [_board('style')],
        'rendered_boards': [_board('root-rendered')],
        'data': {
          'rendered_boards': [_board('nested-rendered')],
        },
      });

      expect(selected.path, 'data.rendered_boards');
      expect(selected.boards.single['board_id'], 'nested-rendered');
    });

    test('mirrored aliases select one list without duplicating boards', () {
      final board = _board('same-board');
      final selected = selectStyleBoardAlias({
        'route': 'visual_inspiration',
        'cards': [board],
        'style_boards': [board],
        'data': {
          'rendered_boards': [board],
          'outfits': [board],
        },
      });

      expect(selected.path, 'data.rendered_boards');
      expect(selected.boards, hasLength(1));
    });

    test('distinct board ids remain distinct when item signatures match', () {
      Map<String, dynamic> board(String id) => {
        'board_id': id,
        'title': 'Smart Casual',
        'items': [
          {'item_id': 'shared-shirt', 'name': 'White Shirt'},
        ],
      };

      expect(
        styleBoardCountForTesting({
          'route': 'visual_inspiration',
          'data': {
            'rendered_boards': [
              board('board-1'),
              board('board-2'),
              board('board-3'),
            ],
          },
        }),
        3,
      );
    });

    test('cards remains a fallback', () {
      final selected = selectStyleBoardAlias({
        'route': 'visual_inspiration',
        'cards': [_board('card')],
      });

      expect(selected.path, 'cards');
    });

    test('data.outfits remains a fallback', () {
      final selected = selectStyleBoardAlias({
        'route': 'wardrobe_style',
        'data': {
          'outfits': [_board('outfit')],
        },
      });

      expect(selected.path, 'data.outfits');
    });

    test('invalid and empty higher aliases fall through', () {
      final selected = selectStyleBoardAlias({
        'route': 'visual_inspiration',
        'rendered_boards': 'encoded-json-is-not-supported',
        'style_boards': const [],
        'cards': const ['not-a-map'],
        'outfits': [_board('outfit')],
      });

      expect(selected.path, 'outfits');
      expect(selected.boards.single['board_id'], 'outfit');
    });
  });

  group('Style Me renderer precedence', () {
    test('generated Style aliases use canonical visual directions', () {
      for (final response in [
        {
          'route': 'visual_inspiration',
          'data': {
            'rendered_boards': [_board('nested-rendered')],
          },
        },
        {
          'route': 'visual_inspiration',
          'rendered_boards': [_board('rendered')],
        },
        {
          'route': 'visual_inspiration',
          'style_boards': [_board('style')],
        },
        {
          'route': 'visual_inspiration',
          'data': {
            'outfits': [_board('outfit')],
          },
        },
      ]) {
        expect(
          styleResponseRendererKindForTesting(response),
          'visual_directions',
        );
      }
    });

    test('visual directions take precedence over generated boards', () {
      expect(
        styleResponseRendererKindForTesting({
          'route': 'visual_inspiration',
          'visual_directions': [
            {'title': 'Direction'},
          ],
          'style_boards': [_board('board')],
        }),
        'visual_directions',
      );
    });

    test('advice-only responses remain valid without Style boards', () {
      expect(
        styleResponseRendererKindForTesting({
          'type': 'stylist_advice',
          'message_text': 'Try a softer colour balance.',
        }),
        'text',
      );
    });

    test('module_response still suppresses Style board rendering', () {
      expect(
        styleResponseRendererKindForTesting({
          'type': 'module_response',
          'cards': [_board('planner-card')],
        }),
        'text',
      );
    });

    test('module card aliases never become Style directions', () {
      for (final module in ['diet', 'fitness', 'medi']) {
        expect(
          styleResponseRendererKindForTesting({
            'module': module,
            'cards': [
              {'type': 'module_card', 'title': '$module card'},
            ],
          }),
          'text',
        );
      }
    });

    test('packing envelopes never become Style boards or directions', () {
      for (final response in [
        {
          'type': 'checklists',
          'style_boards': const [],
          'cards': [_board('pack-type')],
        },
        {
          'intent': 'plan_pack',
          'data': {
            'style_boards': const [],
            'cards': [_board('pack-intent')],
          },
        },
        {
          'visual_type': 'visual_packing_checklist',
          'visual_directions': [_board('pack-direction')],
          'cards': [_board('pack-visual')],
        },
      ]) {
        expect(styleResponseRendererKindForTesting(response), 'text');
        expect(selectStyleBoardAlias(response).boards, isEmpty);
      }
    });

    test('composite rendered board retains a canonical visual item', () {
      final response = {
        'route': 'visual_inspiration',
        'rendered_boards': [
          {
            'board_id': 'composite-1',
            'title': 'Rendered Look',
            'board_image_url': 'https://example.test/rendered.png',
          },
        ],
      };
      final parsed = parseAhviResponse(response);
      final block = parsed.blocks.singleWhere(
        (item) => item.type == AhviBlockType.visualDirections,
      );
      final direction = (block.data['directions'] as List).single as Map;
      final item = (direction['board_items'] as List).single as Map;

      expect(
        styleResponseRendererKindForTesting(response),
        'visual_directions',
      );
      expect(item['role'], 'dress');
      expect(item['image_url'], 'https://example.test/rendered.png');
    });

    test('adapter preserves masked, catalog, and original provenance', () {
      final item = adaptedItem({
        'item_id': 'blue-shirt',
        'masked_url': 'https://example.test/blue-shirt-mask.png',
        'normalized_url': 'https://example.test/catalog_blue-shirt.jpg',
        'image_url': 'https://example.test/blue-shirt-original.jpg',
      });

      expect(item['masked_url'], 'https://example.test/blue-shirt-mask.png');
      expect(
        item['normalized_url'],
        'https://example.test/catalog_blue-shirt.jpg',
      );
      expect(item['image_url'], 'https://example.test/blue-shirt-original.jpg');
      final resolved = resolveWardrobeImage(
        Map<String, dynamic>.from(item),
        surface: 'style_board_render',
        emitDiagnostic: false,
      );
      expect(resolved.field, 'masked_url');
      expect(resolved.expectedTransparent, isTrue);
      expect(resolved.requiresFrame, isFalse);
    });

    test('adapter retains a masked item without inventing an original', () {
      final item = adaptedItem({
        'item_id': 'masked-only',
        'maskedUrl': 'https://example.test/masked-only.png',
        'normalizedUrl': 'https://example.test/catalog_masked-only.jpg',
      });

      expect(item, isNot(contains('image_url')));
      expect(item['masked_url'], 'https://example.test/masked-only.png');
      expect(
        resolveWardrobeImage(
          Map<String, dynamic>.from(item),
          surface: 'style_board_render',
          emitDiagnostic: false,
        ).url,
        'https://example.test/masked-only.png',
      );
    });

    test('adapter canonicalizes prepared style asset fields', () {
      final item = adaptedItem({
        'item_id': 'prepared-asset',
        'source': 'style_asset',
        'assetCutoutUrl': 'https://example.test/prepared-cutout.png',
        'assetMaskedUrl': 'https://example.test/prepared-mask.png',
        'processedUrl': 'https://example.test/prepared.jpg',
        'imageUrl': 'https://example.test/prepared-original.jpg',
      });

      expect(
        item['asset_cutout_url'],
        'https://example.test/prepared-cutout.png',
      );
      expect(
        item['asset_masked_url'],
        'https://example.test/prepared-mask.png',
      );
      expect(item['processed_url'], 'https://example.test/prepared.jpg');
      expect(item['image_url'], 'https://example.test/prepared-original.jpg');
    });
  });
}
