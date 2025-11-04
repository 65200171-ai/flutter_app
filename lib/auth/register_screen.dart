// lib/auth/register_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _studentId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _auth = FirebaseAuth.instance;
  bool _loading = false;

  static const orangeDark = Color(0xFFFF6A00);
  static const orangeLight = Color(0xFFFFB34D);
  static const hintGrey = Color(0xFF9AA0A6);

  @override
  void dispose() {
    _fullName.dispose();
    _studentId.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _isKmitlEmail(String email) =>
      email.trim().toLowerCase().endsWith('@kmitl.ac.th');

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _input({required String label, String? hint}) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  Future<void> _register() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    final name = _fullName.text.trim();
    final sid = _studentId.text.trim();
    final email = _email.text.trim();
    final pass = _password.text;

    setState(() => _loading = true);
    try {
      // 1) สมัครผู้ใช้ด้วยอีเมล/รหัสผ่าน
      final cred = await _auth
          .createUserWithEmailAndPassword(email: email, password: pass)
          .timeout(const Duration(seconds: 20));

      final user = cred.user!;

      // 2) บันทึกโปรไฟล์พื้นฐาน
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': email,
        'displayName': name,
        'studentId': sid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3) ส่งลิงก์ยืนยันอีเมล (Firebase ส่งให้)
      unawaited(user.sendEmailVerification());

      // 4) ไปหน้า "Verify Email"
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
            (route) => false,
      );
      _toast('ส่งลิงก์ยืนยันไปที่อีเมลแล้ว (อาจอยู่ในสแปม)');
    } on TimeoutException {
      _toast('เครือข่ายช้า/ไม่เสถียร ลองใหม่อีกครั้ง');
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _toast('อีเมลนี้มีบัญชีอยู่แล้ว');
          break;
        case 'invalid-email':
          _toast('รูปแบบอีเมลไม่ถูกต้อง');
          break;
        case 'weak-password':
          _toast('รหัสผ่านอย่างน้อย 6 ตัว');
          break;
        case 'network-request-failed':
          _toast('เครือข่ายล้มเหลว ตรวจสอบอินเทอร์เน็ต');
          break;
        default:
          _toast(e.message ?? 'สมัครไม่สำเร็จ');
      }
    } catch (e) {
      _toast('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    bool canSubmit() {
      return _fullName.text.trim().isNotEmpty &&
          _studentId.text.trim().isNotEmpty &&
          _email.text.isNotEmpty &&
          _password.text.isNotEmpty &&
          _confirm.text.isNotEmpty &&
          _password.text == _confirm.text &&
          _isKmitlEmail(_email.text) &&
          !_loading;
    }

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
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
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'กลับไปหน้า Login',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Smart Transit\nFor',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(height: 95, child: _KmitlLogo()),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(minHeight: size.height * 0.70),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(80),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                        child: Form(
                          key: _formKey,
                          onChanged: () => setState(() {}),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Register',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 50,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 22),
                              TextFormField(
                                controller: _fullName,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                decoration: _input(
                                  label: 'ชื่อ - นามสกุล',
                                  hint: 'ชื่อ - นามสกุล',
                                ),
                                validator: (v) {
                                  final val = (v ?? '').trim();
                                  if (val.isEmpty) return 'กรอกชื่อ-นามสกุล';
                                  if (val.length < 2) return 'ชื่อสั้นเกินไป';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _studentId,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(12),
                                ],
                                decoration: _input(
                                  label: 'รหัสนักศึกษา',
                                  hint: 'รหัสนักศึกษา',
                                ),
                                validator: (v) {
                                  final val = (v ?? '').trim();
                                  if (val.isEmpty) return 'กรอกรหัสนักศึกษา';
                                  if (val.length < 8) {
                                    return 'รหัสนักศึกษายาวอย่างน้อย 8 หลัก';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                                ],
                                decoration: _input(
                                  label: 'อีเมลมหาวิทยาลัย',
                                  hint: 'example@kmitl.ac.th',
                                ),
                                validator: (v) {
                                  final val = (v ?? '').trim();
                                  if (val.isEmpty) return 'กรอกอีเมล';
                                  if (!_isKmitlEmail(val)) {
                                    return 'อนุญาตเฉพาะอีเมล @kmitl.ac.th';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _password,
                                obscureText: true,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.newPassword],
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                                ],
                                decoration: _input(label: 'Password', hint: 'Password'),
                                validator: (v) {
                                  final val = v ?? '';
                                  if (val.isEmpty) return 'กรอกรหัสผ่าน';
                                  if (val.length < 6) return 'รหัสผ่านอย่างน้อย 6 ตัว';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirm,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                                ],
                                decoration: _input(
                                  label: 'Confirm password',
                                  hint: 'Confirm password',
                                ),
                                validator: (v) {
                                  final val = v ?? '';
                                  if (val.isEmpty) return 'ยืนยันรหัสผ่าน';
                                  if (val != _password.text) return 'รหัสผ่านไม่ตรงกัน';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: canSubmit() ? _register : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: orangeDark,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                      : const Text(
                                    'Register',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'หมายเหตุ: ระบบอนุญาตเฉพาะอีเมล @kmitl.ac.th และต้องกดลิงก์ยืนยันจากอีเมลก่อนใช้งาน',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KmitlLogo extends StatelessWidget {
  const _KmitlLogo();
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
