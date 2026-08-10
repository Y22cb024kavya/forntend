import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/style_mutation_contract.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';

void main() {
  test('natural-language board mutations share the legacy endpoint gate', () {
    for (final prompt in [
      'replace the shoes with white sneakers',
      'change the shoes to white sneakers',
      'swap the shoes for white sneakers',
      'give me white sneakers instead',
      'keep everything but change the shoes to white sneakers',
      'make the shoes black',
      'replace the loafers with sneakers',
      'replace the jacket with a navy blazer',
    ]) {
      expect(isStyleBoardMutationPrompt(prompt), isTrue, reason: prompt);
    }
  });

  test('ordinary style prompts do not become board mutations', () {
    for (final prompt in [
      'what should I wear today?',
      'make it more casual',
      'show another look',
      'white sneakers',
    ]) {
      expect(isStyleBoardMutationPrompt(prompt), isFalse, reason: prompt);
    }
  });

  test('active board state preserves identity, revision, items and policy', () {
    final state = styleMutationStateFromBoard(
      {
        'board_id': 'board-1',
        'revision': 4,
        'source_policy': 'wardrobe',
        'board_items': [
          {'item_id': 'top-1', 'role': 'top'},
          {'item_id': 'shoe-1', 'role': 'footwear'},
        ],
      },
      responseState: {
        'board_id': 'board-1',
        'revision': 4,
        'locked_item_ids': ['top-1'],
      },
    );

    expect(state, isNotNull);
    expect(state!['board_id'], 'board-1');
    expect(state['revision'], 4);
    expect(state['source_policy'], 'wardrobe');
    expect(state['locked_item_ids'], ['top-1']);
    expect((state['board_items'] as List), hasLength(2));
  });

  test('mutation response selects the new board for current-turn rendering', () {
    final selected = selectStyleBoardAlias({
      'response_mode': 'wardrobe_recommendation',
      'style_state': {'board_id': 'board-1', 'revision': 2},
      'style_boards': [
        {
          'board_id': 'board-1',
          'revision': 2,
          'board_items': [
            {'item_id': 'top-1', 'role': 'top', 'name': 'White shirt'},
            {
              'item_id': 'shoe-white-2',
              'role': 'footwear',
              'name': 'White sneakers',
            },
          ],
        },
      ],
    });

    expect(selected.boards.single['revision'], 2);
    expect(
      (selected.boards.single['board_items'] as List).last['name'],
      'White sneakers',
    );
  });

  test('multi-board state requires an explicit active board', () {
    final boards = [
      {
        'board_id': 'dinner',
        'revision': 1,
        'source_policy': 'wardrobe',
        'board_items': [
          {'item_id': 'dinner-shoe', 'role': 'footwear'},
        ],
      },
      {
        'board_id': 'office',
        'revision': 1,
        'source_policy': 'wardrobe',
        'board_items': [
          {'item_id': 'office-shoe', 'role': 'footwear'},
        ],
      },
    ];

    expect(styleMutationStateFromBoards(boards), isNull);
    final office = styleMutationStateFromBoards(
      boards,
      activeBoardId: 'office',
    );
    expect(office, isNotNull);
    expect(office!['board_id'], 'office');
    expect((office['board_items'] as List).single['item_id'], 'office-shoe');

    final officeWithoutDinnerState = styleMutationStateFromBoards(
      boards,
      activeBoardId: 'office',
      responseState: {
        'board_id': 'dinner',
        'revision': 1,
        'locked_item_ids': ['dinner-shoe'],
      },
    );
    expect(officeWithoutDinnerState!['locked_item_ids'], isNull);
  });

  test('explicit board revision remains the source for the next mutation', () {
    final state = styleMutationStateFromBoards(
      [
        {
          'board_id': 'dinner',
          'revision': 1,
          'board_items': [
            {'item_id': 'dinner-shoe', 'role': 'footwear'},
          ],
        },
        {
          'board_id': 'office',
          'revision': 2,
          'board_items': [
            {'item_id': 'office-shoe-v2', 'role': 'footwear'},
          ],
        },
      ],
      activeBoardId: 'office',
    );

    expect(state!['board_id'], 'office');
    expect(state['revision'], 2);
    expect((state['board_items'] as List).single['item_id'], 'office-shoe-v2');
  });
}
