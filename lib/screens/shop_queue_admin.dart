import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/queue_entry.dart';
import '../models/shop.dart';
import '../services/admin_service.dart';
import '../services/queue_service.dart';
import '../services/shop_service.dart';
import '../utils/input_formatters.dart';
import '../utils/queue_position.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import '../widgets/motion.dart';
import 'redeem_coupon_dialog.dart';

/// Live queue board for one shop: call the next queue per zone, add walk-ins,
/// pause new bookings, and close queues as completed, no-show or cancelled.
class ShopQueueAdmin extends StatefulWidget {
  const ShopQueueAdmin({
    super.key,
    required this.adminService,
    required this.admin,
  });

  final AdminService adminService;
  final AdminProfile admin;

  @override
  State<ShopQueueAdmin> createState() => _ShopQueueAdminState();
}

class _ShopQueueAdminState extends State<ShopQueueAdmin> {
  final _shopService = ShopService();
  final _queueService = QueueService();
  late final Stream<Shop?> _shop;
  late final Stream<List<QueueEntry>> _queues;
  String? _callingZone;

  /// Queues closed in the last few seconds: hidden from the board and only
  /// written to Firestore when their undo window ends.
  final _pendingCloses = <String, ({Timer timer, String outcome})>{};

  /// Hidden from the board: pending closes and closes being saved.
  final _hidden = <String>{};

  /// The latest queues, to find the one "call next" picked.
  List<QueueEntry> _latest = const [];

  late final _actions = _BoardActions(
    setStatus: _setStatusWithUndo,
    close: _closeWithUndo,
  );

  static const _undoWindow = Duration(seconds: 5);
  static const _soundKey = 'staff.newQueueSound';

  /// Plays a chime when a customer books from the app.
  final _player = AudioPlayer();
  bool _soundOn = true;

  /// Queue ids in the previous snapshot, to spot new bookings.
  Set<String>? _knownIds;

  /// Zone the one-tap walk-in buttons add to.
  String? _walkInZone;

  String get _shopId => widget.admin.shopId;

