import 'package:cloud_firestore/cloud_firestore.dart';

/// Onboarding turlarının tamamlanma bayrakları.
///
/// **Hesap bazlı** (cihaz bazlı DEĞİL) — `users/{uid}` dokümanında düz
/// boolean alanlar olarak tutuluyor, `connectionCode`/`role`/`authProvider`
/// ile aynı desen. Aynı hesap farklı bir cihazda (ör. kurtarma koduyla)
/// açılsa bile tur durumu korunur.
///
/// Ekranlar arası mini-turlar bilinçli bir tasarım kararı (bkz.
/// PRODUCT_NOTES.md → "3. Onboarding") — Home/Ekle/Profil ayrı sekmelerde
/// yaşadığı ve her biri kendi ilk-girişinde tetiklendiği için tek bir
/// "onboardingCompleted" yerine üç ayrı bayrak var.
///
/// Alan Firestore'da hiç yoksa (mevcut/eski hesaplar dahil) **false** kabul
/// edilir — bilinçli karar: bu özellik öncesi açılmış hesaplar da turu bir
/// kereliğine görür (auth sistemindeki "alan yoksa X kabul et" dersiyle aynı
/// yaklaşım, bkz. CLAUDE.md → "Auth Sistemi Yenilendi").
class OnboardingFlags {
  OnboardingFlags._();

  static const String home = 'onboardingHomeCompleted';
  static const String add = 'onboardingAddCompleted';
  static const String profile = 'onboardingProfileCompleted';

  /// Zaten elde bulunan bir user doküman map'inden (ör. bir StreamBuilder'ın
  /// snapshot'ından) okuma yapar — ekstra bir Firestore sorgusu gerekmez.
  static bool isCompletedFromData(Map<String, dynamic>? data, String field) {
    return (data?[field] as bool?) ?? false;
  }

  /// Elde hazır bir user doküman map'i yoksa (ör. add_medicine_page.dart gibi
  /// user dokümanını hiç dinlemeyen sayfalarda) tek seferlik bir okuma yapar.
  static Future<bool> isCompleted(String uid, String field) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return isCompletedFromData(snap.data(), field);
  }

  static Future<void> markCompleted(String uid, String field) {
    return FirebaseFirestore.instance.collection('users').doc(uid).set({
      field: true,
    }, SetOptions(merge: true));
  }
}
