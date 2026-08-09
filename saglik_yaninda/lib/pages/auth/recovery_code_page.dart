import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:saglik_yaninda/core/theme/app_colors.dart';

/// "Kodum var" — Hızlı Başla ile açılmış bir hesabı, kurtarma kodu
/// (bkz. quick_start_page.dart, ConnectionCodeService) girerek yeni bir
/// cihazda/kurulumda geri getirme akışı.
///
/// Kod, functions/index.js -> recoverWithCode callable'ına gönderiliyor;
/// dönen customToken ile signInWithCustomToken() çağrılıp AYNI hesaba (aynı
/// uid, aynı ilaç geçmişi, aynı caregiver bağlantısı) geri dönülüyor.
///
/// login_page.dart'tan Navigator.pushNamed ile (push, replace DEĞİL)
/// açılıyor — main.dart'taki kök authStateChanges StreamBuilder'ı sadece
/// "/" (home) route'unun İÇERİĞİNİ değiştiriyor, bu sayfa AYRI bir route
/// olarak stack'te üstte kaldığı için Google girişindeki context/dispose
/// yarışına (bkz. app_navigator_key.dart) burada da gerek yok — tıpkı
/// quick_start_page.dart'ta olduğu gibi, kendi context'i
/// signInWithCustomToken() sırasında dispose olmuyor.
class RecoveryCodePage extends StatefulWidget {
  const RecoveryCodePage({super.key});

  @override
  State<RecoveryCodePage> createState() => _RecoveryCodePageState();
}

class _RecoveryCodePageState extends State<RecoveryCodePage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen kurtarma kodunuzu girin."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'recoverWithCode',
      );
      final result = await callable.call(<String, dynamic>{'code': code});
      final data = Map<String, dynamic>.from(result.data as Map);
      final customToken = data['customToken'] as String;

      await FirebaseAuth.instance.signInWithCustomToken(customToken);

      if (!mounted) return;
      // recoverWithCode sadece authProvider == "anonymous" hesapları
      // hedefliyor, bu projede anonim hesaplar her zaman role: "elder" ile
      // açılıyor (quick_start_page.dart) - caregiver'a yönlendirme
      // ihtimali yok, bu yüzden doğrudan /home.
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseFunctionsException catch (e) {
      // Backend'in döndürdüğü mesaj (Türkçe, zaten kullanıcıya gösterilebilir
      // ve kasıtlı olarak genel/ayrıştırılamaz - bkz. functions/index.js
      // -> recoverWithCode) doğrudan gösteriliyor, ayrıca bir eşleme
      // yapmıyoruz.
      debugPrint("⚠️ recoverWithCode başarısız: ${e.code} ${e.message}");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? "Kod doğrulanamadı. Lütfen tekrar deneyin.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      debugPrint("⚠️ Kurtarma girişinde beklenmeyen hata: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bir sorun oluştu, lütfen tekrar deneyin."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Kodum Var")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.key_rounded,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Kurtarma Kodunuzu Girin",
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  "Hızlı Başla ile açtığınız hesabınıza ait kodu girerek geri dönebilirsiniz.",
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryStrong,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: "Kod (ör. 6J8-DOS)",
                      labelStyle: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryStrong,
                      ),
                      prefixIcon: const Icon(
                        Icons.pin_outlined,
                        color: AppColors.primary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                            "DOĞRULA",
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              letterSpacing: 1,
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
