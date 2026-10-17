// Import หน้าจอต่าง ๆ ที่จะใช้ใน Tab
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'queue_screen.dart';
import 'promotions_screen.dart';
import 'profile_screen.dart';
import '../widgets/queue_alerts.dart';

// Widget หลักที่ใช้แสดงแถบเมนูด้านล่างและเนื้อหาของแต่ละ Tab
class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // จำนวนแท็บทั้งหมดที่จะแสดง
      child: Scaffold(
        // แจ้งเตือนในแอปเมื่อใกล้ถึงคิว ไม่ว่าจะอยู่แท็บไหน
        body: const QueueAlerts(
          child: TabBarView(
            // เนื้อหาที่จะแสดงในแต่ละแท็บ
            children: [
              HomeScreen(), // หน้าหลัก
              QueueScreen(), // คิวของฉัน
              PromotionsScreen(), // ส่วนลด/โปรโมชั่น
              ProfileScreen(), // โปรไฟล์ผู้ใช้
            ],
          ),
        ),
        // แถบเมนูด้านล่าง สีมาจาก AppTheme
        bottomNavigationBar: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.home), text: 'หน้าหลัก'),
            Tab(icon: Icon(Icons.confirmation_number), text: 'คิวของฉัน'),
            Tab(icon: Icon(Icons.local_offer), text: 'ส่วนลด'),
            Tab(icon: Icon(Icons.person), text: 'โปรไฟล์'),
          ],
        ),
      ),
    );
  }
}
