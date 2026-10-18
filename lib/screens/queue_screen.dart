import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/queue_entry.dart';
import '../models/shop.dart';
import '../services/queue_service.dart';
import '../services/shop_service.dart';
import '../theme/app_theme.dart';
import '../utils/maps.dart';
import '../utils/queue_position.dart';
import '../widgets/brand.dart';
import '../widgets/motion.dart';

/// Shows the customer's active queue and history. Everything streams from
/// Firestore, so the position updates as soon as the shop changes a status.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key, this.queueService, this.shopService, this.uid});

  /// Injected in tests; the app uses the Firebase defaults.
  final QueueService? queueService;
  final ShopService? shopService;
  final String? uid;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  late final QueueService _queueService = widget.queueService ?? QueueService();
  late final ShopService _shopService = widget.shopService ?? ShopService();
  late final String? _uid =
      widget.uid ?? FirebaseAuth.instance.currentUser?.uid;
  late final Stream<QueueEntry?>? _myQueue =
      _uid == null ? null : _queueService.watchMyQueue(_uid);
  late final Stream<List<QueueEntry>>? _history =
      _uid == null ? null : _queueService.watchMyHistory(_uid);

  Future<void> _cancelQueue(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('ยืนยันการยกเลิกคิว'),
            content: const Text('คุณต้องการยกเลิกคิวนี้หรือไม่?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('ไม่'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('ใช่'),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _queueService.cancelMyQueue(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ยกเลิกคิวเรียบร้อย')));
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยกเลิกคิวไม่สำเร็จ กรุณาลองใหม่')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child:
            uid == null
                ? const Center(child: Text('กรุณาเข้าสู่ระบบอีกครั้ง'))
                : StreamBuilder<QueueEntry?>(
                  stream: _myQueue,
                  builder: (context, queueSnapshot) {
                    if (queueSnapshot.hasError) {
                      return const Center(
                        child: Text('ไม่สามารถโหลดข้อมูลคิวได้ กรุณาลองใหม่'),
                      );
                    }
                    if (queueSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final queue = queueSnapshot.data;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'คิวของฉัน',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (queue != null) ...[
                              LiveDot(color: scheme.tertiary, size: 8),
                              const SizedBox(width: 8),
                              Text(
                                'อัปเดตสด',
                                style: TextStyle(
                                  color: scheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (queue != null) ...[
                          _ActiveQueue(
                            key: ValueKey(queue.ticketId),
                            queue: queue,
                            queueService: _queueService,
                            shopService: _shopService,
                            onCancel: () => _cancelQueue(uid),
                          ),
                          const SizedBox(height: 28),
                        ],
                        _QueueHistory(
                          stream: _history!,
                          hasActiveQueue: queue != null,
                        ),
                      ],
                    );
                  },
                ),
      ),
    );
  }
}

class _ActiveQueue extends StatefulWidget {
  const _ActiveQueue({
    super.key,
    required this.queue,
    required this.queueService,
    required this.shopService,
    required this.onCancel,
  });

  final QueueEntry queue;
  final QueueService queueService;
  final ShopService shopService;
  final VoidCallback onCancel;

  @override
  State<_ActiveQueue> createState() => _ActiveQueueState();
}

class _ActiveQueueState extends State<_ActiveQueue> {
  late final Stream<List<QueueTicket>> _tickets = widget.queueService
      .watchWaitingTickets(
        shopId: widget.queue.shopId,
        zone: widget.queue.zone,
        queueDate: widget.queue.queueDate ?? '',
      );
  late final Stream<Shop?> _shop = widget.shopService.watchShop(
    widget.queue.shopId,
  );

