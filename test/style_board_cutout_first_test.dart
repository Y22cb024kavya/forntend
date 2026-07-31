import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/util/wardrobe_image_resolver.dart';

// Board canvases are cutout-first; the wardrobe grid stays catalog-first.
// Catalog URLs must match the catalog_*.<ext> object pattern to be treated
// as catalog images.
const _catalog = 'https://test/catalog_123.png';
const _cutout = 'https://test/cutout.png';
const _masked = 'https://test/masked.png';
const _original = 'https://test/original.jpg';

void main() {
  setUp(resetWardrobeImageDiagnosticCache);

  Map<String, dynamic> wardrobeItem({
    bool cutout = false,
    bool masked = false,
    bool catalog = false,
    bool original = false,
  }) => {
    'item_id': 'w1',
    if (cutout) 'cutout_status': 'ready',
    if (cutout) 'cutout_url': _cutout,
    if (masked) 'masked_url': _masked,
    if (catalog) 'normalized_url': _catalog,
    if (original) 'image_url': _original,
  };

  ResolvedWardrobeImage board(
    Map<String, dynamic> raw, {
    String surface = 'style_board_render',
  }) => resolveWardrobeImage(raw, surface: surface);

  test('1. board prefers validated_cutout over catalog', () {
    final r = board(wardrobeItem(cutout: true, catalog: true, original: true));
    expect(r.url, _cutout);
    expect(r.sourceKind, 'validated_cutout');
    expect(r.shouldFrame, isFalse);
  });

  test('2. board prefers masked cutout over catalog', () {
    final r = board(wardrobeItem(masked: true, catalog: true));
    expect(r.url, _masked);
    expect(r.sourceKind, anyOf('validated_cutout', 'legacy_masked_cutout'));
    expect(r.expectedTransparent, isTrue);
    expect(r.shouldFrame, isFalse);
  });

  test('3. style asset board prefers asset_cutout over original/catalog', () {
    final r = board({
      'item_id': 's1',
      'source': 'style_asset',
      'asset_cutout_url': _cutout,
      'normalized_url': _catalog,
      'image_url': _original,
    });
    expect(r.url, _cutout);
    expect(r.sourceKind, 'style_asset_cutout');
    expect(r.shouldFrame, isFalse);
  });

  test('4. wardrobe grid stays catalog-first', () {
    final r = board(
      wardrobeItem(cutout: true, catalog: true, original: true),
      surface: 'wardrobe_grid',
    );
    expect(r.sourceKind, 'catalog_fallback');
    expect(r.shouldFrame, isTrue);
  });

  test('5. transparent board source sets requires_frame=false', () {
    final r = board(wardrobeItem(cutout: true, catalog: true));
    expect(r.expectedTransparent, isTrue);
    expect(r.requiresFrame, isFalse);
  });

  test('6. opaque fallback sets requires_frame=true', () {
    final r = board(wardrobeItem(catalog: true)); // no cutout available
    expect(r.sourceKind, 'catalog_fallback');
    expect(r.expectedTransparent, isFalse);
    expect(r.requiresFrame, isTrue);
  });

  test('7. missing cutout safely falls back to catalog', () {
    final r = board(wardrobeItem(catalog: true, original: true));
    expect(r.sourceKind, 'catalog_fallback');
    expect(r.url, _catalog);
  });

  test('8. board rejects a raw-only item; grid still uses it', () {
    // Board admission guard: a raw upload (often a selfie) must not render.
    expect(board(wardrobeItem(original: true)).url, isNull);
    // Wardrobe grid is unchanged — it still shows the raw upload.
    expect(
      board(wardrobeItem(original: true), surface: 'wardrobe_grid').url,
      _original,
    );
  });

  test('9. empty/invalid urls are skipped', () {
    final r = board({
      'item_id': 'w9',
      'cutout_status': 'ready',
      'cutout_url': '',
      'normalized_url': _catalog,
    });
    expect(r.url, _catalog); // empty cutout skipped, catalog used
  });

  test('10. Style This surface uses the board (cutout-first) policy', () {
    final r = board(
      wardrobeItem(cutout: true, catalog: true),
      surface: 'style_this_request',
    );
    expect(r.url, _cutout);
    expect(r.sourceKind, 'validated_cutout');
  });

  test('11. saved-board surface retains cutout provenance', () {
    final r = board(
      wardrobeItem(cutout: true, catalog: true),
      surface: 'style_board_saved',
    );
    expect(r.sourceKind, 'validated_cutout');
    expect(r.shouldFrame, isFalse);
  });

  group('resolveWardrobeImageCandidates (fallback ordering)', () {
    test('board: ordered cutout -> catalog -> raw, first is preferred', () {
      final c = resolveWardrobeImageCandidates(
        wardrobeItem(cutout: true, catalog: true, original: true),
        surface: 'style_board_render',
      );
      expect(c.length, greaterThanOrEqualTo(2));
      expect(c.first.url, _cutout);
      expect(c.first.requiresFrame, isFalse); // transparent cutout
      // catalog fallback present and framed
      final cat = c.firstWhere((x) => x.sourceKind == 'catalog_fallback');
      expect(cat.url, _catalog);
      expect(cat.requiresFrame, isTrue);
      // strictly non-decreasing priority rank
      for (var i = 1; i < c.length; i++) {
        expect(c[i].tier, greaterThanOrEqualTo(c[i - 1].tier));
      }
    });

    test('candidates are deduped by URL', () {
      final c = resolveWardrobeImageCandidates({
        'item_id': 'dup',
        'cutout_status': 'ready',
        'cutout_url': _cutout,
        'masked_url': _cutout, // same url via another field
        'normalized_url': _catalog,
      }, surface: 'style_board_render');
      expect(c.where((x) => x.url == _cutout).length, 1);
    });

    test('same URL keeps explicit masked provenance over generic original', () {
      final c = resolveWardrobeImageCandidates({
        'item_id': 'same-url-mask',
        'masked_url': _masked,
        'image_url': _masked,
      }, surface: 'style_board_render');

      expect(c, hasLength(1));
      expect(c.single.field, 'masked_url');
      expect(c.single.sourceKind, 'legacy_masked_cutout');
      expect(c.single.expectedTransparent, isTrue);
      expect(c.single.requiresFrame, isFalse);
    });

    test('plain png original does not imply transparency (grid surface)', () {
      // On the grid, original is a valid source and must be classed opaque
      // (framed). On boards it is rejected by the admission guard instead
      // (covered in "board admission guard").
      final r = resolveWardrobeImage({
        'item_id': 'opaque-png',
        'image_url': 'https://test/product.png',
      }, surface: 'wardrobe_grid');

      expect(r.sourceKind, 'original');
      expect(r.expectedTransparent, isFalse);
      expect(r.requiresFrame, isTrue);
    });

    test('non-board surface exposes no fallback candidates', () {
      final c = resolveWardrobeImageCandidates(
        wardrobeItem(cutout: true, catalog: true),
        surface: 'wardrobe_grid',
      );
      expect(c, isEmpty);
    });

    test('single-source item yields a one-entry candidate list', () {
      final c = resolveWardrobeImageCandidates(
        wardrobeItem(catalog: true),
        surface: 'style_board_render',
      );
      expect(c, hasLength(1));
      expect(c.single.sourceKind, 'catalog_fallback');
    });
  });

  group('board admission guard (no raw/person images)', () {
    test('raw image_url rejected on boards; catalog wins', () {
      final r = board(wardrobeItem(catalog: true, original: true));
      expect(r.sourceKind, 'catalog_fallback');
      expect(r.url, _catalog);
    });

    test('raw-only item resolves to no board image', () {
      expect(board(wardrobeItem(original: true)).url, isNull);
    });

    test('board candidates never include raw/original sources', () {
      final c = resolveWardrobeImageCandidates(
        wardrobeItem(cutout: true, catalog: true, original: true),
        surface: 'style_board_render',
      );
      expect(
        c.any((x) => x.sourceKind == 'original' || x.sourceKind == 'raw'),
        isFalse,
      );
      expect(c.first.sourceKind, 'validated_cutout');
    });

    test('device fixture: raw-selfie top omitted, others render', () {
      // top = raw selfie only -> rejected (omitted, not a person photo)
      expect(
        board({'item_id': 't', 'role': 'top', 'image_url': _original}).url,
        isNull,
      );
      // jeans = catalog -> framed garment
      final jeans =
          board({'item_id': 'b', 'role': 'bottom', 'normalized_url': _catalog});
      expect(jeans.sourceKind, 'catalog_fallback');
      expect(jeans.requiresFrame, isTrue);
      // footwear = masked cutout -> frameless
      final foot = board({
        'item_id': 'f',
        'role': 'footwear',
        'masked_url': _masked,
        'image_status': 'rmbg_complete',
      });
      expect(foot.requiresFrame, isFalse);
    });

    test('wardrobe grid still allows raw (unchanged)', () {
      expect(
        board(wardrobeItem(original: true), surface: 'wardrobe_grid').url,
        _original,
      );
    });
  });
}
