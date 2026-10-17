/// Thai messages for FirebaseAuthException codes shown on the sign-in screen.
String authErrorMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'รูปแบบอีเมลไม่ถูกต้อง';
    case 'user-disabled':
      return 'บัญชีนี้ถูกระงับการใช้งาน';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'INVALID_LOGIN_CREDENTIALS':
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    case 'email-already-in-use':
      return 'อีเมลนี้สมัครสมาชิกแล้ว ลองเข้าสู่ระบบแทน';
    case 'weak-password':
      return 'รหัสผ่านสั้นเกินไป ต้องมีอย่างน้อย 6 ตัวอักษร';
    case 'too-many-requests':
      return 'ลองหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่';
    case 'network-request-failed':
      return 'เชื่อมต่ออินเทอร์เน็ตไม่ได้ กรุณาตรวจสอบสัญญาณ';
    case 'operation-not-allowed':
      return 'ระบบยังไม่เปิดให้เข้าสู่ระบบด้วยอีเมล';
    default:
      return 'เกิดข้อผิดพลาด กรุณาลองใหม่';
  }
}
