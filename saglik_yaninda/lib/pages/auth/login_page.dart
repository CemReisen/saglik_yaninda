import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = true;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🔥 TÜRKÇE HATA ÇEVİRMENİ
  String _getTurkishErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu e-posta adresine ait bir hesap bulunamadı.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta adresiniz veya şifreniz hatalı.';
      case 'invalid-email':
        return 'Lütfen geçerli bir e-posta adresi giriniz.';
      case 'user-disabled':
        return 'Bu hesap yöneticiler tarafından engellenmiş.';
      case 'too-many-requests':
        return 'Üst üste çok fazla hatalı giriş yaptınız. Lütfen biraz bekleyip tekrar deneyin.';
      default:
        return 'Giriş yapılamadı. Lütfen bilgilerinizi kontrol edin.';
    }
  }

  Future<void> _saveDeviceToken(String userId) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();

      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {'fcmToken': token},
        );
        print("✅ FCM Token veritabanına kaydedildi.");
      }
    } catch (e) {
      print("⚠️ FCM Token alınamadı: $e");
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen e-posta ve şifrenizi girin."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('beni_hatirla', _rememberMe);

      await _saveDeviceToken(userCredential.user!.uid);

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      String role = "elder";
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        role = data['role'] ?? "elder";
      }

      if (!mounted) return;

      if (role == "caregiver") {
        Navigator.pushReplacementNamed(context, '/caregiver_home');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getTurkishErrorMessage(e.code)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color mainGreen = Color(0xFF4DB6AC);
    const Color lightGray = Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 🔥 YENİ EKLENEN TEMA İKONU
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: mainGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    size: 70,
                    color: mainGreen,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Sağlık Yanında",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: mainGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Sağlığınızı güvenle takip edin",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),

                _buildCard(
                  label: "E-posta",
                  icon: Icons.email_outlined,
                  controller: _emailController,
                  lightGray: lightGray,
                ),

                _buildCard(
                  label: "Şifre",
                  icon: Icons.lock_outline_rounded,
                  controller: _passwordController,
                  lightGray: lightGray,
                  isPassword: true,
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: mainGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _rememberMe = val!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Beni Hatırla",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/forgot_password'),
                      child: Text(
                        "Şifremi unuttum",
                        style: GoogleFonts.poppins(
                          color: mainGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainGreen,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            "GİRİŞ YAP",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Hesabınız yok mu? ",
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text(
                        "Kayıt Olun",
                        style: GoogleFonts.poppins(
                          color: mainGreen,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _buildCard({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required Color lightGray,
    bool isPassword = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: lightGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? !_passwordVisible : false,
        style: GoogleFonts.poppins(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: Colors.grey[500],
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF4DB6AC), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }
}
