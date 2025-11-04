// lib/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isKmitl(String email) =>
      email.trim().toLowerCase().endsWith('@kmitl.ac.th');

  Future<void> resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _show('กรุณากรอกอีเมล');
      return;
    }
    if (!_isKmitl(email)) {
      _show('ใช้ได้เฉพาะอีเมลมหาวิทยาลัย (@kmitl.ac.th)');
      return;
    }
    if (_loading) return;

    setState(() => _loading = true);
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _show('ส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมลแล้ว');
      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _show(e.message ?? 'ส่งลิงก์ไม่สำเร็จ');
    } catch (e) {
      _show('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // 🎨 ใช้สี/สไตล์เดียวกับหน้า Login/Register
    const orangeDark = Color(0xFFFF6A00);
    const orangeLight = Color(0xFFFFB34D);
    const hintGrey = Color(0xFF9AA0A6);

    InputDecoration inputLabel({required String label, String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelStyle: const TextStyle(
          color: orangeDark,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: hintGrey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: orangeDark, width: 1.2),
        ),
      );
    }

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // พื้นหลังไล่เฉด: ส้มเข้มขวาบน -> ส้มอ่อนซ้ายล่าง
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [orangeDark, orangeLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ปุ่มย้อนกลับมุมบนซ้าย
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // หัวเรื่องด้านบน
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
                  const SizedBox(height: 16),

                  // โลโก้ (ใช้ asset ถ้ามี)
                  const SizedBox(height: 90, child: _KmitlLogoOrFallback()),
                  const SizedBox(height: 50),

                  // การ์ดสีขาวมุมโค้ง ปิดเต็มด้านล่าง
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
                                'Forgot\nPassword',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 48,
                                  height: 1.05,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 45),

                              // ช่องกรอกอีเมล (floating label)
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => resetPassword(),
                                decoration: inputLabel(
                                  label: 'อีเมลมหาวิทยาลัย',
                                  hint: 'กรุณากรอกอีเมลมหาวิทยาลัยของคุณ',
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ปุ่ม Accept (ส้มทึบ)
                              SizedBox(
                                width: 200,
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : resetPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: orangeDark,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                      : const Text(
                                    'Accept',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),
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

/// โลโก้ KMITL ถ้ามี assets/kmitl.png; หากไม่มีก็ fallback เป็นข้อความ
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
