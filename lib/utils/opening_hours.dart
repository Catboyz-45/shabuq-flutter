/// A time of day without the Flutter dependency of TimeOfDay.
class ClockTime {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// Short Thai day names, Monday (1) to Sunday (7) as in DateTime.weekday.
const thaiWeekdays = {
  1: 'จ.',
  2: 'อ.',
  3: 'พ.',
  4: 'พฤ.',
  5: 'ศ.',
  6: 'ส.',
  7: 'อา.',
};

const everyDay = {1, 2, 3, 4, 5, 6, 7};

/// Opening hours picked in the app, saved as text such as
/// "11:00–22:00 ทุกวัน" so customers read it as written.
class OpeningHours {
  const OpeningHours({
    required this.open,
    required this.close,
    this.days = everyDay,
  });

  final ClockTime open;
  final ClockTime close;

  /// Weekdays the shop opens, 1 = Monday … 7 = Sunday.
  final Set<int> days;

  static const standard = OpeningHours(
    open: ClockTime(11, 0),
    close: ClockTime(22, 0),
  );

  OpeningHours copyWith({ClockTime? open, ClockTime? close, Set<int>? days}) {
    return OpeningHours(
      open: open ?? this.open,
      close: close ?? this.close,
      days: days ?? this.days,
    );
  }

  /// "11:00–22:00 ทุกวัน", "11:00–22:00 จ.–ศ." or "11:00–22:00 ส. อา."
  String format() => '$open–$close ${_formatDays(days)}';

  /// Thai error for hours that make no sense, or null.
  String? get error {
    if (days.isEmpty) return 'เลือกวันที่เปิดอย่างน้อย 1 วัน';
    if (open == close) return 'เวลาเปิดและปิดต้องไม่ใช่เวลาเดียวกัน';
    return null;
  }
}

String _formatDays(Set<int> days) {
  final sorted = days.toList()..sort();
  if (sorted.length == 7) return 'ทุกวัน';
  final contiguous = sorted.last - sorted.first == sorted.length - 1;
  if (contiguous && sorted.length >= 3) {
    return '${thaiWeekdays[sorted.first]}–${thaiWeekdays[sorted.last]}';
  }
  return sorted.map((day) => thaiWeekdays[day]).join(' ');
}

final _hoursPattern = RegExp(
  r'^\s*(\d{1,2})[:.](\d{2})\s*[–\-]\s*(\d{1,2})[:.](\d{2})\s*(.*?)\s*$',
);

/// Reads text written by [OpeningHours.format] (or typed in the same shape
/// before the picker existed). Returns null when it can't be understood, so
/// the caller can keep the old text untouched.
OpeningHours? parseOpeningHours(String text) {
  final match = _hoursPattern.firstMatch(text);
  if (match == null) return null;
  ClockTime? time(String hour, String minute) {
    final h = int.parse(hour), m = int.parse(minute);
    return h < 24 && m < 60 ? ClockTime(h, m) : null;
  }

  final open = time(match[1]!, match[2]!);
  final close = time(match[3]!, match[4]!);
  final days = _parseDays(match[5]!);
  if (open == null || close == null || days == null) return null;
  return OpeningHours(open: open, close: close, days: days);
}

Set<int>? _parseDays(String text) {
  if (text.isEmpty || text == 'ทุกวัน') return everyDay;
  int? day(String token) {
    final name = token.trim().replaceAll('.', '');
    for (final entry in thaiWeekdays.entries) {
      if (entry.value.replaceAll('.', '') == name) return entry.key;
    }
    return null;
  }

  final range = text.split(RegExp(r'\s*[–\-]\s*'));
  if (range.length == 2) {
    final from = day(range[0]), to = day(range[1]);
    if (from == null || to == null || from > to) return null;
    return {for (var d = from; d <= to; d++) d};
  }
  final days = <int>{};
  for (final token in text.split(RegExp(r'[\s,]+'))) {
    final value = day(token);
    if (value == null) return null;
    days.add(value);
  }
  return days;
}
