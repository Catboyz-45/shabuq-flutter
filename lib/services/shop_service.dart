import 'package:cloud_firestore/cloud_firestore.dart';

class ShopService {
  ShopService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Map<String, dynamic>>> watchShops({
    bool includeInactive = false,
  }) {
    return _firestore.collection('shops').snapshots().map((snapshot) {
      final shops =
          snapshot.docs
              .map((document) {
                final data = document.data();
                return <String, dynamic>{'id': document.id, ...data};
              })
              .where((shop) => includeInactive || shop['active'] != false)
              .toList();
      shops.sort(
        (left, right) => (left['name'] as String? ?? '').compareTo(
          right['name'] as String? ?? '',
        ),
      );
      return shops;
    });
  }

  Stream<Map<String, dynamic>?> watchShop(String shopId) {
    return _firestore.collection('shops').doc(shopId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      return data == null
          ? null
          : <String, dynamic>{'id': snapshot.id, ...data};
    });
  }

  Future<void> createShop({
    required String id,
    required String name,
    required String location,
    required String phone,
    required String image,
    required List<String> zones,
    required int pricePerPerson,
  }) {
    return _firestore.collection('shops').doc(id).set({
      'name': name.trim(),
      'location': location.trim(),
      'phone': phone.trim(),
      'image': image.trim(),
      'zones': zones.map((zone) => zone.trim()).toList(),
      'pricePerPerson': pricePerPerson,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Settings a shop's own admin may change.
  Future<void> updateShopSettings({
    required String shopId,
    required int pricePerPerson,
    required String openingHours,
  }) {
    return _firestore.collection('shops').doc(shopId).update({
      'pricePerPerson': pricePerPerson,
      'openingHours': openingHours.trim(),
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

  Future<void> updateShop({
    required String shopId,
    required String name,
    required String location,
    required String phone,
    required String image,
    required List<String> zones,
    required int pricePerPerson,
  }) {
    return _firestore.collection('shops').doc(shopId).update({
      'name': name.trim(),
      'location': location.trim(),
      'phone': phone.trim(),
      'image': image.trim(),
      'zones': zones.map((zone) => zone.trim()).toList(),
      'pricePerPerson': pricePerPerson,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setShopActive({required String shopId, required bool active}) {
    return _firestore.collection('shops').doc(shopId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
