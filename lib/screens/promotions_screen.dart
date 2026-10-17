// Import packages ที่จำเป็น
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/coupon_service.dart';
import '../theme/app_theme.dart';

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

  // ใช้คูปองที่หน้าร้าน: แสดงรหัสให้พนักงานกรอก พนักงานเป็นคนยืนยันการใช้
  Future<void> _useCoupon(String id) async {
    final uid = _uid;
    if (uid == null) return;
    final coupon = _userCoupons.firstWhere((c) => c['id'] == id);
    final redeemed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _RedemptionDialog(
            uid: uid,
            couponCode: id,
            couponName: coupon['name'] as String? ?? '',
            value: coupon['value'] as int? ?? 0,
          ),
    );
    if (redeemed == true && mounted) {
      setState(() => _userCoupons.removeWhere((c) => c['id'] == id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('โปรโมชั่น')),
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_userCoupons.length} คูปอง',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_userCoupons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'ยังไม่มีส่วนลด',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                              style: TextStyle(
                                color: StatusColors.of(context).success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              tooltip: 'ใช้คูปองที่หน้าร้าน',
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

/// Shows a short code for the cashier and waits until shop staff redeem it.
class _RedemptionDialog extends StatefulWidget {
  const _RedemptionDialog({
    required this.uid,
    required this.couponCode,
    required this.couponName,
    required this.value,
  });

  final String uid;
  final String couponCode;
  final String couponName;
  final int value;

  @override
  State<_RedemptionDialog> createState() => _RedemptionDialogState();
}

class _RedemptionDialogState extends State<_RedemptionDialog> {
  final _couponService = CouponService();
  String? _code;
  Stream<CouponRedemption?>? _redemption;
  String? _error;

  @override
  void initState() {
    super.initState();
    _couponService
        .requestRedemption(uid: widget.uid, couponCode: widget.couponCode)
        .then((code) {
          if (!mounted) return;
          setState(() {
            _code = code;
            _redemption = _couponService.watchRedemption(code);
          });
        })
        .catchError((Object error) {
          if (!mounted) return;
          setState(
            () =>
                _error =
                    error is StateError ? error.message : 'สร้างรหัสไม่สำเร็จ',
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    return StreamBuilder<CouponRedemption?>(
      stream: _redemption,
      builder: (context, snapshot) {
        final done = snapshot.data?.isRedeemed == true;
        final Widget content;
        if (_error != null) {
          content = Text(_error!);
        } else if (code == null) {
          content = const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (done) {
          content = const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 64),
              SizedBox(height: 8),
              Text('พนักงานยืนยันการใช้คูปองแล้ว'),
            ],
          );
        } else {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('แสดงรหัสนี้ให้พนักงานตอนชำระเงิน (ลด ฿${widget.value})'),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'รหัสใช้ได้ ${redemptionValidity.inMinutes} นาที',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        }
        return AlertDialog(
          title: Text('ใช้คูปอง ${widget.couponName}'),
          content: content,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, done),
              child: Text(done ? 'เสร็จ' : 'ปิด'),
            ),
          ],
        );
      },
    );
  }
}
