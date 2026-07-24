import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const superAdminEmail = 'admin@gmail.com';

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
  AdminService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  bool isSuperAdmin(User user) =>
      user.email?.trim().toLowerCase() == superAdminEmail;

  Stream<bool> watchCurrentUserIsAdmin(User user) async* {
    if (isSuperAdmin(user)) {
      yield true;
      return;
    }

    final reference = _firestore.collection('admins').doc(user.uid);
    final serverSnapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    yield serverSnapshot.data()?['active'] == true;

    await for (final snapshot in reference.snapshots()) {
      yield snapshot.data()?['active'] == true;
    }
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

  Stream<QuerySnapshot<Map<String, dynamic>>> watchShopQueues(String shopId) {
    return _firestore
        .collection('queues')
        .where('shopId', isEqualTo: shopId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchShopQueueHistory(
    String shopId,
  ) {
    return _firestore
        .collection('queueHistory')
        .where('shopId', isEqualTo: shopId)
        .snapshots();
  }

  Future<void> updateQueueStatus({
    required String queueId,
    required String status,
  }) async {
    final queueReference = _firestore.collection('queues').doc(queueId);
    if (status != 'completed') {
      await queueReference.update({'status': status});
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('กรุณาเข้าสู่ระบบอีกครั้ง');
    }

    await _firestore.runTransaction((transaction) async {
      final queueSnapshot = await transaction.get(queueReference);
      final queueData = queueSnapshot.data();
      if (!queueSnapshot.exists || queueData == null) {
        throw StateError('ไม่พบคิวนี้');
      }
      final paymentId = queueData['paymentId'];
      if (paymentId is! String || paymentId.isEmpty) {
        throw StateError('ข้อมูลคิวไม่สมบูรณ์');
      }

      final historyReference = _firestore
          .collection('queueHistory')
          .doc(paymentId);
      transaction.set(historyReference, {
        ...queueData,
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'completedBy': currentUser.uid,
      });
      transaction.delete(queueReference);
    });
  }
}
