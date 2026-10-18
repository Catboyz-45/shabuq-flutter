import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/auth_messages.dart';
import '../widgets/brand.dart';
import '../widgets/motion.dart';

enum _Mode { login, signup, reset }

/// Sign in, sign up and password reset. The app switches to the signed-in
/// screens on its own once Firebase reports a user.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _Mode _mode = _Mode.login;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _switchTo(_Mode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _notice = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final email = _email.text.trim();
    try {
      switch (_mode) {
        case _Mode.login:
          final credential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(
                email: email,
                password: _password.text,
              );
          await _saveEmail(credential.user);
        case _Mode.signup:
          final credential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: email,
                password: _password.text,
              );
          await _saveEmail(credential.user, isNew: true);
        case _Mode.reset:
          try {
            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          } on FirebaseAuthException catch (e) {
            // ไม่บอกว่าอีเมลนี้มีบัญชีหรือไม่ เพื่อไม่ให้ใช้เดารายชื่อผู้ใช้ได้
            if (e.code != 'user-not-found') rethrow;
          }
          if (mounted) {
            setState(
              () => _notice = 'ถ้ามีบัญชีนี้ในระบบ ลิงก์จะถูกส่งไปที่อีเมล',
            );
          }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e.code));
    } on FirebaseException {
      // Signed in, but saving the e-mail failed; the next sign-in retries.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Google sign-in: a popup on the web, the system browser on phones.
  /// Requires the Google provider to be enabled in the Firebase console.
  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final provider = GoogleAuthProvider()..addScope('email');
      final credential =
          kIsWeb
              ? await FirebaseAuth.instance.signInWithPopup(provider)
              : await FirebaseAuth.instance.signInWithProvider(provider);
      await _saveEmail(
        credential.user,
        isNew: credential.additionalUserInfo?.isNewUser ?? false,
      );
    } on FirebaseAuthException catch (e) {
      final message = googleSignInErrorMessage(e.code);
      if (mounted && message != null) setState(() => _error = message);
    } on FirebaseException {
      // Signed in, but saving the e-mail failed; the next sign-in retries.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEmail(User? user, {bool isNew = false}) async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    // The sign-in page keeps its red-and-white look in dark mode too.
    return Theme(
      data: AppTheme.light(),
      child: Builder(
        builder:
            (context) => Scaffold(
              backgroundColor: Palette.chili,
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          children: [
                            const Expanded(child: _Hero()),
                            FadeSlideIn(offset: 48, child: _buildForm(context)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (title, action) = switch (_mode) {
      _Mode.login => ('เข้าสู่ระบบ', 'เข้าสู่ระบบ'),
      _Mode.signup => ('สมัครสมาชิก', 'สมัครสมาชิก'),
      _Mode.reset => ('ตั้งรหัสผ่านใหม่', 'ส่งลิงก์ตั้งรหัสผ่าน'),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Motion.ease,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_mode == _Mode.reset) ...[
                  const SizedBox(height: 4),
                  Text(
                    'กรอกอีเมลที่ใช้สมัคร เราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปให้',
                    style: text.bodyMedium?.copyWith(color: Palette.muted),
                  ),
                ],
                const SizedBox(height: 18),
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'อีเมล',
                    hintText: 'you@example.com',
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)
                        ? null
                        : 'กรุณากรอกอีเมลให้ถูกต้อง';
                  },
                ),
                if (_mode != _Mode.reset) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _hidePassword,
                    autofillHints: [
                      _mode == _Mode.login
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    textInputAction:
                        _mode == _Mode.signup
                            ? TextInputAction.next
                            : TextInputAction.done,
                    onFieldSubmitted:
                        _mode == _Mode.login ? (_) => _submit() : null,
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่าน',
                      suffixIcon: IconButton(
                        tooltip:
                            _hidePassword ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                        onPressed:
                            () =>
                                setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator:
                        (value) =>
                            (value ?? '').length < 6
                                ? 'รหัสผ่านต้องมีอย่างน้อย 6 ตัว'
                                : null,
                  ),
                ],
                if (_mode == _Mode.signup) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirm,
                    enabled: !_busy,
                    obscureText: _hidePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'ยืนยันรหัสผ่าน',
                    ),
                    validator:
                        (value) =>
                            value == _password.text
                                ? null
                                : 'รหัสผ่านไม่ตรงกัน',
                  ),
                ],
                if (_mode == _Mode.login)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : () => _switchTo(_Mode.reset),
                      child: const Text('ลืมรหัสผ่าน?'),
                    ),
                  )
                else
                  const SizedBox(height: 16),
                if (_error != null || _notice != null) ...[
                  _Message(text: _error ?? _notice!, isError: _error != null),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.ink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child:
                      _busy
                          ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                          : Text(action),
                ),
                if (_mode != _Mode.reset) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'หรือ',
                          style: text.bodySmall?.copyWith(color: Palette.muted),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _busy ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('ดำเนินการต่อด้วยบัญชี Google'),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      switch (_mode) {
                        _Mode.login => 'ยังไม่มีบัญชี?',
                        _Mode.signup => 'มีบัญชีแล้ว?',
                        _Mode.reset => 'จำรหัสผ่านได้แล้ว?',
                      },
                      style: text.bodyMedium?.copyWith(color: Palette.inkSoft),
                    ),
                    TextButton(
                      onPressed:
                          _busy
                              ? null
                              : () => _switchTo(
                                _mode == _Mode.login
                                    ? _Mode.signup
                                    : _Mode.login,
                              ),
                      child: Text(
                        _mode == _Mode.login ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo, wordmark and tagline on the red top half.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoopingBuilder(
              duration: const Duration(milliseconds: 3600),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: const BrandLogo(size: 112),
              ),
              builder:
                  (context, t, child) => Transform.translate(
                    offset: Offset(0, -6 * sin(t * 2 * pi)),
                    child: child,
                  ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  'Shabu',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                LoopingBuilder(
                  duration: const Duration(milliseconds: 3200),
                  child: const QChip(size: 54),
                  builder:
                      (context, t, child) => Transform.rotate(
                        angle: 0.09 * sin(t * 2 * pi) - 0.02,
                        child: child,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'รับคิวร้านชาบูจากที่บ้าน\nไม่ต้องไปยืนรอหน้าร้าน',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Palette.chiliTint : Palette.leafTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? Palette.chiliDark : Palette.leafInk,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
