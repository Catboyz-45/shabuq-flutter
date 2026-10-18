import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/queue_entry.dart';
import '../services/app_content_service.dart';
import '../services/queue_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/motion.dart';
import '../widgets/profile_card.dart';
import 'delete_account_dialog.dart';

/// Customer profile: avatar and contact details, visit stats, theme, help
/// pages, account deletion and sign-out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;
    final userDoc =
        user == null
            ? null
            : FirebaseFirestore.instance.collection('users').doc(user.uid);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            if (user != null && userDoc != null) ...[
              ProfileCard(
                userDoc: userDoc,
                email: user.email ?? '-',
                fallbackName: user.displayName ?? '',
              ),
              const SizedBox(height: 18),
              FadeSlideIn(child: _VisitStats(uid: user.uid, userDoc: userDoc)),
            ],
            const SizedBox(height: 22),
            const _GroupLabel('ธีม'),
            const _ThemePicker(),
            const SizedBox(height: 22),
            const _GroupLabel('ช่วยเหลือ'),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // หน้าข้อความ แอดมินแก้ได้จากหน้า Super Admin
                  for (final (index, (page, icon))
                      in const [
                        (AppContentPage.help, Icons.help_outline_rounded),
                        (AppContentPage.terms, Icons.article_outlined),
                        (AppContentPage.privacy, Icons.privacy_tip_outlined),
                      ].indexed) ...[
                    if (index > 0) const Divider(height: 1, indent: 52),
                    ListTile(
                      leading: Icon(icon),
                      title: Text(page.title),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showContentPage(context, page),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('ออกจากระบบ'),
                    onPressed: FirebaseAuth.instance.signOut,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.error,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder: (_) => const DeleteAccountDialog(),
                        ),
                    child: const Text('ลบบัญชีผู้ใช้'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder:
                    (context, snapshot) => Text(
                      'เวอร์ชันแอป ${snapshot.data?.version ?? '-'}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContentPage(BuildContext context, AppContentPage page) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(page.title),
            content: StreamBuilder<String>(
              stream: AppContentService().watch(page),
              builder:
                  (context, snapshot) => SingleChildScrollView(
                    child: Text(snapshot.data ?? page.defaultBody),
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('ปิด'),
              ),
            ],
          ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Meals eaten, coupons held and shops visited, from the customer's own data.
class _VisitStats extends StatefulWidget {
  const _VisitStats({required this.uid, required this.userDoc});

  final String uid;
  final DocumentReference<Map<String, dynamic>> userDoc;

  @override
  State<_VisitStats> createState() => _VisitStatsState();
}

class _VisitStatsState extends State<_VisitStats> {
  late final Stream<List<QueueEntry>> _history = QueueService().watchMyHistory(
    widget.uid,
  );
  late final Stream<int> _coupons = widget.userDoc
      .collection('coupons')
      .snapshots()
      .map((snapshot) => snapshot.size);

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return StreamBuilder<List<QueueEntry>>(
      stream: _history,
      builder: (context, historySnapshot) {
        final completed = [
          for (final queue in historySnapshot.data ?? const <QueueEntry>[])
            if (queue.status == 'completed') queue,
        ];
        final shops = {for (final queue in completed) queue.shopId};
        return StreamBuilder<int>(
          stream: _coupons,
          builder:
              (context, couponSnapshot) => Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isLight ? Palette.ink : Palette.nightCard,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _Stat(
                        value:
                            historySnapshot.hasData ? completed.length : null,
                        label: 'มากินแล้ว',
                      ),
                      const VerticalDivider(color: Palette.nightLine),
                      _Stat(value: couponSnapshot.data, label: 'คูปอง'),
                      const VerticalDivider(color: Palette.nightLine),
                      _Stat(
                        value: historySnapshot.hasData ? shops.length : null,
                        label: 'ร้านที่เคยไป',
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value == null ? '-' : '$value',
            style: AppFonts.numbers(fontSize: 26, color: Palette.yolk),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFFD9D3CB)),
          ),
        ],
      ),
    );
  }
}

/// System / light / dark, remembered on the device.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ThemeScope.of(context);
    const options = [
      (ThemeMode.system, 'ตามเครื่อง'),
      (ThemeMode.light, 'สว่าง'),
      (ThemeMode.dark, 'มืด'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final (mode, label) in options)
            Expanded(
              child: Semantics(
                selected: controller.value == mode,
                button: true,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Motion.ease,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        controller.value == mode
                            ? scheme.surfaceContainerLowest
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => controller.setMode(mode),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight:
                                controller.value == mode
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                            color:
                                controller.value == mode
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
