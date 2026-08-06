import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/wardrobe.dart';

WardrobeItem _item(String id, {String? catalogStatus}) => WardrobeItem(
      id: id,
      name: 'Item $id',
      cat: 'Tops',
      occasions: const [],
      // A null value reads back as '' -> treated as pending, same as absent.
      raw: {'catalog_status': catalogStatus},
    );

void main() {
  group('WardrobeCatalogRefresh.isResolved', () {
    test('pending or absent status is not resolved', () {
      expect(WardrobeCatalogRefresh.isResolved({}), isFalse);
      expect(
        WardrobeCatalogRefresh.isResolved({'catalog_status': ''}),
        isFalse,
      );
      expect(
        WardrobeCatalogRefresh.isResolved({'catalog_status': 'catalog_pending'}),
        isFalse,
      );
    });

    test('terminal statuses are resolved', () {
      for (final s in ['catalog_generated', 'catalog_ready', 'catalog_failed']) {
        expect(
          WardrobeCatalogRefresh.isResolved({'catalog_status': s}),
          isTrue,
          reason: s,
        );
      }
    });

    test('reads camelCase catalogStatus too', () {
      expect(
        WardrobeCatalogRefresh.isResolved({'catalogStatus': 'catalog_generated'}),
        isTrue,
      );
    });
  });

  group('WardrobeCatalogRefresh.resolvedIds', () {
    test('returns only ids whose item has a terminal status', () {
      final items = [
        _item('a', catalogStatus: 'catalog_generated'), // done
        _item('b', catalogStatus: 'catalog_pending'), // still pending
        _item('c'), // no status -> pending
        _item('d', catalogStatus: 'catalog_failed'), // controlled stop
      ];
      final resolved = WardrobeCatalogRefresh.resolvedIds(
        items,
        {'a', 'b', 'c', 'd'},
      );
      expect(resolved, {'a', 'd'});
    });

    test('an id with no matching item is not reported resolved', () {
      // Removed item: caller drops it via the "no longer present" pass; it must
      // not be counted as resolved here.
      final items = [_item('a', catalogStatus: 'catalog_generated')];
      final resolved = WardrobeCatalogRefresh.resolvedIds(items, {'a', 'gone'});
      expect(resolved, {'a'});
      expect(resolved.contains('gone'), isFalse);
    });

    test('all pending -> empty resolved set (a retry is warranted)', () {
      final items = [
        _item('a', catalogStatus: 'catalog_pending'),
        _item('b'),
      ];
      expect(
        WardrobeCatalogRefresh.resolvedIds(items, {'a', 'b'}),
        isEmpty,
      );
    });
  });
}