  void _loadSoundSetting() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getBool(_soundKey);
      if (saved != null && mounted) setState(() => _soundOn = saved);
    } on Exception {
      // Keep the default when storage is unavailable.
    }
  }

  Future<void> _toggleSound() async {
    setState(() => _soundOn = !_soundOn);
    if (_soundOn) _playChime();
    try {
      await (await SharedPreferences.getInstance()).setBool(
        _soundKey,
        _soundOn,
      );
    } on Exception {
      // Remembering the choice is a convenience.
    }
  }

  void _playChime() {
    _player.play(AssetSource('sounds/new_queue.wav')).catchError((Object _) {
      // Browsers may block sound until the page has been tapped once.
    });
  }

  /// Called after a snapshot that holds new bookings from the app.
  void _announceNewQueues(int count) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    if (_soundOn) _playChime();
  }

  Future<void> _quickWalkIn(String zone, int partySize) async {
    try {
      final label = await _queueService.addWalkIn(
        shopId: _shopId,
        zone: zone,
        partySize: partySize,
        customerName: '',
      );
      _showMessage('ออกคิว walk-in $label • $partySize คน');
    } on StateError catch (error) {
      _showMessage(error.message);
    } on FirebaseException {
      _showMessage('เพิ่มคิวไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    // Leaving the board ends every undo window now.
    for (final entry in _pendingCloses.entries) {
      entry.value.timer.cancel();
      widget.adminService.closeQueue(
        queueId: entry.key,
        outcome: entry.value.outcome,
      );
    }
    super.dispose();
  }

  void _showUndo(String message, VoidCallback onUndo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: _undoWindow,
          action: SnackBarAction(label: 'เลิกทำ', onPressed: onUndo),
        ),
      );
  }

  static String _statusName(String status) => switch (status) {
    'called' => 'เรียกแล้ว',
    'serving' => 'กำลังทาน',
    _ => 'รอคิว',
  };

  Future<void> _setStatusWithUndo(QueueEntry queue, String status) async {
    final previous = queue.status;
    await widget.adminService.setQueueStatus(queueId: queue.id, status: status);
    _showUndo('${queue.queueLabel}: ${_statusName(status)}', () {
      widget.adminService
          .setQueueStatus(queueId: queue.id, status: previous)
          .catchError((Object _) => _showMessage('เลิกทำไม่สำเร็จ'));
    });
  }

  void _closeWithUndo(QueueEntry queue, String outcome) {
    final name = switch (outcome) {
      'completed' => 'เสร็จสิ้น',
      'no_show' => 'ไม่มาตามคิว',
      _ => 'ยกเลิกคิว',
    };
    setState(() {
      _hidden.add(queue.id);
      _pendingCloses[queue.id] = (
        timer: Timer(_undoWindow, () => _commitClose(queue.id, outcome)),
        outcome: outcome,
      );
    });
    _showUndo('${queue.queueLabel}: $name', () {
      _pendingCloses.remove(queue.id)?.timer.cancel();
      if (mounted) setState(() => _hidden.remove(queue.id));
    });
  }

  Future<void> _commitClose(String queueId, String outcome) async {
    _pendingCloses.remove(queueId);
    try {
      await widget.adminService.closeQueue(queueId: queueId, outcome: outcome);
    } on Object {
      if (!mounted) return;
      setState(() => _hidden.remove(queueId));
      _showMessage('ปิดคิวไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  @override
  void initState() {
    super.initState();
    _shop = _shopService.watchShop(_shopId);
    _queues = widget.adminService.watchShopQueues(_shopId);
    _loadSoundSetting();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _callNext(String zone) async {
    setState(() => _callingZone = zone);
    try {
      final label = await widget.adminService.callNext(
        shopId: _shopId,
        zone: zone,
      );
      final called =
          _latest
              .where((queue) => queue.queueLabel == label && queue.zone == zone)
              .firstOrNull;
      if (label == null) {
        _showMessage('ไม่มีคิวรอในโซน $zone');
      } else if (called == null) {
        _showMessage('เรียกคิว $label แล้ว');
      } else {
        _showUndo('เรียกคิว $label แล้ว', () {
          widget.adminService
              .setQueueStatus(queueId: called.id, status: 'waiting')
              .catchError((Object _) => _showMessage('เลิกทำไม่สำเร็จ'));
        });
      }
    } on FirebaseException {
      _showMessage('เรียกคิวไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _callingZone = null);
    }
  }

  bool _closing = false;

  Future<void> _redeemCoupon() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final redeemed = await showDialog<bool>(
      context: context,
      builder: (_) => RedeemCouponDialog(staffUid: uid, shopId: _shopId),
    );
    if (redeemed == true) _showMessage('ใช้คูปองเรียบร้อย');
  }

  /// Closes [queueIds] as cancelled after confirming; customers see them in
  /// their history as cancelled by the shop.
  Future<void> _closeAll(List<String> queueIds, {required String title}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(
              'ปิด ${queueIds.length} คิวเป็น "ร้านยกเลิก" '
              'ลูกค้าจะเห็นในประวัติของตัวเอง',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('ปิดคิว'),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _closing = true);
    try {
      final closed = await widget.adminService.closeQueues(
        queueIds: queueIds,
        outcome: 'cancelled',
      );
      _showMessage('ปิดแล้ว $closed คิว');
    } on FirebaseException {
      _showMessage('ปิดคิวไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _setAccepting(bool accepting) async {
    try {
      await _shopService.setAcceptingQueues(
        shopId: _shopId,
        accepting: accepting,
      );
      _showMessage(accepting ? 'เปิดรับคิวแล้ว' : 'ปิดรับคิวชั่วคราวแล้ว');
    } on FirebaseException {
      _showMessage('เปลี่ยนสถานะไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  Future<void> _addWalkIn(List<String> zones) async {
    final result = await showDialog<_WalkIn>(
      context: context,
      builder: (_) => _WalkInDialog(zones: zones),
    );
    if (result == null) return;
    try {
      final label = await _queueService.addWalkIn(
        shopId: _shopId,
        zone: result.zone,
        partySize: result.partySize,
        customerName: result.name,
        customerPhone: result.phone,
      );
      _showMessage('เพิ่มคิว walk-in $label แล้ว');
    } on StateError catch (error) {
      _showMessage(error.message);
    } on FirebaseException {
      _showMessage('เพิ่มคิวไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Shop?>(
      stream: _shop,
      builder: (context, shopSnapshot) {
        final shop = shopSnapshot.data;
        final zones = shop?.bookableZones ?? const ['ทั่วไป'];
        final accepting = shop?.acceptingQueues ?? true;

        return StreamBuilder<List<QueueEntry>>(
          stream: _queues,
          builder: (context, queueSnapshot) {
            if (queueSnapshot.hasError) {
              return const Center(child: Text('โหลดข้อมูลคิวของร้านไม่สำเร็จ'));
            }
            if (!queueSnapshot.hasData || shop == null) {
              return const Center(child: CircularProgressIndicator());
            }
            // Queues arrive oldest first; split today's by status and set
            // aside leftovers from earlier days.
            final today = queueDateKey(DateTime.now());
            final stale = <QueueEntry>[];
            final waiting = <QueueEntry>[];
            final called = <QueueEntry>[];
            final serving = <QueueEntry>[];
            _latest = queueSnapshot.data!;
            final ids = {for (final queue in _latest) queue.id};
            final known = _knownIds;
            _knownIds = ids;
            if (known != null) {
              final fresh =
                  _latest
                      .where(
                        (queue) =>
                            !known.contains(queue.id) &&
                            !queue.walkIn &&
                            queue.status == 'waiting',
                      )
                      .length;
              if (fresh > 0) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _announceNewQueues(fresh),
                );
              }
            }
            _hidden.removeWhere(
              (id) =>
                  !_pendingCloses.containsKey(id) &&
                  !_latest.any((queue) => queue.id == id),
            );
            for (final queue in queueSnapshot.data!) {
              if (_hidden.contains(queue.id)) continue;
              if (queue.isStale(today)) {
                stale.add(queue);
              } else {
                switch (queue.status) {
                  case 'called':
                    called.add(queue);
                  case 'serving':
                    serving.add(queue);
                  default:
                    waiting.add(queue);
                }
              }
            }
            final open = [...waiting, ...called, ...serving];

            final header = _BoardHeader(
              shop: shop,
              waitingCount: waiting.length,
              accepting: accepting,
              onAccepting: _setAccepting,
              soundOn: _soundOn,
              onToggleSound: _toggleSound,
              onRedeem: _redeemCoupon,
            );
            final walkInZone =
                zones.contains(_walkInZone) ? _walkInZone! : zones.first;
            final walkInBar = _WalkInBar(
              zones: zones,
              zone: walkInZone,
              onZone: (zone) => setState(() => _walkInZone = zone),
              onPartySize: (size) => _quickWalkIn(walkInZone, size),
              onMore: () => _addWalkIn(zones),
            );
            final staleBanner =
                stale.isEmpty
                    ? null
                    : _StaleBanner(
                      labels: stale.map((queue) => queue.queueLabel).toList(),
                      onClose:
                          _closing
                              ? null
                              : () => _closeAll(
                                stale.map((queue) => queue.id).toList(),
                                title: 'ปิดคิวค้างจากวันก่อน',
                              ),
                    );
            final callButtons = [
              for (final zone in zones)
                _CallNextButton(
                  zone: zones.length > 1 ? zone : null,
                  next:
                      waiting
                          .where((queue) => queue.zone == zone)
                          .firstOrNull
                          ?.queueLabel,
                  calling: _callingZone == zone,
                  onPressed:
                      _callingZone == null ? () => _callNext(zone) : null,
                ),
            ];
            final closeAll = OutlinedButton.icon(
              onPressed:
                  _closing || open.isEmpty
                      ? null
                      : () => _closeAll([
                        for (final queue in open) queue.id,
                      ], title: 'ปิดร้าน: ปิดคิวที่เหลือทั้งหมด'),
              icon: const Icon(Icons.nightlight_round),
              label: const Text('ปิดร้าน: ปิดคิวที่เหลือทั้งหมด'),
            );

            final columns = [
              _BoardColumn(
                title: 'รอคิว',
                count: waiting.length,
                color: Palette.yolk,
                top: callButtons,
                empty: 'ไม่มีคิวรอ',
                queues: waiting,
                actions: _actions,
              ),
              _BoardColumn(
                title: 'เรียกแล้ว รอลูกค้ามา',
                count: called.length,
                color: Palette.ember,
                empty: 'ยังไม่ได้เรียกคิว',
                queues: called,
                actions: _actions,
              ),
              _BoardColumn(
                title: 'กำลังทาน',
                count: serving.length,
                color: Palette.mint,
                empty: 'ยังไม่มีโต๊ะที่กำลังทาน',
                queues: serving,
                actions: _actions,
                bottom: closeAll,
              ),
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 900) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                    child: Column(
                      children: [
                        header,
                        const SizedBox(height: 14),
                        walkInBar,
                        if (staleBanner != null) ...[
                          const SizedBox(height: 14),
                          staleBanner,
                        ],
                        const SizedBox(height: 14),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final (index, column)
                                  in columns.indexed) ...[
                                if (index > 0) const SizedBox(width: 14),
                                Expanded(child: column.scrolling()),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    header,
                    const SizedBox(height: 12),
                    walkInBar,
                    if (staleBanner != null) ...[
                      const SizedBox(height: 12),
                      staleBanner,
                    ],
                    for (final column in columns) ...[
                      const SizedBox(height: 14),
                      column,
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _BoardHeader extends StatelessWidget {
  const _BoardHeader({
    required this.shop,
    required this.waitingCount,
    required this.accepting,
    required this.onAccepting,
    required this.soundOn,
    required this.onToggleSound,
    required this.onRedeem,
  });

  final Shop shop;
  final int waitingCount;
  final bool accepting;
  final ValueChanged<bool> onAccepting;
  final bool soundOn;
  final VoidCallback onToggleSound;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pace = shop.minutesPerQueue;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shop.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              [
                'วันนี้ • รอ $waitingCount คิว',
                if (pace != null) 'เฉลี่ย ${pace.round()} นาทีต่อคิว',
              ].join(' • '),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Material(
              color:
                  accepting ? scheme.tertiaryContainer : scheme.errorContainer,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => onAccepting(!accepting),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        accepting ? 'เปิดรับคิว' : 'ปิดรับคิวชั่วคราว',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color:
                              accepting
                                  ? scheme.onTertiaryContainer
                                  : scheme.onErrorContainer,
                        ),
                      ),
                      Switch(value: accepting, onChanged: onAccepting),
                    ],
                  ),
                ),
              ),
            ),
            IconButton.outlined(
              tooltip: soundOn ? 'ปิดเสียงแจ้งคิวใหม่' : 'เปิดเสียงแจ้งคิวใหม่',
              onPressed: onToggleSound,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(48),
                side: BorderSide(color: scheme.outlineVariant, width: 1.5),
              ),
              icon: Icon(
                soundOn
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onRedeem,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.local_offer_outlined),
              label: const Text('ใช้คูปองลูกค้า'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.labels, required this.onClose});

  final List<String> labels;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'คิวค้างจากวันก่อน ${labels.length} คิว (${labels.join(', ')}) '
              'ไม่นับรวมในคิววันนี้',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onClose,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('ปิดทั้งหมด'),
          ),
        ],
      ),
    );
  }
}

/// The big yellow "call next" button, one per zone.
class _CallNextButton extends StatelessWidget {
  const _CallNextButton({
    required this.zone,
    required this.next,
    required this.calling,
    required this.onPressed,
  });

  /// Shown when the shop has more than one zone.
  final String? zone;
  final String? next;
  final bool calling;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = this.next;
    if (next == null) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
        ),
        child: Text(
          zone == null ? 'ไม่มีคิวรอแล้ว' : '$zone: ไม่มีคิวรอ',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        backgroundColor: Palette.yolk,
        foregroundColor: Palette.ink,
        disabledBackgroundColor: Palette.yolkDeep,
        disabledForegroundColor: Palette.ink,
      ),
      child:
          calling
              ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: Palette.ink,
                ),
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      zone == null ? 'เรียกคิวถัดไป' : '$zone: เรียกถัดไป',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    next,
                    style: AppFonts.numbers(fontSize: 26, color: Palette.ink),
                  ),
                ],
              ),
    );
  }
}

