import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/account_service.dart';

/// ขอรหัสผ่านอีกครั้งก่อนลบบัญชี เพื่อให้ลบข้อมูลใน Firestore และบัญชีเข้าสู่ระบบได้ครบ
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'กรุณากรอกรหัสผ่าน');
      return;
    }
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await AccountService().deleteAccount(password: _passwordController.text);
      // AuthGate จะแสดงหน้าเข้าสู่ระบบเอง เหลือแค่ปิดหน้าต่างนี้
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = switch (error.code) {
          'wrong-password' || 'invalid-credential' => 'รหัสผ่านไม่ถูกต้อง',
          'too-many-requests' => 'ลองผิดหลายครั้งเกินไป กรุณารอสักครู่',
          _ => 'ไม่สามารถลบบัญชีได้ กรุณาลองใหม่',
        };
      });
    } on FirebaseException {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'ลบข้อมูลไม่สำเร็จ กรุณาลองใหม่';
      });
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ลบบัญชีผู้ใช้'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ระบบจะยกเลิกคิวที่กำลังรอ ลบคูปองและข้อมูลโปรไฟล์ '
            'แล้วลบบัญชีเข้าสู่ระบบ การดำเนินการนี้ย้อนกลับไม่ได้\n\n'
            'กรอกรหัสผ่านเพื่อยืนยัน',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_deleting,
            decoration: InputDecoration(
              labelText: 'รหัสผ่าน',
              errorText: _error,
            ),
            onSubmitted: (_) => _delete(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: _deleting ? null : _delete,
          child:
              _deleting
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(
                    'ยืนยันลบ',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
        ),
      ],
    );
  }
}
