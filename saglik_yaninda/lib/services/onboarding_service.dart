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
/// "onboardingCompleted" yerine ayrı bayraklar var.
///
/// Home özelinde **iki** ayrı bayrak var (homeIntro/homeMeds), tek bir
/// "home" değil — Home turu artık 7 adımlı, iki "dalga" halinde:
///
/// - **Dalga 1 (`homeIntro`):** SOS, Yardım Al, İlaç listesi genel alanı,
///   zaman dilimi filtreleri, alt navbar. Bu 5 adımın hedefi HER ZAMAN
///   mevcut (statik widget'lar ya da her zaman render edilen konteynerler —
///   ilaç sayısı 0 olsa bile) - skip riski yok, tek bir bayrakla takip
///   edilebilir. Bayrak, dalganın SON adımı (navbar) tamamlandığında yazılır.
/// - **Dalga 2 (`homeMeds`):** Tekil ilaç kartı + İçtim butonu. İkisinin de
///   hedefi bugünün ilk alınmamış ilacı — yeni bir elder hesabında genelde
///   henüz yok, bu yüzden ilk Home ziyaretinde `skipIfTargetNotPresent` ile
///   sessizce atlanıyor. Tek bir bayrakla takip etseydik, bu atlama "Home
///   turu tamamlandı" sayılır ve kullanıcı ileride ilk ilacını ekleyip
///   Home'a döndüğünde bu adımları asla otomatik göremezdi. Bayrak, sadece
///   gerçekten gösterilip "Anladım" ile onaylandığında yazılır (bkz.
///   home_page.dart → ShowcaseView.register'daki `onComplete`) — dalga 1
///   atlanmışsa `homeIntro` false kalmaya devam eder, dalga 2 hedefi varsa
///   bir sonraki Home ziyaretinde SADECE o dalga tekrar denenir, diğeri bir
///   daha gösterilmez.
///
/// Alan Firestore'da hiç yoksa (mevcut/eski hesaplar dahil) **false** kabul
/// edilir — bilinçli karar: bu özellik öncesi açılmış hesaplar da turu bir
/// kereliğine görür (auth sistemindeki "alan yoksa X kabul et" dersiyle aynı
/// yaklaşım, bkz. CLAUDE.md → "Auth Sistemi Yenilendi").
class OnboardingFlags {
  OnboardingFlags._();

  static const String homeIntro = 'onboardingHomeIntroCompleted';
  static const String homeMeds = 'onboardingHomeMedsCompleted';
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
