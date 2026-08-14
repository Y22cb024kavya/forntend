import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/calendar.dart';
import 'package:myapp/models/calendar_event_record.dart';

void main() {
  test('consecutive saves queue one follow-up refresh', () async {
    final firstRefresh = Completer<void>();
    var refreshCount = 0;
    var visibleEvents = <String>[];
    final coordinator = CalendarRefreshCoordinator(() async {
      refreshCount++;
      visibleEvents = refreshCount == 1 ? ['Dentist'] : ['Dentist', 'Dinner'];
      if (refreshCount == 1) await firstRefresh.future;
    });

    final eventARefresh = coordinator.request();
    final eventBRefresh = coordinator.request();

    expect(coordinator.isActive, isTrue);
    expect(refreshCount, 1);

    firstRefresh.complete();
    await Future.wait<void>([eventARefresh, eventBRefresh]);

    expect(refreshCount, 2);
    expect(visibleEvents, ['Dentist', 'Dinner']);
    expect(coordinator.isActive, isFalse);
  });

  test(
    'three refresh requests while busy coalesce into one follow-up',
    () async {
      final firstRefresh = Completer<void>();
      var refreshCount = 0;
      final coordinator = CalendarRefreshCoordinator(() async {
        refreshCount++;
        if (refreshCount == 1) await firstRefresh.future;
      });

      final requests = <Future<void>>[coordinator.request()];
      requests.add(coordinator.request());
      requests.add(coordinator.request());
      requests.add(coordinator.request());

      firstRefresh.complete();
      await Future.wait<void>(requests);

      expect(refreshCount, 2);
    },
  );

  test('refresh failure preserves existing plans', () {
    var plans = <String>['Dentist', 'Dinner'];
    final failed = const CalendarEventsLoadResult.failure();

    void apply(CalendarEventsLoadResult result) {
      if (result.succeeded) {
        plans = result.events.map((event) => event['title'] as String).toList();
      }
    }

    apply(failed);

    expect(plans, ['Dentist', 'Dinner']);
  });

  test('successful empty refresh is distinct from failure', () {
    var plans = <String>['Dentist', 'Dinner'];
    final empty = const CalendarEventsLoadResult(
      events: <Map<String, dynamic>>[],
      succeeded: true,
    );

    if (empty.succeeded) {
      plans = empty.events.map((event) => event['title'] as String).toList();
    }

    expect(plans, isEmpty);
  });

  test('same-title different-time events remain separate records', () {
    final batch = CalendarEventBatch.parse([
      {
        'id': 'meeting-10',
        'title': 'Meeting',
        'start_time': '2026-08-14T10:00:00+05:30',
      },
      {
        'id': 'meeting-15',
        'title': 'Meeting',
        'start_time': '2026-08-14T15:00:00+05:30',
      },
    ]);

    expect(batch.events, hasLength(2));
    expect(batch.events.map((event) => event['id']), [
      'meeting-10',
      'meeting-15',
    ]);
  });

  test('refresh errors do not prevent a queued follow-up refresh', () async {
    final firstRefresh = Completer<void>();
    var refreshCount = 0;
    final coordinator = CalendarRefreshCoordinator(() async {
      refreshCount++;
      if (refreshCount == 1) {
        firstRefresh.complete();
        throw StateError('transient refresh failure');
      }
    });

    final firstRequest = coordinator.request();
    final followUpRequest = coordinator.request();
    await Future.wait<void>([firstRequest, followUpRequest]);

    expect(refreshCount, 2);
  });
}
