import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/screens/redeem_coupon_dialog.dart';
import 'package:shabuq_flutter/screens/shop_form_dialog.dart';
import 'package:shabuq_flutter/services/coupon_service.dart';
import 'package:shabuq_flutter/theme/app_theme.dart';
import 'package:shabuq_flutter/utils/shop_form.dart';

/// Pumps a button that opens [dialog] and records what it returns.
Future<List<Object?>> pumpDialogLauncher(
  WidgetTester tester,
  Widget dialog,
) async {
  final results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  results.add(
                    await showDialog<Object>(
                      context: context,
                      builder: (_) => dialog,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  group('RedeemCouponDialog', () {
    late FakeFirebaseFirestore firestore;
    late CouponService coupons;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      coupons = CouponService(firestore: firestore);
      await firestore
          .collection('users')
          .doc('u1')
          .collection('coupons')
          .doc('shabu50')
          .set({'code': 'shabu50', 'name': 'ลด 50', 'value': 50});
    });

    testWidgets('checks a code and redeems it', (tester) async {
      final code = await coupons.requestRedemption(
        uid: 'u1',
        couponCode: 'shabu50',
      );
      final results = await pumpDialogLauncher(
        tester,
        RedeemCouponDialog(
          staffUid: 'staff',
          shopId: 'teenoi',
          couponService: coupons,
        ),
      );

      await tester.enterText(find.byType(TextField), code.toLowerCase());
      await tester.tap(find.text('ตรวจสอบ'));
      await tester.pumpAndSettle();
      expect(find.text('ลด 50'), findsOneWidget);
      expect(find.text('ส่วนลด ฿50'), findsOneWidget);

      await tester.tap(find.text('ยืนยันใช้คูปอง'));
      await tester.pumpAndSettle();

      expect(results, [true]);
      final coupon =
          await firestore
              .collection('users')
              .doc('u1')
              .collection('coupons')
              .doc('shabu50')
              .get();
      expect(coupon.exists, isFalse);
    });

    testWidgets('explains unknown codes', (tester) async {
      await pumpDialogLauncher(
        tester,
        RedeemCouponDialog(
          staffUid: 'staff',
          shopId: 'teenoi',
          couponService: coupons,
        ),
      );

      await tester.enterText(find.byType(TextField), 'ZZZZZZ');
      await tester.tap(find.text('ตรวจสอบ'));
      await tester.pumpAndSettle();

      expect(find.text('ไม่พบรหัสนี้'), findsOneWidget);
    });
  });

  group('ShopFormDialog', () {
    testWidgets('shows validation errors in the dialog', (tester) async {
      final results = await pumpDialogLauncher(tester, const ShopFormDialog());

      await tester.tap(find.widgetWithText(FilledButton, 'เพิ่มร้าน'));
      await tester.pumpAndSettle();

      expect(find.textContaining('รหัสร้านต้องเป็น'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('returns a draft with parsed zones', (tester) async {
      final results = await pumpDialogLauncher(tester, const ShopFormDialog());

      await tester.enterText(
        find.widgetWithText(TextField, 'รหัสร้าน'),
        'suki-bangkhen',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'ชื่อร้าน'),
        'Suki บางเขน',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'โซน (คั่นด้วย ,)'),
        'ในร้าน, ระเบียง',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'เพิ่มร้าน'));
      await tester.pumpAndSettle();

      final draft = results.single! as ShopDraft;
      expect(draft.id, 'suki-bangkhen');
      expect(draft.name, 'Suki บางเขน');
      expect(draft.zones, ['ในร้าน', 'ระเบียง']);
      expect(draft.pricePerPerson, 299);
    });
  });
}
