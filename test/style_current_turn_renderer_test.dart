import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/feature/chat/models/ahvi_response_block.dart';
import 'package:myapp/feature/chat/services/ahvi_block_response_parser.dart';
import 'package:myapp/services/ahvi_response_policy.dart';
import 'package:myapp/services/chat_response_renderer_registry.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';

Map<String, dynamic> _board(String id) => {
  'board_id': id,
  'title': id,
  'items': [
    {'item_id': '$id-top', 'name': 'Shirt', 'role': 'top'},
  ],
};

Map<String, dynamic> _visual(String id) => {
  'response_mode': 'visual_inspiration',
  'message_text': 'Here is the current visual direction.',
  'style_boards': [_board(id)],
};

void _expectTextOnly(Map<String, dynamic> response) {
  final policy = AhviResponsePolicy.fromResponse(response);

  expect(policy.textPrimary, isTrue);
  expect(policy.canRenderBoards(response), isFalse);
  expect(
    AhviChatResponseRendererRegistry.select(response).kind,
    AhviChatRendererKind.text,
  );
  expect(styleResponseRendererKindForTesting(response), 'text');
  expect(styleBoardCountForTesting(response), 0);
  final structuredBlocks = parseAhviResponse(response).blocks.where(
    (block) =>
        block.type == AhviBlockType.visualDirections ||
        block.type == AhviBlockType.styleBoards ||
        block.type == AhviBlockType.visualBoard,
  );
  expect(structuredBlocks, isEmpty);
}

void main() {
  test('text response suppresses a previous board payload', () {
    final firstTurn = _visual('dinner-look');
    final secondTurn = {
      'response_mode': 'text_only',
      'intent': 'visual_inspiration',
      'message_text':
          'Colour analysis explains how undertones affect palettes.',
      // Simulates a stale board accidentally attached to the current response.
      'style_boards': firstTurn['style_boards'],
    };

    expect(styleResponseRendererKindForTesting(firstTurn), 'visual_directions');
    _expectTextOnly(secondTurn);
  });

  test('clarification response suppresses stale board aliases', () {
    _expectTextOnly({
      'response_mode': 'clarification',
      'message_text': 'What occasion are you dressing for?',
      'data': {
        'rendered_boards': [_board('stale-rendered')],
      },
      'visual_directions': [_board('stale-direction')],
      'outfits': [_board('stale-outfit')],
    });
  });

  test('advice response stays text-only in Style context', () {
    _expectTextOnly({
      'response_mode': 'text_only',
      'module': 'style',
      'message_text': 'Warm undertones often suit earthy and golden colours.',
    });
  });

  test('visual response renders the current board', () {
    final response = _visual('beach-dinner-look');

    expect(
      AhviChatResponseRendererRegistry.select(response).kind,
      AhviChatRendererKind.styleBoard,
    );
    expect(styleResponseRendererKindForTesting(response), 'visual_directions');
    expect(styleBoardCountForTesting(response), 1);
  });

  test('visual to text to visual uses each current response mode', () {
    final responses = [
      _visual('dinner-look'),
      {
        'response_mode': 'text_only',
        'message_text': 'The first look works because the palette is balanced.',
        'style_boards': [_board('dinner-look')],
      },
      _visual('new-dinner-direction'),
    ];

    expect(
      styleResponseRendererKindForTesting(responses[0]),
      'visual_directions',
    );
    _expectTextOnly(responses[1]);
    expect(
      styleResponseRendererKindForTesting(responses[2]),
      'visual_directions',
    );
    expect(styleBoardCountForTesting(responses[2]), 1);
  });

  test(
    'current board rendering does not depend on a previous response object',
    () {
      final prior = _visual('prior');
      final current = {
        'response_mode': 'text_only',
        'message_text': 'Style tips: anchor the outfit with one colour.',
      };

      // The prior board is still a valid history response, but the current
      // renderer receives only the current response payload.
      expect(styleBoardCountForTesting(prior), 1);
      _expectTextOnly(current);
    },
  );
}
