// Source-contract tests for OfflineSyncBootstrap lifecycle and request guards.
// The production widget uses singleton services, so these focused contracts
// verify the ordering guarantees without coupling tests to network clients.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

String _methodBody(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) throw StateError('marker not found: $marker');
  final open = source.indexOf('{', start);
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  throw StateError('unbalanced braces for $marker');
}

void main() {
  final source = _read('lib/services/offline_sync_bootstrap.dart');
  final bootstrap = _methodBody(source, 'Future<void> _bootstrap() async');
  final maybeSync = _methodBody(source, 'Future<void> _maybeSync() async');
  final build = _methodBody(source, 'Widget build(BuildContext context)');

  group('OfflineSyncBootstrap lifecycle safety', () {
    test('guards disposal while getCurrentUser is pending', () {
      expect(bootstrap, contains('if (!mounted || _initStarted) return;'));
      expect(
        bootstrap,
        contains(
          RegExp(
            r'final user = await appwrite\.getCurrentUser\(\);\s*'
            r'if \(!mounted\) return;',
          ),
        ),
      );
      expect(
        bootstrap,
        contains(
          RegExp(
            r'await cache\.init\(userId: user\?\.\$id\);\s*'
            r'if \(!mounted\) return;',
          ),
        ),
      );
    });

    test('preserves logged-out startup handling', () {
      expect(bootstrap, contains('await cache.init(userId: user?.\$id)'));
      expect(maybeSync, contains('if (!mounted || user == null) return;'));
      expect(source, contains('cache.setUser(null)'));
    });

    test('schedules online recovery after navigation rebuilds', () {
      expect(build, contains('if (conn.isOnline)'));
      expect(build, contains('addPostFrameCallback((_) => _maybeSync())'));
      expect(maybeSync, contains('if (!connectivity.isOnline) return;'));
    });

    test('prevents duplicate or overlapping sync', () {
      final gate = maybeSync.indexOf('if (_syncInflight || !mounted) return;');
      final setInflight = maybeSync.indexOf('_syncInflight = true;');
      final authAwait = maybeSync.indexOf('await appwrite.getCurrentUser()');
      expect(gate, isNonNegative);
      expect(setInflight, lessThan(authAwait));
      expect(maybeSync, contains('} finally {\n      _syncInflight = false;'));
    });

    test('keeps sync errors controlled without catching the whole method', () {
      expect(maybeSync, contains('OfflineSyncBootstrap sync error:'));
      expect(maybeSync, contains('await _runSync(cache, appwrite);'));
      expect(maybeSync, isNot(contains('catch (_)')));
    });
  });
}
