import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shop.dart';
import '../utils/shop_form.dart';

class ShopService {
  ShopService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Shops sorted by name; hidden shops only when [includeInactive].
  Stream<List<Shop>> watchShops({bool includeInactive = false}) {
    return _firestore.collection('shops').snapshots().map((snapshot) {
      return snapshot.docs
          .map(Shop.fromSnapshot)
          .where((shop) => includeInactive || shop.active)
          .toList()
        ..sort((left, right) => left.name.compareTo(right.name));
    });
  }

  Stream<Shop?> watchShop(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists ? Shop.fromSnapshot(snapshot) : null,
        );
  }

  /// Creates a shop from the Super Admin form. Fails if the id is taken.
  Future<void> createShop(ShopDraft draft) {
    return _firestore.runTransaction((transaction) async {
      final reference = _firestore.collection('shops').doc(draft.id);
      if ((await transaction.get(reference)).exists) {
        throw StateError('รหัสร้านนี้ถูกใช้แล้ว');
      }
      transaction.set(reference, {
        ..._draftFields(draft),
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Settings a shop's own admin may change.
  Future<void> updateShopSettings({
    required String shopId,
    required int pricePerPerson,
    required String openingHours,
    required String image,
    required String location,
    required String phone,
  }) {
    return _firestore.collection('shops').doc(shopId).update({
      'pricePerPerson': pricePerPerson,
      'openingHours': openingHours.trim(),
      'image': image.trim(),
      'location': location.trim(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setAcceptingQueues({
    required String shopId,
    required bool accepting,
  }) {
    return _firestore.collection('shops').doc(shopId).update({
      'acceptingQueues': accepting,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateShop(ShopDraft draft) {
    return _firestore.collection('shops').doc(draft.id).update({
      ..._draftFields(draft),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Map<String, Object> _draftFields(ShopDraft draft) => {
    'name': draft.name.trim(),
    'location': draft.location.trim(),
    'phone': draft.phone.trim(),
    'image': draft.image.trim(),
    'zones': draft.zones,
    'pricePerPerson': draft.pricePerPerson,
    'openingHours': draft.openingHours.trim(),
  };

  Future<void> setShopActive({required String shopId, required bool active}) {
    return _firestore.collection('shops').doc(shopId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
