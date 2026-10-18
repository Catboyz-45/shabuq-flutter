import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/utils/opening_hours.dart';

void main() {
  group('format', () {
    test('every day', () {
      expect(OpeningHours.standard.format(), '11:00–22:00 ทุกวัน');
    });

    test('a run of days becomes a range', () {
      final hours = OpeningHours.standard.copyWith(
        open: const ClockTime(9, 30),
        days: {1, 2, 3, 4, 5},
      );
      expect(hours.format(), '09:30–22:00 จ.–ศ.');
    });

    test('scattered days are listed', () {
      expect(
        OpeningHours.standard.copyWith(days: {7, 6}).format(),
        '11:00–22:00 ส. อา.',
      );
    });
  });

  group('parse', () {
    test('reads what format writes', () {
      for (final days in [
        everyDay,
        {1, 2, 3, 4, 5},
        {6, 7},
        {1, 3},
      ]) {
        final hours = OpeningHours.standard.copyWith(days: days);
        final parsed = parseOpeningHours(hours.format())!;
        expect(parsed.days, days);
        expect(parsed.open, hours.open);
        expect(parsed.close, hours.close);
      }
    });

    test('accepts older hand-typed text', () {
      final parsed = parseOpeningHours('11.00 - 22:00')!;
      expect(parsed.open, const ClockTime(11, 0));
      expect(parsed.days, everyDay);
    });

    test('gives up on text it cannot read', () {
      expect(parseOpeningHours('เปิดทุกวันตอนเที่ยง'), isNull);
      expect(parseOpeningHours('25:00–22:00'), isNull);
      expect(parseOpeningHours('11:00–22:00 วันหยุด'), isNull);
    });
  });

  test('flags impossible hours', () {
    expect(OpeningHours.standard.error, isNull);
    expect(OpeningHours.standard.copyWith(days: {}).error, isNotNull);
    expect(
      OpeningHours.standard.copyWith(close: const ClockTime(11, 0)).error,
      isNotNull,
    );
  });
}
