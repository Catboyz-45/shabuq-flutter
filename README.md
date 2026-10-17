# ShabuQ

แอปพลิเคชันจองคิวร้านชาบู พัฒนาด้วย Flutter และ Firebase เพื่อฝึกสร้างแอปแบบข้ามแพลตฟอร์มที่มีระบบสมาชิก การจัดการข้อมูลแบบ Cloud และขั้นตอนการจองคิวตั้งแต่ต้นจนจบ

> โปรเจกต์นี้เป็นผลงานระหว่างเรียน รายวิชา 02739342 Application Development for Mobile Devices

## เกี่ยวกับโปรเจกต์

ShabuQ ช่วยให้ลูกค้ารับคิวร้านชาบูได้ในแตะเดียว ได้เลขคิวอย่าง `A012` เห็นว่าเหลืออีกกี่คิวและต้องรอประมาณกี่นาที และได้รับการแจ้งเตือนในแอปเมื่อใกล้ถึงคิว ส่วนพนักงานร้านมีหน้าจอเรียกคิว จัดการลูกค้าที่ไม่มา เพิ่มคิว walk-in และดูสถิติของร้าน

โปรเจกต์นี้แสดงการประยุกต์ใช้ Flutter ร่วมกับ Firebase Authentication และ Cloud Firestore รวมถึงข้อมูลแบบ real-time, Security Rules แบบแยกสิทธิ์ และการออกแบบ UI ด้วย Material Design 3

## ความสามารถหลัก

**ลูกค้า**

- สมัครสมาชิก เข้าสู่ระบบ และตั้งรหัสผ่านใหม่ทางอีเมล (ข้อความ error เป็นภาษาไทย)
- ดูร้าน เวลาเปิด–ปิด ราคา จำนวนคิวที่รออยู่ แผนที่ และเมนูพร้อมรูป คำอธิบาย และราคาเพิ่ม ในหน้าเดียว
- รับคิวได้ทันทีโดยไม่ต้องจ่ายก่อน (ชำระที่ร้าน) ได้เลขคิวแยกตามโซนที่เริ่มนับใหม่ทุกวัน
- ติดตามลำดับคิวและเวลารอโดยประมาณแบบ real-time
- แจ้งเตือนในแอปเมื่อเหลือ 2 คิว และเมื่อร้านเรียกคิว ไม่ว่าจะเปิดหน้าไหนอยู่
- เก็บคูปองส่วนลดไว้ใช้ที่หน้าร้าน: กดใช้แล้วได้รหัส 6 ตัวให้พนักงานกรอกยืนยัน (ใช้ได้ครั้งเดียว รหัสหมดอายุใน 10 นาที)
- ดูประวัติการใช้บริการ ยกเลิกคิว และลบบัญชีพร้อมข้อมูลที่เกี่ยวข้อง
- เลือกธีมสว่าง มืด หรือตามระบบ

**พนักงานร้าน**

- กด "เรียกคิวถัดไป" แยกตามโซน แล้วอัปเดตสถานะ: รอคิว → เรียกแล้ว → กำลังใช้บริการ → เสร็จสิ้น
- ข้ามคิวลูกค้าที่ไม่มาหลังเรียกแล้ว 5 นาที
- เพิ่มคิว walk-in สำหรับลูกค้าที่ไม่มีแอป
- ปิดรับคิวชั่วคราวเมื่อร้านเต็มหรือใกล้ปิด และกด "ปิดร้าน" เพื่อปิดคิวที่เหลือทั้งหมด
- คิวที่ค้างจากวันก่อนจะแยกออกมาให้ปิดทีเดียว และไม่ถูกนับในลำดับคิวของวันนี้
- ยืนยันคูปองของลูกค้าจากรหัสที่ลูกค้าแสดง
- ดูสถิติ: คิววันนี้แยกตามผลลัพธ์ เวลารอเฉลี่ย 7 วัน และช่วงเวลาที่คนรับคิวเยอะ
- แก้ไขรูปร้าน ที่อยู่ เบอร์โทร ราคา เวลาเปิด–ปิด และเมนู (ชื่อ หมวด คำอธิบาย ราคาเพิ่ม รูป) ของร้านตัวเอง

**Super Admin**

