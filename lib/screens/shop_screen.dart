import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/queue_entry.dart';
import '../models/shop.dart';
import '../services/menu_service.dart';
import '../services/queue_service.dart';
import '../services/shop_service.dart';
import '../theme/app_theme.dart';
import '../utils/last_booking.dart';
import '../utils/maps.dart';
import '../utils/payment_calculator.dart';
import '../utils/queue_position.dart';
import '../widgets/booking_flow.dart';
import '../widgets/brand.dart';
import '../widgets/motion.dart';
import '../widgets/shop_image.dart';

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
  static const _maxParty = 10;

  final _queueService = QueueService();
  final _shopService = ShopService();
  final _menuService = MenuService();
  String? _selectedZone;
  int _party = 2;
  bool _booking = false;

  late final Stream<Shop?> _shop;
  late final Stream<QueueEntry?> _myQueue;
  late final Stream<List<MenuItem>> _menu;

  /// Waiting queues per zone today, kept live for the zone cards and the
  /// wait estimate.
  final _zoneWaiting = <String, int>{};
  final _zoneSubscriptions = <String, StreamSubscription<List<QueueTicket>>>{};

  String get _shopId => widget.shop.id;

  @override
  void initState() {
    super.initState();
    _shop = _shopService.watchShop(_shopId);
    _myQueue = _queueService.watchMyQueue(
      FirebaseAuth.instance.currentUser?.uid ?? '-',
    );
    _menu = _menuService.watchMenu(_shopId);
    // Start from what this customer booked here last time.
    LastBooking.load(_shopId).then((last) {
      if (!mounted || last == null) return;
      setState(() {
        _party = last.partySize.clamp(1, _maxParty);
        _selectedZone = last.zone;
      });
    });
  }

  @override
  void dispose() {
    for (final subscription in _zoneSubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  /// Follows the waiting count of exactly the shop's current zones.
  void _watchZones(List<String> zones) {
    for (final zone in _zoneSubscriptions.keys.toList()) {
      if (!zones.contains(zone)) _zoneSubscriptions.remove(zone)?.cancel();
    }
    final today = queueDateKey(DateTime.now());
    for (final zone in zones) {
      _zoneSubscriptions.putIfAbsent(
        zone,
        () => _queueService
            .watchWaitingTickets(shopId: _shopId, zone: zone, queueDate: today)
            .listen((tickets) {
              if (mounted) setState(() => _zoneWaiting[zone] = tickets.length);
            }),
      );
    }
  }

  Future<void> _book(String zone) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _booking) return;
    setState(() => _booking = true);
    try {
      final label = await BookingFlow(
        _queueService,
      ).book(context, uid: uid, shopId: _shopId, zone: zone, partySize: _party);
      if (!mounted || label == null) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => _BookedDialog(label: label),
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
    if (!await openShopInMaps(shop)) _showError('เปิดแผนที่ไม่สำเร็จ');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Shop?>(
      stream: _shop,
      initialData: widget.shop,
      builder: (context, shopSnapshot) {
        final shop = shopSnapshot.data ?? widget.shop;
        final zones = shop.bookableZones;
        _watchZones(zones);
        final zone =
            zones.contains(_selectedZone) ? _selectedZone! : zones.first;

        return StreamBuilder<QueueEntry?>(
          stream: _myQueue,
          builder: (context, queueSnapshot) {
            final activeQueue = queueSnapshot.data;
            // Until the first snapshot arrives, assume a queue exists so
            // the button can't be pressed twice.
            final hasQueue =
                queueSnapshot.connectionState != ConnectionState.active ||
                activeQueue != null;
            final waiting = _zoneWaiting[zone];
            return Scaffold(
              body: CustomScrollView(
                slivers: [
                  _Hero(shop: shop),
                  SliverToBoxAdapter(
                    child: FadeSlideIn(
                      offset: 40,
                      child: _Details(
                        shop: shop,
                        zones: zones,
                        zone: zone,
                        zoneWaiting: _zoneWaiting,
                        party: _party,
                        maxParty: _maxParty,
                        activeQueue: activeQueue,
                        menu: _menu,
                        onZone:
                            (value) => setState(() => _selectedZone = value),
                        onParty: (value) => setState(() => _party = value),
                        onOpenMap: () => _openMap(shop),
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                offset: 90,
                child: _BookingBar(
                  party: _party,
                  waitMinutes:
                      waiting == null
                          ? null
                          : estimateWaitMinutes(
                            ahead: waiting,
                            minutesPerQueue: shop.minutesPerQueue,
                          ),
                  booking: _booking,
                  blockedReason:
                      !shop.canBook
                          ? 'ร้านปิดรับคิวชั่วคราว'
                          : hasQueue
                          ? 'คุณมีคิวอยู่แล้ว'
                          : null,
                  onBook: () => _book(zone),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      stretch: true,
      backgroundColor: scheme.surface,
      leading: Padding(
        padding: const EdgeInsets.all(6),
        child: IconButton.filled(
          tooltip: 'กลับ',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Palette.ink,
          ),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            ShopImage(source: shop.image),
            // Keeps the back button readable on bright photos.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment(0, -0.2),
                  colors: [Color(0x55000000), Color(0x00000000)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.shop,
    required this.zones,
    required this.zone,
    required this.zoneWaiting,
    required this.party,
    required this.maxParty,
    required this.activeQueue,
    required this.menu,
    required this.onZone,
    required this.onParty,
    required this.onOpenMap,
  });

  final Shop shop;
  final List<String> zones;
  final String zone;
  final Map<String, int> zoneWaiting;
  final int party;
  final int maxParty;
  final QueueEntry? activeQueue;
  final Stream<List<MenuItem>> menu;
  final ValueChanged<String> onZone;
  final ValueChanged<int> onParty;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hours = shop.openingHours.trim();
    final location = shop.location.trim();
    final phone = shop.phone.trim();
    final price = shop.pricePerPerson;
    final queue = activeQueue;

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shop.name,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (shop.canBook)
                StatusPill(
                  label: 'เปิดรับคิว',
                  background: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                  leading: LiveDot(color: scheme.tertiary, size: 7),
                )
              else
                StatusPill(
                  label: 'ปิดรับคิวชั่วคราว',
                  background: scheme.errorContainer,
                  foreground: scheme.onErrorContainer,
                ),
              if (hours.isNotEmpty)
                StatusPill(
                  label: hours,
                  background: scheme.surfaceContainer,
                  foreground: scheme.onSurface,
                ),
              if (price > 0)
                StatusPill(
                  label: '฿$price/คน',
                  background: scheme.surfaceContainer,
                  foreground: scheme.onSurface,
                ),
            ],
          ),
          if (location.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.place_outlined,
              text: [
                location,
                phone,
              ].where((part) => part.isNotEmpty).join(' • '),
              action: TextButton(
                onPressed: onOpenMap,
                child: const Text('ดูแผนที่'),
              ),
            ),
          ],
          if (queue != null) ...[
            const SizedBox(height: 12),
            _Notice(
              icon: Icons.confirmation_number_outlined,
              text:
                  'คุณมีคิว ${queue.queueLabel} ที่ ${queue.shopName} อยู่แล้ว '
                  'ยกเลิกคิวเดิมก่อนรับคิวใหม่',
            ),
          ],
          const SizedBox(height: 24),
          const SectionTitle('เลือกโซน'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in zones)
                    SizedBox(
                      width: width,
                      child: _ZoneCard(
                        code: zoneCodeFor(zones, option),
                        name: option,
                        waiting: zoneWaiting[option],
                        selected: option == zone,
                        onTap: () => onZone(option),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Divider(color: scheme.outlineVariant),
          _PartyStepper(party: party, max: maxParty, onChanged: onParty),
          if (price > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'ประมาณ ฿${calculatePayment(partySize: party, pricePerPerson: price).total} '
                '(ชำระที่ร้าน)',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 20),
          const SectionTitle('เมนู'),
          _ShopMenu(stream: menu),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.code,
    required this.name,
    required this.waiting,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String name;
  final int? waiting;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final waitText = switch (waiting) {
      null => 'กำลังโหลด…',
      0 => 'ไม่ต้องรอ',
      final count => 'รอ $count คิว',
    };
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Motion.ease,
        decoration: BoxDecoration(
          color:
              selected
                  ? (isLight ? Palette.yolkTint : scheme.primaryContainer)
                  : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.onSurface : scheme.outlineVariant,
            width: 2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(code, style: AppFonts.numbers(fontSize: 22)),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    waitText,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PartyStepper extends StatelessWidget {
  const _PartyStepper({
    required this.party,
    required this.max,
    required this.onChanged,
  });

  final int party;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'จำนวนคน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'รวมเด็กด้วย',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: 'ลดจำนวนคน',
            style: IconButton.styleFrom(
              fixedSize: const Size.square(44),
              side: BorderSide(color: scheme.outlineVariant, width: 1.5),
            ),
            onPressed: party > 1 ? () => onChanged(party - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 52,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder:
                  (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
              child: Text(
                '$party',
                key: ValueKey(party),
                textAlign: TextAlign.center,
                style: AppFonts.numbers(fontSize: 28),
              ),
            ),
          ),
          IconButton.filled(
            tooltip: 'เพิ่มจำนวนคน',
            style: IconButton.styleFrom(
              fixedSize: const Size.square(44),
              backgroundColor: scheme.onSurface,
              foregroundColor: scheme.surface,
            ),
            onPressed: party < max ? () => onChanged(party + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// Sticky bar: the wait estimate and the big "take a queue" button.
class _BookingBar extends StatelessWidget {
  const _BookingBar({
    required this.party,
    required this.waitMinutes,
    required this.booking,
    required this.blockedReason,
    required this.onBook,
  });

  final int party;
  final int? waitMinutes;
  final bool booking;

  /// Why booking is not possible right now, shown on the button.
  final String? blockedReason;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : Palette.nightPanel,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'รอประมาณ',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  waitMinutes == null ? '-' : '~$waitMinutes นาที',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: blockedReason != null || booking ? null : onBook,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: isLight ? Palette.chili : scheme.primary,
                  foregroundColor: isLight ? Colors.white : scheme.onPrimary,
                ),
                child:
                    booking
                        ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                        : Text(blockedReason ?? 'รับคิว $party คน'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookedDialog extends StatelessWidget {
  const _BookedDialog({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('ได้คิวแล้ว', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Palette.yolk,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.numbers(
                fontSize: 64,
                color: Palette.ink,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'ติดตามลำดับคิวได้ที่แท็บ "คิวของฉัน" '
            'แอปจะแจ้งเตือนเมื่อใกล้ถึงคิว ชำระเงินที่ร้านได้เลย',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('ดูคิวของฉัน'),
        ),
      ],
    );
  }
}

class _ShopMenu extends StatelessWidget {
  const _ShopMenu({required this.stream});

  final Stream<List<MenuItem>> stream;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'ร้านนี้ยังไม่มีเมนู',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;
    final hasImage = item.imageUrl.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ShopImage(
                source: item.imageUrl,
                width: 64,
                height: 64,
                placeholderIcon: Icons.restaurant_menu,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (item.description.isNotEmpty)
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.price > 0 ? '+฿${item.price}' : 'รวมในบุฟเฟ่ต์',
            style: TextStyle(
              color: item.price > 0 ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: item.price > 0 ? FontWeight.w700 : null,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
