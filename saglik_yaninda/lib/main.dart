import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:saglik_yaninda/pages/home_page.dart';
import 'package:saglik_yaninda/pages/calendar_page.dart';
import 'package:saglik_yaninda/pages/add_medicine_page.dart';
import 'package:saglik_yaninda/pages/notifications_page.dart';
import 'package:saglik_yaninda/pages/profile_page.dart';
import 'package:saglik_yaninda/pages/auth/forgot_password_page.dart';
import 'package:saglik_yaninda/pages/auth/login_page.dart';
import 'package:saglik_yaninda/pages/auth/register_page.dart';
import 'package:saglik_yaninda/pages/auth/quick_start_page.dart';
import 'package:saglik_yaninda/pages/auth/recovery_code_page.dart';
import 'package:saglik_yaninda/services/notification_service.dart';
import 'package:saglik_yaninda/pages/caregiver/caregiver_home_page.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/app_navigator_key.dart';

// Firebase konsolu → Authentication → Sign-in method → Google → "Web SDK
// configuration" altındaki Web client ID. Android client ID DEĞİL — Firebase,
// idToken'ın audience'ını bu web client'a göre doğruluyor; yanlış ID
// GoogleSignIn.instance.initialize()'ı sessizce bozmaz ama signInWithCredential
// aşamasında "invalid audience" hatasına yol açar.
const String _googleServerClientId =
    '308628032795-gc0cva54oiujgvf7b9mcf0mfi2fjg0r1.apps.googleusercontent.com';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Arka planda bildirim geldi: ${message.messageId}");
}

/// Firestore'daki fcmToken'ı cihazın güncel FCM token'ıyla senkronize eder.
/// Sadece değer farklıysa yazar (gereksiz write'ları önlemek için).
Future<void> _syncFcmToken(String uid) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await userRef.get();
    if (!snap.exists) return;

    final currentToken = snap.data()?['fcmToken'];
    if (currentToken != token) {
      await userRef.update({'fcmToken': token});
      debugPrint("🔄 FCM token senkronize edildi (uid: $uid).");
    }
  } catch (e) {
    debugPrint("⚠️ FCM token senkronizasyonu başarısız: $e");
  }
}

/// "d.m.y" formatındaki (add_medicine_page.dart'ta yazıldığı gibi, başında
/// sıfır olmadan) tarih string'ini DateTime'a çevirir. Ayrıştırılamazsa null
/// döner.
DateTime? _parseDdMmYyyy(String? value) {
  if (value == null) return null;
  final parts = value.split('.');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

/// Kullanım süresi (endDate) geçmiş ilaçların kurulu OS alarmlarını iptal
/// eder. matchDateTimeComponents ile kurulan haftalık/günlük tekrarlar
/// flutter_local_notifications tarafında kendiliğinden durmadığı için bu
/// tarama gerekiyor — bir bitiş tarihi geçtiğinde alarmı elle iptal etmemiz
/// lazım. Zaten işlenmiş ilaçlar `notificationsCancelled` bayrağıyla
/// atlanır, tekrar taramayı gereksiz Firestore write'larından korur.
Future<void> _cancelExpiredMedicineAlarms(String uid) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .get();

    final DateTime now = DateTime.now();
    final DateTime todayOnly = DateTime(now.year, now.month, now.day);

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['notificationsCancelled'] == true) continue;

      final endDate = _parseDdMmYyyy(data['endDate'] as String?);
      if (endDate == null) continue;
      if (!endDate.isBefore(todayOnly)) continue;

      final ids = NotificationService.extractNotificationIds(data);
      await NotificationService.cancelNotifications(ids);
      await doc.reference.update({'notificationsCancelled': true});
      debugPrint(
        "🧹 Süresi dolmuş ilaç alarmı iptal edildi: ${doc.id} (${ids.length} alarm)",
      );
    }
  } catch (e) {
    debugPrint("⚠️ Süresi dolmuş ilaç taraması başarısız: $e");
  }
}