- จัดการร้าน โค้ดส่วนลด และมอบสิทธิ์แอดมินให้แต่ละร้าน
- จัดการแบนเนอร์หน้าแรก: เพิ่ม แก้ไข เรียงลำดับ ซ่อน และลิงก์ไปยังร้าน
- แก้ข้อความหน้าการช่วยเหลือ ข้อกำหนด และนโยบายความเป็นส่วนตัว

ทุกอย่างข้างบนแก้ได้จากในแอป ไม่ต้องแก้โค้ดหรือออกแอปเวอร์ชันใหม่ รูปภาพใช้วิธีวางลิงก์ `https://` (มีพรีวิวก่อนบันทึก) จึงใช้ Firebase แพ็กเกจฟรีได้ ถ้าต้องการอัปโหลดรูปจากเครื่องต้องใช้ Firebase Storage ซึ่งต้องเปลี่ยนเป็นแพ็กเกจ Blaze

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
├── main.dart                    # จุดเริ่มต้นแอป ตรวจสถานะผู้ใช้และแยกหน้าตามสิทธิ์
├── models/                      # ข้อมูลจาก Firestore ในรูป class แทน Map
│   ├── queue_entry.dart
│   └── shop.dart
├── services/                    # อ่าน/เขียน Firestore (ฉีด FakeFirestore ได้ตอนเทสต์)
│   ├── account_service.dart     # ลบบัญชีพร้อมข้อมูลที่เกี่ยวข้อง
│   ├── admin_service.dart       # สิทธิ์แอดมิน เรียกคิว ปิดคิว
│   ├── app_content_service.dart # ข้อความหน้าช่วยเหลือ/ข้อกำหนด/นโยบาย
│   ├── banner_service.dart      # แบนเนอร์หน้าแรก
│   ├── coupon_service.dart      # รหัสใช้คูปองที่หน้าร้าน
│   ├── menu_service.dart
│   ├── promo_code_service.dart
│   ├── queue_service.dart       # รับคิว ออกเลขคิว walk-in ลำดับคิว
│   └── shop_service.dart
├── theme/                       # สีทั้งหมดของแอป โหมดสว่าง/มืด และตัวเลือกธีม
├── utils/                       # ตรรกะที่ไม่ผูกกับ UI และมี unit test
│   ├── auth_messages.dart       # ข้อความ error ภาษาไทย
│   ├── image_source.dart        # ตรวจลิงก์รูปภาพ
│   ├── payment_calculator.dart
│   ├── queue_position.dart      # ลำดับคิว เลขคิว วันที่ตามเวลาไทย เวลารอ
│   ├── shop_form.dart           # ตรวจข้อมูลร้านก่อนบันทึก
│   └── shop_stats.dart          # สถิติของร้าน
├── widgets/                     # image_url_field, profile_card, queue_alerts, shop_image
└── screens/
    ├── main_screen.dart         # แท็บด้านล่างของลูกค้า
    ├── auth_screen.dart         # เข้าสู่ระบบ สมัครสมาชิก ลืมรหัสผ่าน
    ├── home_screen.dart, shop_screen.dart, queue_screen.dart
    ├── promotions_screen.dart, profile_screen.dart, delete_account_dialog.dart
    ├── admin_screen.dart        # หน้า Super Admin
    ├── shop_form_dialog.dart, admin_account_dialog.dart
    ├── banner_admin.dart, app_content_admin.dart, promo_code_admin.dart
    ├── shop_admin_view.dart     # หน้าแอดมินร้าน (คิว สถิติ เมนู ข้อมูลร้าน)
    ├── shop_queue_admin.dart, shop_stats_admin.dart, shop_menu_admin.dart
    └── redeem_coupon_dialog.dart
