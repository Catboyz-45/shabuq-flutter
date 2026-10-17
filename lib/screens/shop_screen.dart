import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/menu_service.dart';
import '../services/queue_service.dart';
import '../services/shop_service.dart';
import '../utils/payment_calculator.dart';
import '../widgets/shop_image.dart';
import '../theme/app_theme.dart';
import '../models/queue_entry.dart';
import '../models/shop.dart';

/// Shop details, its menu and the one-tap queue booking. Pops with `true`
/// after a successful booking so the caller can switch to the queue tab.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.shop});

  /// The shop as listed on the home screen; the page then follows live
  /// updates such as pausing bookings.
  final Shop shop;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _queueService = QueueService();
  final _shopService = ShopService();
  final _menuService = MenuService();
  String? _selectedZone;
  int _party = 2;
  bool _booking = false;

  late final Stream<Shop?> _shop;
  late final Stream<QueueEntry?> _myQueue;
  late final Stream<int> _waitingCount;
  late final Stream<List<MenuItem>> _menu;

  String get _shopId => widget.shop.id;

  @override
  void initState() {
    super.initState();
    _shop = _shopService.watchShop(_shopId);
    _myQueue = _queueService.watchMyQueue(
      FirebaseAuth.instance.currentUser?.uid ?? '-',
    );
    _waitingCount = _queueService.watchWaitingCount(_shopId);
    _menu = _menuService.watchMenu(_shopId);
  }

  Future<void> _book(String zone) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _booking) return;
    setState(() => _booking = true);
    try {
      final label = await _queueService.bookQueue(
        uid: uid,
        shopId: _shopId,
        zone: zone,
        partySize: _party,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              icon: const Icon(Icons.confirmation_number, size: 40),
              title: Text('ได้คิว $label'),
              content: const Text(
                'ติดตามลำดับคิวได้ที่แท็บ "คิวของฉัน" '
                'แอปจะแจ้งเตือนเมื่อใกล้ถึงคิว ชำระเงินที่ร้านได้เลย',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ดูคิวของฉัน'),
                ),
              ],
            ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on StateError catch (error) {
      _showError(error.message);
    } on FirebaseException {
      _showError('รับคิวไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openMap(Shop shop) async {
    final query = '${shop.name} ${shop.location}'.trim();
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('เปิดแผนที่ไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Shop?>(
      stream: _shop,
      initialData: widget.shop,
      builder: (context, shopSnapshot) {
        final shop = shopSnapshot.data ?? widget.shop;
        final zones = shop.bookableZones;
        final zone =
            zones.contains(_selectedZone) ? _selectedZone! : zones.first;
        final price = shop.pricePerPerson;
        final accepting = shop.canBook;

        return Scaffold(
          appBar: AppBar(title: Text(shop.name)),
          body: StreamBuilder<QueueEntry?>(
            stream: _myQueue,
            builder: (context, queueSnapshot) {
              final activeQueue = queueSnapshot.data;
              // Until the first snapshot arrives, assume a queue exists so
              // the button can't be pressed twice.
              final hasQueue =
                  queueSnapshot.connectionState != ConnectionState.active ||
                  activeQueue != null;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ShopInfoCard(
                    shop: shop,
                    waitingCount: _waitingCount,
                    onOpenMap: () => _openMap(shop),
                  ),
                  const SizedBox(height: 16),
                  if (!accepting)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const ListTile(
                        leading: Icon(Icons.pause_circle),
                        title: Text('ร้านปิดรับคิวชั่วคราว'),
                        subtitle: Text('ลองใหม่อีกครั้งภายหลัง'),
                      ),
                    ),
                  if (activeQueue != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(
                          'คุณมีคิว ${activeQueue.queueLabel} '
                          'ที่ ${activeQueue.shopName} อยู่แล้ว',
                        ),
                        subtitle: const Text('ยกเลิกคิวเดิมก่อนรับคิวใหม่'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey(zones.join('|')),
                    initialValue: zone,
                    decoration: const InputDecoration(labelText: 'เลือกโซน'),
                    items:
                        zones
                            .map(
                              (zone) => DropdownMenuItem(
                                value: zone,
                                child: Text(zone),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => _selectedZone = value),
                  ),
                  const SizedBox(height: 20),
                  const Text('จำนวนคน', textAlign: TextAlign.center),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'ลดจำนวนคน',
                        icon: Icon(
                          Icons.remove_circle,
                          size: 40,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed:
                            _party > 1 ? () => setState(() => _party--) : null,
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          '$_party',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'เพิ่มจำนวนคน',
                        icon: Icon(
                          Icons.add_circle,
                          size: 40,
                          color: StatusColors.of(context).success,
                        ),
                        onPressed:
                            _party < 10 ? () => setState(() => _party++) : null,
                      ),
                    ],
                  ),
                  if (price > 0)
                    Text(
                      'ประมาณ ฿${calculatePayment(partySize: _party, pricePerPerson: price).total} '
                      '(ชำระที่ร้าน)',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed:
                        !accepting || hasQueue || _booking
                            ? null
                            : () => _book(zone),
                    icon:
                        _booking
                            ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.confirmation_number),
                    label: const Text('รับคิว', style: TextStyle(fontSize: 20)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('เมนู', style: Theme.of(context).textTheme.titleLarge),
                  _ShopMenu(stream: _menu),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ShopInfoCard extends StatelessWidget {
  const _ShopInfoCard({
    required this.shop,
    required this.waitingCount,
    required this.onOpenMap,
  });

  final Shop shop;
  final Stream<int> waitingCount;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final hours = shop.openingHours.trim();
    final location = shop.location.trim();
    final phone = shop.phone.trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShopImage(source: shop.image, width: double.infinity, height: 160),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<int>(
                  stream: waitingCount,
                  builder:
                      (context, snapshot) => _InfoRow(
                        icon: Icons.people,
                        text:
                            snapshot.hasData
                                ? 'รอคิวอยู่ ${snapshot.data} คิว'
                                : 'กำลังโหลดจำนวนคิว…',
                        emphasized: true,
                      ),
                ),
                _InfoRow(
                  icon: Icons.payments,
                  text: '฿${shop.pricePerPerson} ต่อคน',
                ),
                if (hours.isNotEmpty)
                  _InfoRow(icon: Icons.schedule, text: 'เปิด $hours'),
                if (location.isNotEmpty)
                  _InfoRow(icon: Icons.place, text: location),
                if (phone.isNotEmpty) _InfoRow(icon: Icons.phone, text: phone),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onOpenMap,
                    icon: const Icon(Icons.map),
                    label: const Text('ดูแผนที่'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.emphasized = false,
  });

  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
                fontSize: emphasized ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopMenu extends StatelessWidget {
  const _ShopMenu({required this.stream});

  final Stream<List<MenuItem>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MenuItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('โหลดเมนูไม่สำเร็จ'),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final grouped = <String, List<MenuItem>>{};
        for (final item in snapshot.data!.where((item) => item.active)) {
          grouped.putIfAbsent(item.category, () => []).add(item);
        }
        if (grouped.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('ร้านนี้ยังไม่มีเมนู'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              for (final item in entry.value) _MenuItemTile(item: item),
            ],
          ],
        );
      },
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl.trim().isNotEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          if (hasImage)
            ShopImage(
              source: item.imageUrl,
              width: 80,
              height: 80,
              placeholderIcon: Icons.restaurant_menu,
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (item.description.isNotEmpty)
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              item.price > 0 ? '+฿${item.price}' : 'รวมในบุฟเฟ่ต์',
              style: TextStyle(
                color:
                    item.price > 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: item.price > 0 ? FontWeight.bold : null,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
