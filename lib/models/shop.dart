import 'package:cloud_firestore/cloud_firestore.dart';

/// A restaurant, stored at shops/{id}.
class Shop {
  const Shop({
    required this.id,
    required this.name,
    this.location = '',
    this.phone = '',
    this.image = '',
    this.zones = const [],
    this.pricePerPerson = 0,
    this.active = true,
    this.acceptingQueues = true,
    this.openingHours = '',
    this.minutesPerQueue,
  });

  final String id;
  final String name;
  final String location;
  final String phone;

  /// An https link or a bundled `assets/images/...` path; empty for none.
  final String image;
  final List<String> zones;
  final int pricePerPerson;

  /// False when a Super Admin has hidden the shop.
  final bool active;

  /// False while the shop has paused new bookings.
  final bool acceptingQueues;
  final String openingHours;

  /// Average minutes between "call next" presses, for wait estimates.
  final double? minutesPerQueue;

  /// Zones customers can pick; shops without zones get a single default.
  List<String> get bookableZones => zones.isEmpty ? const ['ทั่วไป'] : zones;

  bool get canBook => active && acceptingQueues;

  factory Shop.fromMap(String id, Map<String, dynamic> data) {
    return Shop(
      id: id,
      name: data['name'] as String? ?? '',
      location: data['location'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      image: data['image'] as String? ?? '',
      zones: (data['zones'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((zone) => zone.trim())
          .where((zone) => zone.isNotEmpty)
          .toList(growable: false),
      pricePerPerson: data['pricePerPerson'] as int? ?? 0,
      active: data['active'] as bool? ?? true,
      acceptingQueues: data['acceptingQueues'] as bool? ?? true,
      openingHours: data['openingHours'] as String? ?? '',
      minutesPerQueue: (data['minutesPerQueue'] as num?)?.toDouble(),
    );
  }

  factory Shop.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      Shop.fromMap(snapshot.id, snapshot.data() ?? const {});
}
