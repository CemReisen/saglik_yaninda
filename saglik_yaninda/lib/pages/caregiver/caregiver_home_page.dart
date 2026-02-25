import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      const Center(
        child: Text("Profil Sayfası Yapım Aşamasında"),
      ), // İleride eklenecek
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      body: SafeArea(
        child: Column(
          children: [
            // Üst Başlık
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
                  "Aile Takip Paneli",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: const Color(
                      0xFF3949AB,
                    ), // Yaşlıların Mint Yeşili yerine İndigo Mavisi
                  ),
                ),
              ),
            ),
            Expanded(child: _pages[_currentIndex]),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom > 0 ? 10 : 16,
          left: 16,
          right: 16,
        ),
        child: Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Ana Sayfa İkonu
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _currentIndex == 0
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _currentIndex == 0
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/home.svg',
                      colorFilter: ColorFilter.mode(
                        _currentIndex == 0
                            ? Colors.black
                            : const Color(0xFF9E9E9E),
                        BlendMode.srcIn,
                      ),
                      width: 28,
                      height: 28,
                    ),
                  ),
                ),
              ),
              // Profil / Ayarlar İkonu
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _currentIndex == 1
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _currentIndex == 1
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/profile.svg',
                      colorFilter: ColorFilter.mode(
                        _currentIndex == 1
                            ? Colors.black
                            : const Color(0xFF9E9E9E),
                        BlendMode.srcIn,
                      ),
                      width: 28,
                      height: 28,
                    ),
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

//ANA SAYFA İÇERİĞİ
class CaregiverHomePage extends StatelessWidget {
  const CaregiverHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String firstName = user?.displayName?.split(' ').first ?? "Kullanıcı";

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            "Hoş Geldin, $firstName",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF263238),
            ),
          ),
          Text(
            "Yakınlarının sağlık durumu kontrol altında.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.blueGrey[400],
            ),
          ),
          const SizedBox(height: 30),

          //YAKINIMI EKLE BUTONU
          GestureDetector(
            onTap: () {
              _showAddRelativeDialog(context);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5C6BC0), Color(0xFF3949AB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3949AB).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Yeni Yakın Ekle",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Bağlantı kodunu girerek takibe başla",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          //TAKİP EDİLENLER LİSTESİ BAŞLIĞI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Takip Ettiğim Kişiler",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF37474F),
                ),
              ),
              Text(
                "0 Kişi",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3949AB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          //BOŞ DURUM (EMPTY STATE)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Icon(Icons.family_restroom, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  "Henüz kimseyi takip etmiyorsunuz.",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // BAĞLANTI KODU GİRME DİYALOĞU
  void _showAddRelativeDialog(BuildContext context) {
    TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            "Yakın Ekle",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Takip etmek istediğiniz kişinin profilinde yazan 6 haneli kodu giriniz.",
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                maxLength: 7, // Örn: AX7-B92
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
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
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                // Şimdilik sadece uyarı veriyoruz, haftaya buranın Firestore kodlarını yazacağız.
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Bağlantı isteği gönderildi! (Altyapı haftaya eklenecek)",
                    ),
                    backgroundColor: Color(0xFF3949AB),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3949AB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("İstek Gönder"),
            ),
          ],
        );
      },
    );
  }
}