test/                            # unit, service (Firestore จำลอง) และ widget tests
tool/
├── seed_emulator.mjs            # ข้อมูลตัวอย่างสำหรับ Emulator
└── test_rules.mjs               # ทดสอบ Security Rules กับ Emulator
```

## การติดตั้งและรัน

### สิ่งที่ต้องมี

- Flutter SDK ที่รองรับ Dart `^3.7.2`
- Android Studio หรือ Xcode ตามแพลตฟอร์มที่ต้องการรัน
- Firebase project ที่เปิดใช้งาน Email/Password Authentication และ Cloud Firestore

โปรเจกต์นี้ตั้งค่าเริ่มต้นให้เชื่อมต่อ Firebase project `ftf3-f150b`

### การเริ่มต้น Super Admin

สิทธิ์ Super Admin ไม่ได้ผูกกับอีเมลอีกต่อไป (เดิมใครสมัครด้วยอีเมลที่กำหนดก่อนก็ได้สิทธิ์ทันที) ให้ทำดังนี้

1. สมัครสมาชิกในแอปตามปกติ
2. เปิด Firebase Console → Authentication แล้วคัดลอก User UID ของบัญชีนั้น
3. ไปที่ Firestore → สร้าง collection `superAdmins` และสร้างเอกสารที่มี ID เป็น UID นั้น (ใส่ field อะไรก็ได้ เช่น `email`)

แอปจะพาบัญชีนี้ไปหน้า `ShabuQ Admin` อัตโนมัติ Security Rules ห้ามแอปเขียน collection `superAdmins` จึงเพิ่มหรือลบ Super Admin ได้จาก Console เท่านั้น

> **ถ้าอัปเดตจากเวอร์ชันเดิม:** ให้สร้าง `superAdmins/{uid}` ของบัญชีแอดมินเดิมก่อน deploy rules ชุดใหม่ ไม่เช่นนั้นจะเข้าหน้าแอดมินไม่ได้ และเคลียร์ `queues` ที่ค้างจากเวอร์ชันเดิมก่อน เพราะโครงสร้างคิวเปลี่ยนไป (ไม่มีขั้นตอนชำระเงินและใช้ `ticketId` แทน `paymentId`)

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

### ทดลองกับ Firebase Emulator

ทดสอบแอปและ Security Rules บนเครื่องได้โดยไม่แตะข้อมูลจริง (ต้องมี Java 21 ขึ้นไป):

```bash
firebase emulators:start --only auth,firestore
```

เปิดอีก terminal แล้วใส่ข้อมูลตัวอย่าง (บัญชีทดลองและรหัสผ่านอยู่ในหัวไฟล์ `tool/seed_emulator.mjs`):

```bash
node tool/seed_emulator.mjs
```

```bash
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
```

ข้อมูลตัวอย่างมีลูกค้า 3 คนรอคิวอยู่ที่ร้าน Teenoi และประวัติคิวย้อนหลัง 7 วันให้หน้าสถิติมีข้อมูลแสดง

### ข้อมูลที่แอดมินแก้ได้

| Collection | เก็บอะไร | ใครแก้ได้ |
| --- | --- | --- |
| `shops/{shopId}` | ชื่อ รูป ที่อยู่ เบอร์โทร โซน ราคา เวลาเปิด–ปิด | Super Admin ทุกช่อง, แอดมินร้านแก้รูป ที่อยู่ เบอร์โทร ราคา และเวลาของร้านตัวเอง |
| `shops/{shopId}/menuItems/{id}` | ชื่อ หมวด คำอธิบาย ราคาเพิ่ม รูป การแสดงผล | แอดมินร้านนั้น |
| `banners/{id}` | รูป ชื่อ ร้านที่ลิงก์ไป ลำดับ การแสดงผล | Super Admin |
| `appContent/{help\|terms\|privacy}` | ข้อความแต่ละหน้า (ถ้ายังไม่ได้บันทึกจะใช้ข้อความเริ่มต้นในแอป) | Super Admin |

Security Rules ยอมรับรูปเฉพาะลิงก์ `https://` หรือรูปที่มากับแอป (`assets/images/...`)

### โครงสร้างข้อมูลคิว

| Collection | เก็บอะไร | ใครอ่านได้ |
| --- | --- | --- |
| `queues/{uid}` หรือ `queues/walkin-{ticketId}` | คิวที่ยังไม่ปิด | เจ้าของคิวและแอดมินร้าน |
| `queueTickets/{ticketId}` | สำเนาไม่ระบุตัวตน: ร้าน โซน เลขคิว สถานะ เวลา | ผู้ใช้ที่ล็อกอิน (ใช้นับคิวข้างหน้า) |
| `shops/{shopId}/queueCounters/{A–Z}` | เลขคิวล่าสุดของแต่ละโซนในวันนั้น | ผู้ใช้ที่ล็อกอิน |
| `queueHistory/{ticketId}` | คิวที่ปิดแล้ว: เสร็จสิ้น ไม่มา หรือร้านยกเลิก | เจ้าของคิวและแอดมินร้าน |
| `couponRedemptions/{รหัส}` | รหัสใช้คูปอง 6 ตัว อายุ 10 นาที | เจ้าของรหัสและพนักงานร้าน (อ่านทีละรหัส ไม่ให้ list) |

