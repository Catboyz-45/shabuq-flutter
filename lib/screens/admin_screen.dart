import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/shop_service.dart';
import 'promo_code_admin.dart';
import 'shop_menu_admin.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.isSuperAdmin});

  final bool isSuperAdmin;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final AdminService _adminService = AdminService();
  final ShopService _shopService = ShopService();

  Future<void> _disposeAfterDialog(
    Iterable<TextEditingController> controllers,
  ) async {
    // showDialog completes when Navigator.pop is called, while the route can
    // still be building during its reverse transition.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _addAdmin(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    Set<String> adminIds,
    List<Map<String, dynamic>> shops,
  ) async {
    if (shops.isEmpty) {
      _showMessage('กรุณาเพิ่มร้านก่อนเพิ่มแอดมิน', error: true);
      return;
    }
    final candidates =
        users.where((document) {
          final email =
              (document.data()['email'] as String? ?? '').trim().toLowerCase();
          return email.isNotEmpty &&
              document.id != FirebaseAuth.instance.currentUser?.uid &&
              !adminIds.contains(document.id);
        }).toList();

    if (candidates.isEmpty) {
      _showMessage(
        'ไม่มีผู้ใช้ที่สามารถเพิ่มได้ ผู้ใช้ต้องสมัครสมาชิกก่อน',
        error: true,
      );
      return;
    }

    QueryDocumentSnapshot<Map<String, dynamic>> selected = candidates.first;
    Map<String, dynamic> selectedShop = shops.first;
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('เพิ่มแอดมิน'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selected.id,
                        decoration: const InputDecoration(
                          labelText: 'บัญชีผู้ใช้',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            candidates.map((document) {
                              final email =
                                  document.data()['email'] as String? ??
                                  'ไม่พบอีเมล';
                              return DropdownMenuItem(
                                value: document.id,
                                child: Text(
                                  email,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                        onChanged: (uid) {
                          if (uid == null) return;
                          setDialogState(() {
                            selected = candidates.firstWhere(
                              (document) => document.id == uid,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedShop['id'] as String,
                        decoration: const InputDecoration(
                          labelText: 'ร้านที่รับผิดชอบ',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            shops
                                .map(
                                  (shop) => DropdownMenuItem(
                                    value: shop['id'] as String,
                                    child: Text(
                                      shop['name'] as String,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (shopId) {
                          if (shopId == null) return;
                          setDialogState(() {
                            selectedShop = shops.firstWhere(
                              (shop) => shop['id'] == shopId,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อที่แสดง',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('ยกเลิก'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('เพิ่ม'),
                    ),
                  ],
                ),
          ),
    );

    if (confirmed != true) {
      await _disposeAfterDialog([nameController]);
      return;
    }

    final email = selected.data()['email'] as String? ?? '';
    try {
      await _adminService.addAdmin(
        uid: selected.id,
        email: email,
        displayName:
            nameController.text.trim().isEmpty
                ? email.split('@').first
                : nameController.text,
        shopId: selectedShop['id'] as String,
        shopName: selectedShop['name'] as String,
      );
      _showMessage('เพิ่ม $email เป็นแอดมินแล้ว');
    } on FirebaseException {
      _showMessage('เพิ่มแอดมินไม่สำเร็จ กรุณาลองใหม่', error: true);
    } finally {
      await _disposeAfterDialog([nameController]);
    }
  }

  Future<void> _editAdmin(
    AdminProfile admin,
    List<Map<String, dynamic>> shops,
  ) async {
    if (shops.isEmpty) {
      _showMessage('ยังไม่มีร้านให้เลือก', error: true);
      return;
    }
    final nameController = TextEditingController(text: admin.displayName);
    var active = admin.active;
    Map<String, dynamic> selectedShop = shops.firstWhere(
      (shop) => shop['id'] == admin.shopId,
      orElse: () => shops.first,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('แก้ไข ${admin.email}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อที่แสดง',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('เปิดใช้งานสิทธิ์แอดมิน'),
                        value: active,
                        onChanged:
                            (value) => setDialogState(() => active = value),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedShop['id'] as String,
                        decoration: const InputDecoration(
                          labelText: 'ร้านที่รับผิดชอบ',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            shops
                                .map(
                                  (shop) => DropdownMenuItem(
                                    value: shop['id'] as String,
                                    child: Text(
                                      shop['name'] as String,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (shopId) {
                          if (shopId == null) return;
                          setDialogState(() {
                            selectedShop = shops.firstWhere(
                              (shop) => shop['id'] == shopId,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('ยกเลิก'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('บันทึก'),
                    ),
                  ],
                ),
          ),
    );

    if (confirmed != true) {
      await _disposeAfterDialog([nameController]);
      return;
    }

    try {
      await _adminService.updateAdmin(
        admin: admin,
        displayName: nameController.text,
        active: active,
        shopId: selectedShop['id'] as String,
        shopName: selectedShop['name'] as String,
      );
      _showMessage('บันทึกข้อมูลแอดมินแล้ว');
    } on FirebaseException {
      _showMessage('แก้ไขแอดมินไม่สำเร็จ กรุณาลองใหม่', error: true);
    } finally {
      await _disposeAfterDialog([nameController]);
    }
  }

  Future<void> _removeAdmin(AdminProfile admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ลบสิทธิ์แอดมิน'),
            content: Text(
              '${admin.email} จะกลับเป็นผู้ใช้ทั่วไป แต่บัญชีและข้อมูลจะยังอยู่',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ลบสิทธิ์'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;
    try {
      await _adminService.removeAdmin(admin);
      _showMessage('ลบสิทธิ์แอดมินแล้ว');
    } on FirebaseException {
      _showMessage('ลบสิทธิ์แอดมินไม่สำเร็จ กรุณาลองใหม่', error: true);
    }
  }

  Future<void> _addShop() async {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final phoneController = TextEditingController();
    final imageController = TextEditingController();
    final zonesController = TextEditingController(text: 'โซนทั่วไป');
    final priceController = TextEditingController(text: '299');
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('เพิ่มร้าน'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'รหัสร้าน (อังกฤษ ตัวเลข และ -)',
                    ),
                  ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'ชื่อร้าน'),
                  ),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'ที่อยู่'),
                  ),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'โทรศัพท์'),
                  ),
                  TextField(
                    controller: imageController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'URL รูปภาพ (ไม่บังคับ)',
                    ),
                  ),
                  TextField(
                    controller: zonesController,
                    decoration: const InputDecoration(
                      labelText: 'โซน (คั่นด้วยเครื่องหมาย ,)',
                    ),
                  ),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ราคาต่อคน'),
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
                onPressed: () => Navigator.pop(context, true),
                child: const Text('เพิ่มร้าน'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      await _disposeAfterDialog([
        idController,
        nameController,
        locationController,
        phoneController,
        imageController,
        zonesController,
        priceController,
      ]);
      return;
    }
    final id = idController.text.trim().toLowerCase();
    final name = nameController.text.trim();
    final image = imageController.text.trim();
    final price = int.tryParse(priceController.text.trim());
    final zones =
        zonesController.text
            .split(',')
            .map((zone) => zone.trim())
            .where((zone) => zone.isNotEmpty)
            .toSet()
            .toList();
    if (!RegExp(r'^[a-z0-9][a-z0-9-]{2,49}$').hasMatch(id) ||
        name.isEmpty ||
        (image.isNotEmpty && !image.startsWith('https://')) ||
        price == null ||
        price < 1 ||
        price > 100000 ||
        zones.isEmpty) {
      _showMessage('ข้อมูลร้านไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง', error: true);
    } else {
      try {
        await _shopService.createShop(
          id: id,
          name: name,
          location: locationController.text,
          phone: phoneController.text,
          image: image,
          zones: zones,
          pricePerPerson: price,
        );
        _showMessage('เพิ่มร้าน $name แล้ว');
      } on FirebaseException {
        _showMessage('เพิ่มร้านไม่สำเร็จ รหัสร้านอาจถูกใช้แล้ว', error: true);
      }
    }
    await _disposeAfterDialog([
      idController,
      nameController,
      locationController,
      phoneController,
      imageController,
      zonesController,
      priceController,
    ]);
  }

  Future<void> _editShop(Map<String, dynamic> shop) async {
    final nameController = TextEditingController(
      text: shop['name'] as String? ?? '',
    );
    final locationController = TextEditingController(
      text: shop['location'] as String? ?? '',
    );
    final phoneController = TextEditingController(
      text: shop['phone'] as String? ?? '',
    );
    final imageController = TextEditingController(
      text: shop['image'] as String? ?? '',
    );
    final zonesController = TextEditingController(
      text: (shop['zones'] as List<dynamic>? ?? const []).join(', '),
    );
    final priceController = TextEditingController(
      text: (shop['pricePerPerson'] as int? ?? 299).toString(),
    );
    final controllers = [
      nameController,
      locationController,
      phoneController,
      imageController,
      zonesController,
      priceController,
    ];
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('แก้ไข ${shop['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'ชื่อร้าน'),
                  ),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'ที่อยู่'),
                  ),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'โทรศัพท์'),
                  ),
                  TextField(
                    controller: imageController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'URL รูปภาพ (ไม่บังคับ)',
                    ),
                  ),
                  TextField(
                    controller: zonesController,
                    decoration: const InputDecoration(
                      labelText: 'โซน (คั่นด้วยเครื่องหมาย ,)',
                    ),
                  ),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ราคาต่อคน'),
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
                onPressed: () => Navigator.pop(context, true),
                child: const Text('บันทึก'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      await _disposeAfterDialog(controllers);
      return;
    }
    final name = nameController.text.trim();
    final image = imageController.text.trim();
    final price = int.tryParse(priceController.text.trim());
    final zones =
        zonesController.text
            .split(',')
            .map((zone) => zone.trim())
            .where((zone) => zone.isNotEmpty)
            .toSet()
            .toList();
    if (name.isEmpty ||
        (image.isNotEmpty &&
            !image.startsWith('https://') &&
            !image.startsWith('assets/images/')) ||
        price == null ||
        price < 1 ||
        price > 100000 ||
        zones.isEmpty) {
      _showMessage('ข้อมูลร้านไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง', error: true);
    } else {
      try {
        await _shopService.updateShop(
          shopId: shop['id'] as String,
          name: name,
          location: locationController.text,
          phone: phoneController.text,
          image: image,
          zones: zones,
          pricePerPerson: price,
        );
        _showMessage('แก้ไขข้อมูลร้านแล้ว');
      } on FirebaseException {
        _showMessage('แก้ไขร้านไม่สำเร็จ กรุณาลองใหม่', error: true);
      }
    }
    await _disposeAfterDialog(controllers);
  }

  Future<void> _setShopActive(
    Map<String, dynamic> shop, {
    required bool active,
  }) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('ลบร้าน'),
              content: Text(
                'ร้าน ${shop['name']} จะหายจากหน้าผู้ใช้ แต่ประวัติคิวและการชำระเงินจะยังอยู่',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('ลบร้าน'),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
    }
    try {
      await _shopService.setShopActive(
        shopId: shop['id'] as String,
        active: active,
      );
      _showMessage(active ? 'กู้คืนร้านแล้ว' : 'ลบร้านแล้ว');
    } on FirebaseException {
      _showMessage('เปลี่ยนสถานะร้านไม่สำเร็จ กรุณาลองใหม่', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSuperAdmin) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        return const Scaffold(
          body: Center(child: Text('กรุณาเข้าสู่ระบบอีกครั้ง')),
        );
      }
      return _ShopAdminView(adminService: _adminService, uid: uid);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShabuQ Admin'),
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ',
            onPressed: FirebaseAuth.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<AdminProfile>>(
        stream: _adminService.watchAdmins(),
        builder: (context, adminSnapshot) {
          if (adminSnapshot.hasError) {
            return const Center(child: Text('โหลดรายชื่อแอดมินไม่สำเร็จ'));
          }
          if (!adminSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final admins = adminSnapshot.data!;
          final adminIds = admins.map((admin) => admin.uid).toSet();
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _shopService.watchShops(includeInactive: true),
            builder: (context, shopSnapshot) {
              if (shopSnapshot.hasError) {
                return const Center(child: Text('โหลดข้อมูลร้านไม่สำเร็จ'));
              }
              if (!shopSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final shops = shopSnapshot.data!;
              final activeShops =
                  shops.where((shop) => shop['active'] != false).toList();
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _adminService.watchUsers(),
                builder: (context, userSnapshot) {
                  final users = userSnapshot.data?.docs;
                  return RefreshIndicator(
                    onRefresh: () async {
                      await FirebaseFirestore.instance
                          .collection('admins')
                          .limit(1)
                          .get(const GetOptions(source: Source.server));
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.shield),
                            ),
                            title: const Text('Super Admin'),
                            subtitle: Text(
                              FirebaseAuth.instance.currentUser?.email ?? '',
                            ),
                            trailing: const Chip(label: Text('ลบไม่ได้')),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'ร้านทั้งหมด',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _addShop,
                              icon: const Icon(Icons.add_business),
                              label: const Text('เพิ่มร้าน'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (shops.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text('ยังไม่มีร้าน')),
                            ),
                          ),
                        ...shops.map(
                          (shop) => Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.storefront),
                              ),
                              title: Text(shop['name'] as String? ?? ''),
                              subtitle: Text(
                                'รหัส: ${shop['id']}\nราคา ฿${shop['pricePerPerson'] ?? 0}/คน'
                                '${shop['active'] == false ? '\nปิดใช้งาน' : ''}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _editShop(shop);
                                  } else if (action == 'delete') {
                                    _setShopActive(shop, active: false);
                                  } else if (action == 'restore') {
                                    _setShopActive(shop, active: true);
                                  }
                                },
                                itemBuilder:
                                    (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('แก้ไขร้าน'),
                                      ),
                                      if (shop['active'] == false)
                                        const PopupMenuItem(
                                          value: 'restore',
                                          child: Text('กู้คืนร้าน'),
                                        )
                                      else
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('ลบร้าน'),
                                        ),
                                    ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        PromoCodeAdmin(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'บัญชีแอดมิน',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            if (widget.isSuperAdmin)
                              FilledButton.icon(
                                onPressed:
                                    users == null
                                        ? null
                                        : () => _addAdmin(
                                          users,
                                          adminIds,
                                          activeShops,
                                        ),
                                icon: const Icon(Icons.person_add),
                                label: const Text('เพิ่มแอดมิน'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (admins.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text('ยังไม่มีบัญชีแอดมินเพิ่มเติม'),
                              ),
                            ),
                          ),
                        ...admins.map(
                          (admin) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(
                                  admin.active
                                      ? Icons.admin_panel_settings
                                      : Icons.person_off,
                                ),
                              ),
                              title: Text(
                                admin.displayName.isEmpty
                                    ? admin.email
                                    : admin.displayName,
                              ),
                              subtitle: Text(
                                '${admin.email}\n${admin.shopName}\n${admin.active ? 'เปิดใช้งาน' : 'ปิดใช้งาน'}',
                              ),
                              isThreeLine: true,
                              trailing:
                                  widget.isSuperAdmin
                                      ? PopupMenuButton<String>(
                                        onSelected: (action) {
                                          if (action == 'edit') {
                                            _editAdmin(admin, shops);
                                          } else if (action == 'remove') {
                                            _removeAdmin(admin);
                                          }
                                        },
                                        itemBuilder:
                                            (context) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('แก้ไข'),
                                              ),
                                              PopupMenuItem(
                                                value: 'remove',
                                                child: Text('ลบสิทธิ์แอดมิน'),
                                              ),
                                            ],
                                      )
                                      : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ShopAdminView extends StatelessWidget {
  const _ShopAdminView({required this.adminService, required this.uid});

  final AdminService adminService;
  final String uid;

  static const statuses = <String, String>{
    'waiting': 'รอคิว',
    'serving': 'กำลังให้บริการ',
    'completed': 'เสร็จสิ้น',
    'cancelled': 'ยกเลิก',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminProfile?>(
      stream: adminService.watchAdmin(uid),
      builder: (context, adminSnapshot) {
        if (!adminSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final admin = adminSnapshot.data;
        if (admin == null || !admin.active || admin.shopId.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('ShabuQ Admin'),
              actions: [
                IconButton(
                  tooltip: 'ออกจากระบบ',
                  onPressed: FirebaseAuth.instance.signOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            body: const Center(child: Text('บัญชีนี้ยังไม่ได้รับมอบหมายร้าน')),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(admin.shopName),
              actions: [
                IconButton(
                  tooltip: 'ออกจากระบบ',
                  onPressed: FirebaseAuth.instance.signOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.queue), text: 'จัดการคิว'),
                  Tab(icon: Icon(Icons.restaurant_menu), text: 'จัดการเมนู'),
                  Tab(icon: Icon(Icons.store), text: 'ข้อมูลร้าน'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _ShopQueueManagement(adminService: adminService, admin: admin),
                ShopMenuAdmin(admin: admin),
                _ShopSettings(admin: admin),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShopSettings extends StatefulWidget {
  const _ShopSettings({required this.admin});

  final AdminProfile admin;

  @override
  State<_ShopSettings> createState() => _ShopSettingsState();
}

class _ShopSettingsState extends State<_ShopSettings> {
  final ShopService _shopService = ShopService();
  final TextEditingController _priceController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _savePrice() async {
    final price = int.tryParse(_priceController.text.trim());
    if (price == null || price < 1 || price > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกราคาระหว่าง 1–100,000 บาท')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _shopService.updatePrice(
        shopId: widget.admin.shopId,
        pricePerPerson: price,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกราคาแล้ว')));
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกราคาไม่สำเร็จ กรุณาลองใหม่')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _shopService.watchShop(widget.admin.shopId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('โหลดข้อมูลร้านไม่สำเร็จ'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final shop = snapshot.data;
        if (shop == null) {
          return const Center(child: Text('ไม่พบข้อมูลร้าน'));
        }
        final currentPrice = shop['pricePerPerson'] as int? ?? 0;
        if (!_saving && _priceController.text.isEmpty) {
          _priceController.text = currentPrice.toString();
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront),
                title: Text(shop['name'] as String? ?? widget.admin.shopName),
                subtitle: Text('ราคาปัจจุบัน ฿$currentPrice/คน'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ราคาต่อคน (บาท)',
                border: OutlineInputBorder(),
                prefixText: '฿ ',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _savePrice,
              icon:
                  _saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save),
              label: const Text('บันทึกราคา'),
            ),
          ],
        );
      },
    );
  }
}

class _ShopQueueManagement extends StatelessWidget {
  const _ShopQueueManagement({required this.adminService, required this.admin});

  final AdminService adminService;
  final AdminProfile admin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: adminService.watchShopQueues(admin.shopId),
      builder: (context, queueSnapshot) {
        if (queueSnapshot.hasError) {
          return const Center(child: Text('โหลดข้อมูลคิวของร้านไม่สำเร็จ'));
        }
        if (!queueSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final queues =
            queueSnapshot.data!.docs.toList()..sort(
              (left, right) => _dateOf(
                left.data()['createdAt'],
              ).compareTo(_dateOf(right.data()['createdAt'])),
            );

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: adminService.watchShopQueueHistory(admin.shopId),
          builder: (context, historySnapshot) {
            if (historySnapshot.hasError) {
              return const Center(child: Text('โหลดประวัติคิวไม่สำเร็จ'));
            }
            if (!historySnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final histories =
                historySnapshot.data!.docs.toList()..sort(
                  (left, right) => _dateOf(
                    right.data()['completedAt'],
                  ).compareTo(_dateOf(left.data()['completedAt'])),
                );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.storefront)),
                    title: Text(admin.shopName),
                    subtitle: Text(
                      '${admin.displayName}\n${admin.email}\nจัดการได้เฉพาะร้านนี้',
                    ),
                    isThreeLine: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'คิวปัจจุบัน (${queues.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (queues.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('ไม่มีคิวที่กำลังใช้งาน')),
                    ),
                  ),
                ...queues.map(
                  (document) => _ActiveQueueCard(
                    key: ValueKey(document.id),
                    document: document,
                    adminService: adminService,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ประวัติคิว (${histories.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (histories.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('ยังไม่มีประวัติคิว')),
                    ),
                  ),
                ...histories.map((document) {
                  final data = document.data();
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.history)),
                      title: Text(
                        'คิว ${document.id.substring(0, 6).toUpperCase()}',
                      ),
                      subtitle: Text(
                        'โซน: ${data['zone'] ?? '-'} • '
                        '${data['partySize'] ?? 0} คน\n'
                        'เสร็จสิ้น ${_formatDate(_dateOf(data['completedAt']))}',
                      ),
                      isThreeLine: true,
                      trailing: const Chip(label: Text('เสร็จสิ้น')),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  static DateTime _dateOf(Object? value) {
    return value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '-';
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}

class _ActiveQueueCard extends StatefulWidget {
  const _ActiveQueueCard({
    super.key,
    required this.document,
    required this.adminService,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final AdminService adminService;

  @override
  State<_ActiveQueueCard> createState() => _ActiveQueueCardState();
}

class _ActiveQueueCardState extends State<_ActiveQueueCard> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.document.data()['status'] == 'completed') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveStatus('completed');
      });
    }
  }

  Future<void> _saveStatus(String status) async {
    if (_saving || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.adminService.updateQueueStatus(
        queueId: widget.document.id,
        status: status,
      );
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปลี่ยนสถานะไม่สำเร็จ กรุณาลองใหม่')),
      );
      setState(() => _saving = false);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.document.data();
    final status = data['status'] as String? ?? 'waiting';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'คิว ${widget.document.id.substring(0, 6).toUpperCase()}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('โซน: ${data['zone'] ?? '-'}'),
            Text('จำนวน: ${data['partySize'] ?? 0} คน'),
            Text('วิธีชำระ: ${data['payMethod'] ?? '-'}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue:
                  _ShopAdminView.statuses.containsKey(status)
                      ? status
                      : 'waiting',
              decoration: InputDecoration(
                labelText: 'สถานะคิว',
                border: const OutlineInputBorder(),
                suffixIcon:
                    _saving
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : null,
              ),
              items:
                  _ShopAdminView.statuses.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
              onChanged:
                  _saving
                      ? null
                      : (newStatus) async {
                        if (newStatus == null || newStatus == status) return;
                        await _saveStatus(newStatus);
                      },
            ),
          ],
        ),
      ),
    );
  }
}
