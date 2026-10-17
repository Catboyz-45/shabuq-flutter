import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/queue_service.dart';
import '../services/shop_service.dart';
import '../utils/queue_position.dart';

/// Shows the customer's active queue and history. Everything streams from
/// Firestore, so the position updates as soon as the shop changes a status.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final _queueService = QueueService();
  final _shopService = ShopService();

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 149, 144, 248),
        foregroundColor: Colors.white,
        title: const Text('คิวของฉัน'),
      ),
      body:
          uid == null
              ? const Center(child: Text('กรุณาเข้าสู่ระบบอีกครั้ง'))
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _queueService.watchMyQueue(uid),
                builder: (context, queueSnapshot) {
                  if (queueSnapshot.hasError) {
                    return const Center(
                      child: Text('ไม่สามารถโหลดข้อมูลคิวได้ กรุณาลองใหม่'),
                    );
                  }
                  if (!queueSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final queue = queueSnapshot.data!.data();
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (queue != null) ...[
                        Text(
                          'คิวปัจจุบัน',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        _ActiveQueueCard(
                          key: ValueKey(queue['ticketId']),
                          queue: queue,
                          queueService: _queueService,
                          shopService: _shopService,
                          onCancel: () => _cancelQueue(uid),
                        ),
                        const SizedBox(height: 24),
                      ],
                      _QueueHistory(
                        stream: _queueService.watchMyHistory(uid),
                        hasActiveQueue: queue != null,
                      ),
                    ],
                  );
                },
              ),
    );
  }
}

class _ActiveQueueCard extends StatefulWidget {
  const _ActiveQueueCard({
    super.key,
    required this.queue,
    required this.queueService,
    required this.shopService,
    required this.onCancel,
  });

  final Map<String, dynamic> queue;
  final QueueService queueService;
  final ShopService shopService;
  final VoidCallback onCancel;

  @override
  State<_ActiveQueueCard> createState() => _ActiveQueueCardState();
}

class _ActiveQueueCardState extends State<_ActiveQueueCard> {
  late final Stream<List<QueueTicket>> _tickets;
  late final Stream<Map<String, dynamic>?> _shop;

  @override
  void initState() {
    super.initState();
    _tickets = widget.queueService.watchWaitingTickets(
      shopId: widget.queue['shopId'] as String? ?? '',
      zone: widget.queue['zone'] as String? ?? '',
    );
    _shop = widget.shopService.watchShop(
      widget.queue['shopId'] as String? ?? '-',
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    final zone = queue['zone'] as String? ?? '';
    final ticketId = queue['ticketId'] as String? ?? '';
    final status = queue['status'] as String? ?? 'waiting';
    final createdAt = queue['createdAt'];
    final ownCreatedAt =
        createdAt is Timestamp ? createdAt.toDate() : DateTime.now();

    return StreamBuilder<List<QueueTicket>>(
      stream: _tickets,
      builder: (context, ticketSnapshot) {
        final ahead =
            ticketSnapshot.hasData
                ? queuesAhead(
                  waitingTickets: ticketSnapshot.data!,
                  ownTicketId: ticketId,
                  ownCreatedAt: ownCreatedAt,
                )
                : null;
        final progress =
            ahead == null ? null : queueProgress(status: status, ahead: ahead);
        final colors = Theme.of(context).colorScheme;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            queue['shopName'] as String? ?? '',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text('$zone • ${queue['partySize'] ?? 0} คน'),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        const Text('เลขคิว'),
                        Text(
                          queue['queueLabel'] as String? ?? '-',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (ticketSnapshot.hasError)
                  const Text('โหลดลำดับคิวไม่สำเร็จ')
                else if (progress == null)
                  const LinearProgressIndicator()
                else
                  StreamBuilder<Map<String, dynamic>?>(
                    stream: _shop,
                    builder:
                        (context, shopSnapshot) => _ProgressBanner(
                          progress: progress,
                          ahead: ahead!,
                          minutesPerQueue:
                              (shopSnapshot.data?['minutesPerQueue'] as num?)
                                  ?.toDouble(),
                        ),
                  ),
                if (progress != QueueProgress.serving) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: widget.onCancel,
                      icon: Icon(Icons.close, color: colors.error),
                      label: Text(
                        'ยกเลิกคิว',
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({
    required this.progress,
    required this.ahead,
    required this.minutesPerQueue,
  });

  final QueueProgress progress;
  final int ahead;
  final double? minutesPerQueue;

  @override
  Widget build(BuildContext context) {
    final wait = estimateWaitMinutes(
      ahead: ahead,
      minutesPerQueue: minutesPerQueue,
    );
    final (
      IconData icon,
      Color color,
      String title,
      String detail,
    ) = switch (progress) {
      QueueProgress.called => (
        Icons.campaign,
        Colors.green,
        'ถึงคิวแล้ว!',
        'เชิญที่หน้าร้าน แจ้งเลขคิวกับพนักงานได้เลย',
      ),
      QueueProgress.serving => (
        Icons.restaurant,
        Colors.teal,
        'กำลังใช้บริการ',
        'ขอให้อร่อยกับมื้อนี้',
      ),
      QueueProgress.next => (
        Icons.hourglass_top,
        Colors.orange,
        'คิวถัดไป',
        'ประมาณ $wait นาที กรุณาเตรียมตัวใกล้ร้าน',
      ),
      QueueProgress.waiting => (
        Icons.schedule,
        Colors.deepPurple,
        'รออีก $ahead คิว',
        'ประมาณ $wait นาที • อัปเดตอัตโนมัติ',
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueHistory extends StatelessWidget {
  const _QueueHistory({required this.stream, required this.hasActiveQueue});

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool hasActiveQueue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('โหลดประวัติการใช้บริการไม่สำเร็จ');
        }
        if (!snapshot.hasData) return const SizedBox.shrink();
        final items =
            snapshot.data!.docs.map((document) => document.data()).toList()
              ..sort(
                (left, right) => _dateOf(
                  right['completedAt'],
                ).compareTo(_dateOf(left['completedAt'])),
              );
        if (items.isEmpty) {
          return hasActiveQueue
              ? const SizedBox.shrink()
              : const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: Text('ยังไม่มีการจอง')),
              );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ประวัติการใช้บริการ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.history)),
                  title: Text(
                    '${item['queueLabel'] ?? ''} ${item['shopName'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${item['zone'] ?? ''} • ${item['partySize'] ?? 0} คน\n'
                    '${_formatDate(_dateOf(item['completedAt']))}',
                  ),
                  trailing: Chip(
                    label: Text(switch (item['status']) {
                      'no_show' => 'ไม่มาตามคิว',
                      'cancelled' => 'ร้านยกเลิก',
                      _ => 'เสร็จสิ้น',
                    }),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static DateTime _dateOf(Object? value) {
    return value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '-';
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}
