import 'package:flutter/services.dart';

/// Keeps only characters matching [allowed] after optionally changing case,
/// so a field can't hold anything the server would reject.
class CharacterFilter extends TextInputFormatter {
  CharacterFilter(
    this.allowed, {
    this.toUpperCase = false,
    this.toLowerCase = false,
  });

  final RegExp allowed;
  final bool toUpperCase;
  final bool toLowerCase;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (toUpperCase) text = text.toUpperCase();
    if (toLowerCase) text = text.toLowerCase();
    final filtered = text.split('').where(allowed.hasMatch).join();
    if (filtered == newValue.text) return newValue;
    final offset = (newValue.selection.baseOffset -
            (text.length - filtered.length))
        .clamp(0, filtered.length);
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Digits only, e.g. prices and phone numbers.
final digitsOnly = FilteringTextInputFormatter.digitsOnly;

/// Phone numbers as Thai shops write them: digits and dashes
/// (02-123-4567, 081-234-5678).
final phoneCharacters = CharacterFilter(RegExp(r'[0-9-]'));

/// Longest phone number with dashes, e.g. 081-234-5678.
const phoneMaxLength = 12;

/// Shop ids: lower-case English letters, digits and dashes.
final shopIdCharacters = CharacterFilter(
  RegExp(r'[a-z0-9-]'),
  toLowerCase: true,
);

/// Promo codes: lower-case English letters, digits, dash and underscore.
final promoCodeCharacters = CharacterFilter(
  RegExp(r'[a-z0-9_-]'),
  toLowerCase: true,
);
