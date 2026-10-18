import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Letters and digits that are hard to mix up when read aloud or typed
/// (no I, L, O, 0 or 1). Matches the pattern in firestore.rules.
const redemptionAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const redemptionCodeLength = 6;
const redemptionValidity = Duration(minutes: 10);

String generateRedemptionCode([Random? random]) {
  final source = random ?? Random.secure();
  return List.generate(
    redemptionCodeLength,
    (_) => redemptionAlphabet[source.nextInt(redemptionAlphabet.length)],
  ).join();
}

/// Normalises what staff type: upper case, spaces and dashes removed.
String normaliseRedemptionCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

class CouponRedemption {
  const CouponRedemption({
    required this.code,
    required this.userId,
    required this.couponCode,
    required this.couponName,
    required this.value,
    required this.status,
    required this.createdAt,
  });

  final String code;
  final String userId;
  final String couponCode;
  final String couponName;
  final int value;
  final String status;
  final DateTime? createdAt;

  bool get isRedeemed => status == 'redeemed';

  bool isExpired(DateTime now) {
    final created = createdAt;
    return created != null && now.difference(created) >= redemptionValidity;
  }

  factory CouponRedemption.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final createdAt = data['createdAt'];
    return CouponRedemption(
      code: snapshot.id,
      userId: data['userId'] as String? ?? '',
      couponCode: data['couponCode'] as String? ?? '',
      couponName: data['couponName'] as String? ?? '',
      value: data['value'] as int? ?? 0,
      status: data['status'] as String? ?? 'pending',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}

/// Coupons are redeemed at the counter: the customer shows a short code and
/// shop staff confirm it, so a customer can't mark a coupon used by themself
/// and the shop knows which coupons it honoured.
class CouponService {
  CouponService({FirebaseFirestore? firestore, Random? random})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _random = random;

  final FirebaseFirestore _firestore;
  final Random? _random;

  DocumentReference<Map<String, dynamic>> _redemption(String code) =>
      _firestore.collection('couponRedemptions').doc(code);

  DocumentReference<Map<String, dynamic>> _coupon(String uid, String code) =>
      _firestore.collection('users').doc(uid).collection('coupons').doc(code);

  /// Creates a redemption code for one of the customer's coupons.
  Future<String> requestRedemption({
    required String uid,
    required String couponCode,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generateRedemptionCode(_random);
      final created = await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(_redemption(code));
        if (existing.exists) return false;
        final coupon = await transaction.get(_coupon(uid, couponCode));
        final data = coupon.data();
        if (data == null) throw StateError('ไม่พบคูปองนี้แล้ว');
        transaction.set(_redemption(code), {
          'userId': uid,
          'couponCode': couponCode,
          'couponName': data['name'],
          'value': data['value'],
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(_coupon(uid, couponCode), {'redemptionCode': code});
        return true;
      });
      if (created) return code;
    }
    throw StateError('สร้างรหัสไม่สำเร็จ กรุณาลองใหม่');
  }

  Stream<CouponRedemption?> watchRedemption(String code) {
    return _redemption(code).snapshots().map(
      (snapshot) =>
          snapshot.exists ? CouponRedemption.fromSnapshot(snapshot) : null,
    );
  }

  /// Staff look up a code before confirming it.
  Future<CouponRedemption?> findRedemption(String code) async {
    final snapshot = await _redemption(normaliseRedemptionCode(code)).get();
    return snapshot.exists ? CouponRedemption.fromSnapshot(snapshot) : null;
  }

  /// Staff confirm the discount: marks the code redeemed for their shop and
  /// removes the coupon from the customer's wallet in one transaction.
  Future<void> redeem({
    required String code,
    required String staffUid,
    required String shopId,
  }) {
    final reference = _redemption(normaliseRedemptionCode(code));
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw StateError('ไม่พบรหัสนี้');
      final redemption = CouponRedemption.fromSnapshot(snapshot);
      if (redemption.isRedeemed) throw StateError('รหัสนี้ถูกใช้ไปแล้ว');
      if (redemption.isExpired(DateTime.now())) {
        throw StateError('รหัสหมดอายุแล้ว ให้ลูกค้ากดสร้างรหัสใหม่');
      }
      transaction.update(reference, {
        'status': 'redeemed',
        'redeemedAt': FieldValue.serverTimestamp(),
        'redeemedBy': staffUid,
        'shopId': shopId,
      });
      transaction.delete(_coupon(redemption.userId, redemption.couponCode));
    });
  }
}
