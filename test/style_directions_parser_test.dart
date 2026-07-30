// Parser tests for the Style This `style_directions` → canonical
// visualDirections adaptation (P0: backend ships style_directions, the parser
// must produce a visualDirections block).
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/feature/chat/models/ahvi_response_block.dart';
import 'package:myapp/feature/chat/services/ahvi_block_response_parser.dart';

Map<String, dynamic> _boardItem(String id, String role) => {
      'item_id': id,
      'name': id,
      'role': role,
      'image_url': 'https://example.test/$id.png',
      'board_image_url': 'https://example.test/$id.png',
    };

Map<String, dynamic> _styleThisResponse({
  Map<String, dynamic>? anchor,
  List<Map<String, dynamic>>? directions,
}) => {
      'success': true,
      'mode': 'style_this',
      'anchor_item': anchor ?? {'item_id': 'anchor-1', 'name': 'Pink Shirt'},
      'style_directions': directions ??
          [
            {
              'board_id': 'style-board-1',
              'revision': 1,
              'title': 'Sharp Layers',
              'occasion': 'work',
              'why_it_works': 'Balances the anchor',
              'board_items': [
                _boardItem('anchor-1', 'top'),
                _boardItem('bottom-7', 'bottom'),
                _boardItem('shoe-9', 'footwear'),
              ],
              'positions': {'anchor-1': {'x': 0.1, 'y': 0.1}},
            },
          ],
      'context_usage': {'context_version': 'v2'},
    };

List<Map<String, dynamic>> _directionsOf(AhviParsedResponse parsed) {
  final block = parsed.blocks.firstWhere(
    (b) => b.type == AhviBlockType.visualDirections,
    orElse: () => AhviResponseBlock(
      type: AhviBlockType.visualDirections,
      data: const {'directions': <Map<String, dynamic>>[]},
    ),
  );
  final raw = block.data['directions'];
  return raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];
}

bool _hasVisualDirections(AhviParsedResponse parsed) =>
    parsed.blocks.any((b) => b.type == AhviBlockType.visualDirections);

void main() {
  test('top-level style_directions produces a visualDirections block', () {
    final parsed = parseAhviResponse(_styleThisResponse());
    expect(_hasVisualDirections(parsed), isTrue);
    expect(_directionsOf(parsed), hasLength(1));
  });

  test('mapped direction carries the Style This contract fields', () {
    final dir = _directionsOf(parseAhviResponse(_styleThisResponse())).single;
    expect(dir['scenario'], 'style_this');
    expect(dir['interaction_mode'], 'style_this');
    expect(dir['source_policy'], 'wardrobe');
  });

  test('anchor id is carried onto the direction for lock + verification', () {
    final dir = _directionsOf(parseAhviResponse(_styleThisResponse())).single;
    expect(dir['anchor_item_id'], 'anchor-1');
    expect(dir['originating_item_id'], 'anchor-1');
  });

  test('all canonical board fields survive the mapping', () {
    final dir = _directionsOf(parseAhviResponse(_styleThisResponse())).single;
    expect(dir['board_id'], 'style-board-1');
    expect(dir['revision'], 1);
    expect(dir['title'], 'Sharp Layers');
    expect(dir['occasion'], 'work');
    expect(dir['why_it_works'], 'Balances the anchor');
    expect(dir['positions'], isNotNull);
    final items = (dir['board_items'] as List).cast<Map>();
    expect(items, hasLength(3));
    expect(items.first['item_id'], 'anchor-1');
  });

  test('anchor present in board_items', () {
    final dir = _directionsOf(parseAhviResponse(_styleThisResponse())).single;
    final items = (dir['board_items'] as List)
        .map((e) => (e as Map)['item_id'])
        .toList();
    expect(items, contains('anchor-1'));
  });

  test('existing visual_directions parsing is unchanged (no style_this stamp)',
      () {
    final response = {
      'success': true,
      'visual_directions': [
        {
          'board_id': 'rec-board-1',
          'revision': 2,
          'interaction_mode': 'recommendation',
          'title': 'Weekend Ease',
          'board_items': [_boardItem('a', 'top')],
        },
      ],
    };
    final dir = _directionsOf(parseAhviResponse(response)).single;
    // Must NOT be forced to style_this — the recommendation path is untouched.
    expect(dir['interaction_mode'], 'recommendation');
    expect(dir.containsKey('scenario'), isFalse);
    expect(dir['board_id'], 'rec-board-1');
  });

  test('no directions of either kind → no visualDirections block', () {
    final parsed = parseAhviResponse({'success': true, 'message_text': 'hi'});
    expect(_hasVisualDirections(parsed), isFalse);
  });

  test('missing anchor_item leaves anchor id unset (contract layer retries)',
      () {
    final resp = _styleThisResponse(anchor: const {})..remove('anchor_item');
    final dir = _directionsOf(parseAhviResponse(resp)).single;
    // Still stamped as style_this, but no anchor id → modal contract fails →
    // existing retry state (asserted in the modal-level tests).
    expect(dir['scenario'], 'style_this');
    expect(dir.containsKey('anchor_item_id'), isFalse);
  });
}
