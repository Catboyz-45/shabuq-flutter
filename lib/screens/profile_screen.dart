import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/app_content_service.dart';
import '../theme/theme_controller.dart';
import '../widgets/profile_card.dart';
import 'delete_account_dialog.dart';

/// Customer profile: avatar and contact details, theme, help pages, account
/// deletion and sign-out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;
    final themeController = ThemeScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            ProfileCard(
              userDoc: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid),
              email: user.email ?? '-',
              fallbackName: user.displayName ?? '',
            ),
          const SizedBox(height: 16),
          // ธีมของแอป: ตามระบบ / สว่าง / มืด (จำไว้ในเครื่อง)
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('ธีมของแอป'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('ตามระบบ'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('สว่าง'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('มืด'),
                  ),
                ],
                selected: {themeController.value},
                onSelectionChanged:
                    (selection) => themeController.setMode(selection.first),
              ),
            ),
          ),
          // หน้าข้อความ แอดมินแก้ได้จากหน้า Super Admin
          for (final (page, icon) in const [
            (AppContentPage.help, Icons.help_outline),
            (AppContentPage.terms, Icons.article_outlined),
            (AppContentPage.privacy, Icons.privacy_tip_outlined),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text(page.title),
              onTap: () => _showContentPage(context, page),
            ),
          ListTile(
            leading: Icon(Icons.no_accounts_outlined, color: scheme.error),
            title: Text('ลบบัญชีผู้ใช้', style: TextStyle(color: scheme.error)),
            onTap:
                () => showDialog<void>(
                  context: context,
                  builder: (_) => const DeleteAccountDialog(),
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('ออกจากระบบ'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: FirebaseAuth.instance.signOut,
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
