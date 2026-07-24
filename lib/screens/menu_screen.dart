import 'package:flutter/material.dart';

import '../services/menu_service.dart';
import '../services/shop_service.dart';
import '../widgets/shop_image.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final MenuService _menuService = MenuService();
  Map<String, dynamic>? _selectedShop;

  @override
  Widget build(BuildContext context) {
    final selectedShop = _selectedShop;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 149, 144, 248),
        foregroundColor: Colors.white,
        title: const Text('เมนูอาหาร'),
      ),
      body:
          selectedShop == null
              ? _ShopPicker(
                onSelected: (shop) => setState(() => _selectedShop = shop),
              )
              : _ShopMenu(
                shop: selectedShop,
                menuService: _menuService,
                onBack: () => setState(() => _selectedShop = null),
              ),
    );
  }
}

class _ShopPicker extends StatelessWidget {
  const _ShopPicker({required this.onSelected});

  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ShopService().watchShops(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('โหลดข้อมูลร้านไม่สำเร็จ'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final shops = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'เลือกร้านชาบู',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: shops.length,
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    return InkWell(
                      onTap: () => onSelected(shop),
                      borderRadius: BorderRadius.circular(16),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Expanded(
                              child: ShopImage(
                                source: shop['image'] as String? ?? '',
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                shop['name'] as String,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShopMenu extends StatelessWidget {
  const _ShopMenu({
    required this.shop,
    required this.menuService,
    required this.onBack,
  });

  final Map<String, dynamic> shop;
  final MenuService menuService;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final shopId = shop['id'] as String;
    return Column(
      children: [
        ListTile(
          leading: IconButton(
            tooltip: 'กลับไปเลือกร้าน',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            shop['name'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<MenuItem>>(
            stream: menuService.watchMenu(shopId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('โหลดเมนูไม่สำเร็จ กรุณาลองใหม่'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final activeItems =
                  snapshot.data!.where((item) => item.active).toList();
              if (activeItems.isEmpty) {
                return const Center(child: Text('ร้านนี้ยังไม่มีเมนู'));
              }
              final grouped = <String, List<MenuItem>>{};
              for (final item in activeItems) {
                grouped.putIfAbsent(item.category, () => []).add(item);
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children:
                    grouped.entries
                        .map(
                          (entry) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...entry.value.map(
                                (item) => _MenuCard(item: item),
                              ),
                            ],
                          ),
                        )
                        .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.restaurant_menu)),
        title: Text(item.name),
      ),
    );
  }
}
