// lib/auth/verify_email_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sending = false, _checking = false;

  // สีและสไตล์ให้เหมือนกับเพจตัวอย่าง
  static const orangeDark = Color(0xFFFF6A00);
  static const orangeLight = Color(0xFFFFB34D);
  static const hintGrey = Color(0xFF9AA0A6);

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // === logic เดิม: ส่งลิงก์ยืนยันอีเมลอีกครั้ง
  Future<void> _resend() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    setState(() => _sending = true);
    try {
      await u.sendEmailVerification();
      _toast('ส่งลิงก์ยืนยันอีกครั้งแล้ว');
    } catch (e) {
      _toast('ส่งลิงก์ไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // === logic เดิม: รีโหลดแล้วเช็ค emailVerified -> ถ้าใช่พากลับหน้าแรก (AuthGate)
  Future<void> _refresh() async {
    final auth = FirebaseAuth.instance;
    setState(() => _checking = true);
    await auth.currentUser?.reload();
    if (auth.currentUser?.emailVerified == true) {
      if (!mounted) return;
      _toast('ยืนยันอีเมลเรียบร้อย');
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } else {
      _toast('ยังไม่พบการยืนยันอีเมล');
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      body: Stack(
        children: [
          // พื้นหลังไล่สี
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
                // ปุ่มย้อนกลับ -> ออกจากระบบแล้วกลับหน้า AuthGate
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/', (route) => false);
                    },
                  ),
                ),

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
                const SizedBox(height: 90, child: _KmitlLogoOrFallback()),
                const SizedBox(height: 16),

                // แผงขาวมุมโค้ง
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(80),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: size.height * 0.56,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Verify\nEmail',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 48,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 14),

                            if (email.isNotEmpty)
                              Text(
                                email,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: hintGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 18),

                            const Text(
                              'กรุณายืนยันอีเมลก่อนเข้าใช้งานระบบ\n'
                                  'ตรวจสอบอีเมลของคุณแล้วคลิกลิงก์ที่ได้รับ\n'
                                  'หมายเหตุ: อีเมลอาจอยู่ในจดหมายขยะ (Spam)',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                            const SizedBox(height: 26),

                            // ปุ่มส้มทึบ: ส่งลิงก์อีกครั้ง
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _sending ? null : _resend,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: orangeDark,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                                child: _sending
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                    : const Text(
                                  'ส่งลิงก์ยืนยันอีกครั้ง',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ปุ่มขอบส้ม: ฉันยืนยันแล้ว (รีเฟรช)
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton(
                                onPressed: _checking ? null : _refresh,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: orangeDark, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                                child: _checking
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : const Text(
                                  'ฉันยืนยันแล้ว (รีเฟรช)',
                                  style: TextStyle(
                                    color: orangeDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ปุ่มออกจากระบบ (เหมือนหน้าดั้งเดิม)
                            TextButton(
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                if (!mounted) return;
                                Navigator.of(context)
                                    .pushNamedAndRemoveUntil('/', (r) => false);
                              },
                              child: const Text('ออกจากระบบ'),
                            ),
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
    );
  }
}

/// โลโก้ KMITL ถ้ามี assets/kmitl.png; ถ้าไม่มีก็แสดงข้อความสำรอง
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