ตอนรับคิว แอปจะเพิ่มเลขใน counter สร้างคิว และสร้าง ticket ใน transaction เดียวกัน Security Rules บังคับให้เลขเพิ่มทีละ 1 และตรงกับคิวที่สร้าง ทุกคิวมี `queueDate` เป็นวันที่ตามเวลาไทย (UTC+7) Security Rules คำนวณวันที่เดียวกันจากนาฬิกาของ server จึงตั้งวันที่เองไม่ได้ และเลขคิวไม่ขึ้นกับเขตเวลาในเครื่อง คิวของวันก่อนที่ยังไม่ได้ปิดจะไม่ถูกนับในลำดับคิว ส่วนเวลารอโดยประมาณคำนวณจากจำนวนคิวข้างหน้า คูณค่าเฉลี่ยของระยะห่างระหว่างการกด "เรียกคิวถัดไป" (`minutesPerQueue` ของร้าน ถ้ายังไม่มีข้อมูลจะใช้ 10 นาที)

## การตรวจสอบคุณภาพโค้ด

```bash
flutter analyze
flutter test
```

ทดสอบ Security Rules กับ Emulator (ต้องมี Java 21):

```bash
firebase emulators:exec --only auth,firestore "node tool/seed_emulator.mjs && node tool/test_rules.mjs"
```

GitHub Actions (`.github/workflows/ci.yml`) รันทั้งหมดนี้ทุกครั้งที่ push หรือเปิด PR: ตรวจ format, `flutter analyze`, `flutter test` และชุดทดสอบ Rules บน Emulator

สถานะการตรวจล่าสุด (Flutter 3.47.7):

- `flutter analyze` — ผ่าน ไม่พบปัญหา
- `flutter test` — ผ่าน 54 tests (unit, service กับ Firestore จำลอง และ widget)
- `tool/test_rules.mjs` — ผ่าน 33 กรณี
- รันบนเว็บกับ Firebase Emulator และทดสอบด้วยมือ: รับคิว ลำดับคิวและการแจ้งเตือน เรียกคิว คิวค้างข้ามวัน walk-in คูปองที่หน้าร้าน ธีมมืด โปรไฟล์ เพิ่มร้าน แบนเนอร์ เมนู และข้อความในแอป

## สิ่งที่ได้เรียนรู้

- ออกแบบแอป Flutter แบบหลายหน้าจอ แยก service, ตรรกะที่ทดสอบได้ และ UI ออกจากกัน
- ใช้ข้อมูลแบบ real-time จาก Firestore และรับมือกับ snapshot จาก cache
- เขียนเทสต์หลายระดับ: unit, service กับ Firestore จำลอง, widget และ Security Rules บน Emulator พร้อม CI
- ออกแบบ Security Rules ที่ตรวจทั้งสิทธิ์และความถูกต้องของข้อมูลใน transaction
- ออกแบบ flow ให้ใช้งานได้จริงทั้งฝั่งลูกค้าและฝั่งพนักงานร้าน

## สถานะและข้อจำกัด

โปรเจกต์นี้จัดทำขึ้นเพื่อการเรียนรู้และนำเสนอผลงาน ยังไม่ได้ทดสอบกับร้านอาหารจริง

- การแจ้งเตือนทำงานเฉพาะตอนเปิดแอปอยู่ การส่ง push notification ตอนปิดแอปต้องใช้ Firebase Cloud Messaging คู่กับ Cloud Functions ซึ่งต้องใช้แพ็กเกจ Blaze
- บน Firebase Spark plan การลบแอดมินหมายถึงการถอนสิทธิ์และให้บัญชีกลับเป็นผู้ใช้ทั่วไป การลบบัญชี Auth ของคนอื่นต้องทำผ่าน trusted backend ที่ใช้ Firebase Admin SDK

## แนวทางพัฒนาต่อ

- Push notification ผ่าน Firebase Cloud Messaging และ Cloud Functions
- Integration test บนอุปกรณ์จริงสำหรับ flow รับคิวและเรียกคิว
- จอแสดงเลขคิวหน้าร้าน และ QR ให้ลูกค้า walk-in สแกนรับคิวเอง
- รองรับหลายภาษาและปรับ accessibility

## ผู้พัฒนา

พัฒนาโดย [Catboyz-45](https://github.com/Catboyz-45) เพื่อใช้เป็นผลงานระหว่างเรียนและประกอบการสัมภาษณ์
