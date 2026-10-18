import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../utils/input_formatters.dart';
import '../utils/shop_form.dart';
import '../widgets/image_url_field.dart';
import '../widgets/opening_hours_field.dart';
import '../widgets/zone_list_field.dart';

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
  late List<String> _zones =
      _shop == null || _shop.zones.isEmpty ? const ['ในร้าน'] : _shop.zones;
  late final _price = TextEditingController(
    text: '${_shop?.pricePerPerson ?? 299}',
  );
  late String _hours = _shop?.openingHours ?? '';
  String? _error;

  bool get _isNew => _shop == null;

  @override
  void dispose() {
    for (final controller in [_id, _name, _location, _phone, _image, _price]) {
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
      zones: _zones,
      pricePerPerson: int.tryParse(_price.text.trim()) ?? 0,
      openingHours: _hours.trim(),
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
                  maxLength: 50,
                  inputFormatters: [shopIdCharacters],
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
                maxLength: phoneMaxLength,
                inputFormatters: [phoneCharacters],
                decoration: const InputDecoration(
                  labelText: 'โทรศัพท์',
                  border: OutlineInputBorder(),
                ),
              ),
              gap,
              OpeningHoursField(
                initial: _hours,
                optional: true,
                onChanged: (value) => _hours = value,
              ),
              gap,
              ImageUrlField(
                controller: _image,
                label: 'ลิงก์รูปร้าน (ไม่บังคับ)',
              ),
              gap,
              ZoneListField(
                initial: _zones,
                onChanged: (zones) => _zones = zones,
                helperText:
                    _isNew
                        ? 'โซนแรกได้เลขคิว A โซนที่สองได้ B ตามลำดับ'
                        : 'ลำดับโซนกำหนดตัวอักษรเลขคิว '
                            'ควรแก้ตอนร้านยังไม่เปิดรับคิว',
              ),
              gap,
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [digitsOnly],
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
