import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../theme/app_theme.dart';
import '../utils/shop_stats.dart';
import '../widgets/motion.dart';

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
  int _days = ShopStats.defaultDays;

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
        final stats = computeShopStats(history, DateTime.now(), days: _days);
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final chart = _Panel(
              title: 'คิวแต่ละชั่วโมง (${stats.days} วันล่าสุด)',
              trailing: _peakLabel(stats.queuesByHour),
              fill: wide,
              child:
                  wide
                      ? _HourlyChart(counts: stats.queuesByHour)
                      : SizedBox(
                        height: 220,
                        child: _HourlyChart(counts: stats.queuesByHour),
                      ),
            );
            final side = [
              _WaitCard(minutes: stats.averageWaitMinutes, days: stats.days),
              const SizedBox(height: 14),
              _ZonePanel(counts: stats.queuesByZone),
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'สถิติร้าน',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'ตัวเลขวันนี้ และย้อนหลัง ${stats.days} วัน',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        for (final days in ShopStats.periods)
                          ButtonSegment(value: days, label: Text('$days วัน')),
                      ],
                      selected: {_days},
                      onSelectionChanged:
                          (selection) =>
                              setState(() => _days = selection.first),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Metrics(stats: stats, columns: wide ? 4 : 2),
                const SizedBox(height: 14),
                if (wide)
                  SizedBox(
                    height: 380,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: chart),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(children: side),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  chart,
                  const SizedBox(height: 14),
                  ...side,
                ],
              ],
            );
          },
        );
      },
    );
  }

  static String? _peakLabel(List<int> counts) {
    final peak = counts.fold(0, max);
    if (peak == 0) return null;
    final hours = [
      for (var hour = 0; hour < counts.length; hour++)
        if (counts[hour] == peak) hour,
    ];
    return 'คนเยอะสุด ${hours.map((hour) => '$hour:00').join(', ')}';
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
      zone: data['zone'] as String? ?? '',
    );
  }
}

String _percent(int part, int total) =>
    total == 0 ? '-' : '${(part * 100 / total).round()}%';

class _Metrics extends StatelessWidget {
  const _Metrics({required this.stats, required this.columns});

  final ShopStats stats;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = stats.todayTotal;
    final change = total - stats.yesterdayTotal;
    final tiles = [
      _Metric(
        label: 'คิววันนี้',
        value: total,
        note:
            change == 0
                ? 'เท่ากับเมื่อวาน'
                : change > 0
                ? 'มากกว่าเมื่อวาน $change คิว'
                : 'น้อยกว่าเมื่อวาน ${-change} คิว',
        noteColor: change > 0 ? scheme.tertiary : scheme.onSurfaceVariant,
      ),
      _Metric(
        label: 'ได้ทาน',
        value: stats.todayCompleted,
        color: scheme.tertiary,
        note: '${_percent(stats.todayCompleted, total)} ของคิววันนี้',
      ),
      _Metric(
        label: 'ไม่มาตามคิว',
        value: stats.todayNoShow,
        color: scheme.error,
        note: '${_percent(stats.todayNoShow, total)} ของคิววันนี้',
      ),
      _Metric(
        label: 'ยกเลิก',
        value: stats.todayCancelled,
        color: scheme.primary,
        note: '${_percent(stats.todayCancelled, total)} ของคิววันนี้',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (index, tile) in tiles.indexed)
              SizedBox(
                width: width,
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 60 * index),
                  child: tile,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.note,
    this.color,
    this.noteColor,
  });

  final String label;
  final int value;
  final String note;
  final Color? color;
  final Color? noteColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Motion.ease,
            builder:
                (context, shown, _) => Text(
                  '${shown.round()}',
                  style: AppFonts.numbers(
                    fontSize: 42,
                    color: color ?? scheme.onSurface,
                    height: 1.15,
                  ),
                ),
          ),
          Text(
            note,
            style: TextStyle(
              fontSize: 13,
              color: noteColor ?? scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.trailing,
    this.fill = false,
  });

  final String title;
  final String? trailing;
  final Widget child;

  /// Stretch [child] to the panel's height (inside a fixed-height row).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (fill) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _WaitCard extends StatelessWidget {
  const _WaitCard({required this.minutes, required this.days});

  final double? minutes;
  final int days;

  @override
  Widget build(BuildContext context) {
    final minutes = this.minutes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.yolk,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Palette.ink),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ลูกค้ารอเฉลี่ย',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: minutes == null ? '-' : '${minutes.round()}',
                    style: AppFonts.numbers(fontSize: 52, color: Palette.ink),
                  ),
                  const TextSpan(
                    text: ' นาที',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Text(
              'จากรับคิวถึงร้านเรียก • $days วันล่าสุด',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZonePanel extends StatelessWidget {
  const _ZonePanel({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = counts.values.fold(0, (a, b) => a + b);
    return _Panel(
      title: 'แยกตามโซน',
      child:
          counts.isEmpty
              ? Text(
                'ยังไม่มีข้อมูล',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
              : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, entry) in counts.entries.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(entry.key)),
                              Text(
                                '${entry.value}',
                                style: AppFonts.numbers(fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: entry.value / total),
                              duration: Duration(
                                milliseconds: 800 + 80 * index,
                              ),
                              curve: Motion.ease,
                              builder:
                                  (context, value, _) =>
                                      LinearProgressIndicator(
                                        value: value,
                                        minHeight: 10,
                                        color: scheme.onSurface,
                                        backgroundColor:
                                            scheme.surfaceContainerHigh,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }
}

/// Bar per hour between the first and last hour that had any bookings. Bars
/// grow in one after another; the busiest hours are yellow.
class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busyHours = [
      for (var hour = 0; hour < counts.length; hour++)
        if (counts[hour] > 0) hour,
    ];
    if (busyHours.isEmpty) {
      return Text(
        'ยังไม่มีข้อมูล',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }
    final first = busyHours.first;
    final last = busyHours.last;
    final peak = counts.fold(0, max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var hour = first; hour <= last; hour++)
          Expanded(
            child: Tooltip(
              message: '$hour:00 น. • ${counts[hour]} คิว',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isPeak = counts[hour] == peak;
                    final barSpace = max(0.0, constraints.maxHeight - 56);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          counts[hour] > 0 ? '${counts[hour]}' : '',
                          style: AppFonts.numbers(
                            fontSize: 13,
                            fontWeight:
                                isPeak ? FontWeight.w700 : FontWeight.w600,
                            color:
                                isPeak ? Palette.yolk : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: counts[hour] / peak),
                          duration: Duration(
                            milliseconds: 600 + 50 * (hour - first),
                          ),
                          curve: Motion.ease,
                          builder:
                              (context, value, _) => Container(
                                height: barSpace * value,
                                decoration: BoxDecoration(
                                  color:
                                      isPeak
                                          ? Palette.yolk
                                          : scheme.surfaceContainerHighest,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                ),
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$hour',
                          style: AppFonts.numbers(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isPeak ? Palette.yolk : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
