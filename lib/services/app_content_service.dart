import 'package:cloud_firestore/cloud_firestore.dart';

/// Text pages shown from the profile screen. Super Admins edit them in the
/// app; [defaultBody] is shown until a page has been saved to Firestore.
enum AppContentPage {
  help('help', 'การช่วยเหลือ'),
  terms('terms', 'ข้อกำหนดและเงื่อนไขการใช้งาน'),
  privacy('privacy', 'นโยบายความเป็นส่วนตัว');

  const AppContentPage(this.id, this.title);

  final String id;
  final String title;

  String get defaultBody => switch (this) {
    help => 'ติดต่อทีมงานได้ที่ support@shabuq.com',
    terms =>
      '1. ผู้ใช้ต้องปฏิบัติตามกฎระเบียบของแอปพลิเคชัน\n'
          '2. ห้ามใช้แอปเพื่อวัตถุประสงค์ที่ผิดกฎหมายหรือสร้างความเสียหาย\n'
          '3. ข้อมูลส่วนตัวของผู้ใช้จะถูกเก็บรักษาอย่างปลอดภัย\n'
          '4. แอปขอสงวนสิทธิ์ในการเปลี่ยนแปลงข้อกำหนดโดยไม่ต้องแจ้งให้ทราบล่วงหน้า\n'
          '5. การใช้งานแอปถือว่าผู้ใช้ยอมรับข้อกำหนดทั้งหมด\n'
          '6. การละเมิดข้อกำหนดอาจนำไปสู่การระงับบัญชี',
    privacy =>
      'เราให้ความสำคัญกับข้อมูลส่วนตัวของผู้ใช้:\n'
          '- เก็บเฉพาะอีเมล เบอร์โทร และข้อมูลการจองคิว เพื่อให้บริการเท่านั้น\n'
          '- ไม่เปิดเผยข้อมูลส่วนตัวแก่บุคคลที่สามโดยไม่ได้รับอนุญาต\n'
          '- ผู้ใช้ลบบัญชีและข้อมูลของตนเองได้จากหน้าโปรไฟล์\n'
          '- ติดต่อสอบถามเรื่องข้อมูลส่วนตัวได้ที่ support@shabuq.com',
  };
}

class AppContentService {
  AppContentService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(AppContentPage page) =>
      _firestore.collection('appContent').doc(page.id);

  /// The saved body of [page], or its default when nothing is saved yet.
  Stream<String> watch(AppContentPage page) {
    return _doc(page).snapshots().map((snapshot) {
      final body = snapshot.data()?['body'];
      return body is String && body.trim().isNotEmpty
          ? body
          : page.defaultBody;
    });
  }

  Future<void> save(AppContentPage page, String body) {
    return _doc(page).set({
      'body': body.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
