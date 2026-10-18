import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/admin_service.dart';

/// A registered user that can be made a shop admin.
class AdminCandidate {
  const AdminCandidate({required this.uid, required this.email});

  final String uid;
  final String email;
}

/// What the dialog returns.
class AdminDraft {
  const AdminDraft({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.shop,
    required this.active,
  });

  final String uid;
  final String email;
  final String displayName;
  final Shop shop;
  final bool active;
}

/// Adds a shop admin (pick a user from [candidates]) or edits [admin].
class AdminAccountDialog extends StatefulWidget {
  const AdminAccountDialog({
    super.key,
    required this.shops,
    this.candidates = const [],
    this.admin,
  }) : assert(admin != null || candidates.length > 0);

  final List<Shop> shops;
  final List<AdminCandidate> candidates;
  final AdminProfile? admin;

  @override
  State<AdminAccountDialog> createState() => _AdminAccountDialogState();
}

class _AdminAccountDialogState extends State<AdminAccountDialog> {
  late final AdminProfile? _admin = widget.admin;
  late final _name = TextEditingController(text: _admin?.displayName ?? '');
  late AdminCandidate? _candidate =
      _admin == null ? widget.candidates.first : null;
  late Shop _shop = widget.shops.firstWhere(
    (shop) => shop.id == _admin?.shopId,
    orElse: () => widget.shops.first,
  );
  late bool _active = _admin?.active ?? true;

  bool get _isNew => _admin == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final email = _admin?.email ?? _candidate!.email;
    final name = _name.text.trim();
    Navigator.pop(
      context,
      AdminDraft(
        uid: _admin?.uid ?? _candidate!.uid,
        email: email,
        displayName: name.isEmpty ? email.split('@').first : name,
        shop: _shop,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'เพิ่มแอดมิน' : 'แก้ไข ${_admin!.email}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isNew) ...[
              DropdownButtonFormField<String>(
                initialValue: _candidate!.uid,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'บัญชีผู้ใช้',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final candidate in widget.candidates)
                    DropdownMenuItem(
                      value: candidate.uid,
                      child: Text(
                        candidate.email,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged:
                    (uid) => setState(
                      () =>
                          _candidate = widget.candidates.firstWhere(
                            (candidate) => candidate.uid == uid,
                          ),
                    ),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              initialValue: _shop.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'ร้านที่รับผิดชอบ',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final shop in widget.shops)
                  DropdownMenuItem(
                    value: shop.id,
                    child: Text(shop.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged:
                  (shopId) => setState(
                    () =>
                        _shop = widget.shops.firstWhere(
                          (shop) => shop.id == shopId,
                        ),
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'ชื่อที่แสดง',
                border: OutlineInputBorder(),
              ),
            ),
            if (!_isNew)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('เปิดใช้งานสิทธิ์แอดมิน'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isNew ? 'เพิ่ม' : 'บันทึก'),
        ),
      ],
    );
  }
}
