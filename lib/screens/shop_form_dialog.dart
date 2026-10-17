import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../utils/shop_form.dart';
import '../widgets/image_url_field.dart';

/// Add a shop (when [shop] is null) or edit one. Validates in place and
/// returns the draft to save, or null when cancelled.
class ShopFormDialog extends StatefulWidget {
  const ShopFormDialog({super.key, this.shop});

  final Shop? shop;

  @override
  State<ShopFormDialog> createState() => _ShopFormDialogState();
}

class _ShopFormDialogState extends State<ShopFormDialog> {
  late final Shop? _shop = widget.shop;
  late final _id = TextEditingController(text: _shop?.id ?? '');
  late final _name = TextEditingController(text: _shop?.name ?? '');
  late final _location = TextEditingController(text: _shop?.location ?? '');
  late final _phone = TextEditingController(text: _shop?.phone ?? '');
  late final _image = TextEditingController(text: _shop?.image ?? '');
  late final _zones = TextEditingController(
    text: _shop?.zones.join(', ') ?? 'ในร้าน',
  );
  late final _price = TextEditingController(
    text: '${_shop?.pricePerPerson ?? 299}',
  );
  late final _hours = TextEditingController(text: _shop?.openingHours ?? '');
  String? _error;

  bool get _isNew => _shop == null;

  @override
  void dispose() {
    for (final controller in [
      _id,
      _name,
      _location,
      _phone,
      _image,
      _zones,
      _price,
      _hours,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final draft = ShopDraft(
      id: _isNew ? _id.text.trim().toLowerCase() : _shop!.id,
      name: _name.text.trim(),
      location: _location.text.trim(),
      phone: _phone.text.trim(),
      image: _image.text.trim(),
      zones: parseZones(_zones.text),
      pricePerPerson: int.tryParse(_price.text.trim()) ?? 0,
      openingHours: _hours.text.trim(),
    );
    final error = validateShopDraft(draft, isNew: _isNew);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return AlertDialog(
      title: Text(_isNew ? 'เพิ่มร้าน' : 'แก้ไข ${_shop!.name}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isNew) ...[
                TextField(
                  controller: _id,
                  decoration: const InputDecoration(
                    labelText: 'รหัสร้าน',
                    helperText:
                        'อังกฤษตัวเล็ก ตัวเลข และ - เช่น suki-bangkhen '
                        '(แก้ทีหลังไม่ได้)',
                    border: OutlineInputBorder(),
                  ),
                ),
                gap,
              ],
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'ชื่อร้าน',
                  border: OutlineInputBorder(),
                ),
              ),
              gap,
              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'ที่อยู่',
                  border: OutlineInputBorder(),
                ),
              ),
              gap,
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'โทรศัพท์',
                  border: OutlineInputBorder(),
                ),
              ),
              gap,
              TextField(
                controller: _hours,
                decoration: const InputDecoration(
                  labelText: 'เวลาเปิด–ปิด (ไม่บังคับ)',
                  hintText: 'เช่น 11:00–22:00 ทุกวัน',
                  border: OutlineInputBorder(),
                ),
              ),
              gap,
              ImageUrlField(
                controller: _image,
                label: 'ลิงก์รูปร้าน (ไม่บังคับ)',
              ),
              gap,
              TextField(
                controller: _zones,
                decoration: InputDecoration(
                  labelText: 'โซน (คั่นด้วย ,)',
                  helperText:
                      _isNew
                          ? 'โซนแรกได้เลขคิว A โซนที่สองได้ B ตามลำดับ'
                          : 'ลำดับโซนกำหนดตัวอักษรเลขคิว '
                              'ควรแก้ตอนร้านยังไม่เปิดรับคิว',
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
              ),
              gap,
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ราคาต่อคน',
                  prefixText: '฿ ',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                gap,
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isNew ? 'เพิ่มร้าน' : 'บันทึก'),
        ),
      ],
    );
  }
}
