import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/shop.dart';
import '../services/admin_service.dart';
import '../services/shop_service.dart';
import '../theme/theme_controller.dart';
import '../utils/input_formatters.dart';
import '../utils/shop_form.dart';
import '../widgets/brand.dart';
import '../widgets/image_url_field.dart';
import '../widgets/opening_hours_field.dart';
import 'shop_menu_admin.dart';
import 'shop_queue_admin.dart';
import 'shop_stats_admin.dart';

/// Home of a shop admin: queue board, stats, menu and shop details for the
/// one shop they were assigned. Always uses the dark "kitchen display"
/// theme, with a side rail on tablets and bottom tabs on phones.
class ShopAdminView extends StatefulWidget {
  const ShopAdminView({
    super.key,
    required this.adminService,
    required this.uid,
  });

  final AdminService adminService;
  final String uid;

  @override
  State<ShopAdminView> createState() => _ShopAdminViewState();
}

class _ShopAdminViewState extends State<ShopAdminView> {
  late final Stream<AdminProfile?> _admin = widget.adminService.watchAdmin(
    widget.uid,
  );
  ThemeController? _theme;
  int _tab = 0;

  static const _destinations = [
    (Icons.view_column_outlined, Icons.view_column_rounded, 'คิว'),
    (Icons.insights_outlined, Icons.insights_rounded, 'สถิติ'),
    (Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded, 'เมนู'),
    (Icons.storefront_outlined, Icons.storefront_rounded, 'ร้าน'),
  ];

  @override
  void initState() {
    super.initState();
    // Keep the counter tablet's screen on while the board is open.
    WakelockPlus.enable().catchError((Object _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_theme == null) {
      _theme = ThemeScope.maybeRead(context);
      final theme = _theme;
      if (theme != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => theme.staffMode.value = true,
        );
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((Object _) {});
    final theme = _theme;
    if (theme != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => theme.staffMode.value = false,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminProfile?>(
      stream: _admin,
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
              title: const Wordmark(size: 20),
              actions: const [_SignOutButton()],
            ),
            body: const Center(child: Text('บัญชีนี้ยังไม่ได้รับมอบหมายร้าน')),
          );
        }

        final pages = IndexedStack(
          index: _tab,
          children: [
            ShopQueueAdmin(adminService: widget.adminService, admin: admin),
            ShopStatsAdmin(
              adminService: widget.adminService,
              shopId: admin.shopId,
            ),
            ShopMenuAdmin(admin: admin),
            ShopSettingsAdmin(shopId: admin.shopId),
          ],
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 840) {
              return Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      _StaffRail(
                        selected: _tab,
                        destinations: _destinations,
                        onSelect: (index) => setState(() => _tab = index),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      Expanded(child: pages),
                    ],
                  ),
                ),
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    const QChip(size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        admin.shopName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                actions: const [_SignOutButton()],
              ),
              body: pages,
              bottomNavigationBar: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (index) => setState(() => _tab = index),
                destinations: [
                  for (final (icon, selectedIcon, label) in _destinations)
                    NavigationDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selectedIcon),
                      label: label,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Left rail for tablets: the Q mark, the four sections and sign-out.
class _StaffRail extends StatelessWidget {
  const _StaffRail({
    required this.selected,
    required this.destinations,
    required this.onSelect,
  });

  final int selected;
  final List<(IconData, IconData, String)> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          const SizedBox(height: 18),
          const QChip(size: 48),
          const SizedBox(height: 22),
          for (final (index, (icon, selectedIcon, label))
              in destinations.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                selected: index == selected,
                button: true,
                child: Material(
                  color:
                      index == selected
                          ? scheme.surfaceContainerHigh
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelect(index),
                    child: SizedBox(
                      width: 74,
                      height: 64,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            index == selected ? selectedIcon : icon,
                            color:
                                index == selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  index == selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color:
                                  index == selected
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          const _SignOutButton(),
          const SizedBox(height: 16),
        ],
      ),
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
      icon: const Icon(Icons.logout_rounded),
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
  String _hours = '';
  final _image = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  late final Stream<Shop?> _shop = _shopService.watchShop(widget.shopId);
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_price, _image, _location, _phone]) {
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
      openingHours: _hours.trim(),
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
          _hours = shop.openingHours;
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
              maxLength: 6,
              inputFormatters: [digitsOnly],
              decoration: const InputDecoration(
                labelText: 'ราคาต่อคน (บาท)',
                border: OutlineInputBorder(),
                prefixText: '฿ ',
              ),
            ),
            const SizedBox(height: 16),
            OpeningHoursField(
              initial: _hours,
              optional: true,
              enabled: !_saving,
              onChanged: (value) => _hours = value,
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
              maxLength: phoneMaxLength,
              inputFormatters: [phoneCharacters],
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
