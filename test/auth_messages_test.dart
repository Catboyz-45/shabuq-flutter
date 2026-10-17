import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/utils/auth_messages.dart';

void main() {
  test('does not reveal whether the email or the password was wrong', () {
    expect(
      authErrorMessage('user-not-found'),
      authErrorMessage('wrong-password'),
    );
    expect(
      authErrorMessage('invalid-credential'),
      'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
    );
  });

  test('translates common sign-up errors', () {
    expect(
      authErrorMessage('email-already-in-use'),
      contains('สมัครสมาชิกแล้ว'),
    );
    expect(authErrorMessage('weak-password'), contains('6 ตัวอักษร'));
  });

  test('falls back to a generic Thai message', () {
    expect(authErrorMessage('something-new'), 'เกิดข้อผิดพลาด กรุณาลองใหม่');
  });
}
