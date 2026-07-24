// Import packages และหน้าจอที่เกี่ยวข้อง
import 'package:flutter/material.dart';

import '../services/shop_service.dart';
import '../widgets/shop_image.dart';
import 'booking_screen.dart';

// รายการรูปภาพโปรโมชั่นที่ใช้ใน banner
final bannerImages = [
  'assets/images/promotion/pho_promotion.jpeg',
  'assets/images/promotion/wiyaki_promotion.jpeg',
  'assets/images/promotion/teenoi_promotion.jpg',
];

// หน้าหลักของแอป
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ShopService _shopService = ShopService();
  final PageController _bannerController =
      PageController(); // ควบคุมการเลื่อน banner
  int _bannerIndex = 0; // ตำแหน่งปัจจุบันของ banner

  @override
  void initState() {
    super.initState();
    // เริ่มเลื่อน banner อัตโนมัติหลังจาก 3 วินาที
    Future.delayed(const Duration(seconds: 3), _autoScrollBanner);
  }

  // ฟังก์ชันเลื่อน banner แบบวนลูป
  void _autoScrollBanner() {
    if (!mounted) return;
    setState(() {
      _bannerIndex = (_bannerIndex + 1) % bannerImages.length;
      _bannerController.animateToPage(
        _bannerIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
    Future.delayed(const Duration(seconds: 3), _autoScrollBanner);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 149, 144, 248),
        foregroundColor: Colors.white,
        title: const Text('ShabuQ'),
      ),
      body: Column(
        children: [
          // แสดง banner โปรโมชั่นแบบเลื่อนอัตโนมัติ
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _bannerController,
              itemCount: bannerImages.length,
              itemBuilder:
                  (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        bannerImages[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 48,
                              ),
                            ),
                      ),
                    ),
                  ),
              onPageChanged: (i) => setState(() => _bannerIndex = i),
            ),
          ),
          const SizedBox(height: 8),
          // จุดบอกตำแหน่ง banner ปัจจุบัน
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              bannerImages.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _bannerIndex ? Colors.deepPurple : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ข้อความหัวข้อ "เลือกร้านชาบู"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'เลือกร้านชาบู',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 17),
          // แสดงร้านชาบูในรูปแบบ Grid
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _shopService.watchShops(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('โหลดข้อมูลร้านไม่สำเร็จ'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final shops = snapshot.data!;
                if (shops.isEmpty) {
                  return const Center(
                    child: Text('ยังไม่มีร้านที่เปิดให้บริการ'),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: shops.length,
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    return _MenuCard(
                      tile: _Tile(
                        shop['name'] as String? ?? '',
                        shop['image'] as String? ?? '',
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingScreen(shopInfo: shop),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// คลาสแทนข้อมูลแต่ละร้าน
class _Tile {
  final String title;
  final String imagePath;
  final VoidCallback onTap;
  _Tile(this.title, this.imagePath, this.onTap);
}

// การ์ดแสดงร้านชาบูพร้อมรูปภาพ
class _MenuCard extends StatelessWidget {
  final _Tile tile;
  const _MenuCard({required this.tile});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: tile.onTap, // เมื่อกดจะเรียกฟังก์ชัน onTap
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // แสดงรูปภาพร้าน
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ShopImage(
                  source: tile.imagePath,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ชื่อร้าน
            Text(tile.title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
