import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_localizations.dart';
import 'package:myapp/feature/chat/widgets/blocks/visual_directions/ahvi_outfit_board_card.dart';
import 'package:myapp/feature/chat/widgets/blocks/visual_directions/visual_direction_carousel.dart';
import 'package:myapp/style_board/editorial_board_renderer.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/wardrobe.dart';
import 'package:myapp/widgets/ahvi_item_detail_modal.dart';
import 'package:myapp/widgets/style_boards.dart';

const _accent = AccentPalette(
  primary: Color(0xFFFF8EC7),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

final _anchor = WardrobeItem(
  id: 'wardrobe-anchor-42',
  name: 'Black Blazer',
  cat: 'outerwear',
  occasions: const ['work'],
  raw: const {r'$id': 'wardrobe-anchor-42', 'board_status': 'ready'},
);

Map<String, dynamic> _boardItem(
  String id,
  String role, {
  bool locked = false,
}) => {
  'item_id': id,
  'name': id,
  'category': role,
  'role': role,
  'slot': role,
  'source': 'wardrobe',
  'locked': locked,
  'image_url': 'https://example.test/$id.png',
  'masked_url': 'https://example.test/$id-cutout.png',
  'position': {
    'x': role == 'top' ? .08 : .46,
    'y': role == 'footwear' ? .62 : .12,
    'width': .3,
    'height': .3,
    'rotation': 0,
    'z': 1,
  },
};

Map<String, dynamic> _successfulResponse() => {
  'success': true,
  'visual_directions': [
    {
      'board_id': 'style-board-stable-1',
      'revision': 1,
      'source_policy': 'wardrobe',
      'scenario': 'style_this',
      'direction_name': 'Sharp Layers',
      'title': 'Sharp Layers',
      'occasion': 'work',
      'board_items': [
        _boardItem(_anchor.id, 'top'),
        _boardItem('wardrobe-bottom-7', 'bottom', locked: true),
        _boardItem('wardrobe-shoe-9', 'footwear', locked: true),
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Style This sends canonical backend request and renders canonical board',
    (tester) async {
      String? itemId;
      String? scenario;
      Map<String, dynamic>? anchorItem;
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      try {
        await _pumpItemDetail(
          tester,
          styleCall:
              ({
                required requestedItemId,
                required requestedScenario,
                requestAnchorItem,
                occasion,
              }) async {
                itemId = requestedItemId;
                scenario = requestedScenario;
                anchorItem = requestAnchorItem;
                return _successfulResponse();
              },
        );
        debugPrint = (message, {wrapWidth}) {
          if (message != null) logs.add(message);
        };

        await tester.tap(find.text('Style'));
        await tester.pumpAndSettle();

        expect(itemId, _anchor.id);
        expect(scenario, 'style_this');
        expect(anchorItem?['item_id'], _anchor.id);
        expect(anchorItem?['interaction_mode'], 'style_this');
        expect(anchorItem?['source_policy'], 'wardrobe');
        expect(anchorItem?['locked'], isTrue);
        expect(anchorItem?['anchor'], isTrue);
        expect(anchorItem?['resolved_image_field'], isNotNull);
        expect(find.byType(StyleBoardsScreen), findsNothing);
        expect(find.byType(VisualDirectionCarousel), findsOneWidget);
        expect(find.byType(AhviOutfitBoardCard), findsOneWidget);
        expect(find.byType(EditorialBoardCanvas), findsOneWidget);
        expect(find.text('STYLE THIS'), findsOneWidget);
        expect(find.text('1 of 3 items locked'), findsOneWidget);
        expect(
          logs,
          contains(
            contains(
              'AHVI_STYLE_THIS_REQUEST anchor_item_id=${_anchor.id} '
              'scenario=style_this source_policy=wardrobe',
            ),
          ),
        );
        final anchorLog = logs.singleWhere(
          (line) => line.startsWith('AHVI_STYLE_THIS_ANCHOR'),
        );
        expect(anchorLog, contains('anchor_present=true'));
        expect(anchorLog, contains('initial_locked_ids=${_anchor.id}'));
        expect(anchorLog, contains('supporting_locked_count=0'));
      } finally {
        debugPrint = originalDebugPrint;
      }
    },
  );

  testWidgets('failed Style This response keeps detail open with retry', (
    tester,
  ) async {
    var calls = 0;
    await _pumpItemDetail(
      tester,
      styleCall:
          ({
            required requestedItemId,
            required requestedScenario,
            requestAnchorItem,
            occasion,
          }) async {
            calls++;
            return {'success': true, 'visual_directions': const []};
          },
    );

    await tester.tap(find.text('Style'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Black Blazer'), findsOneWidget);
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(StyleBoardsScreen), findsNothing);
    expect(find.byType(VisualDirectionCarousel), findsNothing);
    expect(find.byType(AhviOutfitBoardCard), findsNothing);
  });

  testWidgets('recommendation mode remains feedback-only', (tester) async {
    final direction = Map<String, dynamic>.from(
      (_successfulResponse()['visual_directions'] as List).single as Map,
    )..remove('scenario');
    direction['interaction_mode'] = 'recommendation';

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_TestLocalizationsDelegate()],
        supportedLocales: const [Locale('en')],
        theme: ThemeData(
          useMaterial3: true,
          extensions: [AppThemeTokens.light(_accent)],
        ),
        home: Scaffold(
          body: AhviOutfitBoardCard(direction: direction, width: 390),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AHVI EDIT'), findsOneWidget);
    expect(find.text('Like'), findsOneWidget);
    expect(find.text('Dislike'), findsOneWidget);
    expect(find.byType(BoardMutationBar), findsNothing);
  });
}

typedef _TestStyleCall =
    Future<Map<String, dynamic>?> Function({
      required String requestedItemId,
      required String requestedScenario,
      Map<String, dynamic>? requestAnchorItem,
      String? occasion,
    });

Future<void> _pumpItemDetail(
  WidgetTester tester, {
  required _TestStyleCall styleCall,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [_TestLocalizationsDelegate()],
      supportedLocales: const [Locale('en')],
      theme: ThemeData(
        useMaterial3: true,
        extensions: [AppThemeTokens.light(_accent)],
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showItemDetailModal(
              context,
              item: _anchor,
              allItems: [_anchor],
              styleWardrobeItemCall:
                  ({
                    required itemId,
                    required scenario,
                    anchorItem,
                    occasion,
                  }) => styleCall(
                    requestedItemId: itemId,
                    requestedScenario: scenario,
                    requestAnchorItem: anchorItem,
                    occasion: occasion,
                  ),
            ),
            child: const Text('Open item'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open item'));
  await tester.pumpAndSettle();
}

class _TestLocalizations extends AppLocalizations {
  _TestLocalizations() : super(const Locale('en'));

  @override
  String translate(String key) =>
      const {
        'item_detail_style_this': 'Style',
        'item_detail_build_outfit': 'Build',
        'item_detail_wore_today': 'Wore',
        'common_edit': 'Edit',
        'item_detail_never_worn': 'Never worn',
        'item_detail_style_directions': 'Style Directions',
      }[key] ??
      'Label';
}

class _TestLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _TestLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(_TestLocalizations());

  @override
  bool shouldReload(_TestLocalizationsDelegate old) => false;
}
