import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'queue_service.dart';

class AccountService {
  AccountService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Deletes the signed-in customer's data, then their login.
  ///
  /// Re-authenticating first guarantees the final [User.delete] will not fail
  /// with requires-recent-login after the Firestore data is already gone.
  /// Payments and queue history stay as the shop's records (rules forbid
  /// deleting them from the client).
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('กรุณาเข้าสู่ระบบอีกครั้ง');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );

    await QueueService(firestore: _firestore).cancelMyQueue(user.uid);

    final userDoc = _firestore.collection('users').doc(user.uid);
    final coupons = await userDoc.collection('coupons').get();
    final batch = _firestore.batch();
    for (final coupon in coupons.docs) {
      batch.delete(coupon.reference);
    }
    batch.delete(userDoc);
    await batch.commit();

    await user.delete();
  }
}
