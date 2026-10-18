import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.active,
    this.description = '',
    this.imageUrl = '',
    this.price = 0,
  });

  final String id;
  final String name;
  final String category;
  final bool active;
  final String description;
  final String imageUrl;

  /// Extra charge in baht; 0 means included in the buffet price.
  final int price;

  factory MenuItem.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return MenuItem(
      id: document.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      price: data['price'] as int? ?? 0,
    );
  }
}

class MenuService {
  MenuService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _items(String shopId) {
    return _firestore.collection('shops').doc(shopId).collection('menuItems');
  }

  Stream<List<MenuItem>> watchMenu(String shopId) {
    return _items(shopId).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(MenuItem.fromDocument)
          .toList(growable: false);
      return items..sort((left, right) {
        final categoryCompare = left.category.compareTo(right.category);
        return categoryCompare != 0
            ? categoryCompare
            : left.name.compareTo(right.name);
      });
    });
  }

  Future<void> addMenuItem({
    required String shopId,
    required String shopName,
    required String name,
    required String category,
    required bool active,
    String description = '',
    String imageUrl = '',
    int price = 0,
  }) {
    return _items(shopId).add({
      'shopId': shopId,
      'shopName': shopName,
      'name': name.trim(),
      'category': category.trim(),
      'active': active,
      'description': description.trim(),
      'imageUrl': imageUrl.trim(),
      'price': price,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMenuItem({
    required String shopId,
    required MenuItem item,
    required String name,
    required String category,
    required bool active,
    String description = '',
    String imageUrl = '',
    int price = 0,
  }) {
    return _items(shopId).doc(item.id).update({
      'name': name.trim(),
      'category': category.trim(),
      'active': active,
      'description': description.trim(),
      'imageUrl': imageUrl.trim(),
      'price': price,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMenuItem({
    required String shopId,
    required String menuItemId,
  }) {
    return _items(shopId).doc(menuItemId).delete();
  }
}
