import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';

Map<String, dynamic> _board(String id) => {
  'board_id': id,
  'title': 'Board',
  'items': const [],
};

void main() {
  group('Style Me board alias parsing', () {
    test('accepts root style_boards', () {
      final selected = selectStyleBoardAlias({
        'style_boards': [_board('style')],
      });

      expect(selected.path, 'style_boards');
      expect(selected.boards.single['board_id'], 'style');
    });

    test('accepts root rendered_boards', () {
      final selected = selectStyleBoardAlias({
        'rendered_boards': [_board('rendered')],
      });

      expect(selected.path, 'rendered_boards');
      expect(selected.boards.single['board_id'], 'rendered');
    });

    test('accepts data.style_boards', () {
      final selected = selectStyleBoardAlias({
        'data': {
          'style_boards': [_board('nested-style')],
        },
      });

      expect(selected.path, 'data.style_boards');
      expect(selected.boards.single['board_id'], 'nested-style');
    });

    test('data.rendered_boards is the highest valid alias', () {
      final selected = selectStyleBoardAlias({
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

    test('cards remains a fallback', () {
      final selected = selectStyleBoardAlias({
        'cards': [_board('card')],
      });

      expect(selected.path, 'cards');
    });

    test('data.outfits remains a fallback', () {
      final selected = selectStyleBoardAlias({
        'data': {
          'outfits': [_board('outfit')],
        },
      });

      expect(selected.path, 'data.outfits');
    });

    test('invalid and empty higher aliases fall through', () {
      final selected = selectStyleBoardAlias({
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
    test('visual directions take precedence over generated boards', () {
      expect(
        styleResponseRendererKindForTesting({
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
  });
}
