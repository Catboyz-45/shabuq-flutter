import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/banner_service.dart';
import '../services/shop_service.dart';
import '../utils/image_source.dart';
import '../widgets/image_url_field.dart';
import '../widgets/shop_image.dart';

/// Super Admin page for the home screen banners: add, edit, reorder, hide
/// and delete without releasing a new version of the app.
class BannerAdminScreen extends StatefulWidget {
  const BannerAdminScreen({super.key});

  @override
  State<BannerAdminScreen> createState() => _BannerAdminScreenState();
}

class _BannerAdminScreenState extends State<BannerAdminScreen> {
  final _bannerService = BannerService();
  late final Stream<List<PromoBanner>> _banners = _bannerService.watchBanners(
    activeOnly: false,
  );
  late final Stream<List<Map<String, dynamic>>> _shops = ShopService()
      .watchShops(includeInactive: true);

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _edit(
    List<Map<String, dynamic>> shops, {
    PromoBanner? banner,
    required int nextOrder,
  }) async {
    final result = await showDialog<_BannerDraft>(
      context: context,
      builder: (_) => _BannerDialog(banner: banner, shops: shops),
    );
    if (result == null) return;
    try {
      await _bannerService.saveBanner(
        id: banner?.id,
        imageUrl: result.imageUrl,
        title: result.title,
        shopId: result.shopId,
        order: banner?.order ?? nextOrder,
        active: result.active,
      );
      _showMessage(banner == null ? 'เพิ่มแบนเนอร์แล้ว' : 'บันทึกแบนเนอร์แล้ว');
    } on FirebaseException {
      _showMessage('บันทึกแบนเนอร์ไม่สำเร็จ กรุณาลองใหม่', error: true);
    }
  }

  Future<void> _move(List<PromoBanner> banners, int index, int offset) async {
    final other = index + offset;
    if (other < 0 || other >= banners.length) return;
    final a = banners[index], b = banners[other];
    try {
      // สลับลำดับ ถ้าลำดับซ้ำกันให้ใช้ตำแหน่งในรายการแทน
      final orderA = a.order == b.order ? other : b.order;
      final orderB = a.order == b.order ? index : a.order;
      for (final (banner, order) in [(a, orderA), (b, orderB)]) {
        await _bannerService.saveBanner(
          id: banner.id,
          imageUrl: banner.imageUrl,
          title: banner.title,
          shopId: banner.shopId,
          order: order,
          active: banner.active,
        );
      }
    } on FirebaseException {
      _showMessage('เปลี่ยนลำดับไม่สำเร็จ', error: true);
    }
  }

