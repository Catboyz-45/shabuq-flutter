// Import packages ที่จำเป็น
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart'; // UI สำหรับหน้าล็อกอิน/สมัครสมาชิก
import 'package:firebase_auth/firebase_auth.dart'; // สำหรับจัดการผู้ใช้
import 'package:cloud_firestore/cloud_firestore.dart'; // สำหรับบันทึกข้อมูลผู้ใช้เพิ่มเติม

import '../utils/auth_messages.dart';

// หน้าจอสำหรับล็อกอินและสมัครสมาชิก
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  // ฟังก์ชันล็อกอิน
  Future<String?> _login(LoginData data) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: data.name.trim(), // ใช้อีเมลจากช่องกรอก
        password: data.password, // ใช้รหัสผ่านจากช่องกรอก
      );
      final user = credential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
        }, SetOptions(merge: true));
      }
      return null; // null หมายถึงสำเร็จ
    } on FirebaseAuthException catch (e) {
      return authErrorMessage(e.code); // แสดงข้อความ error เป็นภาษาไทย
    }
  }

  // ฟังก์ชันสมัครสมาชิก
  Future<String?> _signup(SignupData data) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: (data.name ?? '').trim(),
        password: (data.password ?? ''),
      );
      // บันทึกข้อมูลผู้ใช้ลง Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
            'email': cred.user!.email,
            'createdAt': FieldValue.serverTimestamp(), // เวลาที่สมัคร
          }, SetOptions(merge: true));
      return null; // สมัครสำเร็จ
    } on FirebaseAuthException catch (e) {
      return authErrorMessage(e.code);
    }
  }

  // ส่งอีเมลสำหรับตั้งรหัสผ่านใหม่
  Future<String?> _recoverPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      // ไม่บอกว่าอีเมลนี้มีบัญชีหรือไม่ เพื่อไม่ให้ใช้เดารายชื่อผู้ใช้ได้
      if (e.code == 'user-not-found') return null;
      return authErrorMessage(e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      title: 'ShabuQ', // ชื่อแอปที่แสดงบนหน้าจอ
      onLogin: _login, // ฟังก์ชันล็อกอิน
      onSignup: _signup, // ฟังก์ชันสมัครสมาชิก
      onRecoverPassword: _recoverPassword, // ส่งลิงก์ตั้งรหัสผ่านใหม่
      onSubmitAnimationCompleted: () {
        Navigator.of(context).pop(); // กลับไปหน้าหลักหลังล็อกอิน/สมัครเสร็จ
      },
      theme: LoginTheme(
        primaryColor: const Color.fromARGB(255, 149, 144, 248), // สีหลักของธีม
        buttonTheme: LoginButtonTheme(
          backgroundColor: const Color.fromARGB(255, 149, 144, 248),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      messages: LoginMessages(
        userHint: 'อีเมล',
        passwordHint: 'รหัสผ่าน',
        confirmPasswordHint: 'ยืนยันรหัสผ่าน',
        loginButton: 'เข้าสู่ระบบ',
        signupButton: 'สมัครสมาชิก',
        forgotPasswordButton: 'ลืมรหัสผ่าน?',
        recoverPasswordIntro: 'ตั้งรหัสผ่านใหม่',
        recoverPasswordDescription:
            'กรอกอีเมลที่ใช้สมัคร เราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปให้',
        recoverPasswordButton: 'ส่งลิงก์',
        recoverPasswordSuccess: 'ถ้ามีบัญชีนี้ในระบบ ลิงก์จะถูกส่งไปที่อีเมล',
        goBackButton: 'กลับ',
        confirmPasswordError: 'รหัสผ่านไม่ตรงกัน',
        flushbarTitleError: 'เกิดข้อผิดพลาด',
        flushbarTitleSuccess: 'สำเร็จ',
        signUpSuccess: 'สมัครสมาชิกเรียบร้อย',
      ),
    );
  }
}
