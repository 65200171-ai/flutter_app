// lib/auth/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/driver_screen.dart';
import '../screens/user_screen.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // ✅ ต้องยืนยันอีเมลก่อน
        if (!user.emailVerified) {
          return const VerifyEmailScreen();
        }

        // ✅ role แบบเดิมของเจี๊ยบ
        final email = user.email?.toLowerCase() ?? '';
        if (email == '65200241@kmitl.ac.th') {
          return const DriverScreen();
        } else {
          return const UserScreen();
        }
      },
    );
  }
}
