import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/queue_position.dart';

/// Customer-side queue access. Each active queue lives at queues/{uid} and has
/// an anonymous mirror at queueTickets/{paymentId} that other customers may
/// read to work out their position without seeing who is in line.
class QueueService {
  QueueService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> queueOf(String uid) =>
      _firestore.collection('queues').doc(uid);

  DocumentReference<Map<String, dynamic>> ticketOf(String paymentId) =>
      _firestore.collection('queueTickets').doc(paymentId);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMyQueue(String uid) {
    return queueOf(uid).snapshots();
  }

  Stream<List<QueueTicket>> watchWaitingTickets({
    required String shopId,
    required String zone,
  }) {
    return _waitingTickets(shopId: shopId, zone: zone).snapshots().map(
      (snapshot) =>
          snapshot.docs.map((document) {
            final createdAt = document.data()['createdAt'];
            return QueueTicket(
              id: document.id,
              createdAt:
                  createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
            );
          }).toList(),
    );
  }

  Future<int> countWaiting(String shopId) async {
    final snapshot =
        await _firestore
            .collection('queueTickets')
            .where('shopId', isEqualTo: shopId)
            .where('status', isEqualTo: 'waiting')
            .count()
            .get();
    return snapshot.count ?? 0;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyHistory(String uid) {
    return _firestore
        .collection('queueHistory')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  /// Removes the customer's active queue and its ticket together.
  Future<void> cancelMyQueue(String uid) async {
    final queue = await queueOf(uid).get();
    if (!queue.exists) return;
    final batch = _firestore.batch()..delete(queueOf(uid));
    final paymentId = queue.data()?['paymentId'];
    if (paymentId is String && paymentId.isNotEmpty) {
      batch.delete(ticketOf(paymentId));
    }
    await batch.commit();
  }

  Query<Map<String, dynamic>> _waitingTickets({
    required String shopId,
    required String zone,
  }) {
    return _firestore
        .collection('queueTickets')
        .where('shopId', isEqualTo: shopId)
        .where('zone', isEqualTo: zone)
        .where('status', isEqualTo: 'waiting');
  }
}
