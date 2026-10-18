// Import หน้าจอต่าง ๆ ที่จะใช้ใน Tab
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/queue_entry.dart';
import '../services/queue_service.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';
import '../widgets/queue_alerts.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'promotions_screen.dart';
import 'queue_screen.dart';

// Widget หลักที่ใช้แสดงแถบเมนูด้านล่างและเนื้อหาของแต่ละ Tab
class MainTabs extends StatelessWidget {
  const MainTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // จำนวนแท็บทั้งหมดที่จะแสดง
      child: Builder(
        builder:
            (context) => Scaffold(
              // แจ้งเตือนในแอปเมื่อใกล้ถึงคิว ไม่ว่าจะอยู่แท็บไหน
              body: const QueueAlerts(
                child: TabBarView(
                  children: [
                    HomeScreen(), // หน้าหลัก
                    QueueScreen(), // คิวของฉัน
                    PromotionsScreen(), // คูปอง
                    ProfileScreen(), // โปรไฟล์ผู้ใช้
                  ],
                ),
              ),
              bottomNavigationBar: _BottomBar(
                controller: DefaultTabController.of(context),
              ),
            ),
      ),
    );
  }
}

/// Bottom tabs. The queue tab carries the customer's queue number while they
/// have one, so it is visible from every screen.
class _BottomBar extends StatefulWidget {
  const _BottomBar({required this.controller});

  final TabController controller;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  late final Stream<QueueEntry?> _myQueue = QueueService().watchMyQueue(
    FirebaseAuth.instance.currentUser?.uid ?? '-',
  );

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'หน้าแรก'),
    (
      Icons.confirmation_number_outlined,
      Icons.confirmation_number_rounded,
      'คิวของฉัน',
    ),
    (Icons.local_offer_outlined, Icons.local_offer_rounded, 'คูปอง'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'ฉัน'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return StreamBuilder<QueueEntry?>(
      stream: _myQueue,
      builder: (context, snapshot) {
        final queueLabel = snapshot.data?.queueLabel;
        return AnimatedBuilder(
          animation: widget.controller,
          builder:
              (context, _) => Container(
                decoration: BoxDecoration(
                  color: isLight ? Colors.white : Palette.nightPanel,
                  border: Border(top: BorderSide(color: scheme.outlineVariant)),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 68,
                    child: Row(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          Expanded(
                            child: _TabButton(
                              icon: _items[i].$1,
                              selectedIcon: _items[i].$2,
                              label: _items[i].$3,
                              selected: widget.controller.index == i,
                              badge: i == 1 ? queueLabel : null,
                              onTap: () => widget.controller.animateTo(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: badge == null ? label : '$label $badge',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: selected ? 1.12 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    selected ? selectedIcon : icon,
                    color: color,
                    size: 26,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    left: 16,
                    top: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: Palette.yolk,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: AppFonts.numbers(
                          fontSize: 11,
                          color: Palette.ink,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Motion.ease,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
