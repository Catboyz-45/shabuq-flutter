import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/utils/shop_stats.dart';

void main() {
  final now = DateTime(2026, 5, 10, 20);

  ClosedQueue queue(
    String status,
    DateTime createdAt, {
    int waitMinutes = 0,
    bool called = true,
    String zone = '',
  }) {
    return ClosedQueue(
      status: status,
      zone: zone,
      createdAt: createdAt,
      calledAt: called ? createdAt.add(Duration(minutes: waitMinutes)) : null,
      completedAt: createdAt.add(Duration(minutes: waitMinutes + 60)),
    );
  }

  test('counts today by outcome', () {
    final stats = computeShopStats([
      queue('completed', DateTime(2026, 5, 10, 12)),
      queue('completed', DateTime(2026, 5, 10, 13)),
      queue('no_show', DateTime(2026, 5, 10, 14)),
      queue('cancelled', DateTime(2026, 5, 10, 15), called: false),
      queue('completed', DateTime(2026, 5, 9, 12)),
    ], now);

    expect(stats.todayCompleted, 2);
    expect(stats.todayNoShow, 1);
    expect(stats.todayCancelled, 1);
    expect(stats.todayTotal, 4);
  });

  test('averages the wait over the last seven days only', () {
    final stats = computeShopStats([
      queue('completed', DateTime(2026, 5, 10, 12), waitMinutes: 10),
      queue('completed', DateTime(2026, 5, 4, 12), waitMinutes: 20),
      queue('completed', DateTime(2026, 5, 3, 12), waitMinutes: 90),
      queue('cancelled', DateTime(2026, 5, 10, 12), called: false),
    ], now);

    expect(stats.averageWaitMinutes, closeTo(15, 0.001));
  });

  test('has no average without called queues', () {
    final stats = computeShopStats([
      queue('cancelled', DateTime(2026, 5, 10, 12), called: false),
    ], now);

    expect(stats.averageWaitMinutes, isNull);
  });

  test('buckets bookings by hour of day', () {
    final stats = computeShopStats([
      queue('completed', DateTime(2026, 5, 10, 18, 5)),
      queue('completed', DateTime(2026, 5, 9, 18, 50)),
      queue('completed', DateTime(2026, 5, 8, 12)),
    ], now);

    expect(stats.queuesByHour[18], 2);
    expect(stats.queuesByHour[12], 1);
    expect(stats.queuesByHour.reduce((a, b) => a + b), 3);
  });

  test('counts yesterday separately from today', () {
    final stats = computeShopStats([
      queue('completed', DateTime(2026, 5, 10, 12)),
      queue('completed', DateTime(2026, 5, 9, 12)),
      queue('no_show', DateTime(2026, 5, 9, 19)),
      queue('completed', DateTime(2026, 5, 8, 12)),
    ], now);

    expect(stats.todayTotal, 1);
    expect(stats.yesterdayTotal, 2);
  });

  test('counts zones over the last seven days, busiest first', () {
    final stats = computeShopStats([
      queue('completed', DateTime(2026, 5, 10, 12), zone: 'ระเบียง'),
      queue('completed', DateTime(2026, 5, 10, 13), zone: 'ในร้าน'),
      queue('completed', DateTime(2026, 5, 9, 13), zone: 'ในร้าน'),
      queue('completed', DateTime(2026, 5, 1, 13), zone: 'ระเบียง'),
    ], now);

    expect(stats.queuesByZone, {'ในร้าน': 2, 'ระเบียง': 1});
    expect(stats.queuesByZone.keys.first, 'ในร้าน');
  });
}
