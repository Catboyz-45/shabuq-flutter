import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/admin_service.dart';
import '../services/shop_service.dart';
import '../utils/shop_form.dart';
import '../widgets/image_url_field.dart';
import 'shop_menu_admin.dart';
import 'shop_queue_admin.dart';
import 'shop_stats_admin.dart';

/// Home of a shop admin: queue board, stats, menu and shop details for the
/// one shop they were assigned.
class ShopAdminView extends StatelessWidget {
  const ShopAdminView({
    super.key,
    required this.adminService,
    required this.uid,
  });

  final AdminService adminService;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminProfile?>(
      stream: adminService.watchAdmin(uid),
      builder: (context, adminSnapshot) {
        if (adminSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final admin = adminSnapshot.data;
        if (admin == null || !admin.active || admin.shopId.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('ShabuQ Admin'),
              actions: const [_SignOutButton()],
            ),
            body: const Center(child: Text('บัญชีนี้ยังไม่ได้รับมอบหมายร้าน')),
          );
        }

        // Tabs sit on the coloured app bar, so they use its text colour.
        final onAppBar =
            AppBarTheme.of(context).foregroundColor ??
            Theme.of(context).colorScheme.onSurface;
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(admin.shopName),
              actions: const [_SignOutButton()],
              bottom: TabBar(
                labelColor: onAppBar,
                unselectedLabelColor: onAppBar.withValues(alpha: 0.7),
                indicatorColor: onAppBar,
                tabs: const [
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
                ShopSettingsAdmin(shopId: admin.shopId),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'ออกจากระบบ',
      onPressed: FirebaseAuth.instance.signOut,
      icon: const Icon(Icons.logout),
    );
  }
}

/// The details a shop admin may change for their own shop.
class ShopSettingsAdmin extends StatefulWidget {
  const ShopSettingsAdmin({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopSettingsAdmin> createState() => _ShopSettingsAdminState();
}

class _ShopSettingsAdminState extends State<ShopSettingsAdmin> {
  final _shopService = ShopService();
  final _price = TextEditingController();
  final _hours = TextEditingController();
  final _image = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  late final Stream<Shop?> _shop = _shopService.watchShop(widget.shopId);
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_price, _hours, _image, _location, _phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(Shop shop) async {
    // Same checks as the Super Admin form, for the fields edited here.
    final draft = ShopDraft(
      id: shop.id,
      name: shop.name,
      location: _location.text.trim(),
      phone: _phone.text.trim(),
      image: _image.text.trim(),
      zones: shop.bookableZones,
      pricePerPerson: int.tryParse(_price.text.trim()) ?? 0,
      openingHours: _hours.text.trim(),
    );
    final error = validateShopDraft(draft, isNew: false);
    if (error != null) {
      _showMessage(error);
      return;
    }
    setState(() => _saving = true);
    try {
      await _shopService.updateShopSettings(
        shopId: shop.id,
        pricePerPerson: draft.pricePerPerson,
        openingHours: draft.openingHours,
        image: draft.image,
        location: draft.location,
        phone: draft.phone,
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
    return StreamBuilder<Shop?>(
      stream: _shop,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('โหลดข้อมูลร้านไม่สำเร็จ'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final shop = snapshot.data;
        if (shop == null) {
          return const Center(child: Text('ไม่พบข้อมูลร้าน'));
        }
        if (!_loaded) {
          _loaded = true;
          _price.text = '${shop.pricePerPerson}';
          _hours.text = shop.openingHours;
          _image.text = shop.image;
          _location.text = shop.location;
          _phone.text = shop.phone;
        }
        const gap = SizedBox(height: 8);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront),
                title: Text(shop.name),
                subtitle: Text('ราคาปัจจุบัน ฿${shop.pricePerPerson}/คน'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _price,
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
              controller: _hours,
              enabled: !_saving,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'เวลาเปิด–ปิด',
                hintText: 'เช่น 11:00–22:00 ทุกวัน',
                border: OutlineInputBorder(),
              ),
            ),
            gap,
            TextField(
              controller: _location,
              enabled: !_saving,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'ที่อยู่',
                border: OutlineInputBorder(),
              ),
            ),
            gap,
            TextField(
              controller: _phone,
              enabled: !_saving,
              maxLength: 30,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'เบอร์โทร',
                border: OutlineInputBorder(),
              ),
            ),
            gap,
            ImageUrlField(
              controller: _image,
              enabled: !_saving,
              label: 'ลิงก์รูปร้าน',
              previewHeight: 160,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(shop),
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
