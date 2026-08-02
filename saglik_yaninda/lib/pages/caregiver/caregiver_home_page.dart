import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart'; // 🔥 EFSANE ANİMASYON PAKETİ EKLENDİ

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
                onTap: () => setState(() => _currentIndex = 0),
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
                onTap: () => setState(() => _currentIndex = 1),
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

class CaregiverHomePage extends StatelessWidget {
  const CaregiverHomePage({super.key});

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
                fontSize: 14,
                fontWeight: isTaken ? FontWeight.w500 : FontWeight.w600,
                color: isTaken ? Colors.grey.shade500 : const Color(0xFF263238),
                decoration: isTaken ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            medTime,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isTaken ? Colors.grey.shade400 : const Color(0xFF3949AB),
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

        if (caregiverSnap.hasData && caregiverSnap.data!.exists) {
          var data = caregiverSnap.data!.data() as Map<String, dynamic>;
          String fullName =
              data['name']?.toString().trim() ??
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
                  InkWell(
                    onTap: () => _showAddRelativeDialog(context),
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
                            color: const Color(0xFF3949AB).withOpacity(0.3),
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
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                color: Colors.grey[500],
                                fontSize: 15,
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
                      return _buildElderCard(context, elderId);
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

  Widget _buildElderCard(BuildContext context, String elderId) {
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

            return Container(
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
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
                      if (totalMeds > 0 && takenMeds < totalMeds) ...[
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () {
                            final currentUser =
                                FirebaseAuth.instance.currentUser;
                            String caregiverName =
                                currentUser?.displayName ?? "Yakınınız";
                            _sendNudgeNotification(
                              context,
                              elderId,
                              caregiverName,
                            );
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
                        ),
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

class CaregiverProfilePage extends StatelessWidget {
  const CaregiverProfilePage({super.key});

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
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
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

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                              userSnapshot.data!.data()
                                  as Map<String, dynamic>?;
                          if (elderData == null) return const SizedBox();

                          String elderName =
                              elderData['name'] ??
                              elderData['email'] ??
                              "Kullanıcı";

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
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () async {
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
