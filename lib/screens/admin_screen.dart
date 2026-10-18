import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/admin_service.dart';
import '../services/shop_service.dart';
import '../theme/app_theme.dart';
import '../utils/shop_form.dart';
import '../widgets/brand.dart';
import 'admin_account_dialog.dart';
import 'app_content_admin.dart';
import 'banner_admin.dart';
import 'promo_code_admin.dart';
import 'shop_admin_view.dart';
import 'shop_form_dialog.dart';

/// Entry point for admins: the Super Admin dashboard, or a shop admin's own
/// shop.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.isSuperAdmin});

  final bool isSuperAdmin;

  @override
  Widget build(BuildContext context) {
    if (isSuperAdmin) return const _SuperAdminPage();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('กรุณาเข้าสู่ระบบอีกครั้ง')),
      );
    }
    return ShopAdminView(adminService: AdminService(), uid: uid);
  }
}

/// Shops, promo codes, admin accounts and app content.
class _SuperAdminPage extends StatefulWidget {
  const _SuperAdminPage();

  @override
  State<_SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<_SuperAdminPage> {
  final _adminService = AdminService();
  final _shopService = ShopService();
  late final Stream<List<AdminProfile>> _admins = _adminService.watchAdmins();
  late final Stream<List<Shop>> _shops = _shopService.watchShops(
    includeInactive: true,
  );
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _users =
      _adminService.watchUsers();

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                style: destructiveButtonStyle(dialogContext),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
    );
    return confirmed == true;
  }

  // ---- Shops ----

  Future<void> _addShop() async {
    final draft = await showDialog<ShopDraft>(
      context: context,
      builder: (_) => const ShopFormDialog(),
    );
    if (draft == null) return;
    try {
      await _shopService.createShop(draft);
      _showMessage('เพิ่มร้าน ${draft.name} แล้ว');
    } on StateError catch (error) {
      _showMessage(error.message, error: true);
    } on FirebaseException {
      _showMessage('เพิ่มร้านไม่สำเร็จ รหัสร้านอาจถูกใช้แล้ว', error: true);
    }
  }

  Future<void> _editShop(Shop shop) async {
    final draft = await showDialog<ShopDraft>(
      context: context,
      builder: (_) => ShopFormDialog(shop: shop),
    );
    if (draft == null) return;
    try {
      await _shopService.updateShop(draft);
      _showMessage('แก้ไขข้อมูลร้านแล้ว');
    } on FirebaseException {
      _showMessage('แก้ไขร้านไม่สำเร็จ กรุณาลองใหม่', error: true);
    }
  }

  Future<void> _setShopActive(Shop shop, {required bool active}) async {
    if (!active &&
        !await _confirm(
          title: 'ซ่อนร้าน',
          message:
              'ร้าน ${shop.name} จะหายจากหน้าลูกค้า '
              'แต่ประวัติคิวและสถิติยังอยู่ และกู้คืนได้ภายหลัง',
          action: 'ซ่อนร้าน',
        )) {
      return;
    }
    try {
      await _shopService.setShopActive(shopId: shop.id, active: active);
      _showMessage(active ? 'กู้คืนร้านแล้ว' : 'ซ่อนร้านแล้ว');
    } on FirebaseException {
      _showMessage('เปลี่ยนสถานะร้านไม่สำเร็จ กรุณาลองใหม่', error: true);
    }
  }

  // ---- Admin accounts ----

  Future<void> _addAdmin(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    Set<String> adminIds,
    List<Shop> activeShops,
  ) async {
    if (activeShops.isEmpty) {
      _showMessage('กรุณาเพิ่มร้านก่อนเพิ่มแอดมิน', error: true);
      return;
    }
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final candidates = [
      for (final user in users)
        if ((user.data()['email'] as String? ?? '').trim().isNotEmpty &&
            user.id != myUid &&
            !adminIds.contains(user.id))
          AdminCandidate(uid: user.id, email: user.data()['email'] as String),
    ];
    if (candidates.isEmpty) {
      _showMessage(
        'ไม่มีผู้ใช้ที่สามารถเพิ่มได้ ผู้ใช้ต้องสมัครสมาชิกก่อน',
        error: true,
      );
      return;
    }
    final draft = await showDialog<AdminDraft>(
      context: context,
      builder:
          (_) => AdminAccountDialog(shops: activeShops, candidates: candidates),
    );
    if (draft == null) return;
    try {
      await _adminService.addAdmin(
        uid: draft.uid,
        email: draft.email,
        displayName: draft.displayName,
        shopId: draft.shop.id,
        shopName: draft.shop.name,
      );
      _showMessage('เพิ่ม ${draft.email} เป็นแอดมินแล้ว');
    } on FirebaseException {
      _showMessage('เพิ่มแอดมินไม่สำเร็จ กรุณาลองใหม่', error: true);
    }
  }

  Future<void> _editAdmin(AdminProfile admin, List<Shop> activeShops) async {
    if (activeShops.isEmpty) {
      _showMessage('ยังไม่มีร้านให้เลือก', error: true);
      return;
    }
    final draft = await showDialog<AdminDraft>(
      context: context,
      builder: (_) => AdminAccountDialog(shops: activeShops, admin: admin),
    );
    if (draft == null) return;
    try {
      await _adminService.updateAdmin(
        admin: admin,
        displayName: draft.displayName,
        active: draft.active,
        shopId: draft.shop.id,
        shopName: draft.shop.name,
      );
      _showMessage('บันทึกข้อมูลแอดมินแล้ว');
    } on FirebaseException {
      _showMessage('แก้ไขแอดมินไม่สำเร็จ กรุณาลองใหม่', error: true);
    }
  }

  Future<void> _removeAdmin(AdminProfile admin) async {
    if (!await _confirm(
      title: 'ลบสิทธิ์แอดมิน',
      message:
          '${admin.email} จะกลับเป็นผู้ใช้ทั่วไป แต่บัญชีและข้อมูลจะยังอยู่',
      action: 'ลบสิทธิ์',
    )) {
      return;
    }
    try {
      await _adminService.removeAdmin(admin);
      _showMessage('ลบสิทธิ์แอดมินแล้ว');
    } on FirebaseException {
      _showMessage('ลบสิทธิ์แอดมินไม่สำเร็จ กรุณาลองใหม่', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [Wordmark(size: 20), SizedBox(width: 10), Text('Admin')],
        ),
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ',
            onPressed: FirebaseAuth.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<AdminProfile>>(
        stream: _admins,
        builder: (context, adminSnapshot) {
          return StreamBuilder<List<Shop>>(
            stream: _shops,
            builder: (context, shopSnapshot) {
              if (adminSnapshot.hasError || shopSnapshot.hasError) {
                return const Center(child: Text('โหลดข้อมูลไม่สำเร็จ'));
              }
              if (!adminSnapshot.hasData || !shopSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final admins = adminSnapshot.data!;
              final shops = shopSnapshot.data!;
              final activeShops = shops.where((shop) => shop.active).toList();
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _users,
                builder: (context, userSnapshot) {
                  final users = userSnapshot.data?.docs;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const _SuperAdminHeader(),
                      const SizedBox(height: 8),
                      const _ContentLinks(),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'ร้านทั้งหมด',
                        action: FilledButton.icon(
                          onPressed: _addShop,
                          icon: const Icon(Icons.add_business),
                          label: const Text('เพิ่มร้าน'),
                        ),
                      ),
                      if (shops.isEmpty) const _EmptyCard('ยังไม่มีร้าน'),
                      for (final shop in shops)
                        _ShopTile(
                          shop: shop,
                          onEdit: () => _editShop(shop),
                          onSetActive:
                              (active) => _setShopActive(shop, active: active),
                        ),
                      const SizedBox(height: 16),
                      PromoCodeAdmin(),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'บัญชีแอดมิน',
                        action: FilledButton.icon(
                          onPressed:
                              users == null
                                  ? null
                                  : () => _addAdmin(users, {
                                    for (final admin in admins) admin.uid,
                                  }, activeShops),
                          icon: const Icon(Icons.person_add),
                          label: const Text('เพิ่มแอดมิน'),
                        ),
                      ),
                      if (admins.isEmpty)
                        const _EmptyCard('ยังไม่มีบัญชีแอดมินเพิ่มเติม'),
                      for (final admin in admins)
                        _AdminTile(
                          admin: admin,
                          onEdit: () => _editAdmin(admin, activeShops),
                          onRemove: () => _removeAdmin(admin),
                        ),
                    ],
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

class _SuperAdminHeader extends StatelessWidget {
  const _SuperAdminHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.shield)),
        title: const Text('Super Admin'),
        subtitle: Text(FirebaseAuth.instance.currentUser?.email ?? ''),
        trailing: const Chip(label: Text('ลบไม่ได้')),
      ),
    );
  }
}

