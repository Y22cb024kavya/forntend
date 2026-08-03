import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/feature/chat/models/ahvi_response_block.dart';
import 'package:myapp/feature/chat/services/ahvi_block_response_parser.dart';
import 'package:myapp/services/ahvi_response_policy.dart';
import 'package:myapp/services/chat_response_renderer_registry.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';

Map<String, dynamic> _board(String id) => {
  'board_id': id,
  'title': 'A look',
  'items': [
    {'item_id': '$id-item', 'image_url': 'https://example.test/$id.png'},
  ],
};

Map<String, dynamic> _response({
  required String route,
  Map<String, dynamic>? extra,
}) => {
  'route': route,
  'board_policy': 'allow',
  'message_text': 'Backend response for $route.',
  ...?extra,
};

void main() {
  group('canonical board routing', () {
    test('advice plus style_boards stays text-only', () {
      final response = _response(
        route: 'style_advice',
        extra: {
          'board_policy': 'none',
          'style_boards': [_board('advice')],
        },
      );

      expect(
        AhviChatResponseRendererRegistry.select(response).kind,
        AhviChatRendererKind.text,
      );
      expect(styleResponseRendererKindForTesting(response), 'text');
    });

    test('pairing plus cards and outfits stays text-only', () {
      final response = _response(
        route: 'style_pairing',
        extra: {
          'cards': [_board('card')],
          'outfits': [_board('outfit')],
        },
      );

      expect(styleResponseRendererKindForTesting(response), 'text');
      expect(
        AhviChatResponseRendererRegistry.select(response).kind,
        AhviChatRendererKind.text,
      );
    });

    test('visual inspiration renders a board with recommendation controls', () {
      final response = _response(
        route: 'visual_inspiration',
        extra: {
          'style_boards': [_board('inspiration')],
        },
      );
      final policy = AhviResponsePolicy.fromResponse(response);
      final controls = policy.controlsFor(response);

      expect(
        styleResponseRendererKindForTesting(response),
        'visual_directions',
      );
      expect(controls.save, isTrue);
      expect(controls.share, isTrue);
      expect(controls.like, isTrue);
      expect(controls.dislike, isTrue);
      expect(controls.lock, isFalse);
      expect(controls.shuffle, isFalse);
      expect(controls.undo, isFalse);
    });

    test('canonical Style advice can authorize internal visual directions', () {
      final response = _response(
        route: 'style_advice',
        extra: {
          'board_policy': 'recommendation',
          'visual_directions': [_board('direction-1')],
          'cards': [_board('generic-card')],
        },
      );

      final policy = AhviResponsePolicy.fromResponse(response);
      expect(policy.canRenderBoards(response), isTrue);
      expect(
        AhviChatResponseRendererRegistry.select(response).kind,
        AhviChatRendererKind.visualDirections,
      );
      expect(policy.controlsFor(response).like, isTrue);
    });

    test('alias selection prefers complete boards and deduplicates IDs', () {
      final response = _response(
        route: 'style_advice',
        extra: {
          'board_policy': 'recommendation',
          'data': {
            'rendered_boards': [_board('incomplete')],
          },
          'style_boards': [
            _board('complete-1'),
            _board('complete-1'),
            _board('complete-2'),
          ],
        },
      );

      final collection = AhviResponsePolicy.fromResponse(
        response,
      ).boardCollection(response);
      expect(collection.path, 'style_boards');
      expect(collection.boards.map((board) => board['board_id']), [
        'complete-1',
        'complete-2',
      ]);
      expect(collection.dedupDroppedCount, 1);
    });

    test('wardrobe style preserves ownership-backed board policy', () {
      final response = _response(
        route: 'wardrobe_style',
        extra: {
          'source_policy': 'wardrobe',
          'style_boards': [_board('wardrobe')],
        },
      );
      final board = AhviResponsePolicy.fromResponse(
        response,
      ).boardCollection(response).boards.single;

      expect(
        styleResponseRendererKindForTesting(response),
        'visual_directions',
      );
      expect(board['source_policy'], 'wardrobe');
    });

    test('wardrobe release path keeps two valid boards over generic cards', () {
      final response = _response(
        route: 'wardrobe_style',
        extra: {
          'board_policy': 'wardrobe',
          'source_policy': 'wardrobe',
          'data': {
            'rendered_boards': [
              {..._board('wardrobe-1'), 'source_policy': 'wardrobe'},
              {..._board('wardrobe-2'), 'source_policy': 'wardrobe'},
            ],
          },
          'cards': [
            {'title': 'Generic module card one'},
            {'title': 'Generic module card two'},
          ],
        },
      );

      final collection = AhviResponsePolicy.fromResponse(
        response,
      ).boardCollection(response);

      expect(collection.rawCount, 2);
      expect(collection.boards, hasLength(2));
      expect(styleBoardCountForTesting(response), 2);
      expect(collection.path, 'data.rendered_boards');
      expect(
        collection.boards,
        everyElement(containsPair('source_policy', 'wardrobe')),
      );
      expect(styleResponseRendererKindForTesting(response), 'visual_directions');
    });

    for (final route in const [
      'missing_pieces',
      'medical_urgent',
      'diagnosis_request',
      'supportive_conversation',
    ]) {
      test('$route does not render a generic board', () {
        final response = _response(
          route: route,
          extra: {
            'style_boards': [_board(route)],
            'cards': [_board('$route-card')],
          },
        );
        final parsed = parseAhviResponse(response);

        expect(styleResponseRendererKindForTesting(response), 'text');
        expect(
          parsed.blocks.where(
            (block) =>
                block.type == AhviBlockType.visualDirections ||
                block.type == AhviBlockType.styleBoards ||
                block.type == AhviBlockType.visualBoard,
          ),
          isEmpty,
        );
      });
    }

    test(
      'backend urgent text is preserved and technical metadata is hidden',
      () {
        const urgentText = 'Please seek urgent medical care now.';
        final response = _response(
          route: 'medical_urgent',
          extra: {
            'message_text': urgentText,
            'safety_level': 'urgent',
            'conversation_signals': {'classifier': 'medical'},
          },
        );
        final policy = AhviResponsePolicy.fromResponse(response);

        expect(parseAhviResponse(response).text, urgentText);
        expect(policy.isSafetySensitive, isTrue);
        expect(policy.textPrimary, isTrue);
        expect(policy.technicalMetadataHidden, isTrue);
      },
    );

    test('Style This requires an anchor and keeps mutation controls', () {
      final response = _response(
        route: 'style_this',
        extra: {
          'anchor_locked': true,
          'anchor_item': {'item_id': 'anchor-1'},
          'style_directions': [_board('style-this')],
        },
      );
      final policy = AhviResponsePolicy.fromResponse(response);
      final controls = policy.controlsFor(response);

      expect(policy.canRenderBoards(response), isTrue);
      expect(controls.lock, isTrue);
      expect(controls.shuffle, isTrue);
      expect(controls.undo, isTrue);
      expect(controls.save, isTrue);
      expect(controls.share, isTrue);
      expect(
        styleResponseRendererKindForTesting(response),
        'visual_directions',
      );
    });

    test('Style This without an anchor cannot render directions', () {
      final response = _response(
        route: 'style_this',
        extra: {
          'style_directions': [_board('missing-anchor')],
        },
      );

      expect(
        AhviResponsePolicy.fromResponse(response).canRenderBoards(response),
        isFalse,
      );
      expect(styleResponseRendererKindForTesting(response), 'text');
    });

    test('Build Outfit exposes its mutation controls', () {
        final response = _response(
          route: 'build_outfit',
          extra: {
            'outfits': [_board('build')],
          },
        );
        final controls = AhviResponsePolicy.fromResponse(
          response,
        ).controlsFor(response);

        expect(controls.buildOutfit, isTrue);
        expect(controls.like, isFalse);
        expect(controls.dislike, isFalse);
        expect(controls.lock, isTrue);
        expect(controls.shuffle, isTrue);
        expect(controls.undo, isTrue);
        expect(
          styleResponseRendererKindForTesting(response),
          'visual_directions',
        );
      },
    );
  });

  group('typed Style action context', () {
    test('does not create a deprecated Visual Inspiration action', () {
      final context = styleActionContextFromValue(
        'Show Visual Inspiration',
        originalRequest: 'office dinner',
        occasion: 'office',
        sessionId: 'session-1',
      );

      expect(context, isNull);
      expect(
        filterDeprecatedVisibleStyleActions([
          {'label': 'Show visual inspiration'},
          {'label': 'Use my wardrobe'},
        ]),
        hasLength(1),
      );
    });

    test('Use My Wardrobe carries typed action and context', () {
      final context = styleActionContextFromValue(
        'Use My Wardrobe for office',
        sessionId: 'session-2',
        previousPairingTarget: 'navy trousers',
      );

      expect(context!.toJson(), containsPair('action', 'use_my_wardrobe'));
      expect(context.toJson(), containsPair('wardrobe_override', isTrue));
      expect(context.toJson(), containsPair('session_id', 'session-2'));
      expect(
        context.toJson(),
        containsPair('previous_pairing_target', 'navy trousers'),
      );
      expect(context.originalRequest, 'office');
    });

    test('Find Missing Pieces carries typed action and context', () {
      final context = styleActionContextFromValue(
        'Find Missing Pieces for date night',
        originalRequest: 'date night',
        occasion: 'date',
      );

      expect(context!.action, 'find_missing_pieces');
      expect(context.originalRequest, 'date night');
      expect(context.occasion, 'date');
    });

    test('Style This sends selected anchor metadata', () {
      final anchor = {'item_id': 'garment-1', 'source_policy': 'wardrobe'};
      final context = styleActionContextFromValue(
        'Style This',
        selectedAnchor: anchor,
        boardId: 'board-1',
        boardRevision: '4',
      );

      expect(context!.action, 'style_this');
      expect(context.toJson(), containsPair('selected_anchor', anchor));
      expect(context.toJson(), containsPair('anchor_item', anchor));
      expect(context.toJson(), containsPair('board_id', 'board-1'));
      expect(context.toJson(), containsPair('board_revision', '4'));
    });
  });

  group('stale response and copy safety', () {
    test('old session responses are discarded', () {
      final guard = AhviSessionGenerationGuard();
      final old = guard.capture('old');
      guard.invalidate();
      final current = guard.capture('new');

      expect(guard.accepts(old, 'old'), isFalse);
      expect(guard.accepts(current, 'new'), isTrue);
    });

    test('current-session responses remain valid', () {
      final guard = AhviSessionGenerationGuard();
      final token = guard.capture('session');

      expect(guard.accepts(token, 'session'), isTrue);
    });

    test('safe copy never contains a raw exception', () {
      expect(AhviClientCopy.requestError, isNot(contains('Exception')));
      expect(AhviClientCopy.requestError, isNot(contains(r'$err')));
      expect(AhviClientCopy.timeout, isNot(contains('http')));
    });

    test('empty response fallback is concise', () {
      expect(AhviClientCopy.emptyResponse, contains('try again'));
      expect(AhviClientCopy.emptyResponse.length, lessThan(80));
    });
  });
}
