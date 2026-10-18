import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/opening_hours.dart';

/// Picks opening and closing times with a clock and the open days with
/// chips, instead of typing "11:00–22:00 ทุกวัน" by hand.
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

  Future<void> _pickTime({required bool opening}) async {
    final current = opening ? _hours.open : _hours.close;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: opening ? 'เวลาเปิด' : 'เวลาปิด',
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
    );
    if (picked == null) return;
    final time = ClockTime(picked.hour, picked.minute);
    _update(
      opening ? _hours.copyWith(open: time) : _hours.copyWith(close: time),
    );
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
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'เปิด',
                    time: _hours.open,
                    onPressed:
                        widget.enabled ? () => _pickTime(opening: true) : null,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('–'),
                ),
                Expanded(
                  child: _TimeButton(
                    label: 'ปิด',
                    time: _hours.close,
                    onPressed:
                        widget.enabled ? () => _pickTime(opening: false) : null,
                  ),
                ),
              ],
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

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onPressed,
  });

  final String label;
  final ClockTime time;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Text('$time', style: AppFonts.numbers(fontSize: 18)),
        ],
      ),
    );
  }
}
