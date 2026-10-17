import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/queue_service.dart';
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

  Future<void> _cancelQueue(String uid, {bool askFirst = true}) async {
    if (askFirst) {
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
    }

    try {
      await _queueService.cancelMyQueue(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(askFirst ? 'ยกเลิกคิวเรียบร้อย' : 'ลบคิวออกแล้ว'),
        ),
      );
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
                          queue: queue,
                          queueService: _queueService,
                          onCancel: () => _cancelQueue(uid),
                          onDismissCancelled:
                              () => _cancelQueue(uid, askFirst: false),
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

class _ActiveQueueCard extends StatelessWidget {
  const _ActiveQueueCard({
    required this.queue,
    required this.queueService,
    required this.onCancel,
    required this.onDismissCancelled,
  });

  final Map<String, dynamic> queue;
  final QueueService queueService;
  final VoidCallback onCancel;
  final VoidCallback onDismissCancelled;

  @override
  Widget build(BuildContext context) {
    final shopId = queue['shopId'] as String? ?? '';
    final zone = queue['zone'] as String? ?? '';
    final paymentId = queue['paymentId'] as String? ?? '';
    final status = queue['status'] as String? ?? 'waiting';
    final createdAt = queue['createdAt'];
    final ownCreatedAt =
        createdAt is Timestamp ? createdAt.toDate() : DateTime.now();

    return StreamBuilder<List<QueueTicket>>(
      stream: queueService.watchWaitingTickets(shopId: shopId, zone: zone),
      builder: (context, ticketSnapshot) {
        final ahead =
            ticketSnapshot.hasData
                ? queuesAhead(
                  waitingTickets: ticketSnapshot.data!,
                  ownTicketId: paymentId,
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
                Text(
                  '${queue['shopName'] ?? ''} ($zone)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'คิว ${paymentId.length >= 6 ? paymentId.substring(0, 6).toUpperCase() : '-'}'
                  ' • ${queue['partySize'] ?? 0} คน',
                ),
                const SizedBox(height: 16),
                if (ticketSnapshot.hasError)
                  const Text('โหลดลำดับคิวไม่สำเร็จ')
                else if (progress == null)
                  const LinearProgressIndicator()
                else
                  _ProgressBanner(progress: progress, ahead: ahead!),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child:
                      progress == QueueProgress.cancelled
                          ? FilledButton.tonal(
                            onPressed: onDismissCancelled,
                            child: const Text('ลบคิวนี้'),
                          )
                          : progress == QueueProgress.serving
                          ? const SizedBox.shrink()
                          : TextButton.icon(
                            onPressed: onCancel,
                            icon: Icon(Icons.close, color: colors.error),
                            label: Text(
                              'ยกเลิกคิว',
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.progress, required this.ahead});

  final QueueProgress progress;
  final int ahead;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      Color color,
      String title,
      String detail,
    ) = switch (progress) {
      QueueProgress.serving => (
        Icons.restaurant,
        Colors.green,
        'ถึงคิวแล้ว',
        'เชิญที่หน้าร้านได้เลย',
      ),
      QueueProgress.next => (
        Icons.hourglass_top,
        Colors.orange,
        'คิวถัดไป',
        'กรุณาเตรียมตัวใกล้ร้าน',
      ),
      QueueProgress.waiting => (
        Icons.schedule,
        Colors.deepPurple,
        'รออีก $ahead คิว',
        'ลำดับจะอัปเดตอัตโนมัติ',
      ),
      QueueProgress.cancelled => (
        Icons.cancel,
        Colors.red,
        'ร้านยกเลิกคิวนี้',
        'กรุณาติดต่อร้านหรือจองใหม่',
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
                    '${item['shopName'] ?? ''} (${item['zone'] ?? ''})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'จำนวนที่นั่ง ${item['partySize'] ?? 0}\n'
                    'เสร็จสิ้น ${_formatDate(_dateOf(item['completedAt']))}',
                  ),
                  trailing: const Chip(label: Text('เสร็จสิ้น')),
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
