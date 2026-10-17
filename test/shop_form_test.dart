import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/utils/shop_form.dart';

void main() {
  ShopDraft draft({
    String id = 'suki-bangkhen',
    String name = 'Suki',
    String image = '',
    List<String> zones = const ['ในร้าน'],
    int price = 299,
    String hours = '',
  }) {
    return ShopDraft(
      id: id,
      name: name,
      location: '',
      phone: '',
      image: image,
      zones: zones,
      pricePerPerson: price,
      openingHours: hours,
    );
  }

  test('parses zones in order without blanks or duplicates', () {
    expect(parseZones(' ในร้าน, ระเบียง ,, ในร้าน '), ['ในร้าน', 'ระเบียง']);
    expect(parseZones(' , '), isEmpty);
  });

  test('accepts a valid shop', () {
    expect(validateShopDraft(draft(), isNew: true), isNull);
  });

  test('checks the id only for new shops', () {
    expect(validateShopDraft(draft(id: 'Bad ID'), isNew: true), isNotNull);
    expect(validateShopDraft(draft(id: 'ab'), isNew: true), isNotNull);
    expect(validateShopDraft(draft(id: 'Bad ID'), isNew: false), isNull);
  });

  test('reports the first problem in Thai', () {
    expect(
      validateShopDraft(draft(name: ' '), isNew: false),
      contains('ชื่อร้าน'),
    );
    expect(
      validateShopDraft(draft(image: 'http://x.com/a.jpg'), isNew: false),
      contains('https://'),
    );
    expect(validateShopDraft(draft(zones: []), isNew: false), contains('โซน'));
    expect(validateShopDraft(draft(price: 0), isNew: false), contains('ราคา'));
    expect(
      validateShopDraft(draft(hours: 'x' * 41), isNew: false),
      contains('เวลา'),
    );
  });
}
