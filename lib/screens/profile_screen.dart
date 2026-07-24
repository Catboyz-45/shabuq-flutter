import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;
    final cardColor = theme.cardColor;

    // Firestore reference
    final userDoc =
        user != null
            ? FirebaseFirestore.instance.collection('users').doc(user.uid)
            : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 149, 144, 248),
        foregroundColor: Colors.white,
        title: const Text('โปรไฟล์'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Card สำหรับข้อมูลส่วนตัว
            FutureBuilder<DocumentSnapshot>(
              future: userDoc?.get(),
              builder: (context, snapshot) {
                final data =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};
                String birthday = data['birthday'] ?? '';
                String gender = data['gender'] ?? '';
                String phone = data['phone'] ?? '';
                String displayName =
                    data['displayName'] ?? user?.displayName ?? '';
                String avatarIcon = data['avatarIcon'] ?? 'person';
                int avatarColor = data['avatarColor'] ?? Colors.grey.toARGB32();

                return StatefulBuilder(
                  builder:
                      (context, setState) => Column(
                        children: [
                          // รูปโปรไฟล์ + เลือกไอคอนและสี
                          Center(
                            child: GestureDetector(
                              onTap: () async {
                                // เลือกไอคอนและสี
                                await showDialog(
                                  context: context,
                                  builder: (ctx) {
                                    String tempIcon = avatarIcon;
                                    int tempColor = avatarColor;
                                    final icons = [
                                      'person',
                                      'face',
                                      'star',
                                      'pets',
                                      'emoji_emotions',
                                    ];
                                    final colors = [
                                      Colors.grey,
                                      Colors.blue,
                                      Colors.red,
                                      Colors.green,
                                      Colors.orange,
                                      Colors.purple,
                                    ];
                                    return StatefulBuilder(
                                      builder:
                                          (
                                            context,
                                            setDialogState,
                                          ) => AlertDialog(
                                            title: const Text(
                                              'เลือกไอคอนและสี',
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Wrap(
                                                  spacing: 8,
                                                  children:
                                                      icons.map((iconName) {
                                                        final selected =
                                                            tempIcon ==
                                                            iconName;
                                                        return GestureDetector(
                                                          onTap: () {
                                                            tempIcon = iconName;
                                                            setDialogState(
                                                              () {},
                                                            );
                                                          },
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                              border: Border.all(
                                                                color:
                                                                    selected
                                                                        ? Colors
                                                                            .blue
                                                                        : Colors
                                                                            .transparent,
                                                                width: 3,
                                                              ),
                                                              color:
                                                                  selected
                                                                      ? Colors
                                                                          .blue
                                                                          .withValues(
                                                                            alpha:
                                                                                0.15,
                                                                          )
                                                                      : Colors
                                                                          .transparent,
                                                            ),
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8,
                                                                ),
                                                            child: Icon(
                                                              _iconFromName(
                                                                iconName,
                                                              ),
                                                              size: 32,
                                                              color:
                                                                  selected
                                                                      ? Colors
                                                                          .blue
                                                                      : Colors
                                                                          .black54,
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                ),
                                                const SizedBox(height: 16),
                                                Wrap(
                                                  spacing: 8,
                                                  children:
                                                      colors.map((c) {
                                                        final selected =
                                                            tempColor ==
                                                            c.toARGB32();
                                                        return GestureDetector(
                                                          onTap: () {
                                                            tempColor =
                                                                c.toARGB32();
                                                            setDialogState(
                                                              () {},
                                                            );
                                                          },
                                                          child: Container(
                                                            width: 32,
                                                            height: 32,
                                                            decoration: BoxDecoration(
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                              color: c,
                                                              border: Border.all(
                                                                color:
                                                                    selected
                                                                        ? Colors
                                                                            .blue
                                                                        : Colors
                                                                            .transparent,
                                                                width: 3,
                                                              ),
                                                            ),
                                                            child:
                                                                selected
                                                                    ? const Icon(
                                                                      Icons
                                                                          .check,
                                                                      color:
                                                                          Colors
                                                                              .white,
                                                                      size: 20,
                                                                    )
                                                                    : null,
                                                          ),
                                                        );
                                                      }).toList(),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                child: const Text('ยกเลิก'),
                                                onPressed:
                                                    () => Navigator.pop(ctx),
                                              ),
                                              TextButton(
                                                child: const Text('บันทึก'),
                                                onPressed: () async {
                                                  await userDoc?.set({
                                                    'avatarIcon': tempIcon,
                                                    'avatarColor': tempColor,
                                                  }, SetOptions(merge: true));
                                                  if (!ctx.mounted) return;
                                                  setState(() {
                                                    avatarIcon = tempIcon;
                                                    avatarColor = tempColor;
                                                  });
                                                  Navigator.pop(ctx);
                                                },
                                              ),
                                            ],
                                          ),
                                    );
                                  },
                                );
                              },
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 48,
                                    backgroundColor: Color(avatarColor),
                                    child: Icon(
                                      _iconFromName(avatarIcon),
                                      size: 48,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: 220,
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: displayName,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'ชื่อผู้ใช้',
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (val) async {
                                        await userDoc?.set({
                                          'displayName': val,
                                        }, SetOptions(merge: true));
                                        displayName = val;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // ข้อมูลส่วนตัว
                          Card(
                            color: cardColor,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Container(
                              width: 380,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 28,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ข้อมูลส่วนตัว',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'อีเมล',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            user?.email ?? '-',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          height: 1,
                                          color: theme.dividerColor,
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // วันเกิด
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'วันเกิด',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child:
                                              birthday.isNotEmpty
                                                  ? GestureDetector(
                                                    child: Text(
                                                      (() {
                                                        // แปลง yyyy-m-d เป็น d/m/yyyy
                                                        final parts = birthday
                                                            .split('-');
                                                        if (parts.length == 3) {
                                                          return '${parts[2]}/${parts[1]}/${parts[0]}';
                                                        }
                                                        return birthday;
                                                      })(),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: textColor,
                                                      ),
                                                    ),
                                                    onTap: () async {
                                                      DateTime? picked =
                                                          await showDatePicker(
                                                            context: context,
                                                            initialDate:
                                                                DateTime(2000),
                                                            firstDate: DateTime(
                                                              1900,
                                                            ),
                                                            lastDate:
                                                                DateTime.now(),
                                                          );
                                                      if (picked != null &&
                                                          userDoc != null) {
                                                        String newBirthday =
                                                            '${picked.year}-${picked.month}-${picked.day}';
                                                        await userDoc.set(
                                                          {
                                                            'birthday':
                                                                newBirthday,
                                                          },
                                                          SetOptions(
                                                            merge: true,
                                                          ),
                                                        );
                                                        setState(() {
                                                          birthday =
                                                              newBirthday;
                                                        });
                                                      }
                                                    },
                                                  )
                                                  : GestureDetector(
                                                    child: Text(
                                                      'กรอกวันเกิด',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                    onTap: () async {
                                                      DateTime? picked =
                                                          await showDatePicker(
                                                            context: context,
                                                            initialDate:
                                                                DateTime(2000),
                                                            firstDate: DateTime(
                                                              1900,
                                                            ),
                                                            lastDate:
                                                                DateTime.now(),
                                                          );
                                                      if (picked != null &&
                                                          userDoc != null) {
                                                        String newBirthday =
                                                            '${picked.year}-${picked.month}-${picked.day}';
                                                        await userDoc.set(
                                                          {
                                                            'birthday':
                                                                newBirthday,
                                                          },
                                                          SetOptions(
                                                            merge: true,
                                                          ),
                                                        );
                                                        setState(() {
                                                          birthday =
                                                              newBirthday;
                                                        });
                                                      }
                                                    },
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          height: 1,
                                          color: theme.dividerColor,
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // เพศ
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'เพศ',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: ButtonTheme(
                                            alignedDropdown: true,
                                            child: DropdownButton<String>(
                                              isDense: true,
                                              value:
                                                  [
                                                        'ชาย',
                                                        'หญิง',
                                                        'อื่นๆ',
                                                      ].contains(gender)
                                                      ? gender
                                                      : null,
                                              hint: Text(
                                                'เลือกเพศ',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              items:
                                                  ['ชาย', 'หญิง', 'อื่นๆ'].map((
                                                    g,
                                                  ) {
                                                    return DropdownMenuItem(
                                                      value: g,
                                                      child: Text(
                                                        g,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                              onChanged: (val) async {
                                                if (val != null &&
                                                    userDoc != null) {
                                                  await userDoc.set({
                                                    'gender': val,
                                                  }, SetOptions(merge: true));
                                                  setState(() {
                                                    gender = val;
                                                  });
                                                }
                                              },
                                              underline: Container(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          height: 1,
                                          color: theme.dividerColor,
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // เบอร์โทรศัพท์
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'เบอร์โทรศัพท์',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: SizedBox(
                                            width: 140,
                                            child: TextField(
                                              controller: TextEditingController(
                                                text: phone,
                                              ),
                                              keyboardType: TextInputType.phone,
                                              decoration: InputDecoration(
                                                hintText: 'กรอกเบอร์',
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 8,
                                                    ),
                                                border: InputBorder.none,
                                                counterText: '',
                                              ),
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: textColor,
                                              ),
                                              textAlign:
                                                  TextAlign
                                                      .right, // เพิ่มบรรทัดนี้ให้ชิดขวา
                                              maxLength: 10,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                  10,
                                                ),
                                              ],
                                              onChanged: (val) async {
                                                if (userDoc != null) {
                                                  await userDoc.set({
                                                    'phone': val,
                                                  }, SetOptions(merge: true));
                                                  setState(() {
                                                    phone = val;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                );
              },
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'เวอร์ชั่นแอป 1.0.0',
                style: TextStyle(color: theme.disabledColor),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text('การช่วยเหลือ', style: TextStyle(color: textColor)),
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        backgroundColor: cardColor,
                        title: Text(
                          'ช่วยเหลือ',
                          style: TextStyle(color: textColor),
                        ),
                        content: Text(
                          'ติดต่อทีมงานได้ที่ support@shabuq.com',
                          style: TextStyle(color: textColor),
                        ),
                        actions: [
                          TextButton(
                            child: Text(
                              'ปิด',
                              style: TextStyle(color: textColor),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                );
              },
            ),
            // ข้อกำหนดและเงื่อนไขการใช้งาน
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: Text(
                'ข้อกำหนดและเงื่อนไขการใช้งาน',
                style: TextStyle(color: textColor),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        backgroundColor: cardColor,
                        title: Text(
                          'ข้อกำหนดและเงื่อนไขการใช้งาน',
                          style: TextStyle(color: textColor),
                        ),
                        content: SingleChildScrollView(
                          child: Text(
                            'ข้อกำหนดและเงื่อนไขการใช้งาน\n\n'
                            '1. ผู้ใช้ต้องปฏิบัติตามกฎระเบียบของแอปพลิเคชัน\n'
                            '2. ห้ามใช้แอปเพื่อวัตถุประสงค์ที่ผิดกฎหมายหรือสร้างความเสียหาย\n'
                            '3. ข้อมูลส่วนตัวของผู้ใช้จะถูกเก็บรักษาอย่างปลอดภัย\n'
                            '4. แอปขอสงวนสิทธิ์ในการเปลี่ยนแปลงข้อกำหนดโดยไม่ต้องแจ้งให้ทราบล่วงหน้า\n'
                            '5. การใช้งานแอปถือว่าผู้ใช้ยอมรับข้อกำหนดทั้งหมด\n'
                            '6. หากมีข้อสงสัย กรุณาติดต่อทีมงาน\n'
                            '7. ข้อกำหนดเพิ่มเติมสามารถดูได้ที่เว็บไซต์ของเรา\n'
                            '8. การละเมิดข้อกำหนดอาจนำไปสู่การระงับบัญชี\n'
                            '9. แอปไม่รับผิดชอบต่อความเสียหายที่เกิดจากการใช้งาน\n'
                            '10. ผู้ใช้ควรตรวจสอบข้อกำหนดเป็นระยะ\n',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: Text(
                              'ปิด',
                              style: TextStyle(color: textColor),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                );
              },
            ),
            // นโยบายความเป็นส่วนตัว
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(
                'นโยบายความเป็นส่วนตัว',
                style: TextStyle(color: textColor),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        backgroundColor: cardColor,
                        title: Text(
                          'นโยบายความเป็นส่วนตัว',
                          style: TextStyle(color: textColor),
                        ),
                        content: SingleChildScrollView(
                          child: Text(
                            'นโยบายความเป็นส่วนตัว\n\n'
                            'เราให้ความสำคัญกับข้อมูลส่วนตัวของผู้ใช้:\n'
                            '- ข้อมูลที่เก็บรวบรวมจะใช้เพื่อปรับปรุงบริการเท่านั้น\n'
                            '- เราจะไม่เปิดเผยข้อมูลส่วนตัวแก่บุคคลที่สามโดยไม่ได้รับอนุญาต\n'
                            '- ผู้ใช้สามารถร้องขอให้ลบหรือแก้ไขข้อมูลส่วนตัวได้\n'
                            '- ข้อมูลจะถูกเก็บรักษาอย่างปลอดภัยตามมาตรฐานสากล\n'
                            '- หากมีการเปลี่ยนแปลงนโยบายจะแจ้งให้ผู้ใช้ทราบ\n'
                            '- ผู้ใช้สามารถติดต่อสอบถามเกี่ยวกับข้อมูลส่วนตัวได้ที่ support@shabuq.com\n'
                            '- การใช้งานแอปถือว่าผู้ใช้ยอมรับนโยบายนี้\n'
                            '- ข้อมูลการใช้งานจะถูกนำไปวิเคราะห์เพื่อปรับปรุงประสบการณ์ผู้ใช้\n'
                            '- เราใช้เทคโนโลยีเพื่อป้องกันการเข้าถึงข้อมูลโดยไม่ได้รับอนุญาต\n'
                            '- หากพบการละเมิดความเป็นส่วนตัว กรุณาแจ้งทีมงานทันที\n',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: Text(
                              'ปิด',
                              style: TextStyle(color: textColor),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                );
              },
            ),
            // ตั้งค่าบัญชีผู้ใช้
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(
                'ตั้งค่าบัญชีผู้ใช้',
                style: TextStyle(color: textColor),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        backgroundColor: cardColor,
                        title: Text(
                          'ลบบัญชีผู้ใช้',
                          style: TextStyle(color: textColor),
                        ),
                        content: Text(
                          'คุณแน่ใจหรือไม่ว่าต้องการลบบัญชีผู้ใช้?\n'
                          'การดำเนินการนี้จะลบบัญชีเข้าสู่ระบบและย้อนกลับไม่ได้ '
                          'ข้อมูลประกอบบางรายการอาจต้องให้ผู้ดูแลระบบลบเพิ่มเติม',
                          style: TextStyle(color: textColor),
                        ),
                        actions: [
                          TextButton(
                            child: Text(
                              'ยกเลิก',
                              style: TextStyle(color: textColor),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          TextButton(
                            child: Text(
                              'ยืนยันลบ',
                              style: TextStyle(color: Colors.red),
                            ),
                            onPressed: () async {
                              try {
                                await user?.delete();
                                if (!context.mounted) return;
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              } on FirebaseAuthException catch (error) {
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                if (!context.mounted) return;
                                showDialog(
                                  context: context,
                                  builder:
                                      (_) => AlertDialog(
                                        backgroundColor: cardColor,
                                        title: Text(
                                          'เกิดข้อผิดพลาด',
                                          style: TextStyle(color: textColor),
                                        ),
                                        content: Text(
                                          error.code == 'requires-recent-login'
                                              ? 'กรุณาออกจากระบบและเข้าสู่ระบบใหม่ก่อนลบบัญชี'
                                              : 'ไม่สามารถลบบัญชีได้ กรุณาลองใหม่',
                                          style: TextStyle(color: textColor),
                                        ),
                                        actions: [
                                          TextButton(
                                            child: Text(
                                              'ปิด',
                                              style: TextStyle(
                                                color: textColor,
                                              ),
                                            ),
                                            onPressed:
                                                () => Navigator.pop(context),
                                          ),
                                        ],
                                      ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                );
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('ออกจากระบบ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // เพิ่มฟังก์ชันแปลงชื่อไอคอนเป็น IconData
  IconData _iconFromName(String name) {
    switch (name) {
      case 'face':
        return Icons.face;
      case 'star':
        return Icons.star;
      case 'pets':
        return Icons.pets;
      case 'emoji_emotions':
        return Icons.emoji_emotions;
      default:
        return Icons.person;
    }
  }
}
