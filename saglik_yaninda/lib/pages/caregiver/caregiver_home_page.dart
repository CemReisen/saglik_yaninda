import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart'; // 🔥 EFSANE ANİMASYON PAKETİ EKLENDİ
import 'package:showcaseview/showcaseview.dart';
import 'package:saglik_yaninda/core/theme/app_colors.dart';
import 'package:saglik_yaninda/widgets/onboarding/onboarding_tooltip_card.dart';
import 'package:saglik_yaninda/widgets/onboarding/home_tour_shared.dart';
import 'package:saglik_yaninda/services/onboarding_service.dart';

class CaregiverLayout extends StatefulWidget {
  const CaregiverLayout({super.key});

  @override
  State<CaregiverLayout> createState() => _CaregiverLayoutState();
}

class _CaregiverLayoutState extends State<CaregiverLayout> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      const CaregiverHomePage(),
      const CaregiverProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(children: [Expanded(child: _pages[_currentIndex])]),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom > 0 ? 10 : 16,
          left: 20,
          right: 20,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () {
                  // Home/Profil onboarding turlarından biri açıkken sekme
                  // değiştirmeye izin verme - aksi halde gerçek bir sekme
                  // dokunuşu (showcaseview'ın hedef overlay'i varsayılan
                  // olarak translucent olduğu için spotlight'lanan widget'a
                  // da ulaşabiliyor) o an tur gösteren sayfayı ortasında
                  // unmount edip overlay'i sahipsiz bırakırdı - elder
                  // tarafındaki aynı korumanın (main.dart → MainLayout)
                  // caregiver muadili, aynı paylaşılan notifier kullanılıyor.
                  if (onboardingTourActiveNotifier.value) return;
                  setState(() => _currentIndex = 0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _currentIndex == 0
                        ? const Color(0xFF3949AB).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/home.svg',
                    colorFilter: ColorFilter.mode(
                      _currentIndex == 0
                          ? const Color(0xFF3949AB)
                          : Colors.grey.shade400,
                      BlendMode.srcIn,
                    ),
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (onboardingTourActiveNotifier.value) return;
                  setState(() => _currentIndex = 1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _currentIndex == 1
                        ? const Color(0xFF3949AB).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/profile.svg',
                    colorFilter: ColorFilter.mode(
                      _currentIndex == 1
                          ? const Color(0xFF3949AB)
                          : Colors.grey.shade400,
                      BlendMode.srcIn,
                    ),
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CaregiverHomePage extends StatefulWidget {
  const CaregiverHomePage({super.key});

  @override
  State<CaregiverHomePage> createState() => _CaregiverHomePageState();
}

class _CaregiverHomePageState extends State<CaregiverHomePage> {
  // --- Onboarding turu (Caregiver Home) ------------------------------------
  // 2 dalgalı, 4 adımlı - bkz. OnboardingFlags dokümantasyonu için detaylı
  // gerekçe. Elder'daki Home turunun aksine bu tur navbar'ı spotlight'lamıyor
  // (istenmedi) - bu yüzden scope tamamen bu State'e özel/private kalabiliyor,
  // home_tour_shared.dart'tan sadece `onboardingTourActiveNotifier`ı
  // (CaregiverLayout'un alt navbar'ını tur sırasında kilitlemek için) ödünç
  // alıyoruz.
  static const String _caregiverHomeTourScope = 'caregiver_home_onboarding';
  final GlobalKey _yardimAlShowcaseKey = GlobalKey();
  final GlobalKey _yeniYakinShowcaseKey = GlobalKey();
  final GlobalKey _elderCardShowcaseKey = GlobalKey();
  final GlobalKey _nudgeIconShowcaseKey = GlobalKey();
  late final ShowcaseView _homeTourView;
  bool _hasCheckedCaregiverHomeOnboarding = false;
  bool _onboardingTourActive = false;
  bool _onboardingTourIsManual = false;

  void _setOnboardingTourActive(bool active, {bool manual = false}) {
    _onboardingTourActive = active;
    _onboardingTourIsManual = manual;
    onboardingTourActiveNotifier.value = active;
  }

  List<GlobalKey> get _wave1Keys => [
    _yardimAlShowcaseKey,
    _yeniYakinShowcaseKey,
  ];

  List<GlobalKey> get _wave2Keys => [
    _elderCardShowcaseKey,
    _nudgeIconShowcaseKey,
  ];

  @override
  void initState() {
    super.initState();
    _homeTourView = ShowcaseView.register(
      scope: _caregiverHomeTourScope,
      disableBarrierInteraction: true,
      skipIfTargetNotPresent: true,
      onComplete: (index, key) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;
        if (key == _yardimAlShowcaseKey) {
          // Dalga 1'in son adımı.
          OnboardingFlags.markCompleted(uid, OnboardingFlags.caregiverHomeIntro);
        } else if (key == _elderCardShowcaseKey) {
          // Dalga 2 - bilinçli olarak SON adımda (zil ikonu) değil, kart
          // adımında yazılıyor - bkz. OnboardingFlags dokümantasyonu
          // (Seçenek B, kullanıcı onaylı).
          OnboardingFlags.markCompleted(uid, OnboardingFlags.caregiverHomeElder);
        }
      },
      onFinish: () {
        if (mounted) setState(() => _setOnboardingTourActive(false));
      },
      onDismiss: (_) {
        if (mounted) setState(() => _setOnboardingTourActive(false));
      },
    );
  }

  /// Relations StreamBuilder'ının builder'ından çağrılır (caregiver'ın kendi
  /// user-doc stream'inden DEĞİL) - dalga 2'nin hedefi (ilk yakın kartı)
  /// itemBuilder'ın en az bir kez gerçek veriyle çalışmış olmasını
  /// gerektiriyor, aksi halde skipIfTargetNotPresent onu sessizce ve kalıcı
  /// olarak atlar (bkz. home_page.dart → _maybeStartHomeOnboarding'teki aynı
  /// bug fix notu).
  void _maybeStartCaregiverHomeOnboarding(Map<String, dynamic>? userData) {
    if (_hasCheckedCaregiverHomeOnboarding) return;
    _hasCheckedCaregiverHomeOnboarding = true;
    final bool introDone = OnboardingFlags.isCompletedFromData(
      userData,
      OnboardingFlags.caregiverHomeIntro,
    );
    final bool elderDone = OnboardingFlags.isCompletedFromData(
      userData,
      OnboardingFlags.caregiverHomeElder,
    );
    final List<GlobalKey> pendingSteps = [
      if (!introDone) ..._wave1Keys,
      if (!elderDone) ..._wave2Keys,
    ];
    if (pendingSteps.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      _runOnboardingSequence(pendingSteps);
    });
  }

  /// "Yardım Al" butonu - daha önce tamamlanmış olsa bile turu manuel olarak
  /// baştan (4 adımın hepsini sırayla) yeniden başlatır.
  void _startCaregiverHomeTourManually() {
    _runOnboardingSequence([..._wave1Keys, ..._wave2Keys], manual: true);
  }

  void _runOnboardingSequence(List<GlobalKey> steps, {bool manual = false}) {
    setState(() => _setOnboardingTourActive(true, manual: manual));

    void start() {
      if (!mounted) return;
      try {
        _homeTourView.startShowCase(steps);
      } catch (e) {
        debugPrint(
          "Caregiver Home onboarding turu başlatılamadı (scope kaydı kayboldu): $e",
        );
        if (mounted) setState(() => _setOnboardingTourActive(false));
      }
    }

    if (manual) {
      WidgetsBinding.instance.addPostFrameCallback((_) => start());
    } else {
      start();
    }
  }

  @override
  void dispose() {
    _homeTourView.unregister();
    if (_onboardingTourActive) {
      onboardingTourActiveNotifier.value = false;
    }
    super.dispose();
  }

  DateTime? _parseDate(String dateStr) {
    try {
      List<String> parts = dateStr.split('.');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (e) {
      return null;
    }
  }

  String _getShortDayName() {
    List<String> weekDays = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
    return weekDays[DateTime.now().weekday - 1];
  }

  Future<void> _sendNudgeNotification(
    BuildContext context,
    String elderId,
    String fallbackCaregiverName,
  ) async {
    try {
      var elderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(elderId)
          .get();
      if (!elderDoc.exists) return;

      String elderName = "Yakınınız";
      if (elderDoc.data() != null) {
        String? dbName = elderDoc.data()?['name'];
        if (dbName != null && dbName.trim().isNotEmpty) {
          elderName = dbName;
        }
      }

      String caregiverName = fallbackCaregiverName;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        var caregiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (caregiverDoc.exists && caregiverDoc.data() != null) {
          String? dbCaregiverName = caregiverDoc.data()?['name'];
          if (dbCaregiverName != null && dbCaregiverName.trim().isNotEmpty) {
            caregiverName = dbCaregiverName;
          }
        }
      }

      String? fcmToken = elderDoc.data()?['fcmToken'];
      if (fcmToken == null || fcmToken.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Kullanıcı şu an bildirim alamıyor (Çevrimdışı)."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (currentUser == null) return;

      await FirebaseFirestore.instance.collection('notification_requests').add({
        'type': 'nudge',
        'caregiverId': currentUser.uid,
        'elderId': elderId,
        'elderName': elderName,
        'callerName': caregiverName,
        'medicineName': '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Hatırlatma başarıyla gönderildi! ✅"),
            backgroundColor: Color(0xFF4DB6AC),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("⚠️ Dürtme bildirimi gönderilemedi: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hatırlatma gönderilemedi: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTimelineItem(String medName, String medTime, bool isTaken) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            isTaken ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: isTaken ? const Color(0xFF4DB6AC) : Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              medName,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: isTaken ? FontWeight.w500 : FontWeight.w600,
                color: isTaken
                    ? AppColors.textSecondaryStrong
                    : const Color(0xFF263238),
                decoration: isTaken ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            medTime,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isTaken
                  ? AppColors.textSecondaryStrong
                  : const Color(0xFF3949AB),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 YENİ: İskelet Yükleme Ekranı (Kompakt karta uygun boyutta)
  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          2,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 6),
                          Container(width: 60, height: 12, color: Colors.white),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                Container(
                  width: double.infinity,
                  height: 10,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, caregiverSnap) {
        String firstName = "Kullanıcı";
        Map<String, dynamic>? userData;

        if (caregiverSnap.hasData && caregiverSnap.data!.exists) {
          userData = caregiverSnap.data!.data() as Map<String, dynamic>;
          String fullName =
              userData['name']?.toString().trim() ??
              user?.displayName ??
              "Kullanıcı";
          firstName = fullName.split(' ').first;
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // KOMPAKT BAŞLIK VE EKLEME BUTONU
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hoş Geldin,",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.blueGrey[400],
                        ),
                      ),
                      Text(
                        firstName,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF263238),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "Yardım Al" - SOS'un olmadığı caregiver tarafında
                      // acil bir buton yok, bu yüzden elder'daki gibi kendi
                      // geniş satırı yerine birincil aksiyonun ("Yeni Yakın")
                      // hemen soluna, küçük dairesel bir ikon buton olarak
                      // yerleştirildi - PRODUCT_NOTES'un "yan yana, farklı
                      // renk" ilkesi korunuyor, ama "Yeni Yakın"ın görsel
                      // ağırlığı gölgelenmiyor.
                      Showcase.withWidget(
                        key: _yardimAlShowcaseKey,
                        scope: _caregiverHomeTourScope,
                        targetPadding: const EdgeInsets.all(4),
                        container: OnboardingTooltipCard(
                          title: "Yardım Al",
                          description:
                              "Turu unuttuysan ya da tekrar izlemek "
                              "istersen, istediğin zaman bu butona "
                              "dokunabilirsin.",
                          buttonLabel: "Anladım",
                          onNext: () => _homeTourView.next(force: true),
                          showCloseButton: _onboardingTourIsManual,
                          onClose: () => _homeTourView.dismiss(),
                        ),
                        child: InkWell(
                          onTap: () {
                            // Tur açıkken (spotlight overlay'i translucent
                            // olduğu için gerçek dokunuş buraya da
                            // ulaşabiliyor) turun kendisi ortasında yeniden
                            // başlatılmasın.
                            if (_onboardingTourActive) return;
                            _startCaregiverHomeTourManually();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.helpAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.helpAccent.withOpacity(
                                    0.35,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.help_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Showcase.withWidget(
                        key: _yeniYakinShowcaseKey,
                        scope: _caregiverHomeTourScope,
                        targetPadding: const EdgeInsets.all(4),
                        container: OnboardingTooltipCard(
                          title: "Yeni Yakın Ekle",
                          description:
                              "Takip etmek istediğin kişinin profilinde "
                              "yazan bağlantı kodunu girerek ona "
                              "bağlanabilirsin.",
                          buttonLabel: "Anladım",
                          onNext: () => _homeTourView.next(force: true),
                          showCloseButton: _onboardingTourIsManual,
                          onClose: () => _homeTourView.dismiss(),
                        ),
                        child: InkWell(
                          onTap: () {
                            if (_onboardingTourActive) return;
                            _showAddRelativeDialog(context);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3949AB),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3949AB,
                                  ).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_add_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Yeni Yakın",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('relations')
                    .where('caregiverId', isEqualTo: user?.uid)
                    .where('status', isEqualTo: 'approved')
                    .snapshots(),
                builder: (context, snapshot) {
                  // 🔥 DÖNEN ÇARK SİLİNDİ, İSKELET ANİMASYONU EKLENDİ
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonLoader();
                  }

                  // Dalga 2'nin hedefi (ilk yakın kartı) bu builder'ın en az
                  // bir kez gerçek veriyle (relationCount 0 dahil) çalışmış
                  // olmasını gerektiriyor - bkz. _maybeStartCaregiverHomeOnboarding
                  // dokümantasyonu.
                  _maybeStartCaregiverHomeOnboarding(userData);

                  int relationCount = snapshot.hasData
                      ? snapshot.data!.docs.length
                      : 0;

                  if (relationCount == 0) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(
                          children: [
                            Icon(
                              Icons.monitor_heart_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Henüz takip ettiğiniz biri yok.",
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondaryStrong,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: relationCount,
                    itemBuilder: (context, index) {
                      String elderId = snapshot.data!.docs[index]['elderId'];
                      return _buildElderCard(
                        context,
                        elderId,
                        isFirst: index == 0,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildElderCard(
    BuildContext context,
    String elderId, {
    required bool isFirst,
  }) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(elderId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        var elderData = userSnapshot.data!.data() as Map<String, dynamic>;
        String name =
            elderData['name']?.toString().trim() ??
            elderData['email']?.toString().split('@').first ??
            "Yakınınız";
        int score = elderData['totalScore'] ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(elderId)
              .collection('medicines')
              .snapshots(),
          builder: (context, medSnapshot) {
            int totalMeds = 0;
            int takenMeds = 0;
            List<QueryDocumentSnapshot> todaysMedicines = [];

            if (medSnapshot.hasData) {
              final allDocs = medSnapshot.data!.docs;
              final String today = DateFormat(
                'yyyy-MM-dd',
              ).format(DateTime.now());
              final todayDate = DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              );
              String todayName = _getShortDayName();

              todaysMedicines = allDocs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                DateTime? start = _parseDate(data['startDate'] ?? '');
                DateTime? end = _parseDate(data['endDate'] ?? '');
                if (start != null &&
                    end != null &&
                    (todayDate.isBefore(start) || todayDate.isAfter(end))) {
                  return false;
                }
                String repeat = data['repeatType'] ?? 'daily';
                return (repeat == 'daily' ||
                    repeat == 'Her Gün' ||
                    (data['days'] as List?)?.contains(todayName) == true);
              }).toList();

              totalMeds = todaysMedicines.length;
              takenMeds = todaysMedicines.where((doc) {
                return (doc.data() as Map<String, dynamic>)['lastTakenDate'] ==
                    today;
              }).length;
            }

            double progress = totalMeds == 0 ? 0.0 : (takenMeds / totalMeds);
            final String todayStringForTimeline = DateFormat(
              'yyyy-MM-dd',
            ).format(DateTime.now());

            final bool showNudgeIcon = totalMeds > 0 && takenMeds < totalMeds;

            final Widget nudgeIcon = InkWell(
              onTap: () {
                if (_onboardingTourActive) return;
                final currentUser = FirebaseAuth.instance.currentUser;
                String caregiverName =
                    currentUser?.displayName ?? "Yakınınız";
                _sendNudgeNotification(context, elderId, caregiverName);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFFEF5350),
                  size: 20,
                ),
              ),
            );

            final Widget elderCard = Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(
                          0xFF3949AB,
                        ).withOpacity(0.1),
                        child: Text(
                          name[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF3949AB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF263238),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: Color(0xFFFFB300),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "$score Puan",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondaryStrong,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (totalMeds > 0 && takenMeds == totalMeds)
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          (totalMeds > 0 && takenMeds == totalMeds)
                              ? Icons.done_all_rounded
                              : Icons.pending_actions_rounded,
                          color: (totalMeds > 0 && takenMeds == totalMeds)
                              ? Colors.green
                              : Colors.orange,
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(height: 1, thickness: 0.5),
                  ),

                  // 🔥 KOMPAKT KARTTAKİ PROGRESS VE HATIRLAT BUTONU
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Bugün ($takenMeds/$totalMeds)",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondaryStrong,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  (totalMeds > 0 && takenMeds == totalMeds)
                                      ? const Color(0xFF4DB6AC)
                                      : const Color(0xFF3949AB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showNudgeIcon) ...[
                        const SizedBox(width: 16),
                        // Dürtme (zil) ikonu SADECE bu yakının o gün
                        // bekleyen bir ilacı varsa render ediliyor - kartın
                        // (her zaman mevcut) aksine "all-or-nothing" değil.
                        // Bu yüzden dalga 2'nin bayrağı bu adıma değil, kart
                        // adımına bağlı - bkz. OnboardingFlags dokümantasyonu.
                        isFirst
                            ? Showcase.withWidget(
                                key: _nudgeIconShowcaseKey,
                                scope: _caregiverHomeTourScope,
                                targetPadding: const EdgeInsets.all(4),
                                container: OnboardingTooltipCard(
                                  title: "Hatırlatma Gönder",
                                  description:
                                      "Yakının bir ilacını almayı unuttuysa "
                                      "bu zile dokunarak ona bir hatırlatma "
                                      "bildirimi gönderebilirsin.",
                                  buttonLabel: "Anladım",
                                  onNext: () =>
                                      _homeTourView.next(force: true),
                                  showCloseButton: _onboardingTourIsManual,
                                  onClose: () => _homeTourView.dismiss(),
                                ),
                                child: nudgeIcon,
                              )
                            : nudgeIcon,
                      ],
                    ],
                  ),

                  if (totalMeds > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: todaysMedicines.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          String medName = data['name'] ?? "İlaç";
                          String medTime =
                              (data['hour'] != null && data['minute'] != null)
                              ? "${data['hour'].toString().padLeft(2, '0')}:${data['minute'].toString().padLeft(2, '0')}"
                              : (data['label'] ?? "-");
                          bool isTaken =
                              data['lastTakenDate'] == todayStringForTimeline;
                          return _buildTimelineItem(medName, medTime, isTaken);
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            );

            // İlk (index 0) yakın kartı onboarding turunun 3. adımının
            // (elderCard) spotlight hedefi - liste her zaman en az bu kartı
            // içerdiğinde (relationCount > 0) hedef garanti mevcut.
            return isFirst
                ? Showcase.withWidget(
                    key: _elderCardShowcaseKey,
                    scope: _caregiverHomeTourScope,
                    targetPadding: const EdgeInsets.all(4),
                    container: OnboardingTooltipCard(
                      title: "Yakının Durumu",
                      description:
                          "Her kart bir yakınının bugünkü ilaç durumunu "
                          "gösterir - kaç ilacını aldığını, puanını ve "
                          "ilaç listesini buradan takip edebilirsin.",
                      buttonLabel: "Anladım",
                      onNext: () => _homeTourView.next(force: true),
                      showCloseButton: _onboardingTourIsManual,
                      onClose: () => _homeTourView.dismiss(),
                    ),
                    child: elderCard,
                  )
                : elderCard;
          },
        );
      },
    );
  }

  void _showAddRelativeDialog(BuildContext context) {
    TextEditingController codeController = TextEditingController();
    bool isRequesting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                "Yeni Yakın Ekle",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Takip etmek istediğiniz kişinin profilinde yazan 6 haneli kodu giriniz.",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondaryStrong,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    maxLength: 7,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: "Örn: AX7-B92",
                      hintStyle: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                        letterSpacing: 0,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isRequesting ? null : () => Navigator.pop(context),
                  child: const Text(
                    "İptal",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isRequesting
                      ? null
                      : () async {
                          String enteredCode = codeController.text.trim();
                          if (enteredCode.isEmpty) return;

                          setStateDialog(() => isRequesting = true);

                          try {
                            final currentUserId =
                                FirebaseAuth.instance.currentUser!.uid;

                            // Bağlantı kodu çözümlemesi Cloud Function'a
                            // (resolveConnectionCode) taşındı: users
                            // koleksiyonunda connectionCode'a client'tan
                            // doğrudan sorgu yasak (bkz. firestore.rules) —
                            // elder'ın tam profilinin rastgele erişime
                            // açılmaması için Admin SDK ile, sadece
                            // {elderId, elderName} döndürerek çalışır.
                            String elderId;
                            String elderName = "";
                            try {
                              final callable = FirebaseFunctions.instance
                                  .httpsCallable('resolveConnectionCode');
                              final result = await callable.call(
                                <String, dynamic>{'code': enteredCode},
                              );
                              final data = Map<String, dynamic>.from(
                                result.data as Map,
                              );
                              elderId = data['elderId'] as String;
                              elderName = (data['elderName'] as String?) ?? "";
                            } on FirebaseFunctionsException catch (e) {
                              String message;
                              switch (e.code) {
                                case 'not-found':
                                  message =
                                      "Geçersiz kod veya kullanıcı bulunamadı! ❌";
                                  break;
                                case 'resource-exhausted':
                                  message =
                                      e.message ??
                                      "Çok fazla deneme yaptınız. Lütfen bir dakika sonra tekrar deneyin.";
                                  break;
                                case 'unauthenticated':
                                  message =
                                      "Oturum süreniz dolmuş, lütfen tekrar giriş yapın.";
                                  break;
                                default:
                                  message =
                                      "Kod doğrulanamadı. Lütfen tekrar deneyin.";
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                              setStateDialog(() => isRequesting = false);
                              return;
                            }

                            if (elderId == currentUserId) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Kendi kodunuzu giremezsiniz! ⚠️",
                                  ),
                                ),
                              );
                              setStateDialog(() => isRequesting = false);
                              return;
                            }

                            // relations dokümanları deterministik ID kullanır:
                            // "{elderId}_{caregiverId}" — Firestore güvenlik
                            // kuralları, onaylı ilişkiyi bu sabit yoldan
                            // exists()/get() ile doğrulayabilsin diye.
                            final relationRef = FirebaseFirestore.instance
                                .collection('relations')
                                .doc('${elderId}_$currentUserId');

                            var existingRelation = await relationRef.get();

                            if (existingRelation.exists) {
                              String existingStatus =
                                  existingRelation.data()!['status'];
                              String message = existingStatus == 'approved'
                                  ? "Bu kişiyle zaten bağlısınız. ✅"
                                  : "İsteğiniz zaten beklemede. ⏳";
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                              setStateDialog(() => isRequesting = false);
                              return;
                            }

                            await relationRef.set({
                              'caregiverId': currentUserId,
                              'elderId': elderId,
                              'status': 'pending',
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    elderName.trim().isNotEmpty
                                        ? "İsteğiniz $elderName kişisine gönderildi! ✅"
                                        : "İstek başarıyla gönderildi! ✅",
                                  ),
                                  backgroundColor: const Color(0xFF3949AB),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text("Hata: $e")));
                            setStateDialog(() => isRequesting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3949AB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isRequesting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Gönder",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class CaregiverProfilePage extends StatefulWidget {
  const CaregiverProfilePage({super.key});

  @override
  State<CaregiverProfilePage> createState() => _CaregiverProfilePageState();
}

class _CaregiverProfilePageState extends State<CaregiverProfilePage> {
  // --- Onboarding turu (Caregiver Profil) ----------------------------------
  // Tek adımlı - elder Profil'deki bağlantı kodu turuyla aynı desen (bkz.
  // profile_page.dart → _profileTourScope).
  static const String _caregiverProfileTourScope =
      'caregiver_profile_onboarding';
  final GlobalKey _manageElderlyShowcaseKey = GlobalKey();
  late final ShowcaseView _profileTourView;
  bool _hasCheckedCaregiverProfileOnboarding = false;
  bool _onboardingTourActive = false;
  bool _onboardingTourIsManual = false;

  void _setOnboardingTourActive(bool active, {bool manual = false}) {
    _onboardingTourActive = active;
    _onboardingTourIsManual = manual;
    onboardingTourActiveNotifier.value = active;
  }

  @override
  void initState() {
    super.initState();
    _profileTourView = ShowcaseView.register(
      scope: _caregiverProfileTourScope,
      disableBarrierInteraction: true,
      skipIfTargetNotPresent: true,
      onComplete: (index, key) {
        if (mounted) setState(() => _setOnboardingTourActive(false));
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          OnboardingFlags.markCompleted(uid, OnboardingFlags.caregiverProfile);
        }
      },
      onFinish: () {
        if (mounted) setState(() => _setOnboardingTourActive(false));
      },
      onDismiss: (_) {
        if (mounted) setState(() => _setOnboardingTourActive(false));
      },
    );
  }

  /// userSnapshot verisi ilk kez geldiğinde bir kez çağrılır - bu sayfadaki
  /// StreamBuilder her alan güncellemesinde yeniden tetiklendiği için
  /// `_hasCheckedCaregiverProfileOnboarding` bayrağı turun tekrar tekrar
  /// başlamasını önler.
  void _maybeStartCaregiverProfileOnboarding(Map<String, dynamic> userData) {
    if (_hasCheckedCaregiverProfileOnboarding) return;
    _hasCheckedCaregiverProfileOnboarding = true;
    if (OnboardingFlags.isCompletedFromData(
      userData,
      OnboardingFlags.caregiverProfile,
    )) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _setOnboardingTourActive(true));
      _profileTourView.startShowCase([_manageElderlyShowcaseKey]);
    });
  }

  /// "Tekrar Öğren" satırı - Home'daki "Yardım Al" gibi yedek bir erişim
  /// noktası, kullanıcı Profil'e gelmişken bu turu tekrar görmek isterse.
  void _startCaregiverProfileTourManually() {
    setState(() => _setOnboardingTourActive(true, manual: true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _profileTourView.startShowCase([_manageElderlyShowcaseKey]);
    });
  }

  @override
  void dispose() {
    _profileTourView.unregister();
    if (_onboardingTourActive) {
      onboardingTourActiveNotifier.value = false;
    }
    super.dispose();
  }

  /// "Tekrar Öğren" satırı - elder Profil'deki `_buildHelpRow` ile aynı
  /// görsel dil (mor/lavanta ikon, aynı ListTile deseni) - caregiver
  /// tarafında ayrı bir "ayarlar listesi" widget'ı olmadığı için burada
  /// tek başına, kendi kartında.
  Widget _buildHelpRow(String label, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
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
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, userSnap) {
        String profileName = "Bakıcı Hesabı";
        if (userSnap.hasData && userSnap.data!.exists) {
          var data = userSnap.data!.data() as Map<String, dynamic>;
          profileName = data['name']?.toString().trim() ?? "Bakıcı Hesabı";
          _maybeStartCaregiverProfileOnboarding(data);
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF3949AB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 60,
                  color: Color(0xFF3949AB),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                profileName,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF263238),
                ),
              ),
              Text(
                currentUser.email ?? "",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppColors.textSecondaryStrong,
                ),
              ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: _buildHelpRow(
                  "Tekrar Öğren",
                  "'Takip Edilenleri Yönet' turunu tekrar izle",
                  _startCaregiverProfileTourManually,
                ),
              ),
              const SizedBox(height: 8),

              Showcase.withWidget(
                key: _manageElderlyShowcaseKey,
                scope: _caregiverProfileTourScope,
                targetPadding: const EdgeInsets.all(4),
                container: OnboardingTooltipCard(
                  title: "Takip Edilenleri Yönet",
                  description:
                      "Takip ettiğin kişileri burada görebilir, "
                      "istediğinde birini takipten çıkarabilirsin.",
                  buttonLabel: "Anladım",
                  onNext: () => _profileTourView.next(force: true),
                  showCloseButton: _onboardingTourIsManual,
                  onClose: () => _profileTourView.dismiss(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Takip Edilenleri Yönet",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF37474F),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('relations')
                          .where('caregiverId', isEqualTo: currentUser.uid)
                          .where('status', isEqualTo: 'approved')
                          .snapshots(),
                      builder: (context, snapshot) {
                        // 🔥 PROFİL SAYFASINDAKİ ÇARKLAR DA İSKELETE DÖNÜŞTÜ
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor: Colors.grey.shade100,
                            child: Column(
                              children: List.generate(
                                2,
                                (index) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData ||
                            snapshot.data!.docs.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              "Henüz kimseyi takip etmiyorsunuz.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondaryStrong,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            var relationDoc = snapshot.data!.docs[index];
                            String elderId = relationDoc['elderId'];
                            String docId = relationDoc.id;

                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(elderId)
                                  .get(),
                              builder: (context, userSnapshot) {
                                if (!userSnapshot.hasData) {
                                  return const SizedBox();
                                }
                                var elderData =
                                    userSnapshot.data!.data()
                                        as Map<String, dynamic>?;
                                if (elderData == null) {
                                  return const SizedBox();
                                }

                                String elderName =
                                    elderData['name'] ??
                                    elderData['email'] ??
                                    "Kullanıcı";

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFFE8EAF6),
                                      child: Icon(
                                        Icons.elderly,
                                        color: Color(0xFF3949AB),
                                      ),
                                    ),
                                    title: Text(
                                      elderName,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "Takipte",
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 15,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.person_remove_rounded,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: Colors.white,
                                            title: const Text("Takipten Çık"),
                                            content: Text(
                                              "$elderName adlı kişiyi takip etmeyi bırakmak istiyor musunuz?",
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text(
                                                  "İptal",
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('relations')
                                                      .doc(docId)
                                                      .delete();
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          "Takipten çıkıldı.",
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                style:
                                                    ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.redAccent,
                                                    ),
                                                child: const Text(
                                                  "Çıkar",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      // .update() değil .set(merge:true) - elder tarafındaki
                      // aynı bug'ın (profile_page.dart -> _buildLogoutButton)
                      // caregiver eşleniği: doküman her zaman var olacağı
                      // garanti edilemez, .update() NOT_FOUND ile tüm çıkış
                      // işlemini (signOut/yönlendirme dahil) çökertiyordu.
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .set({'fcmToken': ''}, SetOptions(merge: true));
                    } catch (e) {
                      debugPrint("⚠️ Çıkışta fcmToken temizlenemedi: $e");
                    }
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
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
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
