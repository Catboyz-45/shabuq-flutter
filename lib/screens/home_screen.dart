// Import packages และหน้าจอที่เกี่ยวข้อง
import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/queue_entry.dart';
import '../models/shop.dart';
import '../services/banner_service.dart';
import '../services/queue_service.dart';
import '../services/shop_service.dart';
import '../theme/app_theme.dart';
import '../utils/queue_position.dart';
import '../widgets/brand.dart';
import '../widgets/motion.dart';
import '../widgets/shop_image.dart';
import 'shop_screen.dart';

// หน้าหลักของแอป: ค้นหาร้าน คิวที่กำลังรอ แบนเนอร์ และรายชื่อร้าน
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _ShopFilter { all, open, shortWait }

/// "Short wait" means at most this many queues ahead.
const _shortWaitQueues = 3;

class _HomeScreenState extends State<HomeScreen> {
  final ShopService _shopService = ShopService();
  final QueueService _queueService = QueueService();
  // แบนเนอร์มาจาก Firestore แอดมินเพิ่ม/แก้ได้จากหน้า Super Admin
  late final Stream<List<PromoBanner>> _banners =
      BannerService().watchBanners();
  late final Stream<List<Shop>> _shops = _shopService.watchShops();
  late final Stream<QueueEntry?> _myQueue = _queueService.watchMyQueue(
    FirebaseAuth.instance.currentUser?.uid ?? '-',
  );

  /// Live number of waiting queues per shop, for the rows and the
  /// short-wait filter.
  final _waiting = <String, int>{};
  final _waitingSubscriptions = <String, StreamSubscription<int>>{};
  String _query = '';
  _ShopFilter _filter = _ShopFilter.all;

