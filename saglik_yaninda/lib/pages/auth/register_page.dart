import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:math';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // 🔥 İSİM KAYDETMEK İÇİN EKSİK OLAN CONTROLLER EKLENDİ
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  String _selectedRole = "elder";

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 🔥 TÜRKÇE HATA ÇEVİRMENİ
  String _getTurkishErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'invalid-email':
        return 'Lütfen geçerli bir e-posta adresi giriniz.';
      case 'weak-password':
        return 'Şifreniz çok zayıf. Lütfen en az 6 karakterli bir şifre belirleyin.';
      default:
        return 'Kayıt işlemi başarısız oldu. Lütfen tekrar deneyin.';
    }
  }

  String _generateConnectionCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    String code = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
    return "${code.substring(0, 3)}-${code.substring(3, 6)}";
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen tüm alanları doldurun."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Girdiğiniz şifreler birbiriyle eşleşmiyor."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      String? token = await FirebaseMessaging.instance.getToken();
      String uid = userCredential.user!.uid;
      String connectionCode = _generateConnectionCode();

      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "uid": uid,
        "name": name, // 🔥 ARTIK İSİM DE VERİTABANINA GİDİYOR
        "email": email,
        "role": _selectedRole,
        "connectionCode": connectionCode,
        "fcmToken": token,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kayıt işlemi başarıyla tamamlandı! ✅"),
          backgroundColor: Color(0xFF4DB6AC),
        ),
      );

      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getTurkishErrorMessage(e.code)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color mainGreen = Color(0xFF4DB6AC);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: mainGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 60,
                    color: mainGreen,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Yeni Hesap Oluştur",
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: mainGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Sağlık takibine hemen başla",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 30),

                // 🔥 CONTROLLER EKLENDİ
                _buildCard(
                  "Ad Soyad",
                  Icons.person_outline,
                  controller: _nameController,
                ),
                _buildCard(
                  "E-posta Adresi",
                  Icons.email_outlined,
                  controller: _emailController,
                ),
                _buildCard(
                  "Şifre Belirleyin",
                  Icons.lock_outline,
                  controller: _passwordController,
                  obscure: true,
                ),
                _buildCard(
                  "Şifreyi Tekrar Girin",
                  Icons.lock_reset,
                  controller: _confirmPasswordController,
                  obscure: true,
                ),

                const SizedBox(height: 10),
                _buildRoleSelector(),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
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
                            "KAYIT OL",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Zaten hesabınız var mı? ",
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/login'),
                      child: Text(
                        "Giriş Yapın",
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

  Widget _buildCard(
    String label,
    IconData icon, {
    TextEditingController? controller,
    bool obscure = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
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
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    const Color mainGreen = Color(0xFF4DB6AC);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRole = "elder"),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedRole == "elder"
                      ? mainGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _selectedRole == "elder"
                      ? [
                          BoxShadow(
                            color: mainGreen.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    "Kendi İlacım",
                    style: GoogleFonts.poppins(
                      color: _selectedRole == "elder"
                          ? Colors.white
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRole = "caregiver"),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedRole == "caregiver"
                      ? mainGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _selectedRole == "caregiver"
                      ? [
                          BoxShadow(
                            color: mainGreen.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    "Yakınımın İlacı",
                    style: GoogleFonts.poppins(
                      color: _selectedRole == "caregiver"
                          ? Colors.white
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
