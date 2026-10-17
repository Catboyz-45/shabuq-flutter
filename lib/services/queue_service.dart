import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/queue_entry.dart';
import '../utils/queue_position.dart';

/// Queue access for customers and shop staff.
///
/// A customer's active queue lives at queues/{uid}; a walk-in added by staff
/// lives at queues/walkin-{ticketId}. Every active queue has an anonymous
/// mirror at queueTickets/{ticketId} that other customers read to work out
/// their position. Numbers come from shops/{shopId}/queueCounters/{zoneCode}
/// and restart every day.
class QueueService {
  QueueService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> queueOf(String queueId) =>
      _firestore.collection('queues').doc(queueId);

  DocumentReference<Map<String, dynamic>> ticketOf(String ticketId) =>
      _firestore.collection('queueTickets').doc(ticketId);

  /// The customer's active queue, or null when they have none.
  Stream<QueueEntry?> watchMyQueue(String uid) {
    return queueOf(uid).snapshots().map(
      (snapshot) => snapshot.exists ? QueueEntry.fromSnapshot(snapshot) : null,
    );
  }

  /// Waiting tickets in a zone, as confirmed by the server. Snapshots served
  /// only from the local cache are skipped: right after booking the cache
  /// holds just the customer's own ticket, which would read as "first in line".
  Stream<List<QueueTicket>> watchWaitingTickets({
    required String shopId,
    required String zone,
    required String queueDate,
  }) {
    return _firestore
        .collection('queueTickets')
        .where('shopId', isEqualTo: shopId)
        .where('zone', isEqualTo: zone)
        .where('queueDate', isEqualTo: queueDate)
        .where('status', isEqualTo: 'waiting')
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.isFromCache)
        .map(
          (snapshot) =>
              snapshot.docs.map((document) {
                final createdAt = document.data()['createdAt'];
                return QueueTicket(
                  id: document.id,
                  createdAt:
                      createdAt is Timestamp
                          ? createdAt.toDate()
                          : DateTime.now(),
                );
              }).toList(),
        );
  }

  /// Today's waiting queues at a shop; unclosed queues from earlier days
  /// are not counted.
  Stream<int> watchWaitingCount(String shopId) {
    return _firestore
        .collection('queueTickets')
        .where('shopId', isEqualTo: shopId)
        .where('queueDate', isEqualTo: queueDateKey(DateTime.now()))
        .where('status', isEqualTo: 'waiting')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// The customer's closed queues, newest first.
  Stream<List<QueueEntry>> watchMyHistory(String uid) {
    return _firestore
        .collection('queueHistory')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(QueueEntry.fromSnapshot).toList()..sort(
                (left, right) => (right.completedAt ?? DateTime(0)).compareTo(
                  left.completedAt ?? DateTime(0),
                ),
              ),
        );
  }

  /// Gives the signed-in customer the next number in [zone]. Payment happens
  /// at the shop, so booking is a single tap.
  Future<String> bookQueue({
    required String uid,
    required String shopId,
    required String zone,
    required int partySize,
  }) {
    return _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(queueOf(uid));
      if (existing.exists) {
        throw StateError('คุณมีคิวที่กำลังใช้งานอยู่แล้ว');
      }
      return _issueQueue(
        transaction,
        queueId: uid,
        userId: uid,
        shopId: shopId,
        zone: zone,
        partySize: partySize,
      );
    });
  }

  /// Adds a queue for a customer without the app. Only shop staff may do this.
  Future<String> addWalkIn({
    required String shopId,
    required String zone,
    required int partySize,
    required String customerName,
  }) {
    return _firestore.runTransaction((transaction) {
      final ticketId = _firestore.collection('queueTickets').doc().id;
      return _issueQueue(
        transaction,
        queueId: 'walkin-$ticketId',
        ticketId: ticketId,
        userId: '',
        shopId: shopId,
        zone: zone,
        partySize: partySize,
        customerName: customerName.trim(),
      );
    });
  }

  Future<String> _issueQueue(
    Transaction transaction, {
    required String queueId,
    required String userId,
    required String shopId,
    required String zone,
    required int partySize,
    String? ticketId,
    String customerName = '',
  }) async {
    final shopReference = _firestore.collection('shops').doc(shopId);
    final shop = (await transaction.get(shopReference)).data();
    if (shop == null || shop['active'] == false) {
      throw StateError('ร้านนี้ปิดให้บริการแล้ว');
    }
    if (shop['acceptingQueues'] == false) {
      throw StateError('ร้านปิดรับคิวชั่วคราว');
    }
    final zones = (shop['zones'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final zoneCode = zoneCodeFor(zones, zone);
    final counterReference = shopReference
        .collection('queueCounters')
        .doc(zoneCode);
    final counter = (await transaction.get(counterReference)).data();
    final today = queueDateKey(DateTime.now());
    final number = nextQueueNumber(
      counterDate: counter?['date'] as String?,
      counterLast: counter?['last'] as int?,
      today: today,
    );
    final label = formatQueueLabel(zoneCode, number);
    final ticket =
        ticketId == null
            ? _firestore.collection('queueTickets').doc()
            : ticketOf(ticketId);
    final createdAt = FieldValue.serverTimestamp();

    transaction.set(counterReference, {'date': today, 'last': number});
    transaction.set(queueOf(queueId), {
      'userId': userId,
      'shopId': shopId,
      'shopName': shop['name'],
      'zone': zone,
      'zoneCode': zoneCode,
      'partySize': partySize,
      'ticketId': ticket.id,
      'queueNumber': number,
      'queueLabel': label,
      'queueDate': today,
      'walkIn': userId.isEmpty,
      'customerName': customerName,
      'status': 'waiting',
      'createdAt': createdAt,
    });
    transaction.set(ticket, {
      'shopId': shopId,
      'zone': zone,
      'queueLabel': label,
      'queueDate': today,
      'status': 'waiting',
      'createdAt': createdAt,
    });
    return label;
  }

  /// Removes the customer's own active queue and its ticket together.
  Future<void> cancelMyQueue(String uid) async {
    final queue = await queueOf(uid).get();
    if (!queue.exists) return;
    final batch = _firestore.batch()..delete(queueOf(uid));
    final ticketId = queue.data()?['ticketId'];
    if (ticketId is String && ticketId.isNotEmpty) {
      batch.delete(ticketOf(ticketId));
    }
    await batch.commit();
  }
}
