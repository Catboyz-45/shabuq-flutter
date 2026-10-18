/// One closed queue from queueHistory, reduced to what the stats need.
class ClosedQueue {
  const ClosedQueue({
    required this.status,
    required this.createdAt,
    required this.completedAt,
    this.calledAt,
    this.zone = '',
  });

  final String status;
  final String zone;
  final DateTime createdAt;
  final DateTime completedAt;
  final DateTime? calledAt;
}

class ShopStats {
  const ShopStats({
    required this.todayCompleted,
    required this.todayNoShow,
    required this.todayCancelled,
    required this.averageWaitMinutes,
    required this.queuesByHour,
    this.yesterdayTotal = 0,
    this.queuesByZone = const {},
    this.days = defaultDays,
  });

  final int todayCompleted;
  final int todayNoShow;
  final int todayCancelled;

  /// Booking to being called, over the last [days] days.
  final double? averageWaitMinutes;

  /// Index = hour of day (0–23), value = queues booked in that hour over the
  /// last [days] days.
  final List<int> queuesByHour;

  /// Queues closed yesterday, to compare today against.
  final int yesterdayTotal;

  /// Queues booked per zone over the last [days] days, busiest
  /// first.
  final Map<String, int> queuesByZone;

  /// How many days, today included, the period figures cover.
  final int days;

  static const defaultDays = 7;

  /// Periods staff can switch between.
  static const periods = [7, 30];

  int get todayTotal => todayCompleted + todayNoShow + todayCancelled;
}

/// Today's outcomes plus wait, hours and zones over the last [days] days.
ShopStats computeShopStats(
  List<ClosedQueue> history,
  DateTime now, {
  int days = ShopStats.defaultDays,
}) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  final weekStart = DateTime(now.year, now.month, now.day - (days - 1));
  final startOfYesterday = DateTime(now.year, now.month, now.day - 1);
  var completed = 0, noShow = 0, cancelled = 0, yesterday = 0;
  final byHour = List<int>.filled(24, 0);
  final byZone = <String, int>{};
  final waits = <int>[];

  for (final queue in history) {
    if (!queue.completedAt.isBefore(startOfYesterday) &&
        queue.completedAt.isBefore(startOfToday)) {
      yesterday++;
    }
    if (!queue.completedAt.isBefore(startOfToday)) {
      switch (queue.status) {
        case 'completed':
          completed++;
        case 'no_show':
          noShow++;
        case 'cancelled':
          cancelled++;
      }
    }
    if (queue.createdAt.isBefore(weekStart)) continue;
    byHour[queue.createdAt.hour]++;
    if (queue.zone.isNotEmpty) {
      byZone[queue.zone] = (byZone[queue.zone] ?? 0) + 1;
    }
    final calledAt = queue.calledAt;
    if (calledAt != null && !calledAt.isBefore(queue.createdAt)) {
      waits.add(calledAt.difference(queue.createdAt).inSeconds);
    }
  }

  return ShopStats(
    todayCompleted: completed,
    todayNoShow: noShow,
    todayCancelled: cancelled,
    averageWaitMinutes:
        waits.isEmpty
            ? null
            : waits.reduce((a, b) => a + b) / waits.length / 60,
    queuesByHour: byHour,
    yesterdayTotal: yesterday,
    days: days,
    queuesByZone: Map.fromEntries(
      byZone.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    ),
  );
}
