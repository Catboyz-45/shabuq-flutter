import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/utils/payment_calculator.dart';

void main() {
  group('calculatePayment', () {
    test('calculates total without a coupon', () {
      final result = calculatePayment(partySize: 2, pricePerPerson: 299);

      expect(result.total, 598);
      expect(result.discount, 0);
      expect(result.netTotal, 598);
    });

    test('applies a coupon', () {
      final result = calculatePayment(
        partySize: 2,
        pricePerPerson: 299,
        couponValue: 200,
      );

      expect(result.discount, 200);
      expect(result.netTotal, 398);
    });

    test('caps a discount at the total', () {
      final result = calculatePayment(
        partySize: 1,
        pricePerPerson: 299,
        couponValue: 500,
      );

      expect(result.discount, 299);
      expect(result.netTotal, 0);
    });

    test('rejects invalid party sizes', () {
      expect(
        () => calculatePayment(partySize: 0, pricePerPerson: 299),
        throwsRangeError,
      );
      expect(
        () => calculatePayment(partySize: 11, pricePerPerson: 299),
        throwsRangeError,
      );
    });

    test('rejects invalid price and coupon values', () {
      expect(
        () => calculatePayment(partySize: 1, pricePerPerson: 0),
        throwsRangeError,
      );
      expect(
        () => calculatePayment(
          partySize: 1,
          pricePerPerson: 299,
          couponValue: -1,
        ),
        throwsRangeError,
      );
    });
  });
}