/// Uygulama arka plandan ön plana her geldiğinde (resumed), süresi dolmuş
/// ilaç alarmlarını yeniden tarar. authStateChanges sadece oturum açılışında
/// tetiklendiği için, günün ilerleyen saatlerinde ön plana dönüşlerde de
/// kontrol sağlamak amacıyla ayrı bir gözlemci kullanıyoruz — bu, ek bir
/// arka plan görevi paketine (workmanager vb.) ihtiyaç duymadan daha sık bir
/// kontrol noktası sağlıyor.
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _cancelExpiredMedicineAlarms(uid);
      }
    }
  }
}

final _appLifecycleObserver = _AppLifecycleObserver();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // v7 API: GoogleSignIn artık singleton, initialize() runApp'ten önce tam
  // olarak bir kere tamamlanmış olmalı (bkz. login_page.dart → _signInWithGoogle,
  // initialize() bitmeden authenticate() çağrılırsa hata fırlatır).
  await GoogleSignIn.instance.initialize(serverClientId: _googleServerClientId);

  await NotificationService.init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  WidgetsBinding.instance.addObserver(_appLifecycleObserver);

  // Giriş yapılı her oturum açılışında (uygulama her başlatıldığında dahil)
  // Firestore'daki token'ı cihazın güncel token'ıyla karşılaştırıp gerekirse günceller,
  // ve süresi dolmuş ilaç alarmlarını tarar.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      _syncFcmToken(user.uid);
      _cancelExpiredMedicineAlarms(user.uid);
    }
  });

  // FCM, token'ı arka planda kendiliğinden yenileyebilir (örn. cihaz/uygulama
  // verisi sıfırlanınca değil, normal rotasyonla da olabilir) — bu durumda
  // Firestore'daki eski token güncellenmezse bildirimler "NotRegistered"
  // hatasıyla sessizce başarısız olur. Bu yüzden refresh event'ini de dinliyoruz.
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'fcmToken': newToken})
        .then((_) {
          debugPrint("🔄 FCM token refresh sonrası güncellendi (uid: $uid).");
        })
        .catchError((e) {
          debugPrint("⚠️ FCM token refresh güncellemesi başarısız: $e");
        });
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      print('Ön planda bildirim alındı: ${message.notification!.title}');
      NotificationService.showInstantNotification(
        id: DateTime.now().millisecond,
        title: message.notification!.title ?? "Sağlık Yanında",
        body: message.notification!.body ?? "Yeni bir bildiriminiz var.",
      );
    }
  });

  final prefs = await SharedPreferences.getInstance();
  final bool beniHatirla = prefs.getBool('beni_hatirla') ?? true;
  if (beniHatirla == false) {
    await FirebaseAuth.instance.signOut();
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((
    _,
  ) {
    runApp(const SaglikYanindaApp());
  });
}