  void _watchWaiting(List<Shop> shops) {
    final ids = {for (final shop in shops) shop.id};
    for (final id in _waitingSubscriptions.keys.toList()) {
      if (!ids.contains(id)) _waitingSubscriptions.remove(id)?.cancel();
    }
    for (final id in ids) {
      _waitingSubscriptions.putIfAbsent(
        id,
        () => _queueService.watchWaitingCount(id).listen((count) {
          if (mounted) setState(() => _waiting[id] = count);
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _waitingSubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> _openShop(Shop shop) async {
    final tabs = DefaultTabController.maybeOf(context);
    final booked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ShopScreen(shop: shop)),
    );
    // แท็บที่ 2 คือ "คิวของฉัน"
    if (booked == true) tabs?.animateTo(1);
  }

  Future<void> _openBannerShop(String shopId) async {
    final shop = await _shopService.watchShop(shopId).first;
    if (!mounted || shop == null || !shop.active) return;
    await _openShop(shop);
  }

  List<Shop> _visible(List<Shop> shops) {
    final query = _query.trim().toLowerCase();
    return [
      for (final shop in shops)
        if ((query.isEmpty ||
                shop.name.toLowerCase().contains(query) ||
                shop.location.toLowerCase().contains(query)) &&
            switch (_filter) {
              _ShopFilter.all => true,
              _ShopFilter.open => shop.canBook,
              _ShopFilter.shortWait =>
                shop.canBook &&
                    (_waiting[shop.id] ?? _shortWaitQueues + 1) <=
                        _shortWaitQueues,
            })
          shop,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Shop>>(
          stream: _shops,
          builder: (context, snapshot) {
            final shops = snapshot.data;
            if (shops != null) _watchWaiting(shops);
            final visible = shops == null ? const <Shop>[] : _visible(shops);
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        children: [
                          const Wordmark(size: 24),
                          const Spacer(),
                          IconButton.filled(
                            tooltip: 'โปรไฟล์',
                            style: IconButton.styleFrom(
                              backgroundColor: Palette.ink,
                              foregroundColor: Palette.yolk,
                              fixedSize: const Size.square(44),
                            ),
                            onPressed:
                                () => DefaultTabController.maybeOf(
                                  context,
                                )?.animateTo(3),
                            icon: const Icon(Icons.person_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SearchField(
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      StreamBuilder<QueueEntry?>(
                        stream: _myQueue,
                        builder: (context, queueSnapshot) {
                          final queue = queueSnapshot.data;
                          if (queue == null) return const SizedBox.shrink();
                          final shop =
                              shops
                                  ?.where((shop) => shop.id == queue.shopId)
                                  .firstOrNull;
                          return Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: FadeSlideIn(
                              child: _ActiveQueueStrip(
                                key: ValueKey(queue.ticketId),
                                queue: queue,
                                minutesPerQueue: shop?.minutesPerQueue,
                                queueService: _queueService,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'ทั้งหมด',
                              selected: _filter == _ShopFilter.all,
                              onTap:
                                  () =>
                                      setState(() => _filter = _ShopFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'เปิดรับคิว',
                              selected: _filter == _ShopFilter.open,
                              onTap:
                                  () => setState(
                                    () => _filter = _ShopFilter.open,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'รอไม่เกิน $_shortWaitQueues คิว',
                              selected: _filter == _ShopFilter.shortWait,
                              onTap:
                                  () => setState(
                                    () => _filter = _ShopFilter.shortWait,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      _BannerCarousel(
                        stream: _banners,
                        onOpenShop: _openBannerShop,
                      ),
                      const SizedBox(height: 18),
                      SectionTitle(
                        'ร้านทั้งหมด',
                        trailing:
                            shops == null
                                ? null
                                : Text(
                                  '${visible.length} ร้าน',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
                if (snapshot.hasError)
                  const _Message('โหลดข้อมูลร้านไม่สำเร็จ')
                else if (shops == null)
                  const SliverPadding(
                    padding: EdgeInsets.all(40),
                    sliver: SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (shops.isEmpty)
                  const _Message('ยังไม่มีร้านที่เปิดให้บริการ')
                else if (visible.isEmpty)
                  const _Message('ไม่พบร้านที่ตรงกับที่ค้นหา')
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    sliver: SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder:
                          (context, index) => FadeSlideIn(
                            key: ValueKey(visible[index].id),
                            delay: Duration(milliseconds: 60 * min(index, 6)),
                            child: _ShopRow(
                              shop: visible[index],
                              waitingCount: _waiting[visible[index].id],
                              onTap: () => _openShop(visible[index]),
                            ),
                          ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
    );
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'ค้นหาร้านชาบู',
        prefixIcon: const Icon(Icons.search_rounded),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.onSurface, width: 1.5),
        ),
      ),
    );
  }
}

/// "Your queue at X: 3 ahead, about 18 minutes", live, on top of the list.
class _ActiveQueueStrip extends StatefulWidget {
  const _ActiveQueueStrip({
    super.key,
    required this.queue,
    required this.minutesPerQueue,
    required this.queueService,
  });

  final QueueEntry queue;
  final double? minutesPerQueue;
  final QueueService queueService;

  @override
  State<_ActiveQueueStrip> createState() => _ActiveQueueStripState();
}

class _ActiveQueueStripState extends State<_ActiveQueueStrip> {
  late final Stream<List<QueueTicket>> _tickets = widget.queueService
      .watchWaitingTickets(
        shopId: widget.queue.shopId,
        zone: widget.queue.zone,
        queueDate: widget.queue.queueDate ?? '',
      );

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return StreamBuilder<List<QueueTicket>>(
      stream: _tickets,
      builder: (context, snapshot) {
        final ahead =
            snapshot.hasData
                ? queuesAhead(
                  waitingTickets: snapshot.data!,
                  ownTicketId: queue.ticketId,
                  ownCreatedAt: queue.createdAt ?? DateTime.now(),
                )
                : null;
        final called = queue.status == 'called';
        final status = switch (queue.status) {
          'called' => 'ถึงคิวแล้ว! เชิญที่หน้าร้าน',
          'serving' => 'กำลังใช้บริการ',
          _ when ahead == null => 'กำลังโหลดลำดับคิว…',
          _ when ahead == 0 => 'คุณเป็นคิวถัดไป',
          _ =>
            'อีก $ahead คิว • ประมาณ ${estimateWaitMinutes(ahead: ahead, minutesPerQueue: widget.minutesPerQueue)} นาที',
        };
        final background =
            called
                ? Palette.chili
                : (isLight ? Palette.ink : Palette.nightCard);
        return Material(
          color: background,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => DefaultTabController.maybeOf(context)?.animateTo(1),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const LiveDot(color: Palette.yolk),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'คิวของคุณที่ ${queue.shopName}',
                          style: const TextStyle(
                            color: Color(0xFFD9D3CB),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    queue.queueLabel,
                    style: AppFonts.numbers(fontSize: 26, color: Palette.yolk),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Motion.ease,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banners from Firestore, swiping by themselves every few seconds.
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.stream, required this.onOpenShop});

  final Stream<List<PromoBanner>> stream;
  final ValueChanged<String> onOpenShop;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController();
  int _index = 0;
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // เลื่อน banner อัตโนมัติทุก 4 วินาที
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _count < 2 || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % _count,
        duration: const Duration(milliseconds: 450),
        curve: Motion.ease,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<PromoBanner>>(
      stream: widget.stream,
      builder: (context, snapshot) {
        final banners = snapshot.data ?? const <PromoBanner>[];
        _count = banners.length;
        if (banners.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              SizedBox(
                height: 150,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: banners.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final banner = banners[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Semantics(
                        label: banner.title,
                        button: banner.shopId.isNotEmpty,
                        child: Material(
                          clipBehavior: Clip.antiAlias,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap:
                                banner.shopId.isEmpty
                                    ? null
                                    : () => widget.onOpenShop(banner.shopId),
                            child: ShopImage(
                              source: banner.imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (banners.length > 1) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < banners.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index % banners.length ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color:
                              i == _index % banners.length
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// One shop: photo, price and hours, open/closed and the live queue length.
class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.shop,
    required this.waitingCount,
    required this.onTap,
  });

  final Shop shop;

  /// Null until the first count arrives.
  final int? waitingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = [
      if (shop.pricePerPerson > 0) '฿${shop.pricePerPerson}/คน',
      if (shop.openingHours.trim().isNotEmpty) shop.openingHours.trim(),
    ].join(' • ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ShopImage(source: shop.image, width: 92, height: 92),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          shop.canBook
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 8),
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
                          label: 'ปิดรับคิว',
                          background: scheme.surfaceContainer,
                          foreground: scheme.onSurfaceVariant,
                        ),
                      if (shop.canBook && waitingCount != null)
                        waitingCount == 0
                            ? StatusPill(
                              label: 'ไม่ต้องรอ',
                              background: scheme.surfaceContainer,
                              foreground: scheme.onSurface,
                            )
                            : StatusPill(
                              label: 'รอ $waitingCount คิว',
                              background: scheme.secondaryContainer,
                              foreground: scheme.onSecondaryContainer,
                            ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(40),
      sliver: SliverToBoxAdapter(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
