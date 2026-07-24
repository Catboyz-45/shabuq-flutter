import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _historyItems = [];
  List<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _shopQueuesList = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQueues();
  }

  Future<void> _loadQueues() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _items = [];
          _historyItems = [];
          _shopQueuesList = [];
          _loading = false;
          _error = 'กรุณาเข้าสู่ระบบอีกครั้ง';
        });
      }
      return;
    }

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('queues')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt')
            .get(),
        FirebaseFirestore.instance
            .collection('queueHistory')
            .where('userId', isEqualTo: uid)
            .get(),
      ]);
      final snap = results.first;
      final historySnapshot = results.last;
      final items =
          snap.docs.map((doc) {
            final data = doc.data();
            final createdAt = data['createdAt'];
            return <String, dynamic>{
              'id': doc.id,
              'shopId': data['shopId'] as String? ?? '',
              'shopName': data['shopName'] as String? ?? '',
              'zone': data['zone'] as String? ?? '',
              'partySize': data['partySize'] as int? ?? 0,
              'date':
                  createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
            };
          }).toList();
      final historyItems =
          historySnapshot.docs.map((doc) {
              final data = doc.data();
              final completedAt = data['completedAt'];
              return <String, dynamic>{
                'id': doc.id,
                'shopName': data['shopName'] as String? ?? '',
                'zone': data['zone'] as String? ?? '',
                'partySize': data['partySize'] as int? ?? 0,
                'completedAt':
                    completedAt is Timestamp
                        ? completedAt.toDate()
                        : DateTime.fromMillisecondsSinceEpoch(0),
              };
            }).toList()
            ..sort(
              (left, right) => (right['completedAt'] as DateTime).compareTo(
                left['completedAt'] as DateTime,
              ),
            );

      final queues = await Future.wait(
        items.map((item) {
          return FirebaseFirestore.instance
              .collection('queues')
              .where('shopId', isEqualTo: item['shopId'])
              .where('zone', isEqualTo: item['zone'])
              .orderBy('createdAt')
              .get()
              .then((result) => result.docs);
        }),
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _historyItems = historyItems;
        _shopQueuesList = queues;
        _loading = false;
      });
    } on FirebaseException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'ไม่สามารถโหลดข้อมูลคิวได้ กรุณาลองใหม่';
      });
    }
  }

  Future<void> _cancelQueue(String queueId) async {
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || queueId != uid) {
        throw StateError('ไม่มีสิทธิ์ยกเลิกคิวนี้');
      }
      await FirebaseFirestore.instance.collection('queues').doc(uid).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ยกเลิกคิวเรียบร้อย')));
      await _loadQueues();
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยกเลิกคิวไม่สำเร็จ กรุณาลองใหม่')),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 149, 144, 248),
        foregroundColor: Colors.white,
        title: const Text('คิวของฉัน'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadQueues)
              : _items.isEmpty && _historyItems.isEmpty
              ? const Center(child: Text('ยังไม่มีการจอง'))
              : RefreshIndicator(
                onRefresh: _loadQueues,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_items.isNotEmpty)
                      Text(
                        'คิวปัจจุบัน',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
                      final shopQueues = _shopQueuesList[index];
                      final queueIndex = shopQueues.indexWhere(
                        (doc) => doc.id == item['id'],
                      );
                      final queuesAhead = queueIndex < 0 ? 0 : queueIndex;
                      return Dismissible(
                        key: ValueKey(item['id']),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _cancelQueue(item['id'] as String);
                          return false;
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          color: Colors.red,
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(
                              '${item['shopName']} (${item['zone']})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'วันที่ ${(item['date'] as DateTime).toIso8601String().substring(0, 10)}\n'
                              'จำนวนที่นั่ง ${item['partySize']}',
                            ),
                            trailing:
                                queuesAhead == 0
                                    ? const Text(
                                      'ถึงคิวแล้ว',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                    : Text(
                                      'รอ $queuesAhead คิว',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                        ),
                      );
                    }),
                    if (_historyItems.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'ประวัติการใช้บริการ',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ..._historyItems.map(
                        (item) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.history),
                            ),
                            title: Text(
                              '${item['shopName']} (${item['zone']})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'จำนวนที่นั่ง ${item['partySize']}\n'
                              'เสร็จสิ้น ${_formatDate(item['completedAt'] as DateTime)}',
                            ),
                            trailing: const Chip(label: Text('เสร็จสิ้น')),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'รีเฟรชข้อมูล',
        onPressed: _loading ? null : _loadQueues,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '-';
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}
