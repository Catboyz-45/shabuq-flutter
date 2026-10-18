import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/opening_hours.dart';

/// Picks opening and closing times from a bottom sheet with presets and
/// scroll wheels, and the open days with chips, instead of typing
/// "11:00–22:00 ทุกวัน" by hand.
///
/// Reports the formatted text through [onChanged] only after an edit, so
/// old free-text hours the picker can't read stay as they were until
/// someone changes them.
class OpeningHoursField extends StatefulWidget {
  const OpeningHoursField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.optional = false,
    this.enabled = true,
  });

  /// The saved text, possibly empty or written by hand.
  final String initial;

  /// Receives the new text; empty when [optional] hours are switched off.
  final ValueChanged<String> onChanged;

  /// Shows a switch to leave the hours out.
  final bool optional;
  final bool enabled;

  @override
  State<OpeningHoursField> createState() => _OpeningHoursFieldState();
}

class _OpeningHoursFieldState extends State<OpeningHoursField> {
  late final OpeningHours? _parsed = parseOpeningHours(widget.initial);
  late OpeningHours _hours = _parsed ?? OpeningHours.standard;
  late bool _specified = !widget.optional || widget.initial.trim().isNotEmpty;
  bool _edited = false;

  void _update(OpeningHours hours) {
    setState(() {
      _hours = hours;
      _edited = true;
    });
    widget.onChanged(hours.format());
  }

