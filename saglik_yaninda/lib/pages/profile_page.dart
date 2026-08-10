import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:saglik_yaninda/core/theme/app_colors.dart';
import 'package:saglik_yaninda/services/onboarding_service.dart';
import 'package:saglik_yaninda/widgets/onboarding/onboarding_tooltip_card.dart';

// StatelessWidget'tan StatefulWidget'a çevrildi (2026-08-10, onboarding turu
// için) - bu sayfanın kendisi hiçbir alan/constructor parametresi
// kullanmıyordu, aşağıdaki tüm metodlar context/uid gibi parametreleri açıkça
// alıyordu - dönüşüm mekanik: gövde State sınıfına taşındı, hiçbir metod
// imzası değişmedi.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // --- Onboarding turu (Profil) --------------------------------------------
  // Tek adımlı, kısa bir tur: sadece "Aile Bağlantı Kodum" kartı
  // spotlight'lanıyor (bkz. araştırma raporu).
  static const String _profileTourScope = 'profile_onboarding';
  final GlobalKey _connectionCodeShowcaseKey = GlobalKey();
  late final ShowcaseView _profileTourView;
  bool _hasCheckedProfileOnboarding = false;
  bool _onboardingTourActive = false;
  bool _onboardingTourIsManual = false;

  @override
  void initState() {
    super.initState();
    _profileTourView = ShowcaseView.register(
      scope: _profileTourScope,
      disableBarrierInteraction: true,
      skipIfTargetNotPresent: true,
      onFinish: () {
        if (mounted) setState(() => _onboardingTourActive = false);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          OnboardingFlags.markCompleted(uid, OnboardingFlags.profile);
        }
      },
      onDismiss: (_) {
        if (mounted) setState(() => _onboardingTourActive = false);
      },
    );
  }

  @override
  void dispose() {
    _profileTourView.unregister();
    super.dispose();
  }

  /// userSnapshot verisi ilk kez geldiğinde bir kez çağrılır — bu sayfadaki
  /// StreamBuilder her alan güncellemesinde (ör. bir switch değiştirildiğinde)
  /// yeniden tetiklendiği için `_hasCheckedProfileOnboarding` bayrağı turun
  /// tekrar tekrar başlamasını önler.
  void _maybeStartProfileOnboarding(Map<String, dynamic> userData) {
    if (_hasCheckedProfileOnboarding) return;
    _hasCheckedProfileOnboarding = true;
    if (OnboardingFlags.isCompletedFromData(
      userData,
      OnboardingFlags.profile,
    )) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _onboardingTourActive = true;
        _onboardingTourIsManual = false;
      });
      _profileTourView.startShowCase([_connectionCodeShowcaseKey]);
    });
  }

  /// "Tekrar Öğren" satırı — PRODUCT_NOTES'un "Profilde de yedek erişim
  /// noktası" gereksinimi (bkz. araştırma raporu, "Nasıl Kullanılır" butonu
  /// bölümü). Ana tetikleyici Home'daki "Yardım Al" - bu, kullanıcı Profil'e
  /// gelmişken bağlantı kodu kartını tekrar görmek isterse yedek bir yol.
  void _startProfileTourManually() {
    setState(() {
      _onboardingTourActive = true;
      _onboardingTourIsManual = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _profileTourView.startShowCase([_connectionCodeShowcaseKey]);
    });
  }

  Future<void> _updateProfileData(
    String uid,
    String field,
    dynamic value,
  ) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      field: value,
    }, SetOptions(merge: true));

    // 🔥 GÜNCEL: "silentMode" (Sessiz Bildirim) telefonun hafızasına da kaydedilir
    if (field == "notifications" || field == "silentMode") {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(field, value as bool);
    }
  }

  void _showEditNameDialog(
    BuildContext context,
    String uid,
    String currentName,
  ) {
    TextEditingController nameCtrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "İsminizi Düzenleyin",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            hintText: "Ad Soyad",
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4DB6AC)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4DB6AC),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'name': nameCtrl.text.trim()});
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBloodTypePicker(BuildContext context, String uid) {
    final List<String> bloodTypes = [
      "A Rh+",
      "A Rh-",
      "B Rh+",
      "B Rh-",
      "AB Rh+",
      "AB Rh-",
      "0 Rh+",
      "0 Rh-",
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Kan Grubu Seçiniz",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF263238),
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: bloodTypes.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        bloodTypes[index],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                      onTap: () {
                        _updateProfileData(uid, "bloodType", bloodTypes[index]);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHeightWeightPicker(
    BuildContext context,
    String uid,
    String currentVal,
  ) {
    int selectedHeight = 170;
    int selectedWeight = 70;
    if (currentVal.contains("/")) {
      try {
        List<String> parts = currentVal.split("/");
        selectedHeight = int.parse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
        selectedWeight = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      } catch (e) {}
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 350,
              child: Column(
                children: [
                  Text(
                    "Boy ve Kilo Seçiniz",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 40,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) =>
                                selectedHeight = 100 + index,
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) => Center(
                                child: Text(
                                  "${100 + index} cm",
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                              childCount: 151,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 40,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) =>
                                selectedWeight = 30 + index,
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) => Center(
                                child: Text(
                                  "${30 + index} kg",
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                              childCount: 171,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4DB6AC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        _updateProfileData(
                          uid,
                          "heightWeight",
                          "$selectedHeight cm / $selectedWeight kg",
                        );
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Güncelle",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Giriş Gerekli"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        var userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};

        String displayName =
            userData['name'] ?? user.email?.split('@').first ?? "Kullanıcı";
        String bloodType = userData['bloodType'] ?? "Belirlenmedi";
        String heightWeight = userData['heightWeight'] ?? "Belirlenmedi";

        bool notifications = userData['notifications'] ?? true;
        // 🔥 GÜNCEL: "silentMode" (Sessiz Bildirim). Varsayılanı "false" (Yani ses açık)
        bool silentMode = userData['silentMode'] ?? false;

        int totalScore = userData['totalScore'] ?? 0;
        String connectionCode = userData['connectionCode'] ?? "Kod Yok";

        // Sadece gerçek veri geldiğinde kontrol et - userSnapshot.data henüz
        // null'ken (ilk yüklemenin ConnectionState.waiting anı) userData boş
        // bir map'e düşüyor, bu "alan yok = tamamlanmadı" ile karışıp turu
        // erken/eksik veriyle (ör. "Kod Yok" yazan kartla) başlatmasın diye.
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          _maybeStartProfileOnboarding(userData);
        }

        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('notifications', notifications);
          prefs.setBool(
            'silentMode',
            silentMode,
          ); // Hafızaya sessiz modu yazıyoruz
        });

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('medicines')
              .snapshots(),
          builder: (context, medSnapshot) {
            int uniqueMedicinesCount = 0;
            if (medSnapshot.hasData) {
              final docs = medSnapshot.data!.docs;
              final uniqueNames = docs
                  .map(
                    (doc) =>
                        ((doc.data() as Map<String, dynamic>)['name']
                            ?.toString()
                            .toLowerCase()
                            .trim() ??
                        ""),
                  )
                  .toSet();
              uniqueNames.remove("");
              uniqueMedicinesCount = uniqueNames.length;
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildColorUserCard(
                    context,
                    displayName,
                    user.email ?? "",
                    user.uid,
                  ),
                  Showcase.withWidget(
                    key: _connectionCodeShowcaseKey,
                    scope: _profileTourScope,
                    targetPadding: const EdgeInsets.all(4),
                    container: OnboardingTooltipCard(
                      title: "Aile Bağlantı Kodun",
                      description:
                          "Bu kodu bir yakınınla paylaş — seni takip edip "
                          "ilaçlarını hatırlatabilsin.",
                      buttonLabel: "Anladım",
                      onNext: () => _profileTourView.next(force: true),
                      showCloseButton: _onboardingTourIsManual,
                      onClose: () => _profileTourView.dismiss(),
                    ),
                    child: _buildConnectionCodeCard(connectionCode, context),
                  ),
                  Row(
                    children: [
                      _buildStatItem(
                        "İlaçlarım",
                        "$uniqueMedicinesCount Çeşit İlaç",
                        Icons.medication_liquid_rounded,
                        const Color(0xFF4DB6AC),
                      ),
                      const SizedBox(width: 12),
                      _buildStatItem(
                        "Sağlık Puanım",
                        "$totalScore",
                        Icons.workspace_premium_rounded,
                        const Color(0xFFFFB300),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMenuSection(
                    title: "Sağlık Bilgilerim",
                    icon: Icons.favorite_border_rounded,
                    items: [
                      _buildSelectRow(
                        context,
                        user.uid,
                        "Kan Grubu",
                        bloodType,
                        "bloodType",
                        isLast: false,
                      ),
                      _buildSelectRow(
                        context,
                        user.uid,
                        "Boy / Kilo",
                        heightWeight,
                        "heightWeight",
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMenuSection(
                    title: "Ayarlar",
                    icon: Icons.tune_rounded,
                    items: [
                      _buildSwitchRow(
                        user.uid,
                        "Bildirimler",
                        notifications,
                        "notifications",
                        isLast: false,
                      ),
                      // 🔥 GÜNCEL: "Sesli Hatırlatıcı" yerine "Sessiz Bildirim"
                      _buildSwitchRow(
                        user.uid,
                        "Sessiz Bildirim",
                        silentMode,
                        "silentMode",
                        isLast: false,
                      ),
                      _buildHelpRow(
                        "Tekrar Öğren",
                        "Bağlantı kodu turunu tekrar izle",
                        _startProfileTourManually,
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildLogoutButton(context),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorUserCard(
    BuildContext context,
    String name,
    String email,
    String uid,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4DB6AC), Color(0xFF00796B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : "K",
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00796B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 32),
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_note,
                  color: Colors.white70,
                  size: 24,
                ),
                onPressed: () => _showEditNameDialog(context, uid, name),
              ),
            ],
          ),
          Text(
            email,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
          ],
          border: Border(
            bottom: BorderSide(color: color.withOpacity(0.5), width: 3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondaryStrong,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF4DB6AC), size: 18),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: const Color(0xFF263238),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          ...items,
        ],
      ),
    );
  }

  Widget _buildSelectRow(
    BuildContext context,
    String uid,
    String label,
    String value,
    String field, {
    required bool isLast,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: () => field == "bloodType"
              ? _showBloodTypePicker(context, uid)
              : _showHeightWeightPicker(context, uid, value),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00695C),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: Colors.grey.withOpacity(0.1),
          ),
      ],
    );
  }

  Widget _buildSwitchRow(
    String uid,
    String label,
    bool value,
    String field, {
    required bool isLast,
  }) {
    return Column(
      children: [
        SwitchListTile(
          value: value,
          onChanged: (newValue) => _updateProfileData(uid, field, newValue),
          activeColor: const Color(0xFF4DB6AC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: Colors.grey.withOpacity(0.1),
          ),
      ],
    );
  }

  /// "Tekrar Öğren" satırı — PRODUCT_NOTES'un Profil'de istediği yedek
  /// onboarding erişim noktası. Diğer satırlarla (_buildSelectRow/
  /// _buildSwitchRow) aynı ListTile deseni, farkı: mor/lavanta ikon
  /// (AppColors.helpAccent) - "yardım" kimliğinin Home'daki "Yardım Al"
  /// butonuyla tutarlı kalması için.
  Widget _buildHelpRow(
    String label,
    String subtitle,
    VoidCallback onTap, {
    required bool isLast,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const Icon(
            Icons.replay_circle_filled_rounded,
            color: AppColors.helpAccent,
          ),
          title: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondaryStrong,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey,
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: Colors.grey.withOpacity(0.1),
          ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: () async {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            try {
              // .update() değil .set(merge:true) - bu doküman her zaman var
              // olacağı garanti edilemez (ör. Google ile girişte rol seçimi
              // tamamlanmadan çıkış denenirse, ya da başka bir sebeple hiç
              // oluşmamışsa). Üstelik bu çağrı hiç try/catch içinde değildi -
              // .update()'in fırlattığı NOT_FOUND istisnası hiçbir yerde
              // yakalanmadan yukarı fırlıyor, çıkış işlemi (signOut/yönlendirme)
              // hiç çalışmadan uygulama çöküyordu (gerçek cihazda gözlemlendi).
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .set({'fcmToken': ''}, SetOptions(merge: true));
            } catch (e) {
              // fcmToken temizlenemese bile kullanıcı çıkış yapabilmeli -
              // bu, "eski cihazda bildirim almaya devam etme" riskini göze
              // alan, kasıtlı bir öncelik: sessiz kalmıyoruz (loglanıyor) ama
              // engellemiyoruz da.
              debugPrint("⚠️ Çıkışta fcmToken temizlenemedi: $e");
            }
          }
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        },
        icon: const Icon(Icons.logout_rounded, color: Colors.white),
        label: Text(
          "HESAPTAN ÇIKIŞ YAP",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF5350),
          elevation: 4,
          shadowColor: const Color(0xFFEF5350).withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCodeCard(String code, BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF4DB6AC).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Aile Bağlantı Kodum",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: const Color(0xFF00796B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                code,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00695C),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                // Tur açıkken (spotlight overlay'i translucent olduğu için
                // gerçek dokunuş buraya da ulaşabiliyor) "Anladım" yerine
                // yanlışlıkla kopyalama tetiklenmesin.
                if (_onboardingTourActive) return;
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Bağlantı kodu panoya kopyalandı."),
                    backgroundColor: Color(0xFF4DB6AC),
                  ),
                );
              },
              icon: const Icon(
                Icons.copy_rounded,
                color: Color(0xFF00796B),
                size: 20,
              ),
              tooltip: "Kodu Kopyala",
            ),
          ),
        ],
      ),
    );
  }
}
