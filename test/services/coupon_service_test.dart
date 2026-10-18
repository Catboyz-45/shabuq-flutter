import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/services/coupon_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late CouponService coupons;

  DocumentReference<Map<String, dynamic>> coupon() => firestore
      .collection('users')
      .doc('u1')
      .collection('coupons')
      .doc('shabu50');

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    coupons = CouponService(firestore: firestore, random: Random(1));
    await coupon().set({'code': 'shabu50', 'name': 'ลด 50', 'value': 50});
  });

  test('codes use only unambiguous characters', () {
    final random = Random(42);
    for (var i = 0; i < 200; i++) {
      final code = generateRedemptionCode(random);
      expect(code, hasLength(redemptionCodeLength));
      expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]+$')));
    }
    expect(normaliseRedemptionCode(' ab-c d2 '), 'ABCD2');
  });

  test('staff redeem a code and the coupon disappears', () async {
    final code = await coupons.requestRedemption(
      uid: 'u1',
      couponCode: 'shabu50',
    );
    expect((await coupon().get()).data()!['redemptionCode'], code);

    final found = await coupons.findRedemption(code.toLowerCase());
    expect(found!.couponName, 'ลด 50');
    expect(found.value, 50);

    await coupons.redeem(code: code, staffUid: 'staff', shopId: 'teenoi');

    expect((await coupon().get()).exists, isFalse);
    final redemption = await coupons.findRedemption(code);
    expect(redemption!.isRedeemed, isTrue);
  });

  test('a code can only be redeemed once', () async {
    final code = await coupons.requestRedemption(
      uid: 'u1',
      couponCode: 'shabu50',
    );
    await coupons.redeem(code: code, staffUid: 'staff', shopId: 'teenoi');

    expect(
      () => coupons.redeem(code: code, staffUid: 'staff', shopId: 'teenoi'),
      throwsA(isA<StateError>()),
    );
  });

  test('expired codes are refused', () async {
    await firestore.collection('couponRedemptions').doc('ABCDEF').set({
      'userId': 'u1',
      'couponCode': 'shabu50',
      'couponName': 'ลด 50',
      'value': 50,
      'status': 'pending',
      'createdAt': Timestamp.fromDate(
        DateTime.now().subtract(redemptionValidity * 2),
      ),
    });

    expect(
      () => coupons.redeem(code: 'ABCDEF', staffUid: 'staff', shopId: 'x'),
      throwsA(isA<StateError>()),
    );
    expect((await coupon().get()).exists, isTrue);
  });

  test('unknown codes are reported', () async {
    expect(await coupons.findRedemption('ZZZZZZ'), isNull);
    expect(
      () => coupons.redeem(code: 'ZZZZZZ', staffUid: 'staff', shopId: 'x'),
      throwsA(isA<StateError>()),
    );
  });
}
