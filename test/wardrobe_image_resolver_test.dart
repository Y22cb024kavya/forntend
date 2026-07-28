import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/style_board/board_models.dart';
import 'package:myapp/style_board/board_renderer.dart';
import 'package:myapp/style_board/saved_board_images.dart';
import 'package:myapp/util/wardrobe_image_resolver.dart';

void main() {
  setUp(resetWardrobeImageDiagnosticCache);

  test('validated board and cutout fields win over every fallback', () {
    final board = resolveWardrobeImage({
      'item_id': 'item-1',
      'board_status': 'cutout_ready',
      'board_image_url': 'https://test/board.png',
      'cutout_status': 'ready',
      'cutout_url': 'https://test/cutout.png',
      'masked_url': 'https://test/masked.png',
      'normalized_url': 'https://test/catalog.png',
      'image_url': 'https://test/original.jpg',
    });

    expect(board.url, 'https://test/board.png');
    expect(board.sourceKind, 'validated_cutout');
    expect(board.validated, isTrue);
    expect(board.shouldFrame, isFalse);
  });

  test('masked and processed images beat catalogue and original fallbacks', () {
    final masked = resolveWardrobeImage({
      'masked_url': 'https://test/masked.png',
      'transparent_image_url': 'https://test/processed.png',
      'normalized_url': 'https://test/catalog.png',
      'image_url': 'https://test/original.jpg',
    });
    final processed = resolveWardrobeImage({
      'transparent_image_url': 'https://test/processed.png',
      'normalized_url': 'https://test/catalog.png',
      'image_url': 'https://test/original.jpg',
    });

    expect(masked.url, 'https://test/masked.png');
    expect(masked.sourceKind, 'masked');
    expect(processed.url, 'https://test/processed.png');
    expect(processed.sourceKind, 'processed_cutout');
  });

  test('shared style asset provenance validates its board cutout', () {
    final result = resolveWardrobeImage({
      'source': 'style_asset',
      'board_image_url': 'https://test/shared-cutout.png',
      'normalized_url': 'https://test/catalog.png',
    });

    expect(result.sourceKind, 'validated_cutout');
    expect(result.shouldFrame, isFalse);
  });

  test('masked URL equal to original is demoted and framed', () {
    final result = resolveWardrobeImage({
      'masked_url': 'https://test/original.jpg',
      'image_url': 'https://test/original.jpg',
    });

    expect(result.sourceKind, 'original');
    expect(result.shouldFrame, isTrue);
    expect(result.expectedTransparent, isFalse);
  });

  test('catalogue object in masked URL is a framed fallback', () {
    final result = resolveWardrobeImage({
      'masked_url':
          'https://storage.test/buckets/wardrobe/files/catalog_item-1.png/view?project=test',
    });

    expect(result.field, 'masked_url');
    expect(result.sourceKind, 'catalog_fallback');
    expect(result.expectedTransparent, isFalse);
    expect(result.shouldFrame, isTrue);
  });

  test('wardrobe object in masked URL remains a cutout', () {
    final result = resolveWardrobeImage({
      'masked_url': 'https://storage.test/files/wardrobe_item-1.png',
    });

    expect(result.sourceKind, 'masked');
    expect(result.expectedTransparent, isTrue);
    expect(result.shouldFrame, isFalse);
  });

  test('versioned wardrobe cutout remains a cutout', () {
    final result = resolveWardrobeImage({
      'maskedUrl':
          'https://storage.test/files/wardrobe_item-1_cutout_v12.png/view',
    });

    expect(result.sourceKind, 'masked');
    expect(result.expectedTransparent, isTrue);
    expect(result.shouldFrame, isFalse);
  });

  test('normalized catalogue URL remains a framed fallback', () {
    final result = resolveWardrobeImage({
      'normalized_url': 'https://storage.test/files/catalog_item-1.jpg',
    });

    expect(result.sourceKind, 'catalog_fallback');
    expect(result.expectedTransparent, isFalse);
    expect(result.shouldFrame, isTrue);
  });

  test('unvalidated catalogue fallback is retained as a framed tile', () {
    final data = boardDataFromMap({
      'items': [
        {
          'item_id': 'anchor-1',
          'name': 'Anchored shirt',
          'category': 'Tops',
          'normalized_url': 'https://test/catalog.png',
        },
      ],
    });

    expect(data.items, hasLength(1));
    expect(data.items.single.imageUrl, 'https://test/catalog.png');
    expect(data.items.single.shouldFrame, isTrue);
  });

  test('StyleBoardItem canonicalizes rendering to the validated cutout', () {
    final item = StyleBoardItem.fromJson({
      'item_id': 'item-2',
      'name': 'Shirt',
      'slot': 'top',
      'board_status': 'cutout_ready',
      'board_image_url': 'https://test/board.png',
      'image_url': 'https://test/original.jpg',
    });

    expect(item.imageUrl, 'https://test/board.png');
    expect(item.shouldFrame, isFalse);
    expect(item.toContractJson(), isNot(contains('_image_should_frame')));
  });

  test('saved-board extraction uses the shared cutout-first policy', () {
    final urls = extractSavedBoardImages({
      'items': [
        {
          'item_id': 'item-3',
          'cutout_status': 'ready',
          'cutout_url': 'https://test/cutout.png',
          'normalized_url': 'https://test/catalog.png',
        },
      ],
    });

    expect(urls, ['https://test/cutout.png']);
  });

  test('diagnostic contains metadata but never image URLs', () {
    final messages = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    try {
      resolveWardrobeImage({
        'item_id': 'item-4',
        'masked_url': 'https://secret.test/private-cutout.png?token=secret',
      }, surface: 'wardrobe_grid');
    } finally {
      debugPrint = previous;
    }

    expect(messages.single, contains('AHVI_WARDROBE_IMAGE_RESOLVE'));
    expect(messages.single, contains('item_id=item-4'));
    expect(messages.single, contains('surface=wardrobe_grid'));
    expect(messages.single, contains('selected_field=masked_url'));
    expect(messages.single, isNot(contains('secret.test')));
    expect(messages.single, isNot(contains('token=')));
  });
}