/// One status column of the board.
class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.title,
    required this.count,
    required this.color,
    required this.empty,
    required this.queues,
    required this.actions,
    this.top = const [],
    this.bottom,
  });

  final String title;
  final int count;
  final Color color;
  final String empty;
  final List<QueueEntry> queues;
  final _BoardActions actions;
  final List<Widget> top;
  final Widget? bottom;

  /// The tablet layout: fixed header, scrolling cards.
  Widget scrolling() => _BoardColumn(
    title: title,
    count: count,
    color: color,
    empty: empty,
    queues: queues,
    actions: actions,
    top: top,
    bottom: bottom,
  )._build(scroll: true);

  @override
  Widget build(BuildContext context) => _build(scroll: false);

  Widget _build({required bool scroll}) {
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final cards = [
          for (final widget in top) ...[widget, const SizedBox(height: 10)],
          // Call-next buttons already say when nobody is waiting.
          if (queues.isEmpty && top.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                empty,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          for (final queue in queues)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FadeSlideIn(
                key: ValueKey('${queue.id}-${queue.status}'),
                offset: -10,
                duration: const Duration(milliseconds: 320),
                child: _QueueCard(queue: queue, actions: actions),
              ),
            ),
        ];
        final heading = Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder:
                  (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
              child: Text(
                '$count',
                key: ValueKey(count),
                style: AppFonts.numbers(fontSize: 20, color: color),
              ),
            ),
          ],
        );
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: scroll ? MainAxisSize.max : MainAxisSize.min,
            children: [
              heading,
              const SizedBox(height: 12),
              if (scroll)
                Expanded(child: ListView(children: cards))
              else
                ...cards,
              if (bottom != null) ...[const SizedBox(height: 4), bottom!],
            ],
          ),
        );
      },
    );
  }
}