  Future<void> _delete(PromoBanner banner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('ลบแบนเนอร์'),
            content: Text(
              'ต้องการลบ "${banner.title.isEmpty ? 'แบนเนอร์นี้' : banner.title}" หรือไม่?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('ลบ'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await _bannerService.deleteBanner(banner.id);
      _showMessage('ลบแบนเนอร์แล้ว');
    } on FirebaseException {
      _showMessage('ลบแบนเนอร์ไม่สำเร็จ', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _shops,
      builder: (context, shopSnapshot) {
        final shops = shopSnapshot.data ?? const [];
        final shopNames = {
          for (final shop in shops) shop['id'] as String: shop['name'],
        };
        return StreamBuilder<List<PromoBanner>>(
          stream: _banners,
          builder: (context, snapshot) {
            final banners = snapshot.data ?? const <PromoBanner>[];
            final nextOrder =
                banners.isEmpty
                    ? 0
                    : banners
                            .map((banner) => banner.order)
                            .reduce((a, b) => a > b ? a : b) +
                        1;
            return Scaffold(
              appBar: AppBar(title: const Text('แบนเนอร์หน้าแรก')),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _edit(shops, nextOrder: nextOrder),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('เพิ่มแบนเนอร์'),
              ),
              body:
                  snapshot.hasError
                      ? const Center(child: Text('โหลดแบนเนอร์ไม่สำเร็จ'))
                      : !snapshot.hasData
                      ? const Center(child: CircularProgressIndicator())
                      : banners.isEmpty
                      ? const Center(
                        child: Text('ยังไม่มีแบนเนอร์ หน้าแรกจะไม่แสดงแบนเนอร์'),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: banners.length,
                        itemBuilder: (context, index) {
                          final banner = banners[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Opacity(
                                  opacity: banner.active ? 1 : 0.4,
                                  child: ShopImage(
                                    source: banner.imageUrl,
                                    height: 120,
                                  ),
                                ),
                                ListTile(
                                  title: Text(
                                    banner.title.isEmpty
                                        ? '(ไม่มีชื่อ)'
                                        : banner.title,
                                  ),
                                  subtitle: Text(
                                    [
                                      banner.active ? 'แสดงอยู่' : 'ซ่อนอยู่',
                                      if (banner.shopId.isNotEmpty)
                                        'กดแล้วไปร้าน ${shopNames[banner.shopId] ?? banner.shopId}',
                                    ].join(' • '),
                                  ),
                                ),
                                OverflowBar(
                                  alignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: 'เลื่อนขึ้น',
                                      onPressed:
                                          index == 0
                                              ? null
                                              : () => _move(banners, index, -1),
                                      icon: const Icon(Icons.arrow_upward),
                                    ),
                                    IconButton(
                                      tooltip: 'เลื่อนลง',
                                      onPressed:
                                          index == banners.length - 1
                                              ? null
                                              : () => _move(banners, index, 1),
                                      icon: const Icon(Icons.arrow_downward),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => _edit(
                                            shops,
                                            banner: banner,
                                            nextOrder: nextOrder,
                                          ),
                                      child: const Text('แก้ไข'),
                                    ),
                                    TextButton(
                                      onPressed: () => _delete(banner),
                                      child: const Text(
                                        'ลบ',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            );
          },
        );
      },
    );
  }
}

class _BannerDraft {
  const _BannerDraft(this.imageUrl, this.title, this.shopId, this.active);

  final String imageUrl;
  final String title;
  final String shopId;
  final bool active;
}

class _BannerDialog extends StatefulWidget {
  const _BannerDialog({required this.banner, required this.shops});

  final PromoBanner? banner;
  final List<Map<String, dynamic>> shops;

  @override
  State<_BannerDialog> createState() => _BannerDialogState();
}

class _BannerDialogState extends State<_BannerDialog> {
  late final _imageController = TextEditingController(
    text: widget.banner?.imageUrl ?? '',
  );
  late final _titleController = TextEditingController(
    text: widget.banner?.title ?? '',
  );
  late String _shopId = widget.banner?.shopId ?? '';
  late bool _active = widget.banner?.active ?? true;
  String? _error;

  @override
  void dispose() {
    _imageController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _save() {
    final image = _imageController.text.trim();
    if (image.isEmpty || !isAllowedImageSource(image)) {
      setState(() => _error = 'กรุณาวางลิงก์รูปที่ขึ้นต้นด้วย https://');
      return;
    }
    Navigator.pop(
      context,
      _BannerDraft(image, _titleController.text.trim(), _shopId, _active),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopIds = widget.shops.map((shop) => shop['id'] as String).toSet();
    return AlertDialog(
      title: Text(widget.banner == null ? 'เพิ่มแบนเนอร์' : 'แก้ไขแบนเนอร์'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ImageUrlField(
                controller: _imageController,
                label: 'ลิงก์รูปแบนเนอร์',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'ชื่อแบนเนอร์ (สำหรับผู้อ่านหน้าจอ)',
                  border: OutlineInputBorder(),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: shopIds.contains(_shopId) ? _shopId : '',
                decoration: const InputDecoration(
                  labelText: 'กดแบนเนอร์แล้วไปที่ร้าน',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('ไม่ลิงก์ไปร้าน')),
                  for (final shop in widget.shops)
                    DropdownMenuItem(
                      value: shop['id'] as String,
                      child: Text(shop['name'] as String? ?? ''),
                    ),
                ],
                onChanged: (value) => setState(() => _shopId = value ?? ''),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('แสดงบนหน้าแรก'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(onPressed: _save, child: const Text('บันทึก')),
      ],
    );
  }
}
