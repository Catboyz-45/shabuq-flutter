import 'dart:math';

class PaymentSummary {
  const PaymentSummary({
    required this.total,
    required this.discount,
    required this.netTotal,
  });

  final int total;
  final int discount;
  final int netTotal;
}

PaymentSummary calculatePayment({
  required int partySize,
  required int pricePerPerson,
  int couponValue = 0,
}) {
  if (partySize < 1 || partySize > 10) {
    throw RangeError.range(partySize, 1, 10, 'partySize');
  }
  if (pricePerPerson <= 0) {
    throw RangeError.value(
      pricePerPerson,
      'pricePerPerson',
      'must be greater than zero',
    );
  }
  if (couponValue < 0) {
    throw RangeError.value(couponValue, 'couponValue', 'must not be negative');
  }

  final total = partySize * pricePerPerson;
  final discount = min(couponValue, total);
  return PaymentSummary(
    total: total,
    discount: discount,
    netTotal: total - discount,
  );
}
