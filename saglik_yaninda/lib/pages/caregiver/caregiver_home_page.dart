import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // 🔥 TARİH İŞLEMLERİ İÇİN EKLENDİ

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
                    color: const Color(0xFF3949AB), // İndigo Mavisi
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

// ----- ANA SAYFA İÇERİĞİ -----
class CaregiverHomePage extends StatelessWidget {
  const CaregiverHomePage({super.key});

  // 🔥 TARİH YARDIMCI FONKSİYONLARI
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String firstName = user?.displayName?.split(' ').first ?? "Kullanıcı";

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
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

          // YAKINIMI EKLE BUTONU
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

          // 🔥 CANLI VERİ (STREAMBUILDER) BURADA BAŞLIYOR
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('relations')
                .where('caregiverId', isEqualTo: user?.uid)
                .where(
                  'status',
                  isEqualTo: 'approved',
                ) // Sadece ONAYLANMIŞ olanlar
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF3949AB)),
                );
              }

              int relationCount = snapshot.hasData
                  ? snapshot.data!.docs.length
                  : 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LİSTE BAŞLIĞI
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3949AB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "$relationCount Kişi",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF3949AB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // EĞER KİMSE YOKSA BOŞ EKRAN GÖSTER
                  if (relationCount == 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.family_restroom,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Henüz onaylanmış bir takibiniz yok.",
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    )
                  // EĞER VARSA KARTLARI LİSTELE
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: relationCount,
                      itemBuilder: (context, index) {
                        String elderId = snapshot.data!.docs[index]['elderId'];
                        return _buildElderCard(elderId);
                      },
                    ),

                  const SizedBox(height: 40), // Alt boşluk
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // 🔥 HER BİR YAŞLI İÇİN CANLI KART VİDGETI (İSTATİSTİKLİ VERSİYON)
  Widget _buildElderCard(String elderId) {
    return StreamBuilder<DocumentSnapshot>(
      // 1. Yaşlının ana bilgilerini çekiyoruz (İsim, Puan)
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(elderId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const SizedBox.shrink(); // Veri yoksa boş döndür
        }

        var elderData = userSnapshot.data!.data() as Map<String, dynamic>;

        String name = "Bir yakınınız";
        String email = elderData['email'] ?? "";
        if (elderData['name'] != null &&
            elderData['name'].toString().trim().isNotEmpty) {
          name = elderData['name'];
        } else if (email.isNotEmpty) {
          name = email.split('@').first;
        }

        int score = elderData['totalScore'] ?? 0;

        // 2. Yaşlının İlaç Koleksiyonunu Dinliyoruz
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(elderId)
              .collection('medicines')
              .snapshots(),
          builder: (context, medSnapshot) {
            int totalMeds = 0;
            int takenMeds = 0;

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

              var todaysMedicines = allDocs.where((doc) {
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
                var data = doc.data() as Map<String, dynamic>;
                return data['lastTakenDate'] == today;
              }).length;
            }

            double progress = totalMeds == 0 ? 0.0 : (takenMeds / totalMeds);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF3949AB).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ÜST KISIM: Profil Resmi, İsim ve Puan
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3949AB).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            name[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3949AB),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // İsim
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF263238),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Sağlık Durumu",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Puan Rozeti
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFFF57C00),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$score",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF57C00),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(height: 1, thickness: 0.5),
                  ),

                  // ALT KISIM: İlaç İlerleme Çubuğu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Bugünkü İlaç Durumu",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF37474F),
                        ),
                      ),
                      Text(
                        "$takenMeds / $totalMeds",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: totalMeds > 0 && takenMeds == totalMeds
                              ? const Color(0xFF4DB6AC)
                              : const Color(0xFF3949AB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // İlerleme Barı (Linear Progress)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        totalMeds > 0 && takenMeds == totalMeds
                            ? const Color(0xFF4DB6AC)
                            : const Color(0xFF3949AB),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    totalMeds == 0
                        ? "Bugün kayıtlı ilaç bulunmuyor."
                        : (takenMeds == totalMeds
                              ? "Harika! Bugün tüm ilaçlar içilmiş. 🎉"
                              : "İçilmesi gereken ilaçlar var. 🕒"),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
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

  // BAĞLANTI KODU GİRME DİYALOĞU
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
                    style: TextStyle(color: Colors.grey),
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

                            var userQuery = await FirebaseFirestore.instance
                                .collection('users')
                                .where('connectionCode', isEqualTo: enteredCode)
                                .where('role', isEqualTo: 'elder')
                                .get();

                            if (userQuery.docs.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Geçersiz kod veya kullanıcı bulunamadı! ❌",
                                  ),
                                ),
                              );
                              setStateDialog(() => isRequesting = false);
                              return;
                            }

                            String elderId = userQuery.docs.first.id;

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

                            var relationQuery = await FirebaseFirestore.instance
                                .collection('relations')
                                .where('caregiverId', isEqualTo: currentUserId)
                                .where('elderId', isEqualTo: elderId)
                                .get();

                            if (relationQuery.docs.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Bu kişiye zaten bir istek gönderdiniz veya takip ediyorsunuz. ⚠️",
                                  ),
                                ),
                              );
                              setStateDialog(() => isRequesting = false);
                              return;
                            }

                            await FirebaseFirestore.instance
                                .collection('relations')
                                .add({
                                  'caregiverId': currentUserId,
                                  'elderId': elderId,
                                  'status': 'pending',
                                  'createdAt': FieldValue.serverTimestamp(),
                                });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "İstek başarıyla gönderildi! Karşı tarafın onayı bekleniyor. ✅",
                                  ),
                                  backgroundColor: Color(0xFF3949AB),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Bir hata oluştu: $e")),
                            );
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
                      : const Text("İstek Gönder"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ----- BAKICI PROFİL SAYFASI (GÜNCELLENDİ) -----
class CaregiverProfilePage extends StatelessWidget {
  const CaregiverProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return const SizedBox();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // PROFİL BİLGİLERİ (ÜST KISIM)
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
            currentUser.displayName ?? "Bakıcı Hesabı",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF263238),
            ),
          ),
          Text(
            currentUser.email ?? "",
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),

          // TAKİP EDİLENLERİ YÖNETME (ORTA KISIM)
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(
                  color: Color(0xFF3949AB),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "Henüz kimseyi takip etmiyorsunuz.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 13,
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
                      if (!userSnapshot.hasData) return const SizedBox();
                      var elderData =
                          userSnapshot.data!.data() as Map<String, dynamic>?;
                      if (elderData == null) return const SizedBox();

                      String elderName =
                          elderData['name'] ??
                          elderData['email'] ??
                          "Bilinmeyen Kullanıcı";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
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
                              color: Colors.green[600],
                              fontSize: 12,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.person_remove_rounded,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              // Takipten Çıkma İşlemi
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
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        "İptal",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await FirebaseFirestore.instance
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
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      child: const Text(
                                        "Çıkar",
                                        style: TextStyle(color: Colors.white),
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

          const SizedBox(height: 48),

          // ÇIKIŞ YAP BUTONU (HAYALET BİLDİRİM FİX'İ İLE)
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () async {
                // 🔥 ÇIKIŞ YAPMADAN ÖNCE BİLDİRİM TOKEN'INI SİLİYORUZ (Hayalet Bildirimleri Önler)
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .update({'fcmToken': ''});

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
                elevation: 4,
                shadowColor: const Color(0xFFEF5350).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
