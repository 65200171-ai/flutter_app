import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/auth_gate.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'auth/forgot_password_screen.dart';
import 'screens/user_screen.dart';
import 'screens/driver_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // โปรดตั้งค่า Firebase ให้ตรงโปรเจ็กต์
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Transit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),

      // ✅ ให้ AuthGate ตัดสินใจว่าจะไปหน้าไหนตามสถานะผู้ใช้
      home: const AuthGate(),

      // ✅ ตั้งชื่อ route ไว้ให้เรียกสะดวกจากปุ่ม/โค้ดหน้าอื่น ๆ
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/forgot': (_) => const ForgotPasswordScreen(),
        '/user': (_) => const UserScreen(),
        '/driver': (_) => const DriverScreen(),

      },
    );
  }
}