  Future<void> _pickTimes() async {
    final picked = await showModalBottomSheet<(ClockTime, ClockTime)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HoursSheet(open: _hours.open, close: _hours.close),
    );
    if (picked == null) return;
    _update(_hours.copyWith(open: picked.$1, close: picked.$2));
  }

  void _toggleDay(int day) {
    final days = {..._hours.days};
    if (!days.remove(day)) days.add(day);
    _update(_hours.copyWith(days: days));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = _specified ? _hours.error : null;
    final unreadable =
        !_edited && _parsed == null && widget.initial.trim().isNotEmpty;

    return InputDecorator(
      decoration: InputDecoration(
        labelText:
            widget.optional ? 'เวลาเปิด–ปิด (ไม่บังคับ)' : 'เวลาเปิด–ปิด',
        errorText: error,
        helperText:
            unreadable
                ? 'ตอนนี้บันทึกไว้ว่า "${widget.initial.trim()}" '
                    'เลือกเวลาใหม่เพื่อแทนที่'
                : null,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.optional)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('ระบุเวลาเปิด–ปิด'),
              value: _specified,
              onChanged:
                  widget.enabled
                      ? (value) {
                        setState(() => _specified = value);
                        widget.onChanged(value ? _hours.format() : '');
                      }
                      : null,
            ),
          if (_specified) ...[
            _HoursTile(
              open: _hours.open,
              close: _hours.close,
              onTap: widget.enabled ? _pickTimes : null,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in thaiWeekdays.entries)
                  FilterChip(
                    label: Text(
                      entry.value,
                      style: TextStyle(
                        color:
                            _hours.days.contains(entry.key)
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    tooltip:
                        _hours.days.contains(entry.key)
                            ? 'เปิดวัน${entry.value}'
                            : 'ปิดวัน${entry.value}',
                    showCheckmark: false,
                    selected: _hours.days.contains(entry.key),
                    selectedColor: scheme.primary,
                    onSelected:
                        widget.enabled ? (_) => _toggleDay(entry.key) : null,
                  ),
                ActionChip(
                  label: const Text('ทุกวัน'),
                  onPressed:
                      widget.enabled
                          ? () => _update(_hours.copyWith(days: everyDay))
                          : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ลูกค้าจะเห็น: ${_hours.format()}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// "เปิด 11:00 → ปิด 22:00" as one tappable row, like the business-hours
/// rows in merchant apps.
class _HoursTile extends StatelessWidget {
  const _HoursTile({
    required this.open,
    required this.close,
    required this.onTap,
  });

  final ClockTime open;
  final ClockTime close;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget time(String label, ClockTime value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        Text('$value', style: AppFonts.numbers(fontSize: 22, height: 1.2)),
      ],
    );
    return Semantics(
      button: true,
      label: 'เวลาเปิด $open ปิด $close แตะเพื่อเปลี่ยน',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                time('เปิด', open),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                time('ปิด', close),
                if (close.hour * 60 + close.minute <
                    open.hour * 60 + open.minute) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(วันถัดไป)',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
                Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet: common opening hours as one-tap presets, or open and
/// close times on scroll wheels (hours, then minutes in 15-minute steps).
class _HoursSheet extends StatefulWidget {
  const _HoursSheet({required this.open, required this.close});

  final ClockTime open;
  final ClockTime close;

  static const presets = [
    (ClockTime(10, 0), ClockTime(21, 0)),
    (ClockTime(10, 0), ClockTime(22, 0)),
    (ClockTime(11, 0), ClockTime(22, 0)),
    (ClockTime(11, 0), ClockTime(23, 0)),
    (ClockTime(17, 0), ClockTime(0, 0)),
  ];

  @override
  State<_HoursSheet> createState() => _HoursSheetState();
}

class _HoursSheetState extends State<_HoursSheet> {
  late ClockTime _open = widget.open;
  late ClockTime _close = widget.close;
  final _openKey = GlobalKey<_TimeWheelState>();
  final _closeKey = GlobalKey<_TimeWheelState>();

  void _applyPreset((ClockTime, ClockTime) preset) {
    setState(() {
      _open = preset.$1;
      _close = preset.$2;
    });
    _openKey.currentState?.jumpTo(preset.$1);
    _closeKey.currentState?.jumpTo(preset.$2);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sameTime = _open == _close;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'เวลาเปิด–ปิด',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Text(
              'เลือกเร็ว',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _HoursSheet.presets)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(
                      '${preset.$1}–${preset.$2}',
                      style: AppFonts.numbers(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            preset.$1 == _open && preset.$2 == _close
                                ? scheme.onPrimary
                                : scheme.onSurface,
                      ),
                    ),
                    selected: preset.$1 == _open && preset.$2 == _close,
                    selectedColor: scheme.primary,
                    onSelected: (_) => _applyPreset(preset),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _TimeWheel(
                    key: _openKey,
                    label: 'เปิด',
                    initial: _open,
                    onChanged: (time) => setState(() => _open = time),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _TimeWheel(
                    key: _closeKey,
                    label: 'ปิด',
                    initial: _close,
                    onChanged: (time) => setState(() => _close = time),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sameTime
                  ? 'เวลาเปิดและปิดต้องไม่ใช่เวลาเดียวกัน'
                  : _close.hour * 60 + _close.minute <
                      _open.hour * 60 + _open.minute
                  ? 'ปิดหลังเที่ยงคืน: $_open–$_close'
                  : 'เปิด $_open ถึง $_close',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: sameTime ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed:
                  sameTime
                      ? null
                      : () => Navigator.pop(context, (_open, _close)),
              child: const Text('ใช้เวลานี้'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hour and minute wheels for one time of day.
class _TimeWheel extends StatefulWidget {
  const _TimeWheel({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  final String label;
  final ClockTime initial;
  final ValueChanged<ClockTime> onChanged;

  @override
  State<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<_TimeWheel> {
  static const _itemExtent = 40.0;

  /// Quarter hours, plus an odd saved minute so it isn't lost.
  late final List<int> _minutes =
      {0, 15, 30, 45, widget.initial.minute}.toList()..sort();
  late int _hour = widget.initial.hour;
  late int _minute = widget.initial.minute;
  late final _hours = FixedExtentScrollController(initialItem: _hour);
  late final _minuteController = FixedExtentScrollController(
    initialItem: _minutes.indexOf(_minute),
  );

  @override
  void dispose() {
    _hours.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void jumpTo(ClockTime time) {
    _hour = time.hour;
    _minute = _minutes.contains(time.minute) ? time.minute : 0;
    _hours.animateToItem(
      _hour,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    _minuteController.animateToItem(
      _minutes.indexOf(_minute),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _changed() => widget.onChanged(ClockTime(_hour, _minute));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget wheel({
      required FixedExtentScrollController controller,
      required List<int> values,
      required ValueChanged<int> onSelected,
      required String semantics,
    }) {
      return Expanded(
        child: Semantics(
          label: semantics,
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: _itemExtent,
            squeeze: 1.1,
            diameterRatio: 1.3,
            selectionOverlay: const SizedBox.shrink(),
            onSelectedItemChanged: (index) => onSelected(values[index]),
            children: [
              for (final value in values)
                Center(
                  child: Text(
                    value.toString().padLeft(2, '0'),
                    style: AppFonts.numbers(
                      fontSize: 24,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: _itemExtent * 4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The band behind the selected row.
              Container(
                height: _itemExtent,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).brightness == Brightness.light
                          ? Palette.yolkTint
                          : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Row(
                children: [
                  wheel(
                    controller: _hours,
                    values: List.generate(24, (hour) => hour),
                    semantics: '${widget.label} ชั่วโมง',
                    onSelected: (hour) {
                      _hour = hour;
                      _changed();
                    },
                  ),
                  Text(':', style: AppFonts.numbers(fontSize: 24)),
                  wheel(
                    controller: _minuteController,
                    values: _minutes,
                    semantics: '${widget.label} นาที',
                    onSelected: (minute) {
                      _minute = minute;
                      _changed();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
