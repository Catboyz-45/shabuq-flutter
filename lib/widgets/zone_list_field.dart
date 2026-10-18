import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/queue_position.dart';
import '../utils/shop_form.dart';

/// The shop's zones as an ordered list. Zones are added one at a time and
/// moved with arrows, so there are no commas to forget, no blank or
/// duplicate zones, and the queue letter (A, B, …) of each zone is visible.
class ZoneListField extends StatefulWidget {
  const ZoneListField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.helperText,
  });

  final List<String> initial;
  final ValueChanged<List<String>> onChanged;
  final String? helperText;

  static const maxZones = 20;
  static const maxLength = 80;

  @override
  State<ZoneListField> createState() => _ZoneListFieldState();
}

class _ZoneListFieldState extends State<ZoneListField> {
  late final List<String> _zones = [...widget.initial];
  final _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    widget.onChanged(List.unmodifiable(_zones));
  }

  void _add() {
    // parseZones also splits text pasted with commas.
    final added = parseZones(_input.text);
    if (added.isEmpty) return;
    final duplicate = added.where(_zones.contains).firstOrNull;
    if (duplicate != null) {
      setState(() => _error = 'มีโซน "$duplicate" แล้ว');
      return;
    }
    if (_zones.length + added.length > ZoneListField.maxZones) {
      setState(() => _error = 'มีได้ไม่เกิน ${ZoneListField.maxZones} โซน');
      return;
    }
    _zones.addAll(added);
    _input.clear();
    _error = null;
    _changed();
  }

  void _move(int from, int to) {
    _zones.insert(to, _zones.removeAt(from));
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'โซน',
        helperText: widget.helperText,
        helperMaxLines: 2,
        errorText: _zones.isEmpty ? 'เพิ่มอย่างน้อย 1 โซน' : null,
        border: const OutlineInputBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, zone) in _zones.indexed)
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    zoneCodeFor(_zones, zone),
                    style: AppFonts.numbers(
                      fontSize: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(zone)),
                IconButton(
                  tooltip: 'เลื่อนขึ้น',
                  onPressed: index == 0 ? null : () => _move(index, index - 1),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                IconButton(
                  tooltip: 'เลื่อนลง',
                  onPressed:
                      index == _zones.length - 1
                          ? null
                          : () => _move(index, index + 1),
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
                IconButton(
                  tooltip: 'ลบโซน $zone',
                  onPressed:
                      _zones.length == 1
                          ? null
                          : () {
                            _zones.removeAt(index);
                            _changed();
                          },
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  maxLength: ZoneListField.maxLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'ชื่อโซนใหม่',
                    hintText: 'เช่น ในร้าน, ระเบียง',
                    counterText: '',
                    errorText: _error,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed:
                    _zones.length >= ZoneListField.maxZones ? null : _add,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('เพิ่มโซน'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
