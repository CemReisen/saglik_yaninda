import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(child: Text("Oturum açılmamış."));
    }

    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              "Bildirimler",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF263238),
              ),
            ),
            const SizedBox(height: 20),

            // 1. BÖLÜM: BAĞLANTI İSTEKLERİ
            Text(
              "Takip İstekleri",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF00796B),
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('relations')
                  .where('elderId', isEqualTo: currentUser.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4DB6AC)),
                  );
                }

                if (snapshot.hasError) {
                  debugPrint(
                    "⚠️ Takip istekleri sorgusu başarısız: ${snapshot.error}",
                  );
                  return _buildEmptyState(
                    Icons.error_outline,
                    "Takip istekleri yüklenemedi. Lütfen daha sonra tekrar deneyin.",
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(
                    Icons.mark_email_read_outlined,
                    "Bekleyen takip isteği yok.",
                  );
                }

                final requests = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true, // Scroll hatasını önlemek için
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    var requestDoc = requests[index];
                    String caregiverId = requestDoc['caregiverId'];
                    String docId = requestDoc.id;

                    return _buildRequestCard(context, docId, caregiverId);
                  },
                );
              },
            ),

            const SizedBox(height: 30),
            const Divider(height: 1, thickness: 1, color: Colors.black12),
            const SizedBox(height: 20),

            // 2. BÖLÜM: BUGÜNÜN İLAÇ ÖZETLERİ (SİSTEM BİLDİRİMLERİ)
            Text(
              "Sistem Kayıtları",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3949AB), // Mavi ton
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('medicines')
                  .where(
                    'lastTakenDate',
                    isEqualTo: today,
                  ) // Sadece bugün içilenler
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3949AB)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(
                    Icons.notifications_off_outlined,
                    "Bugün henüz bir ilaç bildirimi yok.",
                  );
                }

                final takenMeds = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: takenMeds.length,
                  itemBuilder: (context, index) {
                    var medData =
                        takenMeds[index].data() as Map<String, dynamic>;
                    String medName = medData['name'] ?? 'Bir ilaç';
                    String medTime =
                        "${medData['hour'].toString().padLeft(2, '0')}:${medData['minute'].toString().padLeft(2, '0')}";

                    return _buildSystemLogCard(medName, medTime);
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // YARDIMCI WIDGET: BOŞ DURUM EKRANI
  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  // YARDIMCI WIDGET: SİSTEM LOG KARTI (İçilen İlaçlar İçin)
  Widget _buildSystemLogCard(String medName, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: const Border(
          left: BorderSide(color: Color(0xFF3949AB), width: 4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3949AB).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF3949AB),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "İlaç Alındı",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF263238),
                  ),
                ),
                Text(
                  "Saat $time'da \"$medName\" ilacını içtiniz. +100 Puan!",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // BİLDİRİM KARTI (İSTEK GÖNDERENİN BİLGİLERİ VE BUTONLAR)
  Widget _buildRequestCard(
    BuildContext context,
    String docId,
    String caregiverId,
  ) {
    return FutureBuilder<DocumentSnapshot>(
      // İsteği atan bakıcının bilgilerini çekiyoruz
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverId)
          .get(),
      builder: (context, userSnapshot) {
        String caregiverName = "Bir yakınınız";

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
          String email = userData['email'] ?? "";
          caregiverName = userData['name'] ?? email.split('@').first;
          if (caregiverName.isEmpty) caregiverName = "Bir yakınınız";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFF4DB6AC).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.family_restroom,
                      color: Color(0xFF00796B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Takip İsteği",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00796B),
                          ),
                        ),
                        Text(
                          "$caregiverName sağlık durumunuzu takip etmek istiyor.",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // REDDET BUTONU
                  TextButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('relations')
                          .doc(docId)
                          .delete();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Takip isteği reddedildi."),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    child: Text(
                      "Reddet",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // KABUL ET BUTONU
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('relations')
                          .doc(docId)
                          .update({
                            'status': 'approved',
                            'approvedAt': FieldValue.serverTimestamp(),
                          });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Takip isteği onaylandı! ✅"),
                            backgroundColor: Color(0xFF4DB6AC),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4DB6AC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Kabul Et",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
