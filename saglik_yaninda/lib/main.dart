// Flutter'ın temel materyal tasarım kütüphanesini içe aktarıyoruz.
import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

// Tema dosyamızı içe aktarıyoruz. (renkler, fontlar burada tanımlı)
import 'core/theme/app_theme.dart';

//Google Fonts paketini içe aktarıyoruz.
import 'package:google_fonts/google_fonts.dart';

// Sayfalarımızı içe aktarıyoruz.
import 'package:saglik_yaninda/pages/home_page.dart';
import 'package:saglik_yaninda/pages/calendar_page.dart';
import 'package:saglik_yaninda/pages/add_medicine_page.dart';
import 'package:saglik_yaninda/pages/notifications_page.dart';
import 'package:saglik_yaninda/pages/profile_page.dart';

// Uygulamanın başlangıç noktası. main() fonksiyonu ilk burada çalışır.
void main() {
  runApp(const SaglikYanindaApp());
}

// Tüm uygulamanın ana yapısı (tema, isim, ilk sayfa)
class SaglikYanindaApp extends StatelessWidget {
  const SaglikYanindaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner:
          false, // sağ üstteki "debug" yazısını kaldırır
      title: 'Sağlık Yanında', // uygulama başlığı
      theme: buildLightTheme(), // oluşturduğumuz açık tema buradan yüklenir
      home: const MainLayout(), // uygulama açıldığında ilk gösterilecek sayfa
    );
  }
}

// Sayfalar arasında geçiş yapmayı sağlayan ana iskelet (AppBar + BottomNav)
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Şu anda hangi sayfanın açık olduğunu tutan index (0 = HomePage)
  int _currentIndex = 0;

  // Alt barda sıralanan 5 sayfamız.
  final List<Widget> _pages = const [
    HomePage(),
    CalendarPage(),
    AddMedicinePage(),
    NotificationsPage(),
    ProfilePage(),
  ];

  /*
  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.calendar_today;
      case 2:
        return Icons.add;
      case 3:
        return Icons.notifications;
      case 4:
        return Icons.person;
      default:
        return Icons.home;
    }
  }
*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // tüm ekranın zemin rengi
      backgroundColor: const Color(
        0xFFECEFF1,
      ), // burası senin body renginle aynı olacak

      body: SafeArea(
        child: Stack(
          children: [
            // 🔹 Arka plan zemini (tüm ekran)
            Container(
              color: const Color(0xFFECEFF1), // açık gri zemin, body ile aynı
            ),

            // 🔹 Asıl içerik (AppBar + sayfa gövdesi)
            Column(
              children: [
                // Üst kart gibi duran AppBar
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(
                      24,
                    ), // ✅ tüm köşeler kavisli
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

                // sayfa içeriği
                Expanded(child: _pages[_currentIndex]),
              ],
            ),
          ],
        ),
      ),

      // 🔹 Alt kısımdaki floating navbar (kart gibi duran)
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
              String iconPath = 'assets/icons/home.svg';
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = index),
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
                        Colors.black, // siyah
                        BlendMode
                            .srcIn, // sadece SVG’nin orijinal rengini siyahla doldur
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
