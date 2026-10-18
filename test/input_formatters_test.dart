import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/services/coupon_service.dart';
import 'package:shabuq_flutter/utils/input_formatters.dart';

String typed(TextInputFormatter formatter, String text) =>
    formatter
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        )
        .text;

void main() {
  test('shop ids become lower case without spaces or symbols', () {
    expect(typed(shopIdCharacters, 'Suki Bang-Khen!'), 'sukibang-khen');
  });

  test('phone numbers keep digits and dashes', () {
    expect(typed(phoneCharacters, 'โทร 02-123 4567'), '02-1234567');
  });

  test('promo codes keep only allowed characters', () {
    expect(typed(promoCodeCharacters, 'SHABU 50%'), 'shabu50');
  });

  test('redemption codes drop look-alike characters', () {
    final filter = CharacterFilter(
      RegExp('[$redemptionAlphabet]'),
      toUpperCase: true,
    );
    // O, 0, I and 1 are not in the alphabet.
    expect(typed(filter, 'ab-c o0i1 d2'), 'ABCD2');
  });
}
