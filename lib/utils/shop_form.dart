import 'image_source.dart';

/// Shop ids become document ids and part of nothing user-facing, so they are
/// kept to lower-case letters, digits and dashes. Matches firestore.rules.
final shopIdPattern = RegExp(r'^[a-z0-9][a-z0-9-]{2,49}$');

/// What the shop form produces, before it is saved.
class ShopDraft {
  const ShopDraft({
    required this.id,
    required this.name,
    required this.location,
    required this.phone,
    required this.image,
    required this.zones,
    required this.pricePerPerson,
    required this.openingHours,
  });

  final String id;
  final String name;
  final String location;
  final String phone;
  final String image;
  final List<String> zones;
  final int pricePerPerson;
  final String openingHours;
}

/// "ในร้าน, ระเบียง ,ในร้าน" → ['ในร้าน', 'ระเบียง'], keeping the order
/// because the first zone gets queue letter A, the second B and so on.
List<String> parseZones(String input) {
  final zones = <String>[];
  for (final zone in input.split(',').map((zone) => zone.trim())) {
    if (zone.isNotEmpty && !zones.contains(zone)) zones.add(zone);
  }
  return zones;
}

/// Thai error message for the first problem in [draft], or null when it can
/// be saved. [isNew] also checks the id, which can't change later.
String? validateShopDraft(ShopDraft draft, {required bool isNew}) {
  if (isNew && !shopIdPattern.hasMatch(draft.id)) {
    return 'รหัสร้านต้องเป็นภาษาอังกฤษตัวเล็ก ตัวเลข หรือ - ยาว 3–50 ตัว';
  }
  if (draft.name.trim().isEmpty) return 'กรุณากรอกชื่อร้าน';
  if (draft.name.trim().length > 120) return 'ชื่อร้านยาวเกิน 120 ตัวอักษร';
  if (draft.location.trim().length > 300) return 'ที่อยู่ยาวเกิน 300 ตัวอักษร';
  if (draft.phone.trim().length > 30) return 'เบอร์โทรยาวเกิน 30 ตัวอักษร';
  final imageError = imageSourceError(draft.image);
  if (imageError != null) return imageError;
  if (draft.zones.isEmpty) return 'กรุณากรอกอย่างน้อย 1 โซน';
  if (draft.zones.length > 20) return 'มีได้ไม่เกิน 20 โซน';
  if (draft.zones.any((zone) => zone.length > 80)) {
    return 'ชื่อโซนยาวเกิน 80 ตัวอักษร';
  }
  if (draft.pricePerPerson < 1 || draft.pricePerPerson > 100000) {
    return 'ราคาต่อคนต้องอยู่ระหว่าง 1–100,000 บาท';
  }
  if (draft.openingHours.trim().length > 40) {
    return 'เวลาเปิด–ปิดยาวเกิน 40 ตัวอักษร';
  }
  return null;
}
