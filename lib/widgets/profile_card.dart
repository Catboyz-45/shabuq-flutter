import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Icons a customer can pick for their avatar, by stored name.
const avatarIcons = <String, IconData>{
  'person': Icons.person,
  'face': Icons.face,
  'star': Icons.star,
  'pets': Icons.pets,
  'emoji_emotions': Icons.emoji_emotions,
};

/// Avatar background colours a customer can pick.
const avatarColors = <Color>[
  Colors.grey,
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
];

IconData avatarIconFor(String name) => avatarIcons[name] ?? Icons.person;

/// Avatar, display name and phone of the signed-in customer, saved to
/// users/{uid}. Text fields save shortly after the customer stops typing.
class ProfileCard extends StatefulWidget {
  const ProfileCard({
    super.key,
    required this.userDoc,
    required this.email,
    this.fallbackName = '',
  });

  final DocumentReference<Map<String, dynamic>> userDoc;
  final String email;
  final String fallbackName;

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _icon = 'person';
  int _color = Colors.grey.toARGB32();
  bool _loaded = false;
  Timer? _saveTimer;
  final _pending = <String, Object>{};

  @override
  void initState() {
    super.initState();
    widget.userDoc.get().then((snapshot) {
      if (!mounted) return;
      final data = snapshot.data() ?? const <String, dynamic>{};
      setState(() {
        _name.text = data['displayName'] as String? ?? widget.fallbackName;
        _phone.text = data['phone'] as String? ?? '';
        _icon = data['avatarIcon'] as String? ?? 'person';
        _color = data['avatarColor'] as int? ?? _color;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _flush();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _queueSave(String field, Object value) {
    _pending[field] = value;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _flush);
  }

  void _flush() {
    _saveTimer?.cancel();
    if (_pending.isEmpty) return;
    final changes = Map<String, Object>.of(_pending);
    _pending.clear();
    widget.userDoc.set(changes, SetOptions(merge: true));
  }

  Future<void> _pickAvatar() async {
    final picked = await showDialog<(String, int)>(
      context: context,
      builder: (_) => AvatarPickerDialog(icon: _icon, color: _color),
    );
    if (picked == null) return;
    setState(() {
      _icon = picked.$1;
      _color = picked.$2;
    });
    await widget.userDoc.set({
      'avatarIcon': picked.$1,
      'avatarColor': picked.$2,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Tooltip(
              message: 'เปลี่ยนไอคอนและสี',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _pickAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: Color(_color),
                      child: Icon(
                        avatarIconFor(_icon),
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: scheme.onSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: scheme.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _name,
                    maxLength: 60,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'ชื่อผู้ใช้',
                      counterText: '',
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged:
                        (value) => _queueSave('displayName', value.trim()),
                    onEditingComplete: _flush,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.email,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'ข้อมูลติดต่อ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppFonts.numbers(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            labelText: 'เบอร์โทร (ร้านใช้โทรหาเมื่อถึงคิว)',
            hintText: 'กรอกเบอร์',
            counterText: '',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          onChanged: (value) => _queueSave('phone', value),
          onEditingComplete: _flush,
        ),
      ],
    );
  }
}

/// Lets the customer pick an avatar icon and colour; returns (icon, color).
class AvatarPickerDialog extends StatefulWidget {
  const AvatarPickerDialog({
    super.key,
    required this.icon,
    required this.color,
  });

  final String icon;
  final int color;

  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
  late String _icon = widget.icon;
  late int _color = widget.color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('เลือกไอคอนและสี'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final entry in avatarIcons.entries)
                IconButton(
                  tooltip: entry.key,
                  isSelected: _icon == entry.key,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        _icon == entry.key ? scheme.primaryContainer : null,
                  ),
                  onPressed: () => setState(() => _icon = entry.key),
                  icon: Icon(entry.value, size: 32),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final color in avatarColors)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _color = color.toARGB32()),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: color,
                    child:
                        _color == color.toARGB32()
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_icon, _color)),
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}
