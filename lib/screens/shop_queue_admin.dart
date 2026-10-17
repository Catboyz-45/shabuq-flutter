import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/queue_service.dart';
import '../services/shop_service.dart';
import '../utils/queue_position.dart';
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
  late final Stream<Map<String, dynamic>?> _shop;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _queues;
  String? _callingZone;

  String get _shopId => widget.admin.shopId;

  @override
  void initState() {
    super.initState();
    _shop = _shopService.watchShop(_shopId);
    _queues = widget.adminService.watchShopQueues(_shopId);
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
      _showMessage(
        label == null ? 'ไม่มีคิวรอในโซน $zone' : 'เรียกคิว $label แล้ว',
      );
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
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _shop,
      builder: (context, shopSnapshot) {
        final shop = shopSnapshot.data;
        final zones =
            (shop?['zones'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<String>()
                .toList();
        if (zones.isEmpty) zones.add('ทั่วไป');
        final accepting = shop?['acceptingQueues'] != false;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _queues,
          builder: (context, queueSnapshot) {
            if (queueSnapshot.hasError) {
              return const Center(child: Text('โหลดข้อมูลคิวของร้านไม่สำเร็จ'));
            }
            if (!queueSnapshot.hasData || shop == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final byZone =
                <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{
                  for (final zone in zones) zone: [],
                };
            final today = queueDateKey(DateTime.now());
            final stale = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            for (final document in queueSnapshot.data!.docs) {
              if (isStaleQueue(
                document.data()['queueDate'] as String?,
                today: today,
              )) {
                stale.add(document);
                continue;
              }
              final zone = document.data()['zone'] as String? ?? zones.first;
              byZone.putIfAbsent(zone, () => []).add(document);
            }
            for (final list in byZone.values) {
              list.sort(
                (left, right) => _timeOf(
                  left.data()['createdAt'],
                ).compareTo(_timeOf(right.data()['createdAt'])),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Card(
                  color:
                      accepting
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.errorContainer,
                  child: SwitchListTile(
                    value: accepting,
                    onChanged: _setAccepting,
                    secondary: Icon(
                      accepting ? Icons.play_circle : Icons.pause_circle,
                    ),
                    title: Text(
                      accepting ? 'เปิดรับคิวอยู่' : 'ปิดรับคิวชั่วคราว',
                    ),
                    subtitle: const Text('ลูกค้าจะรับคิวใหม่ไม่ได้เมื่อปิด'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addWalkIn(zones),
                        icon: const Icon(Icons.person_add),
                        label: const Text('เพิ่มคิว walk-in'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _redeemCoupon,
                        icon: const Icon(Icons.local_offer),
                        label: const Text('ใช้คูปองลูกค้า'),
                      ),
                    ),
                  ],
                ),
                if (stale.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.history_toggle_off),
                      title: Text('คิวค้างจากวันก่อน ${stale.length} คิว'),
                      subtitle: Text(
                        stale
                            .map((doc) => doc.data()['queueLabel'] ?? '-')
                            .join(', '),
                      ),
                      trailing: FilledButton.tonal(
                        onPressed:
                            _closing
                                ? null
                                : () => _closeAll(
                                  stale.map((doc) => doc.id).toList(),
                                  title: 'ปิดคิวค้างจากวันก่อน',
                                ),
                        child: const Text('ปิดทั้งหมด'),
                      ),
                    ),
                  ),
                ],
                for (final entry in byZone.entries) ...[
                  const SizedBox(height: 20),
                  _ZoneHeader(
                    zone: entry.key,
                    waiting:
                        entry.value
                            .where((doc) => doc.data()['status'] == 'waiting')
                            .length,
                    calling: _callingZone == entry.key,
                    onCallNext:
                        _callingZone == null
                            ? () => _callNext(entry.key)
                            : null,
                  ),
                  if (entry.value.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('ไม่มีคิวในโซนนี้'),
                    ),
                  for (final document in entry.value)
                    _QueueCard(
                      key: ValueKey(document.id),
                      document: document,
                      adminService: widget.adminService,
                    ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed:
                      _closing || byZone.values.every((list) => list.isEmpty)
                          ? null
                          : () => _closeAll([
                            for (final list in byZone.values)
                              for (final doc in list) doc.id,
                          ], title: 'ปิดร้าน: ปิดคิวที่เหลือทั้งหมด'),
                  icon: const Icon(Icons.nightlight_round),
                  label: const Text('ปิดร้าน: ปิดคิวที่เหลือทั้งหมด'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static DateTime _timeOf(Object? value) =>
      value is Timestamp ? value.toDate() : DateTime.now();
}

class _ZoneHeader extends StatelessWidget {
  const _ZoneHeader({
    required this.zone,
    required this.waiting,
    required this.calling,
    required this.onCallNext,
  });

  final String zone;
  final int waiting;
  final bool calling;
  final VoidCallback? onCallNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$zone • รอ $waiting คิว',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        FilledButton.icon(
          onPressed: waiting == 0 ? null : onCallNext,
          icon:
              calling
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.campaign),
          label: const Text('เรียกคิวถัดไป'),
        ),
      ],
    );
  }
}

class _QueueCard extends StatefulWidget {
  const _QueueCard({
    super.key,
    required this.document,
    required this.adminService,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final AdminService adminService;

  @override
  State<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<_QueueCard> {
  bool _saving = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // นับเวลาตั้งแต่เรียกคิว เพื่อเปิดปุ่ม "ไม่มา" เมื่อครบเวลา
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
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

  Future<void> _setStatus(String status) => _run(
    () => widget.adminService.setQueueStatus(
      queueId: widget.document.id,
      status: status,
    ),
  );

  Future<void> _close(String outcome) => _run(
    () => widget.adminService.closeQueue(
      queueId: widget.document.id,
      outcome: outcome,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = widget.document.data();
    final status = data['status'] as String? ?? 'waiting';
    final calledAt = data['calledAt'];
    final calledMinutes =
        calledAt is Timestamp
            ? DateTime.now().difference(calledAt.toDate()).inMinutes
            : 0;
    final canSkip = calledMinutes >= noShowGraceMinutes;
    final name = (data['customerName'] as String? ?? '').trim();
    final walkIn = data['walkIn'] == true;

    final (String statusText, Color statusColor) = switch (status) {
      'called' => ('เรียกแล้ว $calledMinutes นาที', Colors.orange),
      'serving' => ('กำลังใช้บริการ', Colors.teal),
      _ => ('รอคิว', Colors.deepPurple),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  data['queueLabel'] as String? ?? '-',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${data['partySize'] ?? 0} คน'
                    '${walkIn ? ' • walk-in' : ''}'
                    '${name.isEmpty ? '' : ' • $name'}',
                  ),
                ),
                Chip(
                  label: Text(statusText),
                  labelStyle: TextStyle(color: statusColor),
                  side: BorderSide(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_saving)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: switch (status) {
                  'waiting' => [
                    FilledButton.tonal(
                      onPressed: () => _setStatus('called'),
                      child: const Text('เรียกคิวนี้'),
                    ),
                    TextButton(
                      onPressed: () => _close('cancelled'),
                      child: const Text('ยกเลิกคิว'),
                    ),
                  ],
                  'called' => [
                    FilledButton(
                      onPressed: () => _setStatus('serving'),
                      child: const Text('ลูกค้ามาแล้ว'),
                    ),
                    OutlinedButton(
                      onPressed: canSkip ? () => _close('no_show') : null,
                      child: Text(
                        canSkip
                            ? 'ไม่มา (ข้ามคิว)'
                            : 'ข้ามได้ใน ${noShowGraceMinutes - calledMinutes} นาที',
                      ),
                    ),
                  ],
                  _ => [
                    FilledButton(
                      onPressed: () => _close('completed'),
                      child: const Text('เสร็จสิ้น'),
                    ),
                  ],
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _WalkIn {
  const _WalkIn(this.zone, this.partySize, this.name);

  final String zone;
  final int partySize;
  final String name;
}

class _WalkInDialog extends StatefulWidget {
  const _WalkInDialog({required this.zones});

  final List<String> zones;

  @override
  State<_WalkInDialog> createState() => _WalkInDialogState();
}

class _WalkInDialogState extends State<_WalkInDialog> {
  final _nameController = TextEditingController();
  late String _zone = widget.zones.first;
  int _party = 2;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มคิว walk-in'),
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
                _WalkIn(_zone, _party, _nameController.text),
              ),
          child: const Text('ออกเลขคิว'),
        ),
      ],
    );
  }
}
