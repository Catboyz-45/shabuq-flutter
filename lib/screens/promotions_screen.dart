// Import packages ที่จำเป็น
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/coupon_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import '../widgets/motion.dart';

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
    final redeemed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder:
          (_) => _RedemptionSheet(
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    Text(
                      'คูปองของฉัน',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'มีโค้ดโปรโมชัน?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            onSubmitted: (_) => _addCoupon(),
                            style: AppFonts.numbers(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'กรอกโค้ดที่นี่',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _addCoupon,
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.onSurface,
                            foregroundColor: scheme.surface,
                          ),
                          child: const Text('เพิ่ม'),
                        ),
                      ],
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SectionTitle(
                      'ส่วนลดของคุณ',
                      trailing: Text(
                        '${_userCoupons.length} คูปอง',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_userCoupons.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'ยังไม่มีส่วนลด กรอกโค้ดด้านบนเพื่อรับคูปอง',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    for (final (index, coupon) in _userCoupons.indexed)
                      FadeSlideIn(
                        key: ValueKey(coupon['id']),
                        delay: Duration(milliseconds: 70 * min(index, 5)),
                        child: _CouponStub(
                          name: coupon['name'] as String? ?? '',
                          code: coupon['code'] as String? ?? '',
                          value: coupon['value'] as int? ?? 0,
                          onUse: () => _useCoupon(coupon['id'] as String),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}

/// A coupon drawn as a paper stub: the amount on the left, tear line, then
/// the details.
class _CouponStub extends StatelessWidget {
  const _CouponStub({
    required this.name,
    required this.code,
    required this.value,
    required this.onUse,
  });

  final String name;
  final String code;
  final int value;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 104,
              decoration: BoxDecoration(
                color: isLight ? Palette.chili : Palette.chiliDark,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ลด', style: TextStyle(color: Colors.white)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '฿$value',
                      style: AppFonts.numbers(
                        fontSize: 32,
                        color: Palette.yolk,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(2, double.infinity),
              painter: _DashedLine(color: scheme.surface),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'โค้ด ${code.toUpperCase()} • ใช้ได้ 1 ครั้ง',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: onUse,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        backgroundColor: scheme.secondaryContainer,
                        foregroundColor: scheme.onSecondaryContainer,
                        shape: const StadiumBorder(),
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      child: const Text('ใช้ที่หน้าร้าน'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedLine extends CustomPainter {
  const _DashedLine({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = size.width;
    for (var y = 0.0; y < size.height; y += 10) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, min(y + 6, size.height)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLine oldDelegate) => oldDelegate.color != color;
}

/// Shows a short code for the cashier and waits until shop staff redeem it.
class _RedemptionSheet extends StatefulWidget {
  const _RedemptionSheet({
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
  State<_RedemptionSheet> createState() => _RedemptionSheetState();
}

class _RedemptionSheetState extends State<_RedemptionSheet> {
  final _couponService = CouponService();
  String? _code;
  Stream<CouponRedemption?>? _redemption;
  String? _error;
  final DateTime _requestedAt = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
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
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final code = _code;
    return StreamBuilder<CouponRedemption?>(
      stream: _redemption,
      builder: (context, snapshot) {
        final done = snapshot.data?.isRedeemed == true;
        final issuedAt = snapshot.data?.createdAt ?? _requestedAt;
        final left = redemptionValidity - DateTime.now().difference(issuedAt);
        final remaining = left.isNegative ? Duration.zero : left;
        final expired = !done && remaining == Duration.zero;

        final Widget body;
        if (_error != null) {
          body = Text(_error!, textAlign: TextAlign.center);
        } else if (code == null) {
          body = const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (done) {
          body = Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                builder:
                    (context, t, child) =>
                        Transform.scale(scale: t, child: child),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: StatusColors.of(context).success,
                  size: 88,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'พนักงานยืนยันการใช้คูปองแล้ว',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          );
        } else {
          body = Column(
            children: [
              Row(
                children: [
                  for (final (index, char) in code.split('').indexed) ...[
                    if (index > 0) const SizedBox(width: 6),
                    Expanded(
                      child: FadeSlideIn(
                        offset: -18,
                        delay: Duration(milliseconds: 200 + 60 * index),
                        duration: const Duration(milliseconds: 420),
                        child: Container(
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Palette.ink,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            char,
                            style: AppFonts.numbers(
                              fontSize: 32,
                              color: Palette.yolk,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expired
                          ? 'รหัสหมดอายุแล้ว ปิดแล้วกดใช้ใหม่'
                          : 'รหัสหมดอายุใน',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: AppFonts.numbers(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value:
                      remaining.inMilliseconds /
                      redemptionValidity.inMilliseconds,
                  minHeight: 6,
                  color: scheme.primary,
                  backgroundColor: scheme.surfaceContainerHigh,
                ),
              ),
            ],
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  done ? 'ใช้คูปองเรียบร้อย' : 'ยื่นรหัสนี้ให้พนักงาน',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.couponName} • ลด ฿${widget.value} '
                  '• พนักงานกรอกรหัสตอนชำระเงิน',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  child: body,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, done),
                    child: Text(done ? 'เสร็จ' : 'ปิด'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
