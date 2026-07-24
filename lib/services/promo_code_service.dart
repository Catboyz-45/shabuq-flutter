import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCodeService {
  PromoCodeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Map<String, dynamic>>> watchCodes() {
    return _firestore.collection('promoCodes').snapshots().map((snapshot) {
      final codes =
          snapshot.docs
              .map(
                (document) => <String, dynamic>{
                  'id': document.id,
                  ...document.data(),
                },
              )
              .toList();
      codes.sort(
        (a, b) => (a['code'] as String).compareTo(b['code'] as String),
      );
      return codes;
    });
  }

  Future<void> createCode({
    required String code,
    required String name,
    required int value,
  }) {
    return _firestore.collection('promoCodes').doc(code).set({
      'code': code,
      'name': name.trim(),
      'value': value,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCode({
    required String code,
    required String name,
    required int value,
    required bool active,
  }) {
    return _firestore.collection('promoCodes').doc(code).update({
      'name': name.trim(),
      'value': value,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCode(String code) {
    return _firestore.collection('promoCodes').doc(code).delete();
  }
}
