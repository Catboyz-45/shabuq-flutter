import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/queue_entry.dart';
import '../utils/queue_position.dart';

class AdminProfile {
  const AdminProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.active,
    required this.shopId,
    required this.shopName,
  });

  final String uid;
  final String email;
  final String displayName;
  final bool active;
  final String shopId;
  final String shopName;

  factory AdminProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return AdminProfile(
      uid: document.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      active: data['active'] as bool? ?? false,
      shopId: data['shopId'] as String? ?? '',
      shopName: data['shopName'] as String? ?? '',
    );
  }
}

class AdminService {
  AdminService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _authOverride = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _authOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// A Super Admin is any account with a superAdmins/{uid} document. That
  /// collection is read-only for clients and is managed in the Firebase Console.
  Stream<bool> watchIsSuperAdmin(User user) {
    return _firestore
        .collection('superAdmins')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  /// Whether [user] is an active shop admin, as confirmed by the server so a
  /// cached document never grants or hides admin screens. Being a stream, it
  /// stops reading as soon as the screen that listens to it goes away.
  Stream<bool> watchIsShopAdmin(User user) {
    return _firestore
        .collection('admins')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.isFromCache)
        .map((snapshot) => snapshot.data()?['active'] == true);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUsers() {
    return _firestore.collection('users').snapshots();
  }

  Stream<List<AdminProfile>> watchAdmins() {
    return _firestore.collection('admins').snapshots().map((snapshot) {
      final admins = snapshot.docs
          .map(AdminProfile.fromDocument)
          .toList(growable: false);
      return admins..sort(
        (left, right) =>
            left.email.toLowerCase().compareTo(right.email.toLowerCase()),
      );
    });
  }

  Future<void> addAdmin({
    required String uid,
    required String email,
    required String displayName,
    required String shopId,
    required String shopName,
  }) {
    return _firestore.collection('admins').doc(uid).set({
      'uid': uid,
      'email': email.trim(),
      'displayName': displayName.trim(),
      'active': true,
      'shopId': shopId,
      'shopName': shopName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAdmin({
    required AdminProfile admin,
    required String displayName,
    required bool active,
    required String shopId,
    required String shopName,
  }) {
    return _firestore.collection('admins').doc(admin.uid).update({
      'displayName': displayName.trim(),
      'active': active,
      'shopId': shopId,
      'shopName': shopName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeAdmin(AdminProfile admin) {
    return _firestore.collection('admins').doc(admin.uid).delete();
  }

  Stream<AdminProfile?> watchAdmin(String uid) {
    return _firestore.collection('admins').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return AdminProfile.fromDocument(snapshot);
    });
  }

  /// The shop's active queues, oldest first.
  Stream<List<QueueEntry>> watchShopQueues(String shopId) {
    return _firestore
        .collection('queues')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(QueueEntry.fromSnapshot).toList()..sort(
                (left, right) => (left.createdAt ?? DateTime.now()).compareTo(
                  right.createdAt ?? DateTime.now(),
                ),
              ),
        );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchShopQueueHistory(
    String shopId,
  ) {
    return _firestore
        .collection('queueHistory')
        .where('shopId', isEqualTo: shopId)
        .snapshots();
  }

  /// Moves an active queue between waiting, called and serving, keeping its
  /// public ticket in step. Calling a queue records when, for no-show checks.
  Future<void> setQueueStatus({
    required String queueId,
    required String status,
  }) async {
    if (!activeStatuses.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    final queueReference = _firestore.collection('queues').doc(queueId);
    final queue = await queueReference.get();
    final ticketId = queue.data()?['ticketId'];
    final batch =
        _firestore.batch()..update(queueReference, {
          'status': status,
          if (status == 'called') 'calledAt': FieldValue.serverTimestamp(),
        });
    if (ticketId is String && ticketId.isNotEmpty) {
      batch.update(_firestore.collection('queueTickets').doc(ticketId), {
        'status': status,
      });
    }
    await batch.commit();
  }

  /// Calls the oldest waiting queue in [zone] and returns its label, or null
  /// when nobody is waiting. Also updates the shop's pace for wait estimates.
  Future<String?> callNext({
    required String shopId,
    required String zone,
  }) async {
    final waiting =
        await _firestore
            .collection('queues')
            .where('shopId', isEqualTo: shopId)
            .where('zone', isEqualTo: zone)
            .where('queueDate', isEqualTo: queueDateKey(DateTime.now()))
            .where('status', isEqualTo: 'waiting')
            .get();
    if (waiting.docs.isEmpty) return null;
    var next = waiting.docs.first;
    for (final candidate in waiting.docs.skip(1)) {
      if (_timeOf(
        candidate.data()['createdAt'],
      ).isBefore(_timeOf(next.data()['createdAt']))) {
        next = candidate;
      }
    }
    await setQueueStatus(queueId: next.id, status: 'called');
    await _recordCall(shopId);
    return next.data()['queueLabel'] as String?;
  }

  Future<void> _recordCall(String shopId) async {
    final shopReference = _firestore.collection('shops').doc(shopId);
    final shop = (await shopReference.get()).data() ?? const {};
    final lastCalledAt = shop['lastCalledAt'];
    final previous = (shop['minutesPerQueue'] as num?)?.toDouble();
    final pace =
        lastCalledAt is Timestamp
            ? nextMinutesPerQueue(
              previous: previous,
              intervalMinutes:
                  DateTime.now().difference(lastCalledAt.toDate()).inSeconds /
                  60,
            )
            : previous;
    await shopReference.update({
      'lastCalledAt': FieldValue.serverTimestamp(),
      if (pace != null) 'minutesPerQueue': pace,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Closes an active queue as completed, no-show or cancelled by moving it to
  /// queueHistory/{ticketId} and deleting the queue and its ticket.
  Future<void> closeQueue({
    required String queueId,
    required String outcome,
  }) async {
    if (!closedStatuses.contains(outcome)) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError('กรุณาเข้าสู่ระบบอีกครั้ง');
    }
    final queueReference = _firestore.collection('queues').doc(queueId);

    await _firestore.runTransaction((transaction) async {
      final queueSnapshot = await transaction.get(queueReference);
      final queueData = queueSnapshot.data();
      if (!queueSnapshot.exists || queueData == null) {
        throw StateError('ไม่พบคิวนี้');
      }
      final ticketId = queueData['ticketId'];
      if (ticketId is! String || ticketId.isEmpty) {
        throw StateError('ข้อมูลคิวไม่สมบูรณ์');
      }

      transaction.set(_firestore.collection('queueHistory').doc(ticketId), {
        ...queueData,
        'queueId': queueId,
        'status': outcome,
        'completedAt': FieldValue.serverTimestamp(),
        'completedBy': currentUser.uid,
      });
      transaction.delete(queueReference);
      transaction.delete(_firestore.collection('queueTickets').doc(ticketId));
    });
  }

  /// Closes several queues one by one (each in its own transaction) and
  /// returns how many were closed. Used for leftovers from earlier days and
  /// at closing time.
  Future<int> closeQueues({
    required Iterable<String> queueIds,
    required String outcome,
  }) async {
    var closed = 0;
    for (final queueId in queueIds) {
      try {
        await closeQueue(queueId: queueId, outcome: outcome);
        closed++;
      } on StateError {
        // Already closed, or cancelled by the customer meanwhile.
      }
    }
    return closed;
  }

  static DateTime _timeOf(Object? value) =>
      value is Timestamp ? value.toDate() : DateTime.now();
}
