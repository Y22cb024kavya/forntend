import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/ahvi_style_diagnostics.dart';

Map<String, dynamic> _board(String id) => {
  'board_id': id,
  'revision': 1,
  'source_policy': 'wardrobe',
  'interaction_mode': 'style_this',
  'board_items': [
    {'item_id': '$id-item', 'image_url': 'https://private.test/$id.png'},
  ],
};

void main() {
  test('response alias counts cover every board source', () {
    final response = {
      'rendered_boards': [_board('top')],
      'style_boards': [_board('style-1'), _board('style-2')],
      'outfits': [_board('outfit')],
      'cards': [_board('card')],
      'visual_directions': [_board('direction')],
      'style_directions': [_board('style-direction')],
      'data': {
        'rendered_boards': [_board('nested-rendered')],
        'outfits': [_board('nested-outfit')],
        'visual_directions': [_board('nested-direction')],
        'style_directions': [_board('nested-style-direction')],
      },
    };

    expect(
      AhviStyleDiagnostics.responseAliasCounts(response),
      containsPair('data.rendered_boards', 1),
    );
    expect(
      AhviStyleDiagnostics.responseAliasCounts(response),
      containsPair('style_boards', 2),
    );
    expect(
      AhviStyleDiagnostics.responseAliasCounts(response),
      containsPair('data.style_directions', 1),
    );
  });

  test('masked identifiers are stable and redact raw values', () {
    const raw = 'private-board-42';
    final masked = AhviStyleDiagnostics.maskIdentifier(raw);

    expect(masked, isNot(contains(raw)));
    expect(masked, AhviStyleDiagnostics.maskIdentifier(raw));
    expect(masked, startsWith('id-'));
  });

  test(
    'invalid Style This directions are counted without changing validation',
    () {
      final directions = [_board('valid'), _board('invalid')]
        ..last['source_policy'] = 'style_asset';

      expect(
        AhviStyleDiagnostics.invalidStyleThisDirectionCount(directions),
        1,
      );
    },
  );

  test('response diagnostic is count-only and excludes sensitive values', () {
    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    try {
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };
      AhviStyleDiagnostics.logResponse(
        correlationId: 'style-1',
        response: {
          'route': 'visual_inspiration',
          'message_text': 'private full response body',
          'style_boards': [_board('private-board-42')],
        },
        selectedAlias: 'style_boards',
        selectedRawCount: 1,
        parserInputCount: 1,
        parserAcceptedCount: 1,
        policyRejectedCount: 0,
        invalidContractCount: 0,
        dedupDroppedCount: 0,
        finalRenderedCount: 1,
        staleResponseDiscardedCount: 0,
        boardIds: AhviStyleDiagnostics.maskedIdentifiers([
          _board('private-board-42'),
        ]),
      );
    } finally {
      debugPrint = originalDebugPrint;
    }

    expect(logs, hasLength(1));
    expect(logs.single, startsWith('AHVI_STYLE_RESPONSE_COUNTS'));
    expect(logs.single, contains('alias_style_boards=1'));
    expect(logs.single, isNot(contains('private full response body')));
    expect(logs.single, isNot(contains('private-board-42')));
    expect(logs.single, isNot(contains('private.test')));
  });
}