  Future<void> _openMap(Shop? shop) async {
    final opened = shop != null && await openShopInMaps(shop);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เปิดแผนที่ไม่สำเร็จ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    return StreamBuilder<Shop?>(
      stream: _shop,
      builder: (context, shopSnapshot) {
        final shop = shopSnapshot.data;
        return StreamBuilder<List<QueueTicket>>(
          stream: _tickets,
          builder: (context, ticketSnapshot) {
            final ahead =
                ticketSnapshot.hasData
                    ? queuesAhead(
                      waitingTickets: ticketSnapshot.data!,
                      ownTicketId: queue.ticketId,
                      ownCreatedAt: queue.createdAt ?? DateTime.now(),
                    )
                    : null;
            final progress =
                ahead == null
                    ? null
                    : queueProgress(status: queue.status, ahead: ahead);
            final stale = queue.isStale(queueDateKey(DateTime.now()));

            final actions = Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openMap(shop),
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.ink,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.near_me_rounded, size: 20),
                    label: const Text('นำทางไปร้าน'),
                  ),
                ),
                if (progress != QueueProgress.serving) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('ยกเลิกคิว'),
                    ),
                  ),
                ],
              ],
            );

            if (!stale && progress == QueueProgress.called) {
              return Column(
                children: [
                  _CalledPanel(queue: queue),
                  const SizedBox(height: 14),
                  actions,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(
                  offset: 24,
                  child: _TicketPass(
                    queue: queue,
                    ahead: ahead,
                    progress: progress,
                    minutesPerQueue: shop?.minutesPerQueue,
                    stale: stale,
                    loadFailed: ticketSnapshot.hasError,
                  ),
                ),
                const SizedBox(height: 14),
                if (!stale && progress != QueueProgress.serving) ...[
                  const _NotifyHint(),
                  const SizedBox(height: 14),
                ],
                actions,
              ],
            );
          },
        );
      },
    );
  }
}

/// The queue as a yellow ticket stub: number on top, live position below.
class _TicketPass extends StatelessWidget {
  const _TicketPass({
    required this.queue,
    required this.ahead,
    required this.progress,
    required this.minutesPerQueue,
    required this.stale,
    required this.loadFailed,
  });

