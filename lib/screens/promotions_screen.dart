// Import packages ที่จำเป็น
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// หน้าจอสำหรับจัดการโปรโมชั่นและคูปองของผู้ใช้
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  final TextEditingController _codeController =
      TextEditingController(); // สำหรับกรอกโค้ด
  List<Map<String, dynamic>> _userCoupons = []; // คูปองที่ผู้ใช้มี
  String? _error; // ข้อผิดพลาดที่จะแสดง
  bool _loading = true; // สถานะโหลดข้อมูล

  // ดึง UID ของผู้ใช้ที่ล็อกอิน
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadCoupons(); // โหลดคูปองที่มี
  }

  @override
  void dispose() {
    _codeController.dispose(); // เคลียร์ controller เมื่อ widget ถูก dispose
    super.dispose();
  }

  // โหลดคูปองของผู้ใช้จาก Firestore
  Future<void> _loadCoupons() async {
    if (_uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'กรุณาเข้าสู่ระบบอีกครั้ง';
        });
      }
      return;
    }
    final snap =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('coupons')
            .get();
    if (!mounted) return;
    setState(() {
      _userCoupons =
          snap.docs.map((doc) {
            final d = doc.data();
            return {
              'id': doc.id,
              'code': d['code'],
              'name': d['name'],
              'value': d['value'],
            };
          }).toList();
      _loading = false;
    });
  }

  // เพิ่มคูปองจากโค้ดที่กรอก
  Future<void> _addCoupon() async {
    final code = _codeController.text.trim().toLowerCase();
    final uid = _uid;
    if (uid == null) {
      setState(() => _error = 'กรุณาเข้าสู่ระบบอีกครั้ง');
    } else {
      try {
        final db = FirebaseFirestore.instance;
        final usedRef = db
            .collection('users')
            .doc(uid)
            .collection('used_codes')
            .doc(code);
        final couponRef = db
            .collection('users')
            .doc(uid)
            .collection('coupons')
            .doc(code);
        final promoRef = db.collection('promoCodes').doc(code);
        late Map<String, dynamic> promo;
        await db.runTransaction((transaction) async {
          final promoSnapshot = await transaction.get(promoRef);
          final promoData = promoSnapshot.data();
          if (!promoSnapshot.exists ||
              promoData == null ||
              promoData['active'] != true) {
            throw StateError('โค้ดไม่ถูกต้องหรือปิดใช้งานแล้ว');
          }
          final name = promoData['name'];
          final value = promoData['value'];
          if (name is! String || value is! int || value < 1) {
            throw StateError('ข้อมูลโค้ดไม่ถูกต้อง');
          }
          promo = {'name': name, 'value': value};
          final used = await transaction.get(usedRef);
          if (used.exists) {
            throw StateError('คุณกรอกโค้ดนี้ไปแล้ว');
          }
          transaction.set(couponRef, {'code': code, ...promo});
          transaction.set(usedRef, {
            'used': 1,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        if (!mounted) return;
        setState(() {
          _userCoupons.add({'id': code, 'code': code, ...promo});
          _error = null;
        });
      } on StateError catch (error) {
        if (!mounted) return;
        setState(() => _error = error.message);
      } on FirebaseException {
        if (!mounted) return;
        setState(() => _error = 'เพิ่มคูปองไม่สำเร็จ กรุณาลองใหม่');
      }
    }
    _codeController.clear();
  }

  // ใช้คูปองและลบออกจากรายการ
  Future<void> _useCoupon(String id) async {
    if (_uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('coupons')
            .doc(id)
            .delete();
        if (!mounted) return;
        setState(() {
          _userCoupons.removeWhere((coupon) => coupon['id'] == id);
        });
      } on FirebaseException {
        if (!mounted) return;
        setState(() => _error = 'ใช้คูปองไม่สำเร็จ กรุณาลองใหม่');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 149, 144, 248),
        foregroundColor: Colors.white,
        title: const Text('โปรโมชั่น'),
      ),
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(),
              ) // แสดงโหลดข้อมูล
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Divider(height: 32),
                  const Text(
                    'กรอกโค้ดโปรโมชั่นเพื่อรับส่วนลด',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            hintText: 'กรอกโค้ดที่นี่',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addCoupon,
                        child: const Text('เพิ่ม'),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'ส่วนลดของคุณ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_userCoupons.length} คูปอง',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_userCoupons.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'ยังไม่มีส่วนลด',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  // แสดงรายการคูปอง
                  ..._userCoupons.map(
                    (c) => Card(
                      child: ListTile(
                        title: Text(c['name']),
                        subtitle: Text('โค้ด: ${c['code']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '-฿${c['value']}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.deepPurple,
                              ),
                              tooltip: 'ใช้คูปองนี้',
                              onPressed: () => _useCoupon(c['id']),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
