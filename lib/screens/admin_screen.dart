import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/shop_service.dart';
import '../utils/image_source.dart';
import '../widgets/image_url_field.dart';
import 'app_content_admin.dart';
import 'banner_admin.dart';
import 'promo_code_admin.dart';
import 'shop_menu_admin.dart';
import 'shop_queue_admin.dart';
import 'shop_stats_admin.dart';

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
                  const SizedBox(height: 12),
                  ImageUrlField(
                    controller: imageController,
                    label: 'ลิงก์รูปร้าน (ไม่บังคับ)',
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
        !isAllowedImageSource(image) ||
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
                  const SizedBox(height: 12),
                  ImageUrlField(
                    controller: imageController,
                    label: 'ลิงก์รูปร้าน (ไม่บังคับ)',
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
        !isAllowedImageSource(image) ||
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
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.view_carousel),
                                title: const Text('แบนเนอร์หน้าแรก'),
                                subtitle: const Text(
                                  'เพิ่ม แก้ไข เรียงลำดับ หรือซ่อนแบนเนอร์',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const BannerAdminScreen(),
                                      ),
                                    ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.article),
                                title: const Text('ข้อความในแอป'),
                                subtitle: const Text(
                                  'การช่วยเหลือ ข้อกำหนด และนโยบายความเป็นส่วนตัว',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                const AppContentAdminScreen(),
                                      ),
                                    ),
                              ),
                            ],
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
          length: 4,
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
                  Tab(icon: Icon(Icons.queue), text: 'คิว'),
                  Tab(icon: Icon(Icons.insights), text: 'สถิติ'),
                  Tab(icon: Icon(Icons.restaurant_menu), text: 'เมนู'),
                  Tab(icon: Icon(Icons.store), text: 'ข้อมูลร้าน'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                ShopQueueAdmin(adminService: adminService, admin: admin),
                ShopStatsAdmin(
                  adminService: adminService,
                  shopId: admin.shopId,
                ),
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
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  late final Stream<Map<String, dynamic>?> _shop = _shopService.watchShop(
    widget.admin.shopId,
  );
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _priceController,
      _hoursController,
      _imageController,
      _locationController,
      _phoneController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final price = int.tryParse(_priceController.text.trim());
    final hours = _hoursController.text.trim();
    if (price == null || price < 1 || price > 100000) {
      _showMessage('กรุณากรอกราคาระหว่าง 1–100,000 บาท');
      return;
    }
    if (hours.length > 40) {
      _showMessage('เวลาเปิด–ปิดยาวได้ไม่เกิน 40 ตัวอักษร');
      return;
    }
    final imageError = imageSourceError(_imageController.text);
    if (imageError != null) {
      _showMessage(imageError);
      return;
    }
    if (_locationController.text.trim().length > 300 ||
        _phoneController.text.trim().length > 30) {
      _showMessage('ที่อยู่หรือเบอร์โทรยาวเกินไป');
      return;
    }
    setState(() => _saving = true);
    try {
      await _shopService.updateShopSettings(
        shopId: widget.admin.shopId,
        pricePerPerson: price,
        openingHours: hours,
        image: _imageController.text,
        location: _locationController.text,
        phone: _phoneController.text,
      );
      _showMessage('บันทึกข้อมูลร้านแล้ว');
    } on FirebaseException {
      _showMessage('บันทึกไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _shop,
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
        if (!_loaded) {
          _loaded = true;
          _priceController.text = '${shop['pricePerPerson'] as int? ?? ''}';
          _hoursController.text = shop['openingHours'] as String? ?? '';
          _imageController.text = shop['image'] as String? ?? '';
          _locationController.text = shop['location'] as String? ?? '';
          _phoneController.text = shop['phone'] as String? ?? '';
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront),
                title: Text(shop['name'] as String? ?? widget.admin.shopName),
                subtitle: Text(
                  'ราคาปัจจุบัน ฿${shop['pricePerPerson'] ?? '-'}/คน',
                ),
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
            TextField(
              controller: _hoursController,
              enabled: !_saving,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'เวลาเปิด–ปิด',
                hintText: 'เช่น 11:00–22:00 ทุกวัน',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              enabled: !_saving,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'ที่อยู่',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              enabled: !_saving,
              maxLength: 30,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'เบอร์โทร',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ImageUrlField(
              controller: _imageController,
              enabled: !_saving,
              label: 'ลิงก์รูปร้าน',
              previewHeight: 160,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon:
                  _saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save),
              label: const Text('บันทึก'),
            ),
          ],
        );
      },
    );
  }
}