  final QueueEntry queue;
  final int? ahead;
  final QueueProgress? progress;
  final double? minutesPerQueue;
  final bool stale;
  final bool loadFailed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final paper = isLight ? Colors.white : Palette.nightPanel;
    final ahead = this.ahead;
    final wait =
        ahead == null
            ? null
            : estimateWaitMinutes(
              ahead: ahead,
              minutesPerQueue: minutesPerQueue,
            );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          if (isLight)
            const BoxShadow(
              color: Color(0x1F1A1714),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            decoration: const BoxDecoration(
              color: Palette.yolk,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Palette.ink),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          queue.shopName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${queue.zone} • ${queue.partySize} คน',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      queue.queueLabel,
                      style: AppFonts.numbers(
                        fontSize: 100,
                        color: Palette.ink,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'แสดงเลขนี้ให้พนักงานเมื่อถึงคิว',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4A3600),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _Perforation(paper: paper, background: scheme.surface),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 20),
            decoration: BoxDecoration(
              color: paper,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
            ),
            child:
                stale
                    ? const _StaleBanner()
                    : loadFailed
                    ? const Text('โหลดลำดับคิวไม่สำเร็จ')
                    : progress == null
                    ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (progress != QueueProgress.serving)
                          Row(
                            children: [
                              Expanded(
                                child: _Figure(
                                  label: 'คิวข้างหน้า',
                                  child: _RollingNumber(value: ahead!),
                                ),
                              ),
                              Expanded(
                                child: _Figure(
                                  label: 'เวลารอโดยประมาณ',
                                  child: Text(
                                    '~$wait นาที',
                                    style: AppFonts.numbers(
                                      fontSize: 26,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 14),
                        _Steps(progress: progress!),
                        const SizedBox(height: 14),
                        _StatusLine(
                          progress: progress!,
                          ahead: ahead!,
                          wait: wait!,
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

/// The torn edge between the stub and the body of the ticket.
class _Perforation extends StatelessWidget {
  const _Perforation({required this.paper, required this.background});

  final Color paper;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final notch = BoxDecoration(color: background, shape: BoxShape.circle);
    return Container(
      height: 22,
      color: paper,
      child: Row(
        children: [
          Transform.translate(
            offset: const Offset(-11, 0),
            child: Container(width: 22, height: 22, decoration: notch),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dashes = max(1, constraints.maxWidth ~/ 12);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < dashes; i++)
                      Container(
                        width: 6,
                        height: 2,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                );
              },
            ),
          ),
          Transform.translate(
            offset: const Offset(11, 0),
            child: Container(width: 22, height: 22, decoration: notch),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A number that rolls up to its new value, like a departures board.
class _RollingNumber extends StatelessWidget {
  const _RollingNumber({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Motion.ease,
        switchOutCurve: Motion.ease,
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(value);
          return SlideTransition(
            position: Tween(
              begin: Offset(0, incoming ? 1 : -1),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Text(
          '$value',
          key: ValueKey(value),
          style: AppFonts.numbers(fontSize: 26, height: 1.3),
        ),
      ),
    );
  }
}

/// Waiting → called → seated, with the current step animated.
class _Steps extends StatelessWidget {
  const _Steps({required this.progress});

  final QueueProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = switch (progress) {
      QueueProgress.waiting || QueueProgress.next => 0,
      QueueProgress.called => 1,
      QueueProgress.serving => 2,
    };
    const labels = ['รอคิว', 'ร้านเรียก', 'เข้าโต๊ะ'];
    final active =
        progress == QueueProgress.serving ? scheme.tertiary : scheme.primary;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child:
                        i < current
                            ? ColoredBox(color: active)
                            : i == current
                            ? _Stripes(color: active)
                            : ColoredBox(color: scheme.surfaceContainerHigh),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        i == current
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                    fontWeight: i == current ? FontWeight.w600 : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Diagonal stripes sliding sideways: "this step is in progress".
class _Stripes extends StatelessWidget {
  const _Stripes({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, Colors.white, 0.3)!;
    return LoopingBuilder(
      duration: const Duration(milliseconds: 900),
      builder:
          (context, t, _) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + t * 0.4, 0),
                end: Alignment(-0.8 + t * 0.4, 0),
                colors: [color, color, light, light],
                stops: const [0, 0.5, 0.5, 1],
                tileMode: TileMode.repeated,
              ),
            ),
          ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.progress,
    required this.ahead,
    required this.wait,
  });

  final QueueProgress progress;
  final int ahead;
  final int wait;

  @override
  Widget build(BuildContext context) {
    final status = StatusColors.of(context);
    final (String title, String detail, Color color) = switch (progress) {
      QueueProgress.serving => (
        'กำลังใช้บริการ',
        'ขอให้อร่อยกับมื้อนี้',
        status.serving,
      ),
      QueueProgress.next => (
        'คิวถัดไป',
        'ประมาณ $wait นาที กรุณาเตรียมตัวใกล้ร้าน',
        status.next,
      ),
      QueueProgress.called => (
        'ถึงคิวแล้ว!',
        'เชิญที่หน้าร้าน แจ้งเลขคิวกับพนักงานได้เลย',
        status.called,
      ),
      QueueProgress.waiting => (
        'รออีก $ahead คิว',
        'ประมาณ $wait นาที • อัปเดตอัตโนมัติ',
        Theme.of(context).colorScheme.onSurface,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          detail,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NotifyHint extends StatelessWidget {
  const _NotifyHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_outlined,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'จะแจ้งเตือนเมื่อเหลือ 2 คิว และตอนร้านเรียก (ขณะเปิดแอป)',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full yellow "it's your turn" panel with a ringing bell and the time left
/// before the shop may skip the queue.
class _CalledPanel extends StatefulWidget {
  const _CalledPanel({required this.queue});

  final QueueEntry queue;

  @override
  State<_CalledPanel> createState() => _CalledPanelState();
}

class _CalledPanelState extends State<_CalledPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    const grace = Duration(minutes: noShowGraceMinutes);
    final calledAt = queue.calledAt;
    final left =
        calledAt == null ? grace : grace - DateTime.now().difference(calledAt);
    final remaining = left.isNegative ? Duration.zero : left;
    final fraction = remaining.inMilliseconds / grace.inMilliseconds;
    final clock =
        '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      decoration: BoxDecoration(
        color: Palette.yolk,
        borderRadius: BorderRadius.circular(28),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Palette.ink),
        textAlign: TextAlign.center,
        child: Column(
          children: [
            const _RingingBell(),
            const SizedBox(height: 18),
            Text(
              'ถึงคิวแล้ว!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Palette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'เชิญที่หน้าร้าน${queue.shopName} แล้วแจ้งเลขคิวกับพนักงาน',
              style: const TextStyle(fontSize: 16, color: Color(0xFF3A2E00)),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              offset: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Palette.ink,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    const Text(
                      'เลขคิว',
                      style: TextStyle(color: Color(0xFFD9D3CB)),
                    ),
                    Text(
                      queue.queueLabel,
                      style: AppFonts.numbers(
                        fontSize: 84,
                        color: Palette.yolk,
                        height: 1.05,
                      ),
                    ),
                    Text(
                      '${queue.zone} • ${queue.partySize} คน',
                      style: const TextStyle(color: Color(0xFFD9D3CB)),
                    ),
                  ],
                ),
              ),
            ),
            if (calledAt != null) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'มาภายในเวลานี้ ไม่งั้นร้านอาจข้ามคิว',
                      textAlign: TextAlign.start,
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(clock, style: AppFonts.numbers(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  color: Palette.ink,
                  backgroundColor: Palette.yolkDeep,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RingingBell extends StatelessWidget {
  const _RingingBell();

  @override
  Widget build(BuildContext context) {
    const size = 104.0;
    return SizedBox.square(
      dimension: size * 1.6,
      child: LoopingBuilder(
        duration: const Duration(milliseconds: 2000),
        builder: (context, t, _) {
          // Two rings spreading out half a cycle apart, and a bell that
          // shakes near the end of each cycle.
          Widget ring(double phase) {
            final p = (t + phase) % 1;
            return Opacity(
              opacity: t == 0 && phase == 0 ? 0 : (1 - p) * 0.5,
              child: Transform.scale(
                scale: 1 + p * 0.6,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.ink, width: 3),
                  ),
                ),
              ),
            );
          }

          final shake = t > 0.6 ? sin((t - 0.6) * 40) * (1 - t) * 0.6 : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (t > 0) ...[ring(0), ring(0.5)],
              Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: Palette.ink,
                  shape: BoxShape.circle,
                ),
                child: Transform.rotate(
                  angle: shake,
                  alignment: const Alignment(0, -0.6),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Palette.yolk,
                    size: 50,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'คิวนี้เป็นของวันก่อนและหมดอายุแล้ว กรุณายกเลิกแล้วรับคิวใหม่',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}

class _QueueHistory extends StatelessWidget {
  const _QueueHistory({required this.stream, required this.hasActiveQueue});

  final Stream<List<QueueEntry>> stream;
  final bool hasActiveQueue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<QueueEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('โหลดประวัติการใช้บริการไม่สำเร็จ');
        }
        if (!snapshot.hasData) return const SizedBox.shrink();
        final items = snapshot.data!;
        if (items.isEmpty) {
          return hasActiveQueue
              ? const SizedBox.shrink()
              : Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Column(
                  children: [
                    Opacity(opacity: 0.85, child: BrandLogo(size: 88)),
                    const SizedBox(height: 16),
                    Text(
                      'ยังไม่มีการจอง',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'เลือกร้านจากหน้าแรกแล้วกดรับคิวได้เลย',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed:
                          () => DefaultTabController.maybeOf(
                            context,
                          )?.animateTo(0),
                      child: const Text('ดูร้านทั้งหมด'),
                    ),
                  ],
                ),
              );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('ประวัติการใช้บริการ'),
            const SizedBox(height: 8),
            for (final (index, item) in items.indexed)
              FadeSlideIn(
                delay: Duration(milliseconds: 50 * min(index, 6)),
                child: _HistoryRow(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final QueueEntry item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (item.status) {
      'no_show' => (
        'ไม่มาตามคิว',
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      'cancelled' => (
        'ร้านยกเลิก',
        scheme.surfaceContainer,
        scheme.onSurfaceVariant,
      ),
      _ => ('เสร็จสิ้น', scheme.tertiaryContainer, scheme.onTertiaryContainer),
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              item.queueLabel,
              style: AppFonts.numbers(fontSize: 18, color: scheme.primary),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.shopName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${item.zone} • ${item.partySize} คน • ${_formatDate(item.completedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          StatusPill(
            label: label,
            background: background,
            foreground: foreground,
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}
