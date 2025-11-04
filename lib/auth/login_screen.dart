import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  bool _busy = false;

  // ===== logic เดิมของเจี๊ยบ (ไม่เปลี่ยน) =====
  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _pass.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรอกอีเมลและรหัสผ่าน')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
      final user = cred.user!;

      // ถ้า verified แล้ว AuthGate จะพาไปหน้าถัดไปเอง
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'เข้าสู่ระบบไม่สำเร็จ')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  // ==========================================

  // สี/สไตล์ตามแบบตัวอย่าง
  static const _orangeDark = Color(0xFFFF6A00);
  static const _orangeLight = Color(0xFFFFB34D);
  static const _hintGrey = Color(0xFF9AA0A6);

  InputDecoration _input({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      floatingLabelStyle: const TextStyle(
        color: _orangeDark,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: _hintGrey),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _orangeDark, width: 1.2),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // พื้นหลังไล่สี
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_orangeDark, _orangeLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),

            // โครงหน้า
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 44),

                  const Text(
                    'Smart Transit\nFor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const SizedBox(height: 95, child: _KmitlLogoOrFallback()),
                  const SizedBox(height: 24),

                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(80)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: size.height * 0.56),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Log in',
                                style: TextStyle(
                                  fontSize: 50,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 22),

                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: _input(
                                  label: 'อีเมลมหาวิทยาลัย',
                                  hint: 'username@kmitl.ac.th',
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextField(
                                controller: _pass,
                                obscureText: true,
                                onSubmitted: (_) => _login(),
                                textInputAction: TextInputAction.done,
                                decoration: _input(
                                  label: 'Password',
                                  hint: 'password',
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ปุ่ม Login (ขอบส้ม)
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: _busy ? null : _login,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: _orangeDark, width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                  child: _busy
                                      ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                      : const Text(
                                    'Login',
                                    style: TextStyle(
                                      color: _orangeDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ปุ่ม Register (ส้มทึบ)
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _orangeDark,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                  child: const Text(
                                    'Register',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // ปุ่ม Forgot
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordScreen(),
                                  ),
                                ),
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(color: _orangeDark),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// โลโก้ KMITL: แสดงรูป assets/kmitl.png ถ้ามี, ไม่มีก็ข้อความ fallback
class _KmitlLogoOrFallback extends StatelessWidget {
  const _KmitlLogoOrFallback();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _assetExists(context, 'assets/kmitl.png'),
      builder: (context, snap) {
        if (snap.data == true) {
          return Image.asset('assets/kmitl.png', fit: BoxFit.contain);
        }
        return const Center(
          child: Text(
            'KMITL\nPRINCE OF CHUMPHON',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
              letterSpacing: 1.2,
            ),
          ),
        );
      },
    );
  }

  static Future<bool> _assetExists(BuildContext context, String path) async {
    try {
      await DefaultAssetBundle.of(context).load(path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
