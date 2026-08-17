import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:saglik_yaninda/core/app_navigator_key.dart';
import 'package:saglik_yaninda/services/connection_code_service.dart';

// Google'ın standart çok renkli "G" logosu — asset dosyası eklemeden ya da ağ
// isteği atmadan (favicon vb.) doğrudan gömülü SVG olarak render ediliyor.
const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#FFC107" d="M43.611,20.083H42V20H24v8h11.303c-1.649,4.657-6.08,8-11.303,8c-6.627,0-12-5.373-12-12
    c0-6.627,5.373-12,12-12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C12.955,4,4,12.955,4,24
    c0,11.045,8.955,20,20,20c11.045,0,20-8.955,20-20C44,22.659,43.862,21.35,43.611,20.083z"/>
  <path fill="#FF3D00" d="M6.306,14.691l6.571,4.819C14.655,15.108,18.961,12,24,12c3.059,0,5.842,1.154,7.961,3.039
    l5.657-5.657C34.046,6.053,29.268,4,24,4C16.318,4,9.656,8.337,6.306,14.691z"/>
  <path fill="#4CAF50" d="M24,44c5.166,0,9.86-1.977,13.409-5.192l-6.19-5.238C29.211,35.091,26.715,36,24,36
    c-5.202,0-9.619-3.317-11.283-7.946l-6.522,5.025C9.505,39.556,16.227,44,24,44z"/>
  <path fill="#1976D2" d="M43.611,20.083H42V20H24v8h11.303c-0.792,2.237-2.231,4.166-4.087,5.571
    c0.001-0.001,0.002-0.001,0.003-0.002l6.19,5.238C36.971,39.205,44,34,44,24C44,22.659,43.862,21.35,43.611,20.083z"/>