class _ContentLinks extends StatelessWidget {
  const _ContentLinks();

  @override
  Widget build(BuildContext context) {
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.view_carousel),
            title: const Text('แบนเนอร์หน้าแรก'),
            subtitle: const Text('เพิ่ม แก้ไข เรียงลำดับ หรือซ่อนแบนเนอร์'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const BannerAdminScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.article),
            title: const Text('ข้อความในแอป'),
            subtitle: const Text(
              'การช่วยเหลือ ข้อกำหนด และนโยบายความเป็นส่วนตัว',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const AppContentAdminScreen()),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          action,
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text(message)),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.shop,
    required this.onEdit,
    required this.onSetActive,
  });

  final Shop shop;
  final VoidCallback onEdit;
  final ValueChanged<bool> onSetActive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.storefront)),
        title: Text(shop.name),
        subtitle: Text(
          'รหัส: ${shop.id}\nราคา ฿${shop.pricePerPerson}/คน'
          '${shop.active ? '' : '\nซ่อนจากลูกค้าอยู่'}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'edit':
                onEdit();
              case 'hide':
                onSetActive(false);
              case 'restore':
                onSetActive(true);
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(value: 'edit', child: Text('แก้ไขร้าน')),
                if (shop.active)
                  const PopupMenuItem(value: 'hide', child: Text('ซ่อนร้าน'))
                else
                  const PopupMenuItem(
                    value: 'restore',
                    child: Text('กู้คืนร้าน'),
                  ),
              ],
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.admin,
    required this.onEdit,
    required this.onRemove,
  });

  final AdminProfile admin;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            admin.active ? Icons.admin_panel_settings : Icons.person_off,
          ),
        ),
        title: Text(
          admin.displayName.isEmpty ? admin.email : admin.displayName,
        ),
        subtitle: Text(
          '${admin.email}\n${admin.shopName}\n'
          '${admin.active ? 'เปิดใช้งาน' : 'ปิดใช้งาน'}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) => action == 'edit' ? onEdit() : onRemove(),
          itemBuilder:
              (context) => const [
                PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                PopupMenuItem(value: 'remove', child: Text('ลบสิทธิ์แอดมิน')),
              ],
        ),
      ),
    );
  }
}
