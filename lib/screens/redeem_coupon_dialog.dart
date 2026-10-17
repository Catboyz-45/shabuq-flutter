import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/coupon_service.dart';

/// Shop staff type the code a customer shows, check the coupon and confirm
/// it. Returns true when a coupon was redeemed.
class RedeemCouponDialog extends StatefulWidget {
  const RedeemCouponDialog({
    super.key,
    required this.staffUid,
    required this.shopId,
    this.couponService,
  });

  final String staffUid;
  final String shopId;
  final CouponService? couponService;

  @override
  State<RedeemCouponDialog> createState() => _RedeemCouponDialogState();
}

class _RedeemCouponDialogState extends State<RedeemCouponDialog> {
  late final CouponService _service = widget.couponService ?? CouponService();
  final _controller = TextEditingController();
  CouponRedemption? _found;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final code = normaliseRedemptionCode(_controller.text);
    if (code.length != redemptionCodeLength) {
      setState(() => _error = 'รหัสมี $redemptionCodeLength ตัวอักษร');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
    });
    try {
      final redemption = await _service.findRedemption(code);
      if (!mounted) return;
      setState(() {
        if (redemption == null) {
          _error = 'ไม่พบรหัสนี้';
        } else if (redemption.isRedeemed) {
          _error = 'รหัสนี้ถูกใช้ไปแล้ว';
        } else if (redemption.isExpired(DateTime.now())) {
          _error = 'รหัสหมดอายุแล้ว ให้ลูกค้ากดสร้างรหัสใหม่';
        } else {
          _found = redemption;
        }
      });
    } on FirebaseException {
      if (mounted) setState(() => _error = 'ตรวจสอบรหัสไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeem() async {
    final found = _found;
    if (found == null) return;
    setState(() => _busy = true);
    try {
      await _service.redeem(
        code: found.code,
        staffUid: widget.staffUid,
        shopId: widget.shopId,
      );
      if (mounted) Navigator.pop(context, true);
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FirebaseException {
      if (mounted) setState(() => _error = 'ใช้คูปองไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return AlertDialog(
      title: const Text('ใช้คูปองของลูกค้า'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            enabled: !_busy,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: redemptionCodeLength + 2,
            decoration: InputDecoration(
              labelText: 'รหัสที่ลูกค้าแสดง',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_found != null || _error != null) {
                setState(() {
                  _found = null;
                  _error = null;
                });
              }
            },
            onSubmitted: (_) => _check(),
          ),
          if (found != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.local_offer),
                title: Text(found.couponName),
                subtitle: Text('ส่วนลด ฿${found.value}'),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('ปิด'),
        ),
        FilledButton(
          onPressed: _busy ? null : (found == null ? _check : _redeem),
          child: Text(found == null ? 'ตรวจสอบ' : 'ยืนยันใช้คูปอง'),
        ),
      ],
    );
  }
}