</svg>
''';

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
  bool _isGoogleLoading = false;
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
        // .update() değil .set(merge:true) - Google akışında bu fonksiyon
        // doküman henüz oluşmamışken de çağrılabilir (bkz. _signInWithGoogle
        // içindeki NOT_FOUND bug raporu), .update() bu durumda istisna
        // fırlatırdı.
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
        print("✅ FCM Token veritabanına kaydedildi.");
      }
    } catch (e) {
      print("⚠️ FCM Token alınamadı: $e");
    }
  }

  // Google ile ilk kez giriş yapan bir kullanıcı için rol soruyor (register
  // akışında olduğu gibi elder/caregiver seçimi) - Google girişi ikisinden de
  // gelebileceği için register_page.dart'taki gibi bir varsayım yapılamıyor.
  // barrierDismissible: false - rol seçilmeden dialog kapatılamaz, aksi halde
  // Firestore'a role'süz bir doküman yazılırdı.
  //
  // ÖNEMLİ: context yerine rootNavigatorKey.currentState!.context kullanılıyor.
  // signInWithCredential() döndüğü anda main.dart'taki authStateChanges
  // StreamBuilder'ı home: widget'ını değiştirip LoginPage'i dispose ediyor -
  // bu noktadan sonra LoginPage'in kendi context'i "deactivated widget"
  // hatası verir (bkz. app_navigator_key.dart'taki açıklama). MaterialApp
  // dispose olmadığı için ona bağlı bu context her zaman geçerli kalıyor.
  Future<String?> _askRoleForNewGoogleUser() {
    const Color mainGreen = Color(0xFF4DB6AC);
    final dialogContext = rootNavigatorKey.currentState?.context ?? context;
    return showDialog<String>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Hesap Türünüzü Seçin",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          "Google hesabınızla ilk kez giriş yapıyorsunuz. Devam etmek için hesap türünüzü seçin.",
          style: GoogleFonts.poppins(fontSize: 15),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, "elder"),
            child: Text(
              "Kendi İlacım",
              style: GoogleFonts.poppins(
                color: mainGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, "caregiver"),
            child: Text(
              "Yakınımın İlacı",
              style: GoogleFonts.poppins(
                color: mainGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();
      final String? idToken = googleUser.authentication.idToken;

      if (idToken == null) {
        // FirebaseAuthException fırlatmıyoruz: 'invalid-credential' kodu
        // _getTurkishErrorMessage'da e-posta/şifre hatası olarak eşleniyor,
        // burada yanıltıcı olurdu - generic catch bloğuna düşsün.
        throw Exception('Google kimlik doğrulama bilgisi (idToken) alınamadı.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('beni_hatirla', true);

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final userDoc = await userRef.get();

      // Firebase'in signInWithCredential sonrası döndürdüğü User.displayName,
      // yalnızca idToken geçirilen credential'larda güvenilir şekilde
      // dolmuyor (gözlemlendi: yeni oluşan hesapta null kalabiliyor).
      // googleUser.displayName paketten doğrudan geliyor, kaynağı daha
      // güvenilir - önce onu deniyoruz, sadece o da null ise Firebase'e
      // düşüyoruz.
      final String googleDisplayName =
          googleUser.displayName ?? user.displayName ?? '';

      String role;
      if (!userDoc.exists) {
        final selectedRole = await _askRoleForNewGoogleUser();
        if (selectedRole == null) {
          // barrierDismissible: false olduğu için normalde buraya düşmez,
          // yine de defensive: yarım kalmış bir oturum bırakmamak için çık.
          await _auth.signOut();
          return;
        }
        role = selectedRole;
        await userRef.set({
          'uid': user.uid,
          'name': googleDisplayName,
          'email': googleUser.email,
          'role': role,
          'connectionCode': ConnectionCodeService.generate(),
          'authProvider': 'google',
          'createdAt': FieldValue.serverTimestamp(),
          // Onboarding turu bayrakları - yeni hesap, üçü de henüz görülmedi
          // (bkz. lib/services/onboarding_service.dart). Caregiver turları
          // henüz uygulanmadı ama elder alanlarını her rolde yazmak zararsız
          // - hiç okunmayan bir hesapta sadece kullanılmadan duruyor.
          'onboardingHomeCompleted': false,
          'onboardingAddCompleted': false,
          'onboardingProfileCompleted': false,
        });
      } else {
        final data = userDoc.data() as Map<String, dynamic>;
        role = data['role'] ?? 'elder';

        // Var olan dokümanda connectionCode/name/authProvider eksikse
        // (ör. daha önceki bir kayıt bu alanları hiç yazmadan oluşmuşsa)
        // burada tamamlıyoruz - connectionCode artık Hızlı Başla'da kurtarma
        // kodu olarak da kullanılacağı için HER authProvider'da dolu olması
        // gereken bir alan, "sadece register akışında yazılır" varsayımına
        // güvenilemez.
        final Map<String, dynamic> backfill = {};
        if ((data['connectionCode'] as String?)?.isEmpty ?? true) {
          backfill['connectionCode'] = ConnectionCodeService.generate();
        }
        if (((data['name'] as String?)?.isEmpty ?? true) &&
            googleDisplayName.isNotEmpty) {
          backfill['name'] = googleDisplayName;
        }
        if (data['authProvider'] == null) {
          backfill['authProvider'] = 'google';
        }
        if (backfill.isNotEmpty) {
          // .update() değil .set(merge:true) - userDoc.exists true olsa bile
          // (ör. Firestore'un local cache'i güncel olmayan bir snapshot
          // döndürmüşse, ya da bu arada başka bir yerden silinmişse) doküman
          // sunucuda gerçekten yoksa .update() NOT_FOUND ile patlıyordu -
          // gerçek cihazda gözlemlendi (bkz. HESAPTAN ÇIKIŞ bug'ıyla aynı
          // kategori, profile_page.dart -> _buildLogoutButton). set(merge)
          // doküman varsa sadece bu alanları günceller, yoksa oluşturur -
          // ikisinde de güvenli.
          await userRef.set(backfill, SetOptions(merge: true));
        }
      }

      await _saveDeviceToken(user.uid);

      // Navigator.pushReplacementNamed(context, ...) YERİNE rootNavigatorKey
      // kullanılıyor - aynı gerekçe: bu noktada LoginPage artık mounted
      // olmayabilir (yukarıdaki not). Bu çağrı salt "güzel olsun" değil,
      // gerçekten gerekli: main.dart'taki kök StreamBuilder, auth state
      // değiştiği anda Firestore'u BİR KEZ okuyup (rol dokümanı henüz
      // yazılmamışken) varsayılan "elder" ile MainLayout'u göstermiş olabilir;
      // caregiver seçen bir kullanıcı için bunu burada düzeltmemiz gerekiyor -
      // kök StreamBuilder yeni bir auth event'i olmadan kendiliğinden
      // yeniden kontrol etmiyor.
      final navState = rootNavigatorKey.currentState;
      if (navState != null) {
        if (role == 'caregiver') {
          navState.pushReplacementNamed('/caregiver_home');
        } else {
          navState.pushReplacementNamed('/home');
        }
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return; // Kullanıcı hesap seçiciyi kapattı, sessizce geç.
      }
      debugPrint("⚠️ Google ile giriş başarısız: ${e.code} ${e.description}");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Google ile giriş yapılamadı: ${e.description ?? e.code}",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        "⚠️ Google ile girişte FirebaseAuthException: ${e.code} ${e.message}",
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getTurkishErrorMessage(e.code)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      // Önceden bu blok, LoginPage dispose olmuşsa (bkz. yukarıdaki
      // rootNavigatorKey notu) `if (!mounted) return;` ile HİÇBİR iz
      // bırakmadan çıkıyordu - gerçek hata (ör. showDialog'un "deactivated
      // widget" hatası ya da bir Firestore izin hatası) tamamen kayboluyordu.
      // debugPrint artık mounted durumundan bağımsız, her zaman çalışıyor.
      debugPrint("⚠️ Google ile girişte beklenmeyen hata: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Google ile giriş sırasında bir hata oluştu."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
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

                // Hızlı Başla — BİRİNCİL yöntem: yaşlı kullanıcı hedef
                // kitlesi için e-posta/Google'dan önce geliyor (bkz.
                // PRODUCT_NOTES_AUTH_UPDATE.md). Ayrı bir route olarak push
                // ediliyor (bkz. quick_start_page.dart'taki not) - Google
                // akışındaki context/dispose riskine burada gerek yok.
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/quick_start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainGreen,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      "HIZLI BAŞLA",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Sadece adınızı yazarak hemen başlayın",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/recovery_code'),
                  child: Text(
                    "Kodum var",
                    style: GoogleFonts.poppins(
                      color: mainGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // "Hesabınız yok mu? Kayıt Olun" - eskiden sayfanın en
                // altındaydı (Google butonunun altında), kaydırmadan
                // görünmüyordu. E-posta ile kayıt olan caregiver akışının
                // görünürlüğünü artırmak için buraya, "Kodum var"ın hemen
                // altına taşındı - davranış (register_page.dart'a yönlendirme)
                // değişmedi, sadece konumu.
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

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "veya",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 24),

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

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "veya",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isGoogleLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.string(
                                _googleLogoSvg,
                                width: 22,
                                height: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Google ile Giriş Yap",
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
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
