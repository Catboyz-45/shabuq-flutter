import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'pay_screen.dart';
import '../services/queue_service.dart';
import '../widgets/shop_image.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.shopInfo});

  final Map<String, dynamic> shopInfo;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late String _selectedZone;
  int _party = 2;
  int _queueCount = 0;
  bool _loading = true;
  bool _hasActiveQueue = false;
  String? _error;

  List<String> get _zones =>
      (widget.shopInfo['zones'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .where((zone) => zone.trim().isNotEmpty)
          .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _selectedZone = _zones.isEmpty ? 'ทั่วไป' : _zones.first;
    _loadBookingState();
  }

  Future<void> _loadBookingState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'กรุณาเข้าสู่ระบบก่อนจองคิว';
        });
      }
      return;
    }

    try {
      final queueService = QueueService();
      final results = await Future.wait([
        queueService.countWaiting(widget.shopInfo['id'] as String),
        queueService.queueOf(user.uid).get(),
      ]);
      if (!mounted) return;
      setState(() {
        _queueCount = results.first as int;
        _hasActiveQueue = (results.last as DocumentSnapshot).exists;
        _loading = false;
        _error = null;
      });
    } on FirebaseException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'ไม่สามารถโหลดข้อมูลคิวได้ กรุณาลองใหม่';
      });
    }
  }

  Future<void> _bookQueue() async {
    if (_hasActiveQueue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณมีคิวที่กำลังใช้งานอยู่แล้ว')),
      );
      return;
    }

    final booked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => PayScreen(
              shopId: widget.shopInfo['id'] as String,
              shopName: widget.shopInfo['name'] as String,
              partySize: _party,
              pricePerPerson: widget.shopInfo['pricePerPerson'] as int? ?? 299,
              zone: _selectedZone,
            ),
      ),
    );
    if (booked == true) await _loadBookingState();
  }

  @override
  Widget build(BuildContext context) {
    final shopInfo = widget.shopInfo;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 149, 144, 248),
        foregroundColor: Colors.white,
        title: const Text('จองคิว'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBookingState,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ShopImage(
                        source: shopInfo['image'] as String? ?? '',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopInfo['name'] as String? ?? 'ไม่ระบุชื่อร้าน',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(shopInfo['location'] as String? ?? ''),
                          Text('โทร: ${shopInfo['phone'] as String? ?? '-'}'),
                          Text(
                            'ราคา: ฿${shopInfo['pricePerPerson'] as int? ?? 299}/คน',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'คิวที่ต้องรอ: $_queueCount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_hasActiveQueue) ...[
              const SizedBox(height: 12),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('คุณมีคิวที่กำลังใช้งานอยู่'),
                  subtitle: Text('ยกเลิกหรือใช้คิวเดิมก่อนจองคิวใหม่'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _selectedZone,
              decoration: const InputDecoration(labelText: 'เลือกโซนร้าน'),
              items:
                  (_zones.isEmpty ? <String>['ทั่วไป'] : _zones)
                      .map(
                        (zone) =>
                            DropdownMenuItem(value: zone, child: Text(zone)),
                      )
                      .toList(),
              onChanged:
                  _loading
                      ? null
                      : (value) {
                        if (value != null) {
                          setState(() => _selectedZone = value);
                        }
                      },
            ),
            const SizedBox(height: 24),
            const Text(
              'ระบุจำนวนที่นั่ง',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'ลดจำนวนที่นั่ง',
                  icon: const Icon(
                    Icons.remove_circle,
                    size: 40,
                    color: Colors.red,
                  ),
                  onPressed: _party > 1 ? () => setState(() => _party--) : null,
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    '$_party',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'เพิ่มจำนวนที่นั่ง',
                  icon: const Icon(
                    Icons.add_circle,
                    size: 40,
                    color: Colors.green,
                  ),
                  onPressed:
                      _party < 10 ? () => setState(() => _party++) : null,
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed:
                  _loading || _hasActiveQueue || _error != null
                      ? null
                      : _bookQueue,
              icon:
                  _loading
                      ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.event_available),
              label: const Text('จองคิว', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