class SaglikYanindaApp extends StatelessWidget {
  const SaglikYanindaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Sağlık Yanında',
      theme: buildLightTheme(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (authSnapshot.hasData && authSnapshot.data != null) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(authSnapshot.data!.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                String role = "elder";
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  var data = userSnapshot.data!.data() as Map<String, dynamic>;
                  role = data['role'] ?? "elder";
                }

                if (role == "caregiver") {
                  return const CaregiverLayout();
                } else {
                  return const MainLayout();
                }
              },
            );
          }
          return const LoginPage();
        },
      ),
      routes: {
        '/home': (context) => const MainLayout(),
        '/caregiver_home': (context) => const CaregiverLayout(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot_password': (context) => const ForgotPasswordPage(),
        '/quick_start': (context) => const QuickStartPage(),
        '/recovery_code': (context) => const RecoveryCodePage(),
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      const HomePage(),
      const CalendarPage(),
      const AddMedicinePage(),
      const NotificationsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      body: SafeArea(
        child: Column(
          children: [
            // 1. ÜST BAŞLIK BÖLÜMÜ
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "Sağlık Yanında",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4DB6AC),
                  ),
                ),
              ),
            ),

            // 2. SAYFA İÇERİKLERİ BÖLÜMÜ
            Expanded(child: _pages[_currentIndex]),

            // 3. ALT MENÜ BÖLÜMÜ
            Container(
              margin: const EdgeInsets.only(
                bottom: 12,
                left: 16,
                right: 16,
                top: 8,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.navbarBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(5, (index) {
                  bool isSelected = _currentIndex == index;
                  bool isAddButton = index == 2;
                  const iconPaths = [
                    'assets/icons/home.svg',
                    'assets/icons/calendar.svg',
                    'assets/icons/add.svg',
                    'assets/icons/notification.svg',
                    'assets/icons/profile.svg',
                  ];
                  // Her ikonun altındaki kısa etiket — ikon anlamı zaten
                  // taşıdığı için etiket sadece teyit/hatırlatma görevi
                  // görüyor, bu yüzden genel "ikincil metin ≥16sp" hedefinin
                  // istisnası: 13sp, kalın. İkon boyutu (aşağıda) değişmedi.
                  const labels = [
                    'Ana Sayfa',
                    'Takvim',
                    'Ekle',
                    'Bildirimler',
                    'Profil',
                  ];

                  // Etiket ve ikon aynı seçili/seçili-değil rengini paylaşır.
                  Color labelColor = isSelected
                      ? Colors.black
                      : AppColors.navbarInactive;

                  Widget baseIcon = SvgPicture.asset(
                    iconPaths[index],
                    colorFilter: ColorFilter.mode(
                      isAddButton ? Colors.white : labelColor,
                      BlendMode.srcIn,
                    ),
                    width: isAddButton ? 34 : 28,
                    height: isAddButton ? 34 : 28,
                  );

                  Widget finalIcon = baseIcon;

                  if (index == 3) {
                    finalIcon = StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('relations')
                          .where(
                            'elderId',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                          )
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context, snapshot) {
                        int pendingCount = 0;
                        if (snapshot.hasData) {
                          pendingCount = snapshot.data!.docs.length;
                        }

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            baseIcon,
                            if (pendingCount > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    pendingCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  }

                  // GestureDetector ikon+etiketin ikisini birden sarar —
                  // dokunma alanı büyür (yaşlı kullanıcı için daha kolay
                  // hedeflenir), etiketin de sekmeyi seçmesi sağlanır.
                  //
                  // Item'lar Expanded ile sarılı (sabit genişlik DEĞİL) —
                  // önceki sürümde her item'ın etiketi sabit 68dp genişlikte
                  // bir SizedBox'a oturuyordu: 5 item x 68dp = 340dp, bar'ın
                  // margin (32dp) + padding (24dp) çıkarılmış genişliği
                  // (ekran genişliği - 56dp) bunun altına düştüğünde
                  // (ör. Samsung A53'te ~391dp ekran -> 335dp kullanılabilir
                  // alan < 340dp) Row'un son çocuğu (Profil) RenderFlex
                  // overflow veriyordu. Emülatörün daha geniş dp genişliği
                  // bu açığı gizliyordu. Expanded, her item'ı mevcut alanın
                  // tam 1/5'ine (hangi genişlik olursa olsun) esnetir; hiçbir
                  // ekranda taşma olamaz.
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentIndex = index),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: isAddButton ? 60 : 54,
                            height: isAddButton ? 60 : 54,
                            decoration: BoxDecoration(
                              color: isAddButton
                                  ? AppColors.primary
                                  : (isSelected
                                        ? Colors.white
                                        : Colors.transparent),
                              shape: isAddButton
                                  ? BoxShape.circle
                                  : BoxShape.rectangle,
                              borderRadius: isAddButton
                                  ? null
                                  : BorderRadius.circular(16),
                              boxShadow: isSelected && !isAddButton
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : (isAddButton
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : []),
                            ),
                            child: Center(child: finalIcon),
                          ),
                          const SizedBox(height: 3),
                          // Sabit width yerine: item'ın Expanded'dan aldığı
                          // genişliğin tamamını kaplar (SizedBox(width:
                          // double.infinity)), FittedBox(scaleDown) ise
                          // "Bildirimler" gibi en uzun etiket dar bir ekranda
                          // bile sığmazsa kelimeyi kesmek (ellipsis) yerine
                          // yazı tipini orantılı küçültüp tam metni gösterir.
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                labels[index],
                                maxLines: 1,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: labelColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
