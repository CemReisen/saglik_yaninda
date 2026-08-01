import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // 🔥 TÜRKÇE HATA ÇEVİRMENİ
  String _getTurkishErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu e-posta adresine ait bir hesap bulunamadı.';
      case 'invalid-email':
        return 'Lütfen geçerli bir e-posta adresi giriniz.';
      default:
        return 'Sıfırlama bağlantısı gönderilemedi. Lütfen tekrar deneyin.';
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen kayıtlı e-posta adresinizi girin."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Şifre sıfırlama bağlantısı başarıyla gönderildi! ✅"),
          backgroundColor: Color(0xFF4DB6AC),
        ),
      );

      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getTurkishErrorMessage(e.code)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color mainGreen = Color(0xFF4DB6AC);
    const Color lightGray = Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: mainGreen),
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    Icons.lock_reset_rounded,
                    size: 70,
                    color: mainGreen,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Şifremi Unuttum",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: mainGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "E-posta adresinizi girin, size hemen güvenli bir sıfırlama bağlantısı gönderelim.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: lightGray,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _emailController,
                    style: GoogleFonts.poppins(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: "Kayıtlı E-posta Adresiniz",
                      labelStyle: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.mark_email_read_outlined,
                        color: mainGreen,
                        size: 22,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainGreen,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            "BAĞLANTIYI GÖNDER",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
