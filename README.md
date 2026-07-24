# ShabuQ

แอปพลิเคชันจองคิวร้านชาบู พัฒนาด้วย Flutter และ Firebase เพื่อฝึกสร้างแอปแบบข้ามแพลตฟอร์มที่มีระบบสมาชิก การจัดการข้อมูลแบบ Cloud และขั้นตอนการจองคิวตั้งแต่ต้นจนจบ

> โปรเจกต์นี้เป็นผลงานระหว่างเรียน รายวิชา 02739342 Application Development for Mobile Devices

## เกี่ยวกับโปรเจกต์

ShabuQ ช่วยให้ผู้ใช้ค้นหาร้านชาบู ดูเมนูและโปรโมชั่น เลือกร้าน โซน และจำนวนผู้ใช้บริการ จากนั้นเลือกวิธีชำระเงินและติดตามลำดับคิวของตนเองได้ภายในแอปเดียว

โปรเจกต์นี้แสดงการประยุกต์ใช้ Flutter ร่วมกับ Firebase Authentication และ Cloud Firestore รวมถึงการจัดการสถานะของหน้าจอ การนำทาง และการทำ UI ด้วย Material Design 3

## ความสามารถหลัก

- สมัครสมาชิกและเข้าสู่ระบบด้วยอีเมลและรหัสผ่าน
- แสดงรายชื่อร้าน รายละเอียดร้าน เมนู และโปรโมชั่น
- เลือกโซนและจำนวนผู้ใช้บริการก่อนจองคิว
- รองรับการเลือกชำระที่เคาน์เตอร์และ QR Code ในโหมดสาธิต
- บันทึกข้อมูลการชำระเงินและคิวด้วย Cloud Firestore
- แสดงลำดับคิวของผู้ใช้และยกเลิกคิว
- รับและใช้คูปองส่วนลด
- แก้ไขข้อมูลโปรไฟล์ รูปแบบอวตาร และธีมของแอป
- แยกหน้าผู้ใช้และหน้าแอดมินอัตโนมัติตามสิทธิ์ของบัญชี
- Super Admin จัดการร้าน โค้ดส่วนลด สิทธิ์แอดมิน และการมอบหมายร้าน
- แอดมินร้านจัดการสถานะคิวและราคาต่อคนได้เฉพาะร้านที่ได้รับมอบหมาย
- แอดมินร้านเพิ่ม แก้ไข ซ่อน และลบเมนูได้เฉพาะร้านของตนเอง
- ผู้ใช้เห็นเมนูแบบ real-time จาก Cloud Firestore
- ย้ายคิวที่เสร็จสิ้นออกจากคิวปัจจุบันและเก็บเป็นประวัติ
- จำกัดการใช้โค้ดส่วนลดหนึ่งครั้งต่อหนึ่งบัญชีด้วย Firestore transaction

## เทคโนโลยีที่ใช้

| หมวด | เทคโนโลยี |
| --- | --- |
| Application | Flutter, Dart |
| UI | Material Design 3 |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Authorization | Firestore Security Rules และ Role-based access control |

## โครงสร้างโปรเจกต์

```text
lib/
├── main.dart                 # จุดเริ่มต้นแอปและตรวจสอบสถานะผู้ใช้
├── firebase_options.dart     # การตั้งค่า Firebase ตามแพลตฟอร์ม
├── services/
│   ├── admin_service.dart
│   ├── menu_service.dart
│   ├── promo_code_service.dart
│   └── shop_service.dart
├── widgets/
│   └── shop_image.dart
└── screens/
    ├── admin_screen.dart     # จัดการร้าน แอดมิน และคิว
    ├── auth_screen.dart      # เข้าสู่ระบบและสมัครสมาชิก
    ├── home_screen.dart      # หน้าแรกและรายชื่อร้าน
    ├── booking_screen.dart   # เลือกโซนและจำนวนที่นั่ง
    ├── pay_screen.dart       # เลือกวิธีชำระเงินในโหมดสาธิต
    ├── queue_screen.dart     # ติดตามและยกเลิกคิว
    ├── menu_screen.dart      # เมนูของแต่ละร้าน
    ├── promo_code_admin.dart # จัดการโค้ดส่วนลด
    ├── promotions_screen.dart
    ├── profile_screen.dart
    └── main_screen.dart      # Bottom navigation
```

## การติดตั้งและรัน

### สิ่งที่ต้องมี

- Flutter SDK ที่รองรับ Dart `^3.7.2`
- Android Studio หรือ Xcode ตามแพลตฟอร์มที่ต้องการรัน
- Firebase project ที่เปิดใช้งาน Email/Password Authentication และ Cloud Firestore

