import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/promo_code_service.dart';
import '../theme/app_theme.dart';

class PromoCodeAdmin extends StatelessWidget {
  PromoCodeAdmin({super.key});

  final PromoCodeService _service = PromoCodeService();

  Future<void> _openEditor(
    BuildContext context, {
    Map<String, dynamic>? code,
  }) async {
    final result = await showDialog<_PromoFormValue>(
      context: context,
      builder: (_) => _PromoCodeDialog(initial: code),
    );
    if (result == null || !context.mounted) return;
    try {
      if (code == null) {
        await _service.createCode(
          code: result.code,
          name: result.name,
          value: result.value,
        );
      } else {
        await _service.updateCode(
          code: code['code'] as String,
          name: result.name,
          value: result.value,
          active: result.active,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(code == null ? 'เพิ่มโค้ดแล้ว' : 'แก้ไขโค้ดแล้ว'),
        ),
      );
    } on FirebaseException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกโค้ดไม่สำเร็จ กรุณาลองใหม่')),
      );
    }
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ลบโค้ดส่วนลด'),
            content: Text(
              'ต้องการลบโค้ด ${code['code']} หรือไม่?\nประวัติผู้ที่เคยใช้จะยังคงอยู่',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                style: destructiveButtonStyle(context),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ลบ'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteCode(code['code'] as String);
    } on FirebaseException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบโค้ดไม่สำเร็จ กรุณาลองใหม่')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.watchCodes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(child: ListTile(title: Text('โหลดโค้ดไม่สำเร็จ')));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final codes = snapshot.data!;
        return Column(
          children: [
            Row(
              children: [
                Text(
                  'โค้ดส่วนลด',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มโค้ด'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (codes.isEmpty)
              const Card(child: ListTile(title: Text('ยังไม่มีโค้ดส่วนลด'))),
            ...codes.map(
              (code) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.local_offer)),
                  title: Text(code['name'] as String? ?? ''),
                  subtitle: Text(
                    'โค้ด: ${code['code']} • ลด ฿${code['value']}'
                    '${code['active'] == false ? ' • ปิดใช้งาน' : ''}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'edit') {
                        _openEditor(context, code: code);
                      } else if (action == 'delete') {
                        _delete(context, code);
                      }
                    },
                    itemBuilder:
                        (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                          PopupMenuItem(value: 'delete', child: Text('ลบ')),
                        ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PromoCodeDialog extends StatefulWidget {
  const _PromoCodeDialog({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_PromoCodeDialog> createState() => _PromoCodeDialogState();
}

class _PromoCodeDialogState extends State<_PromoCodeDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late bool _active;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: widget.initial?['code'] as String? ?? '',
    );
    _nameController = TextEditingController(
      text: widget.initial?['name'] as String? ?? '',
    );
    _valueController = TextEditingController(
      text: (widget.initial?['value'] as int? ?? 100).toString(),
    );
    _active = widget.initial?['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _codeController.text.trim().toLowerCase();
    final name = _nameController.text.trim();
    final value = int.tryParse(_valueController.text.trim());
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{2,29}$').hasMatch(code) ||
        name.isEmpty ||
        value == null ||
        value < 1 ||
        value > 100000) {
      setState(() => _error = 'กรุณากรอกข้อมูลให้ถูกต้อง');
      return;
    }
    Navigator.pop(
      context,
      _PromoFormValue(code: code, name: name, value: value, active: _active),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'เพิ่มโค้ดส่วนลด' : 'แก้ไขโค้ด'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              enabled: widget.initial == null,
              decoration: const InputDecoration(labelText: 'โค้ด'),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'ชื่อส่วนลด'),
            ),
            TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'จำนวนเงินส่วนลด'),
            ),
            if (widget.initial != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('เปิดใช้งาน'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(onPressed: _submit, child: const Text('บันทึก')),
      ],
    );
  }
}

class _PromoFormValue {
  const _PromoFormValue({
    required this.code,
    required this.name,
    required this.value,
    required this.active,
  });

  final String code;
  final String name;
  final int value;
  final bool active;
}
