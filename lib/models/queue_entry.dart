import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/queue_position.dart';

/// An active queue (queues/{id}) or a closed one (queueHistory/{ticketId}).
class QueueEntry {
  const QueueEntry({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.zone,
    required this.ticketId,
    required this.queueLabel,
    required this.status,
    this.userId = '',
    this.zoneCode = 'A',
    this.partySize = 0,
    this.queueNumber = 0,
    this.queueDate,
    this.walkIn = false,
    this.customerName = '',
    this.createdAt,
    this.calledAt,
    this.completedAt,
  });

  final String id;
  final String userId;
  final String shopId;
  final String shopName;
  final String zone;
  final String zoneCode;
  final int partySize;
  final String ticketId;
  final int queueNumber;
  final String queueLabel;

  /// Bangkok business day the queue was issued on (see queueDateKey).
  final String? queueDate;
  final bool walkIn;
  final String customerName;

  /// waiting / called / serving while active; completed / no_show /
  /// cancelled once in history.
  final String status;

  /// Null while the server timestamp of a fresh write is still pending.
  final DateTime? createdAt;
  final DateTime? calledAt;
  final DateTime? completedAt;

  bool isStale(String today) => isStaleQueue(queueDate, today: today);

  factory QueueEntry.fromMap(String id, Map<String, dynamic> data) {
    DateTime? time(String key) {
      final value = data[key];
      return value is Timestamp ? value.toDate() : null;
    }

    return QueueEntry(
      id: id,
      userId: data['userId'] as String? ?? '',
      shopId: data['shopId'] as String? ?? '',
      shopName: data['shopName'] as String? ?? '',
      zone: data['zone'] as String? ?? '',
      zoneCode: data['zoneCode'] as String? ?? 'A',
      partySize: data['partySize'] as int? ?? 0,
      ticketId: data['ticketId'] as String? ?? '',
      queueNumber: data['queueNumber'] as int? ?? 0,
      queueLabel: data['queueLabel'] as String? ?? '-',
      queueDate: data['queueDate'] as String?,
      walkIn: data['walkIn'] as bool? ?? false,
      customerName: data['customerName'] as String? ?? '',
      status: data['status'] as String? ?? 'waiting',
      createdAt: time('createdAt'),
      calledAt: time('calledAt'),
      completedAt: time('completedAt'),
    );
  }

  factory QueueEntry.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => QueueEntry.fromMap(snapshot.id, snapshot.data() ?? const {});
}