โปรเจกต์นี้ตั้งค่าเริ่มต้นให้เชื่อมต่อ Firebase project `ftf3-f150b`

### การเริ่มต้น Super Admin

สมัครสมาชิกในแอปด้วยอีเมล `admin@gmail.com` และตั้งรหัสผ่านผ่านหน้าสมัครสมาชิกตามปกติ ระบบจะพาอีเมลนี้ไปยังหน้า `ShabuQ Admin` อัตโนมัติ บัญชีนี้เป็น Super Admin แบบถาวรและไม่สามารถลบหรือลดสิทธิ์ผ่านแอปได้

เพื่อเพิ่มแอดมินอื่น ให้ผู้ใช้นั้นสมัครสมาชิกก่อน จากนั้น Super Admin เลือกบัญชี กำหนดร้าน และมอบสิทธิ์จากหน้าแอดมิน แอดมินทั่วไปจะเห็นและจัดการคิว เมนู และราคาของร้านที่ได้รับมอบหมายเท่านั้น โดย Firestore Security Rules ตรวจ `shopId` ทุกครั้ง ระบบไม่เก็บหรือฝังรหัสผ่านแอดมินไว้ในซอร์สโค้ด

### ขั้นตอน

```bash
git clone <repository-url>
cd shabuq-flutter
flutter pub get
flutter run
```

หากนำโปรเจกต์ไปเชื่อมต่อ Firebase project ใหม่ ให้ติดตั้ง Firebase CLI และ FlutterFire CLI แล้วสร้างไฟล์ตั้งค่าใหม่:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

จากนั้นกำหนด Firestore Security Rules ให้ผู้ใช้เข้าถึงได้เฉพาะข้อมูลของตนเองก่อนใช้งานจริง

โปรเจกต์มี Rules และ indexes ที่เตรียมไว้แล้ว สามารถ deploy ไปยัง Firebase project ที่เลือกด้วย:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

ตรวจสอบชื่อ Firebase project ให้ถูกต้องก่อน deploy ทุกครั้ง

## การตรวจสอบคุณภาพโค้ด

```bash
flutter analyze
flutter test
```

ควรรันทั้งสองคำสั่งและแก้ข้อผิดพลาดทั้งหมดก่อน merge หรือเผยแพร่ release

สถานะการตรวจล่าสุด:

- `flutter analyze` — ผ่าน ไม่พบปัญหา
- `flutter test` — ผ่าน 5 tests
- `flutter build apk --release` — ผ่าน

## สิ่งที่ได้เรียนรู้

- ออกแบบแอป Flutter แบบหลายหน้าจอและจัดการ navigation
- เชื่อมต่อระบบสมาชิกและข้อมูลแบบ real-time กับ Firebase
- ออกแบบ flow ตั้งแต่เลือกร้าน จองคิว ชำระเงิน จนถึงติดตามคิว
- ออกแบบโหมดสาธิตการชำระเงินโดยไม่รับเงินจริง
- จัดโครงสร้างโค้ดด้วย service, reusable widget และ screen ตามหน้าที่

## สถานะและข้อจำกัด

โปรเจกต์นี้จัดทำขึ้นเพื่อการเรียนรู้และนำเสนอผลงาน ยังไม่ใช่ระบบรับชำระเงินจริงหรือระบบพร้อมใช้งานในร้านอาหารจริง หน้าชำระเงินเป็นโหมดสาธิตและไม่มีการรับเงินจริงหรืออัปโหลดสลิป การยืนยันยอดชำระและการลบข้อมูลผู้ใช้ทุกแหล่งควรทำใน trusted backend ก่อนนำไปใช้ใน production

บน Firebase Spark plan การลบแอดมินหมายถึงการถอนสิทธิ์และให้บัญชีกลับเป็นผู้ใช้ทั่วไป ไม่ใช่การลบบัญชี Firebase Authentication ของบุคคลอื่น การลบบัญชี Auth โดยผู้ดูแลต้องทำผ่าน trusted backend ที่ใช้ Firebase Admin SDK

## แนวทางพัฒนาต่อ

- เพิ่ม unit, widget และ integration tests สำหรับ flow สำคัญ
- เพิ่มระบบแจ้งเตือนเมื่อใกล้ถึงคิว
- ป้องกันการส่งรายการซ้ำด้วย transaction หรือ idempotency key
- เพิ่ม Cloud Functions สำหรับงานที่ต้องใช้ Firebase Admin SDK
- รองรับการยืนยันการชำระเงินจาก backend
- ปรับ accessibility และรองรับหลายภาษา

## ผู้พัฒนา

พัฒนาโดย [Catboyz-45](https://github.com/Catboyz-45) เพื่อใช้เป็นผลงานระหว่างเรียนและประกอบการสัมภาษณ์
