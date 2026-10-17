import 'dart:async';

// Import packages ที่จำเป็นสำหรับการทำงานของแอป
import 'package:flutter/material.dart'; // สำหรับ UI
import 'package:firebase_core/firebase_core.dart'; // สำหรับเริ่มต้น Firebase
import 'package:firebase_auth/firebase_auth.dart'; // สำหรับการจัดการผู้ใช้ (Authentication)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shabuq_flutter/screens/main_screen.dart'; // หน้าหลักของแอป
import 'firebase_options.dart'; // การตั้งค่า Firebase สำหรับแพลตฟอร์มต่าง ๆ
import 'screens/admin_screen.dart';
import 'screens/auth_screen.dart'; // หน้าล็อกอิน/สมัครสมาชิก
import 'services/admin_service.dart';

// ฟังก์ชัน main เป็นจุดเริ่มต้นของแอป
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // เตรียมระบบก่อนเริ่มต้นแอป
  await Firebase.initializeApp(
    options:
        DefaultFirebaseOptions
            .currentPlatform, // เริ่มต้น Firebase ด้วย config ที่เหมาะกับแพลตฟอร์ม
  );
  // รันด้วย --dart-define=USE_FIREBASE_EMULATOR=true เพื่อทดสอบกับ Firebase Emulator
  if (const bool.fromEnvironment('USE_FIREBASE_EMULATOR')) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }
  runApp(const MyApp()); // เรียกใช้งานแอปหลัก
}

// คลาสหลักของแอป
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // ซ่อนแถบ debug ด้านขวาบน
      title: 'ShabuQ', // ชื่อแอป
      theme: ThemeData(
        useMaterial3: true, // ใช้ Material Design 3
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // สีหลักของธีม
          brightness: Brightness.light, // โหมดสว่าง
        ),
        brightness: Brightness.light, // กำหนดให้ธีมเป็นโหมดสว่าง
      ),
      home: const _AuthGate(),
      routes: {
        // สามารถเพิ่มเส้นทางไปยังหน้าต่าง ๆ ได้ที่นี่
        // '/admin_manage': (context) => const AdminManageScreen(),
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  StreamSubscription<User?>? _subscription;
  Timer? _transitionTimer;
  User? _user;
  bool _initialized = false;
  bool _readyForAuthenticatedScreen = false;

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChange,
    );
  }

  void _handleAuthChange(User? user) {
    _transitionTimer?.cancel();
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _user = null;
        _initialized = true;
        _readyForAuthenticatedScreen = false;
      });
      return;
    }

    final wasSignedOut = _user == null && _initialized;
    setState(() {
      _user = user;
      _initialized = true;
      _readyForAuthenticatedScreen = !wasSignedOut;
    });

    if (wasSignedOut) {
      // flutter_login finishes its submit animation after the callback returns.
      // Keeping AuthScreen mounted briefly prevents an unmounted-State race.
      _transitionTimer = Timer(const Duration(milliseconds: 700), () {
        if (!mounted || _user == null) return;
        setState(() => _readyForAuthenticatedScreen = true);
      });
    }
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = _user;
    if (user == null || !_readyForAuthenticatedScreen) {
      return const AuthScreen();
    }
    return _RoleRouter(user: user);
  }
}

class _RoleRouter extends StatelessWidget {
  const _RoleRouter({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    return _RoleStream(
      stream: adminService.watchIsSuperAdmin(user),
      builder: (isSuperAdmin) {
        if (isSuperAdmin) return const AdminScreen(isSuperAdmin: true);
        return _RoleStream(
          stream: adminService.watchIsShopAdmin(user),
          builder:
              (isShopAdmin) =>
                  isShopAdmin
                      ? const AdminScreen(isSuperAdmin: false)
                      : const MainTabs(),
        );
      },
    );
  }
}

class _RoleStream extends StatelessWidget {
  const _RoleStream({required this.stream, required this.builder});

  final Stream<bool> stream;
  final Widget Function(bool hasRole) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ตรวจสอบสิทธิ์ผู้ใช้ไม่สำเร็จ'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: FirebaseAuth.instance.signOut,
                    child: const Text('ออกจากระบบ'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return builder(snapshot.data!);
      },
    );
  }
}
