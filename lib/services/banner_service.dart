import 'package:cloud_firestore/cloud_firestore.dart';

/// A promotion banner on the home screen, managed by Super Admins.
class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.shopId,
    required this.order,
    required this.active,
  });

  final String id;
  final String imageUrl;
  final String title;

  /// Shop opened when the banner is tapped; empty for none.
  final String shopId;
  final int order;
  final bool active;

  factory PromoBanner.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return PromoBanner(
      id: document.id,
      imageUrl: data['imageUrl'] as String? ?? '',
      title: data['title'] as String? ?? '',
      shopId: data['shopId'] as String? ?? '',
      order: data['order'] as int? ?? 0,
      active: data['active'] as bool? ?? true,
    );
  }
}

class BannerService {
  BannerService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _banners =>
      _firestore.collection('banners');

  /// All banners in display order; customers filter out inactive ones.
  Stream<List<PromoBanner>> watchBanners({bool activeOnly = true}) {
    return _banners.snapshots().map((snapshot) {
      final banners =
          snapshot.docs
              .map(PromoBanner.fromDocument)
              .where((banner) => !activeOnly || banner.active)
              .toList()
            ..sort((left, right) => left.order.compareTo(right.order));
      return banners;
    });
  }

  Future<void> saveBanner({
    String? id,
    required String imageUrl,
    required String title,
    required String shopId,
    required int order,
    required bool active,
  }) {
    final data = {
      'imageUrl': imageUrl.trim(),
      'title': title.trim(),
      'shopId': shopId,
      'order': order,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      return _banners.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return _banners.doc(id).update(data);
  }

  Future<void> deleteBanner(String id) => _banners.doc(id).delete();
}
