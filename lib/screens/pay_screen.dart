import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/payment_calculator.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.partySize,
    required this.pricePerPerson,
    this.zone,
  });

  final String shopId;
  final String shopName;
  final int partySize;
  final int pricePerPerson;
  final String? zone;

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  Map<String, dynamic>? _selectedCoupon;
  String _payMethod = 'counter';
  bool _loading = false;
  bool _loadingCoupons = true;
  String? _error;
  List<Map<String, dynamic>> _userCoupons = [];
  late int _pricePerPerson = widget.pricePerPerson;

  PaymentSummary get _summary => calculatePayment(
    partySize: widget.partySize,
    pricePerPerson: _pricePerPerson,
    couponValue: (_selectedCoupon?['value'] as int?) ?? 0,
  );
  int get total => _summary.total;
  int get discount => _summary.discount;
  int get netTotal => _summary.netTotal;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loadingCoupons = false;
          _error = 'กรุณาเข้าสู่ระบบอีกครั้ง';
        });
      }
      return;
    }

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('coupons')
            .get(),
        FirebaseFirestore.instance.collection('shops').doc(widget.shopId).get(),
      ]);
      final snap = results.first as QuerySnapshot<Map<String, dynamic>>;
      final shop = results.last as DocumentSnapshot<Map<String, dynamic>>;
      final currentPrice = shop.data()?['pricePerPerson'];
      if (!shop.exists || currentPrice is! int || currentPrice < 1) {
        throw StateError('ไม่พบข้อมูลราคาของร้าน');
      }
      if (!mounted) return;
      setState(() {
        _pricePerPerson = currentPrice;
        _userCoupons =
            snap.docs
                .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
                .where(
                  (coupon) =>
                      coupon['name'] is String && coupon['value'] is int,
                )
                .toList();
        _loadingCoupons = false;
      });
    } on FirebaseException {
      if (!mounted) return;
      setState(() {
        _loadingCoupons = false;
        _error = 'โหลดคูปองไม่สำเร็จ กรุณาลองใหม่';
      });
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCoupons = false;
        _error = error.message;
      });
    }
  }

  Future<void> _submitPayment() async {
    if (_loading) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final queueRef = db.collection('queues').doc(user.uid);
      final paymentRef = db.collection('payments').doc();
      final couponId = _selectedCoupon?['id'] as String?;
      final couponRef =
          couponId == null
              ? null
              : db
                  .collection('users')
                  .doc(user.uid)
                  .collection('coupons')
                  .doc(couponId);

      await db.runTransaction((transaction) async {
        final queue = await transaction.get(queueRef);
        if (queue.exists) {
          throw StateError('คุณมีคิวที่กำลังใช้งานอยู่แล้ว');
        }
        final shop = await transaction.get(
          db.collection('shops').doc(widget.shopId),
        );
        final currentPrice = shop.data()?['pricePerPerson'];
        if (!shop.exists || currentPrice is! int || currentPrice < 1) {
          throw StateError('ไม่พบข้อมูลราคาของร้าน');
        }
        final currentSummary = calculatePayment(
          partySize: widget.partySize,
          pricePerPerson: currentPrice,
          couponValue: (_selectedCoupon?['value'] as int?) ?? 0,
        );

        var verifiedDiscount = 0;
        String couponName = '';
        if (couponRef != null) {
          final coupon = await transaction.get(couponRef);
          if (!coupon.exists) {
            throw StateError('คูปองนี้ถูกใช้ไปแล้ว');
          }
          final data = coupon.data();
          final value = data?['value'];
          final name = data?['name'];
          if (value is! int || value < 0 || name is! String) {
            throw StateError('ข้อมูลคูปองไม่ถูกต้อง');
          }
          verifiedDiscount =
              calculatePayment(
                partySize: widget.partySize,
                pricePerPerson: currentPrice,
                couponValue: value,
              ).discount;
          couponName = name;
          transaction.delete(couponRef);
        }

        final createdAt = FieldValue.serverTimestamp();
        transaction.set(paymentRef, {
          'paymentId': paymentRef.id,
          'userId': user.uid,
          'shopId': widget.shopId,
          'shopName': widget.shopName,
          'partySize': widget.partySize,
          'pricePerPerson': currentPrice,
          'total': currentSummary.total,
          'coupon': couponName,
          'couponCode': couponId ?? '',
          'discount': verifiedDiscount,
          'netTotal': currentSummary.total - verifiedDiscount,
          'payMethod': _payMethod,
          'createdAt': createdAt,
        });
        transaction.set(queueRef, {
          'userId': user.uid,
          'shopId': widget.shopId,
          'shopName': widget.shopName,
          'zone': widget.zone ?? 'ทั่วไป',
          'partySize': widget.partySize,
          'payMethod': _payMethod,
          'paymentId': paymentRef.id,
          'status': 'waiting',
          'createdAt': createdAt,
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('จองคิวเรียบร้อย')));
      Navigator.pop(context, true);
    } on FirebaseException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'บันทึกข้อมูลไม่สำเร็จ กรุณาลองใหม่';
      });
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 149, 144, 248),
        foregroundColor: Colors.white,
        title: const Text('ยืนยันการจอง'),
      ),
      body:
          _loadingCoupons
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(
                        widget.shopName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('จำนวนคน: ${widget.partySize}'),
                      trailing: Text('฿$_pricePerPerson/คน'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedCoupon,
                    decoration: const InputDecoration(
                      labelText: 'คูปองส่วนลด (ไม่บังคับ)',
                    ),
                    items:
                        _userCoupons
                            .map(
                              (coupon) => DropdownMenuItem(
                                value: coupon,
                                child: Text(
                                  '${coupon['name']} (฿${coupon['value']})',
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _loading
                            ? null
                            : (coupon) =>
                                setState(() => _selectedCoupon = coupon),
                  ),
                  const SizedBox(height: 16),
                  _AmountRow(label: 'ยอดรวม', amount: total),
                  _AmountRow(label: 'ส่วนลด', amount: -discount),
                  const Divider(height: 32),
                  _AmountRow(
                    label: 'ยอดสุทธิ',
                    amount: netTotal,
                    emphasized: true,
                  ),
                  const SizedBox(height: 24),
                  const Text('เลือกวิธีชำระเงิน'),
                  RadioGroup<String>(
                    groupValue: _payMethod,
                    onChanged: (value) {
                      if (!_loading && value != null) {
                        setState(() => _payMethod = value);
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          title: Text('ชำระที่เคาน์เตอร์'),
                          value: 'counter',
                        ),
                        RadioListTile<String>(
                          title: Text('สแกน QR Code'),
                          value: 'qr',
                        ),
                      ],
                    ),
                  ),
                  if (_payMethod == 'qr') ...[
                    Image.asset(
                      'assets/images/QR.JPG',
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 12),
                    const Card(
                      color: Color(0xFFF3F0FF),
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('โหมดสาธิต'),
                        subtitle: Text(
                          'ระบบจะบันทึกวิธีชำระเงินเท่านั้น '
                          'ไม่มีการรับเงินจริงหรืออัปโหลดสลิป',
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _submitPayment,
                    icon:
                        _loading
                            ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.check_circle),
                    label: const Text('ยืนยันการจอง'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final int amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: emphasized ? 20 : 16,
      fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
      color: emphasized ? Colors.deepPurple : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${amount < 0 ? '-' : ''}฿${amount.abs()}', style: style),
        ],
      ),
    );
  }
}