class _QueueCard extends StatefulWidget {
  const _QueueCard({required this.queue, required this.actions});

  final QueueEntry queue;
  final _BoardActions actions;

  @override
  State<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<_QueueCard> {
  bool _saving = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Called queues count down every second towards the no-show grace
    // period; other cards only show minutes.
    _ticker = Timer.periodic(
      Duration(seconds: widget.queue.status == 'called' ? 1 : 30),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } on FirebaseException {
      _showError('บันทึกไม่สำเร็จ กรุณาลองใหม่');
    } on StateError catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll('-', ''));
    if (!await launchUrl(uri)) {
      _showError('โทรออกไม่ได้จากเครื่องนี้ เบอร์ $phone');
    }
  }

  Future<void> _setStatus(String status) =>
      _run(() => widget.actions.setStatus(widget.queue, status));

  /// Closing waits a few seconds so it can be undone; see _BoardActions.
  void _close(String outcome) => widget.actions.close(widget.queue, outcome);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final queue = widget.queue;
    final now = DateTime.now();
    final name = queue.customerName.trim();
    final who = [
      '${queue.partySize} คน',
      if (queue.walkIn) 'walk-in',
      if (name.isNotEmpty) name,
    ].join(' • ');

    final number = SizedBox(
      width: 76,
      child: Text(queue.queueLabel, style: AppFonts.numbers(fontSize: 26)),
    );
    final phone = queue.customerPhone.trim();
    final call =
        phone.isEmpty
            ? null
            : IconButton(
              tooltip: 'โทรหาลูกค้า $phone',
              onPressed: () => _callCustomer(phone),
              icon: Icon(Icons.call_rounded, color: scheme.tertiary),
            );
    final busy =
        _saving
            ? const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            )
            : null;

    switch (queue.status) {
      case 'called':
        const grace = Duration(minutes: noShowGraceMinutes);
        final calledAt = queue.calledAt;
        final elapsed =
            calledAt == null ? Duration.zero : now.difference(calledAt);
        final late = elapsed >= grace;
        final left = grace - elapsed;
        final card = Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Row(
                  children: [
                    number,
                    Expanded(
                      child: Text(
                        who,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    if (call != null) call,
                    if (queue.onTheWayAt != null) ...[
                      StatusPill(
                        label: 'กำลังเดินทางมา',
                        background: scheme.tertiaryContainer,
                        foreground: scheme.onTertiaryContainer,
                        leading: Icon(
                          Icons.directions_walk_rounded,
                          size: 16,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      'เรียกแล้ว ${elapsed.inMinutes} นาที',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: late ? scheme.error : Palette.ember,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child:
                    busy ??
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _setStatus('serving'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: scheme.onSurface,
                              foregroundColor: scheme.surface,
                            ),
                            child: const Text('ลูกค้ามาแล้ว'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: late ? () => _close('no_show') : null,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              foregroundColor: scheme.error,
                              side: BorderSide(
                                color:
                                    late ? scheme.error : scheme.outlineVariant,
                                width: 1.5,
                              ),
                            ),
                            // One line on narrow cards: shrink, don't wrap.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                late
                                    ? 'ไม่มา ข้ามคิว'
                                    : 'ข้ามได้ใน ${left.inMinutes + 1} นาที',
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
              SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: late ? 1 : left.inMilliseconds / grace.inMilliseconds,
                  color: late ? scheme.error : Palette.ember,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        );
        if (!late) return card;
        // Past the grace period: the border pulses so staff notice it.
        return LoopingBuilder(
          duration: const Duration(milliseconds: 1400),
          still: 0,
          child: card,
          builder:
              (context, t, child) => DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        Color.lerp(
                          scheme.error,
                          scheme.errorContainer,
                          (sin(t * 2 * pi) + 1) / 2,
                        )!,
                    width: 2,
                  ),
                ),
                child: child,
              ),
        );
      case 'serving':
        return _plainCard(
          scheme,
          children: [
            number,
            Expanded(
              child: Text(
                who,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            if (busy != null)
              const SizedBox(width: 80, child: LinearProgressIndicator())
            else
              FilledButton(
                onPressed: () => _close('completed'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: Palette.mint,
                  foregroundColor: const Color(0xFF0E2A1C),
                  shape: const StadiumBorder(),
                ),
                child: const Text('เสร็จสิ้น'),
              ),
          ],
        );
      default:
        final waited =
            queue.createdAt == null
                ? null
                : now.difference(queue.createdAt!).inMinutes;
        return _plainCard(
          scheme,
          children: [
            number,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    who,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [
                      queue.zone,
                      if (waited != null) 'รอ $waited นาที',
                    ].join(' • '),
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (busy != null)
              const SizedBox(width: 80, child: LinearProgressIndicator())
            else ...[
              if (call != null) call,
              IconButton(
                tooltip: 'ยกเลิกคิว',
                onPressed: () => _close('cancelled'),
                icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
              ),
              OutlinedButton(
                onPressed: () => _setStatus('called'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: const StadiumBorder(),
                ),
                child: const Text('เรียก'),
              ),
            ],
          ],
        );
    }
  }

  Widget _plainCard(ColorScheme scheme, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: children),
    );
  }
}

class _WalkIn {
  const _WalkIn(this.zone, this.partySize, this.name, this.phone);

  final String zone;
  final int partySize;
  final String name;
  final String phone;
}

class _WalkInDialog extends StatefulWidget {
  const _WalkInDialog({required this.zones});

  final List<String> zones;

  @override
  State<_WalkInDialog> createState() => _WalkInDialogState();
}

class _WalkInDialogState extends State<_WalkInDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late String _zone = widget.zones.first;
  int _party = 2;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มคิว walk-in'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'ชื่อลูกค้า (ไม่บังคับ)',
            ),
          ),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: phoneMaxLength,
            inputFormatters: [phoneCharacters],
            decoration: const InputDecoration(
              labelText: 'เบอร์โทร (ไม่บังคับ)',
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _zone,
            decoration: const InputDecoration(labelText: 'โซน'),
            items:
                widget.zones
                    .map(
                      (zone) =>
                          DropdownMenuItem(value: zone, child: Text(zone)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _zone = value ?? _zone),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'ลดจำนวนคน',
                onPressed: _party > 1 ? () => setState(() => _party--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_party คน', style: const TextStyle(fontSize: 18)),
              IconButton(
                tooltip: 'เพิ่มจำนวนคน',
                onPressed: _party < 10 ? () => setState(() => _party++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed:
              () => Navigator.pop(
                context,
                _WalkIn(
                  _zone,
                  _party,
                  _nameController.text,
                  _phoneController.text,
                ),
              ),
          child: const Text('ออกเลขคิว'),
        ),
      ],
    );
  }
}

