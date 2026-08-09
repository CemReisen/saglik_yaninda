import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:saglik_yaninda/core/theme/app_colors.dart';
import 'package:saglik_yaninda/services/connection_code_service.dart';

/// "Hızlı Başla" — email/şifre ya da Google hesabı bilmeyen/hatırlamayan
/// yaşlı kullanıcılar için: sadece isim-soyisim sorup arka planda
/// signInAnonymously() ile bir hesap açar. Aynı zamanda üretilen "Aile
/// Bağlantı Kodu" (bkz. ConnectionCodeService) bu hesap için kurtarma kodu
/// olarak da işlev görür — telefon değişirse bu kodla hesaba geri dönülebilir
/// (bkz. PRODUCT_NOTES_AUTH_UPDATE.md, ADIM 4'te recoverWithCode ile).
///
/// login_page.dart'tan Navigator.pushNamed ile (push, replace DEĞİL)
/// açılıyor — main.dart'taki kök authStateChanges StreamBuilder'ı sadece
/// "/" (home) route'unun İÇERİĞİNİ değiştiriyor, bu sayfa AYRI bir route
/// olarak stack'te üstte kaldığı için Google girişindeki context/dispose
/// yarışına (bkz. app_navigator_key.dart) burada gerek yok — bu sayfanın
/// kendi context'i signInAnonymously() sırasında dispose olmuyor.
class QuickStartPage extends StatefulWidget {
  const QuickStartPage({super.key});

  @override
  State<QuickStartPage> createState() => _QuickStartPageState();
}

class _QuickStartPageState extends State<QuickStartPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  String? _connectionCode; // null: isim formu, dolu: "kodu kaydedin" ekranı

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen adınızı ve soyadınızı yazın."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      final uid = userCredential.user!.uid;
      final code = ConnectionCodeService.generate();

      // register_page.dart/login_page.dart'ta olduğu gibi fcmToken'ı da
      // doğrudan burada yazıyoruz - main.dart'taki authStateChanges
      // dinleyicisi (_syncFcmToken) doküman henüz yokken tetiklenip
      // `!snap.exists` nedeniyle atlayabiliyor, bir sonraki uygulama
      // açılışına kadar (yeni bir auth event'i gelene dek) kendini
      // düzeltmiyor - aradaki süre boyunca caregiver'dan gelecek dürtme/
      // bağlantı bildirimleri bu kullanıcıya ulaşmazdı.
      final fcmToken = await FirebaseMessaging.instance.getToken();

      // set(merge:true) - bu turun dersi: uid burada her zaman taze/yeni
      // olsa da (signInAnonymously her zaman yeni bir hesap açar), aynı
      // deseni tutarlı uygulamak (.update() değil) ek bir maliyeti yok ve
      // ileride bu kod başka bir yerden yeniden kullanılırsa güvenli kalır.
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': '',
        'role': 'elder',
        'connectionCode': code,
        'authProvider': 'anonymous',
        if (fcmToken != null) 'fcmToken': fcmToken,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _connectionCode = code;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("⚠️ Hızlı Başla girişi başarısız: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bir sorun oluştu, lütfen tekrar deneyin."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _goToApp() {
    if (!mounted) return;
    // role her zaman "elder" (Hızlı Başla'da rol seçimi yok) - kök
    // StreamBuilder da doküman yazıldıktan sonra aynı sonuca varır, ama
    // Google akışındaki dersle tutarlı olmak için burada da açıkça
    // yönlendiriyoruz.
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Hızlı Başla")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: _connectionCode == null
                ? _buildForm(textTheme)
                : _buildCodeCard(textTheme),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.rocket_launch_rounded,
            size: 56,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Adınızı ve soyadınızı yazın",
          textAlign: TextAlign.center,
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          "E-posta ya da şifre gerekmez — hemen başlayabilirsiniz.",
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
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: textTheme.bodyLarge,
            decoration: InputDecoration(
              labelText: "Ad Soyad",
              labelStyle: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryStrong,
              ),
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
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
            onPressed: _isLoading ? null : _continue,
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
                    "DEVAM ET",
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeCard(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0x1A4CAF50), // AppColors.positive %10 opak
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 56,
            color: AppColors.positive,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Hesabınız hazır!",
          textAlign: TextAlign.center,
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Bu kodu bir yere yazın veya yakınınıza söyleyin — telefonunuzu değiştirirseniz bu kodla hesabınıza geri dönebilirsiniz.",
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _connectionCode!,
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 26,
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _connectionCode!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Kod panoya kopyalandı."),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      tooltip: "Kodu Kopyala",
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _goToApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              "ANLADIM, DEVAM ET",
              style: textTheme.titleMedium?.copyWith(
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
