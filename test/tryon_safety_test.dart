// Tests for the DailyWear Try On defensive parsing that fixes the crash
// "type 'Null' is not a subtype of type 'String' in type cast".
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/tryon_safety.dart';

void main() {
  group('nullableText', () {
    test('null -> null (null selected garment image / id)', () {
      expect(nullableText(null), isNull);
    });
    test('empty / whitespace -> null (empty response url)', () {
      expect(nullableText(''), isNull);
      expect(nullableText('   '), isNull);
    });
    test('trims and keeps real values', () {
      expect(nullableText('  abc  '), 'abc');
      expect(nullableText(123), '123');
    });
  });

  group('resolveTryOnOutfitId', () {
    test('null id and outfit without id -> null, never throws (the crash)', () {
      // Reproduces the old `_currentOutfit['id'] as String` on a null id.
      expect(resolveTryOnOutfitId(null, <String, dynamic>{}), isNull);
      expect(resolveTryOnOutfitId(null, {'name': 'Look'}), isNull);
    });
    test('explicit id wins', () {
      expect(resolveTryOnOutfitId('exp1', {'id': 'other'}), 'exp1');
    });
    test('falls back to current outfit id', () {
      expect(resolveTryOnOutfitId(null, {'id': 'o9'}), 'o9');
    });
    test('blank explicit id falls through to outfit id', () {
      expect(resolveTryOnOutfitId('  ', {'id': 'o9'}), 'o9');
    });
  });

  group('safeImageUrl', () {
    test('null / empty response url -> null', () {
      expect(safeImageUrl(null), isNull);
      expect(safeImageUrl(''), isNull);
    });
    test('non-http value rejected (no fake/placeholder)', () {
      expect(safeImageUrl('not a url'), isNull);
      expect(safeImageUrl('ftp://x/y.png'), isNull);
    });
    test('valid http(s) url accepted -> opens result normally', () {
      expect(safeImageUrl('https://cdn.example.com/tryon/abc.png'),
          'https://cdn.example.com/tryon/abc.png');
      expect(safeImageUrl('  http://x/y.jpg  '), 'http://x/y.jpg');
    });
  });

  group('Try On validation decision (block reason)', () {
    // The screen blocks + shows a safe SnackBar when there is nothing to try
    // on: no explicit id AND an empty current outfit.
    bool blocks(String? id, Map<String, dynamic> outfit) =>
        resolveTryOnOutfitId(id, outfit) == null && outfit.isEmpty;

    test('missing garment id with empty outfit -> blocked (safe message)', () {
      expect(blocks(null, <String, dynamic>{}), isTrue);
    });
    test('valid outfit -> proceeds', () {
      expect(blocks(null, {'id': 'o1', 'img': 'x'}), isFalse);
    });
    test('explicit id -> proceeds even with empty current outfit', () {
      expect(blocks('o1', <String, dynamic>{}), isFalse);
    });
  });
}
