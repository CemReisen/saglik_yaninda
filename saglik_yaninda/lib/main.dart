import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:saglik_yaninda/services/notification_service.dart';
import 'package:saglik_yaninda/pages/caregiver/caregiver_home_page.dart';
import 'core/theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Arka planda bildirim geldi: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F4),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                  Widget baseIcon = SvgPicture.asset(
                    iconPaths[index],
                    colorFilter: ColorFilter.mode(
                      isAddButton
                          ? Colors.white
                          : (isSelected
                                ? Colors.black
                                : const Color(0xFF9E9E9E)),
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

                  return GestureDetector(
                    onTap: () => setState(() => _currentIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: isAddButton ? 60 : 54,
                      height: isAddButton ? 60 : 54,
                      decoration: BoxDecoration(
                        color: isAddButton
                            ? const Color(0xFF4DB6AC)
                            : (isSelected ? Colors.white : Colors.transparent),
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
                                        color: const Color(
                                          0xFF4DB6AC,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : []),
                      ),
                      child: Center(child: finalIcon),
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
