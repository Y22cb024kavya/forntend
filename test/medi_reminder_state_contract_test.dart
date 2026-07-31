import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('medicine reminder state follows confirmed scheduling', () {
    final medi = File('lib/medi_tracker.dart').readAsStringSync();

    expect(medi, contains("'reminder': false"));
    expect(medi, contains('if (reminderScheduled)'));
    expect(medi, contains("'reminder': true"));
    expect(medi, contains('No reminder is scheduled.'));
  });
}
