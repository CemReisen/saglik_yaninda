import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:saglik_yaninda/pages/auth/forgot_password_page.dart';
import 'package:saglik_yaninda/pages/auth/login_page.dart';
import 'package:saglik_yaninda/pages/auth/register_page.dart';

import 'core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:saglik_yaninda/pages/home_page.dart';
import 'package:saglik_yaninda/pages/calendar_page.dart';
import 'package:saglik_yaninda/pages/add_medicine_page.dart';
import 'package:saglik_yaninda/pages/notifications_page.dart';
import 'package:saglik_yaninda/pages/profile_page.dart';
import 'package:saglik_yaninda/services/notification_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.init();

  final prefs = await SharedPreferences.getInstance();
  final bool beniHatirla = prefs.getBool('beni_hatirla') ?? true;

  if (beniHatirla == false) {
    await FirebaseAuth.instance.signOut();
  }

  runApp(const SaglikYanindaApp());
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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const MainLayout();
          }

          return const LoginPage();
        },
      ),
      routes: {
        '/home': (context) => const MainLayout(),
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

  final List<Widget> _pages = const [
    HomePage(),
    CalendarPage(),
    AddMedicinePage(),
    NotificationsPage(),
    ProfilePage(),
  ];

  Future<void> requestExactAlarmPermission() async {
    const platform = MethodChannel('alarm_permission');

    try {
      await platform.invokeMethod('requestExactAlarmPermission');
    } catch (e) {
      print("EXACT ALARM izin hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),

      body: SafeArea(
        child: Stack(
          children: [
            Container(color: const Color(0xFFECEFF1)),

            Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(0, 0, 0, 0.15),
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

                Expanded(child: _pages[_currentIndex]),
              ],
            ),
          ],
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F4),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              bool isSelected = _currentIndex == index;

              const iconPaths = [
                'assets/icons/home.svg',
                'assets/icons/calendar.svg',
                'assets/icons/add.svg',
                'assets/icons/notification.svg',
                'assets/icons/profile.svg',
              ];

              final iconPath = iconPaths[index];

              return GestureDetector(
                onTap: () {
                  setState(() => _currentIndex = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4DB6AC)
                        : const Color(0xFF9E9E9E),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      iconPath,
                      colorFilter: const ColorFilter.mode(
                        Colors.black,
                        BlendMode.srcIn,
                      ),
                      width: 34,
                      height: 34,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