/// What the queue cards can do, provided by the board so it can offer undo.
class _BoardActions {
  const _BoardActions({required this.setStatus, required this.close});

  final Future<void> Function(QueueEntry queue, String status) setStatus;
  final void Function(QueueEntry queue, String outcome) close;
}

/// One-tap walk-ins: pick the party size and the number is issued at once.
/// "อื่นๆ" opens the full form for larger groups, a name or a phone.
class _WalkInBar extends StatelessWidget {
  const _WalkInBar({
    required this.zones,
    required this.zone,
    required this.onZone,
    required this.onPartySize,
    required this.onMore,
  });

  final List<String> zones;
  final String zone;
  final ValueChanged<String> onZone;
  final ValueChanged<int> onPartySize;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text(
              'walk-in กี่คน?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (zones.length > 1)
            for (final option in zones)
              ChoiceChip(
                label: Text(option),
                selected: option == zone,
                onSelected: (_) => onZone(option),
              ),
          for (var size = 1; size <= 6; size++)
            SizedBox.square(
              dimension: 48,
              child: FilledButton.tonal(
                onPressed: () => onPartySize(size),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '$size',
                  semanticsLabel: 'walk-in $size คน',
                  style: AppFonts.numbers(fontSize: 20),
                ),
              ),
            ),
          TextButton(onPressed: onMore, child: const Text('อื่นๆ…')),
        ],
      ),
    );
  }
}
