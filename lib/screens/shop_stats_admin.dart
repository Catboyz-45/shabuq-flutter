import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../utils/shop_stats.dart';

/// Today's outcomes, average wait and busy hours for one shop, computed from
/// its queueHistory.
class ShopStatsAdmin extends StatefulWidget {
  const ShopStatsAdmin({
    super.key,
    required this.adminService,
    required this.shopId,
  });

  final AdminService adminService;
  final String shopId;

  @override
  State<ShopStatsAdmin> createState() => _ShopStatsAdminState();
}

class _ShopStatsAdminState extends State<ShopStatsAdmin> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _history;

  @override
  void initState() {
    super.initState();
    _history = widget.adminService.watchShopQueueHistory(widget.shopId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _history,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('โหลดสถิติไม่สำเร็จ'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final history = [
          for (final document in snapshot.data!.docs)
            if (_toClosedQueue(document.data()) case final queue?) queue,
        ];
        final stats = computeShopStats(history, DateTime.now());
        final wait = stats.averageWaitMinutes;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('วันนี้', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _StatTile(label: 'คิวทั้งหมด', value: '${stats.todayTotal}'),
                _StatTile(
                  label: 'ใช้บริการแล้ว',
                  value: '${stats.todayCompleted}',
                ),
                _StatTile(label: 'ไม่มาตามคิว', value: '${stats.todayNoShow}'),
                _StatTile(label: 'ยกเลิก', value: '${stats.todayCancelled}'),
              ],
            ),
            const SizedBox(height: 16),
            _StatTile(
              label:
                  'เวลารอเฉลี่ย ${ShopStats.days} วันล่าสุด (รับคิว → เรียก)',
              value: wait == null ? '-' : '${wait.round()} นาที',
            ),
            const SizedBox(height: 24),
            Text(
              'ช่วงเวลาที่คนรับคิว (${ShopStats.days} วันล่าสุด)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _HourlyChart(counts: stats.queuesByHour),
          ],
        );
      },
    );
  }

  static ClosedQueue? _toClosedQueue(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final completedAt = data['completedAt'];
    if (createdAt is! Timestamp || completedAt is! Timestamp) return null;
    final calledAt = data['calledAt'];
    return ClosedQueue(
      status: data['status'] as String? ?? 'completed',
      createdAt: createdAt.toDate(),
      completedAt: completedAt.toDate(),
      calledAt: calledAt is Timestamp ? calledAt.toDate() : null,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Bar per hour between the first and last hour that had any bookings.
class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final busyHours = [
      for (var hour = 0; hour < counts.length; hour++)
        if (counts[hour] > 0) hour,
    ];
    if (busyHours.isEmpty) {
      return const Text('ยังไม่มีข้อมูล');
    }
    final first = busyHours.first;
    final last = busyHours.last;
    final peak = counts.reduce((a, b) => a > b ? a : b);
    final color = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var hour = first; hour <= last; hour++)
            Expanded(
              child: Tooltip(
                message: '$hour:00 น. • ${counts[hour]} คิว',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (counts[hour] > 0)
                      Text(
                        '${counts[hour]}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 120 * counts[hour] / peak,
                      decoration: BoxDecoration(
                        color:
                            counts[hour] == peak
                                ? color
                                : color.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$hour',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
