import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/menu_service.dart';
import '../utils/image_source.dart';
import '../widgets/image_url_field.dart';
import '../widgets/shop_image.dart';

class ShopMenuAdmin extends StatefulWidget {
  const ShopMenuAdmin({super.key, required this.admin});

  final AdminProfile admin;

  @override
  State<ShopMenuAdmin> createState() => _ShopMenuAdminState();
}

class _ShopMenuAdminState extends State<ShopMenuAdmin> {
  final MenuService _menuService = MenuService();

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _openEditor({
    MenuItem? item,
    String initialCategory = '',
  }) async {
    final nameController = TextEditingController(text: item?.name ?? '');
    final categoryController = TextEditingController(
      text: item?.category ?? initialCategory,
    );
    final descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    final imageController = TextEditingController(text: item?.imageUrl ?? '');
    final priceController = TextEditingController(
      text: (item?.price ?? 0) == 0 ? '' : '${item!.price}',
    );
    void disposeControllers() {
      for (final controller in [
        nameController,
        categoryController,
        descriptionController,
        imageController,
        priceController,
      ]) {
        controller.dispose();
      }
    }

    var active = item?.active ?? true;
    String? validationError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(item == null ? 'เพิ่มเมนู' : 'แก้ไขเมนู'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อเมนู',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: categoryController,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'หมวดหมู่',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextField(
                          controller: descriptionController,
                          maxLength: 200,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'คำอธิบาย (ไม่บังคับ)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ราคาเพิ่ม (บาท)',
                            helperText: 'เว้นว่างถ้ารวมอยู่ในบุฟเฟ่ต์แล้ว',
                            prefixText: '฿ ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ImageUrlField(
                          controller: imageController,
                          label: 'ลิงก์รูปเมนู (ไม่บังคับ)',
                          previewHeight: 100,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('แสดงเมนูให้ผู้ใช้เห็น'),
                          value: active,
                          onChanged:
                              (value) => setDialogState(() => active = value),
                        ),
                        if (validationError != null)
                          Text(
                            validationError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('ยกเลิก'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        final category = categoryController.text.trim();
                        if (name.isEmpty || category.isEmpty) {
                          setDialogState(
                            () =>
                                validationError =
                                    'กรุณากรอกชื่อเมนูและหมวดหมู่',
                          );
                          return;
                        }
                        final priceText = priceController.text.trim();
                        final price =
                            priceText.isEmpty ? 0 : int.tryParse(priceText);
                        if (price == null || price < 0 || price > 100000) {
                          setDialogState(
                            () =>
                                validationError =
                                    'ราคาต้องเป็นตัวเลข 0–100,000 บาท',
                          );
                          return;
                        }
                        if (!isAllowedImageSource(imageController.text)) {
                          setDialogState(
                            () =>
                                validationError =
                                    'ลิงก์รูปต้องขึ้นต้นด้วย https://',
                          );
                          return;
                        }
                        Navigator.pop(context, true);
                      },
                      child: const Text('บันทึก'),
                    ),
                  ],
                ),
          ),
    );

    if (confirmed != true) {
      disposeControllers();
      return;
    }
    final price = int.tryParse(priceController.text.trim()) ?? 0;

    try {
      if (item == null) {
        await _menuService.addMenuItem(
          shopId: widget.admin.shopId,
          shopName: widget.admin.shopName,
          name: nameController.text,
          category: categoryController.text,
          active: active,
          description: descriptionController.text,
          imageUrl: imageController.text,
          price: price,
        );
        _showMessage('เพิ่มเมนูแล้ว');
      } else {
        await _menuService.updateMenuItem(
          shopId: widget.admin.shopId,
          item: item,
          name: nameController.text,
          category: categoryController.text,
          active: active,
          description: descriptionController.text,
          imageUrl: imageController.text,
          price: price,
        );
        _showMessage('แก้ไขเมนูแล้ว');
      }
    } on FirebaseException {
      _showMessage('บันทึกเมนูไม่สำเร็จ กรุณาลองใหม่', error: true);
    } finally {
      disposeControllers();
    }
  }

  Future<void> _delete(MenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ลบเมนู'),
            content: Text('ต้องการลบ “${item.name}” หรือไม่?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ลบ'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await _menuService.deleteMenuItem(
        shopId: widget.admin.shopId,
        menuItemId: item.id,
      );
      _showMessage('ลบเมนูแล้ว');
    } on FirebaseException {
      _showMessage('ลบเมนูไม่สำเร็จ กรุณาลองใหม่', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<MenuItem>>(
        stream: _menuService.watchMenu(widget.admin.shopId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('โหลดรายการเมนูไม่สำเร็จ'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('ร้านนี้ยังไม่มีเมนู'));
          }
          final grouped = <String, List<MenuItem>>{};
          for (final item in items) {
            grouped.putIfAbsent(item.category, () => []).add(item);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children:
                grouped.entries.map((entry) {
                  final categoryItems = entry.value;
                  final visibleCount =
                      categoryItems.where((item) => item.active).length;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      initiallyExpanded: grouped.length <= 3,
                      leading: const CircleAvatar(child: Icon(Icons.category)),
                      title: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${categoryItems.length} รายการ • แสดง $visibleCount',
                      ),
                      trailing: IconButton(
                        tooltip: 'เพิ่มเมนูในหมวด ${entry.key}',
                        onPressed:
                            () => _openEditor(initialCategory: entry.key),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      children:
                          categoryItems
                              .map(
                                (item) => ListTile(
                                  contentPadding: const EdgeInsets.only(
                                    left: 24,
                                    right: 8,
                                  ),
                                  leading: Opacity(
                                    opacity: item.active ? 1 : 0.4,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: ShopImage(
                                        source: item.imageUrl,
                                        width: 48,
                                        height: 48,
                                        placeholderIcon: Icons.restaurant_menu,
                                      ),
                                    ),
                                  ),
                                  title: Text(item.name),
                                  subtitle: Text(
                                    [
                                      item.active ? 'แสดงอยู่' : 'ซ่อนอยู่',
                                      if (item.price > 0) '+฿${item.price}',
                                    ].join(' • '),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        _openEditor(item: item);
                                      } else if (action == 'delete') {
                                        _delete(item);
                                      }
                                    },
                                    itemBuilder:
                                        (context) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('แก้ไข'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('ลบ'),
                                          ),
                                        ],
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  );
                }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มเมนู'),
      ),
    );
  }
}
