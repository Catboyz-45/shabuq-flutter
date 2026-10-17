/// One closed queue from queueHistory, reduced to what the stats need.
class ClosedQueue {
  const ClosedQueue({
    required this.status,
    required this.createdAt,
    required this.completedAt,
    this.calledAt,
  });

  final String status;
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
  });

  final int todayCompleted;
  final int todayNoShow;
  final int todayCancelled;

  /// Booking to being called, over the last [ShopStats.days] days.
  final double? averageWaitMinutes;

  /// Index = hour of day (0–23), value = queues booked in that hour over the
  /// last [ShopStats.days] days.
  final List<int> queuesByHour;

  static const days = 7;

  int get todayTotal => todayCompleted + todayNoShow + todayCancelled;
}

ShopStats computeShopStats(List<ClosedQueue> history, DateTime now) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  final weekStart = startOfToday.subtract(
    const Duration(days: ShopStats.days - 1),
  );
  var completed = 0, noShow = 0, cancelled = 0;
  final byHour = List<int>.filled(24, 0);
  final waits = <int>[];

  for (final queue in history) {
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
  );
}
