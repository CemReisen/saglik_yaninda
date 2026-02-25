import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saglik_yaninda/services/notification_service.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = FirebaseAuth.instance.currentUser;

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

  String _getFullDisplayDate() {
    DateTime now = DateTime.now();
    List<String> months = [
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık",
    ];
    List<String> days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    return "${now.day} ${months[now.month - 1]} ${now.year}, ${days[now.weekday - 1]}";
  }

  String _getShortDayName() {
    List<String> weekDays = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
    return weekDays[DateTime.now().weekday - 1];
  }

  Future<void> _toggleTaken(
    String docId,
    bool currentStatus,
    String today,
  ) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid);
    final medRef = userRef.collection('medicines').doc(docId);

    if (currentStatus) {
      await medRef.update({'lastTakenDate': ""});
      await userRef.set({
        'totalScore': FieldValue.increment(-100),
      }, SetOptions(merge: true));
    } else {
      await medRef.update({'lastTakenDate': today});
      await userRef.set({
        'totalScore': FieldValue.increment(100),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Harika! 100 Sağlık Puanı Kazandın."),
            backgroundColor: Color(0xFF4DB6AC),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  QueryDocumentSnapshot? _getNextMedicine(
    List<QueryDocumentSnapshot> medicines,
    String today,
  ) {
    if (medicines.isEmpty) return null;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    List<QueryDocumentSnapshot> futureMeds = [];
    for (var doc in medicines) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['lastTakenDate'] == today) continue;
      int medMinutes = (data['hour'] ?? 0) * 60 + (data['minute'] ?? 0);
      if (medMinutes > currentMinutes) futureMeds.add(doc);
    }
    if (futureMeds.isEmpty) return null;
    futureMeds.sort((a, b) {
      var dataA = a.data() as Map<String, dynamic>;
      var dataB = b.data() as Map<String, dynamic>;
      return ((dataA['hour'] as int) * 60 + (dataA['minute'] as int)).compareTo(
        (dataB['hour'] as int) * 60 + (dataB['minute'] as int),
      );
    });
    return futureMeds.first;
  }

  void _showDeleteConfirmDialog(String docId, int notificationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("İlacı Sil"),
          ],
        ),
        content: const Text("Bu ilacı kalıcı olarak silmek istiyor musunuz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              _deleteMedicine(docId, notificationId);
            },
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMedicine(String docId, int notificationId) async {
    try {
      await NotificationService.cancelNotification(notificationId);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('medicines')
          .doc(docId)
          .delete();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("İlaç silindi")));
    } catch (e) {
      debugPrint("Hata: $e");
    }
  }

  void _showEditDialog(Map<String, dynamic> data, String docId) {
    TextEditingController nameCtrl = TextEditingController(text: data['name']);
    TextEditingController doseCtrl = TextEditingController(text: data['dose']);
    TextEditingController descCtrl = TextEditingController(
      text: data['description'],
    );
    TimeOfDay selectedTime = TimeOfDay(
      hour: data['hour'],
      minute: data['minute'],
    );
    String selectedHunger = data['hungerStatus'] ?? "Tok Karnına";
    bool isCritical = data['isCritical'] ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFF4DB6AC), size: 28),
              SizedBox(width: 10),
              Text(
                "İlacı Düzenle",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  cursorColor: const Color(0xFF4DB6AC),
                  decoration: const InputDecoration(
                    labelText: "İlaç Adı",
                    labelStyle: TextStyle(color: Colors.grey),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4DB6AC)),
                    ),
                    prefixIcon: Icon(
                      Icons.medication,
                      color: Color(0xFF4DB6AC),
                    ),
                  ),
                ),
                TextField(
                  controller: doseCtrl,
                  cursorColor: const Color(0xFF4DB6AC),
                  decoration: const InputDecoration(
                    labelText: "Doz",
                    labelStyle: TextStyle(color: Colors.grey),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4DB6AC)),
                    ),
                    prefixIcon: Icon(
                      Icons.local_pharmacy,
                      color: Color(0xFF4DB6AC),
                    ),
                  ),
                ),
                TextField(
                  controller: descCtrl,
                  cursorColor: const Color(0xFF4DB6AC),
                  decoration: const InputDecoration(
                    labelText: "Notlar",
                    labelStyle: TextStyle(color: Colors.grey),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4DB6AC)),
                    ),
                    prefixIcon: Icon(Icons.notes, color: Color(0xFF4DB6AC)),
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Kullanım Şekli",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    DropdownButton<String>(
                      value: selectedHunger,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF4DB6AC),
                      ),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      underline: Container(
                        height: 2,
                        color: const Color(0xFF4DB6AC),
                      ),
                      items: ["Tok Karnına", "Aç Karnına", "Farketmez"].map((
                        val,
                      ) {
                        return DropdownMenuItem(
                          value: val,
                          child: Text(
                            val,
                            style: TextStyle(
                              color: val == selectedHunger
                                  ? const Color(0xFF4DB6AC)
                                  : Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setStateDialog(() => selectedHunger = val!),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF4DB6AC),
                  title: const Text(
                    "Kritik İlaç",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  value: isCritical,
                  onChanged: (val) => setStateDialog(() => isCritical = val),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Saat: ${selectedTime.format(context)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF4DB6AC),
                                onPrimary: Colors.white,
                                onSurface: Colors.black87,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null)
                        setStateDialog(() => selectedTime = picked);
                    },
                    child: const Text(
                      "Değiştir",
                      style: TextStyle(
                        color: Color(0xFF4DB6AC),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "İptal",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4DB6AC),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('medicines')
                    .doc(docId)
                    .update({
                      'name': nameCtrl.text.trim(),
                      'dose': doseCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'hungerStatus': selectedHunger,
                      'isCritical': isCritical,
                      'hour': selectedTime.hour,
                      'minute': selectedTime.minute,
                    });
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                "Kaydet",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMedicineDetails(Map<String, dynamic> data, String docId) {
    String name = data['name'] ?? 'İsimsiz İlaç';
    bool isCritical = data['isCritical'] ?? false;
    String formattedTime =
        "${(data['hour'] ?? 0).toString().padLeft(2, '0')}:${(data['minute'] ?? 0).toString().padLeft(2, '0')}";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCritical
                    ? Colors.red.withOpacity(0.1)
                    : const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCritical ? Icons.warning_amber_rounded : Icons.info_outline,
                color: isCritical ? Colors.red : const Color(0xFF009688),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCritical)
                Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: Colors.red),
                      SizedBox(width: 5),
                      const Text(
                        "Bu ilaç KRİTİK seviyededir!",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  _buildDetailBox(Icons.access_time, formattedTime, "Saat"),
                  const SizedBox(width: 10),
                  _buildDetailBox(Icons.medication, data['dose'] ?? '', "Doz"),
                ],
              ),
              const SizedBox(height: 15),
              _buildInfoRow(
                Icons.update,
                "Tekrar:",
                data['repeatType'] == "Her Gün"
                    ? "Her Gün"
                    : (data['days'] as List?)?.join(", ") ?? "",
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.date_range,
                "Tarih:",
                "${data['startDate']} - ${data['endDate']}",
              ),
              const SizedBox(height: 15),
              Text(
                "Notlar:",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  data['description'] ?? "Not eklenmemiş.",
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _showDeleteConfirmDialog(
                    docId,
                    data['notificationId'] ?? 0,
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                      Text(
                        "Sil",
                        style: TextStyle(color: Colors.redAccent, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 25),
                InkWell(
                  onTap: () => _showEditDialog(data, docId),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: Colors.blueGrey, size: 22),
                      Text(
                        "Düzenle",
                        style: TextStyle(color: Colors.blueGrey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4DB6AC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Tamam",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBox(IconData icon, String text, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4DB6AC)),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    ),
  );

  Widget _buildInfoRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: Colors.grey),
      const SizedBox(width: 8),
      Text("$label ", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    ],
  );

  Widget _buildProgressCard(int total, int taken) {
    if (total == 0) return const SizedBox();
    double progress = taken / total;
    int hour = DateTime.now().hour;
    String greeting = (hour >= 6 && hour < 12)
        ? "Günaydın! ☀️"
        : (hour >= 12 && hour < 18)
        ? "İyi Günler! 🌤️"
        : (hour >= 18 && hour < 22)
        ? "İyi Akşamlar! 🌆"
        : "İyi Geceler! 🌙";
    String message = (progress == 0)
        ? "$greeting İlaçlarını almayı unutma."
        : (progress == 1.0)
        ? "Tebrikler! Günlük hedefin bitti. 🎉"
        : "Güzel başlangıç, devam et! 🚀";

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4DB6AC), Color(0xFF009688)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4DB6AC).withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Günlük Durum",
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$taken / $total",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextDoseCard(Map<String, dynamic>? nextMed, String? docId) {
    if (nextMed == null || docId == null) return const SizedBox();
    String formattedTime =
        "${nextMed['hour'].toString().padLeft(2, '0')}:${nextMed['minute'].toString().padLeft(2, '0')}";
    return InkWell(
      onTap: () => _showMedicineDetails(nextMed, docId),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sıradaki İlacınız",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    nextMed['name'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "${nextMed['dose']} • Saat $formattedTime",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Giriş Yapılmalı"));
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String rawName =
        user!.displayName ?? user!.email?.split('@').first ?? "Kullanıcı";
    String firstName = rawName.trim().split(' ').first;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('medicines')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var allMedicines = snapshot.data!.docs;
        String todayName = _getShortDayName();
        final todayDate = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );

        var todaysMedicines = allMedicines.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          DateTime? start = _parseDate(data['startDate'] ?? '');
          DateTime? end = _parseDate(data['endDate'] ?? '');
          if (start != null &&
              end != null &&
              (todayDate.isBefore(start) || todayDate.isAfter(end)))
            return false;
          String repeat = data['repeatType'] ?? 'daily';
          return (repeat == 'daily' ||
              repeat == 'Her Gün' ||
              (data['days'] as List?)?.contains(todayName) == true);
        }).toList();

        todaysMedicines.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;
          return ((dataA['hour'] as int) * 60 + (dataA['minute'] as int))
              .compareTo(
                (dataB['hour'] as int) * 60 + (dataB['minute'] as int),
              );
        });

        int totalCount = todaysMedicines.length;
        int takenCount = todaysMedicines
            .where(
              (doc) =>
                  (doc.data() as Map<String, dynamic>)['lastTakenDate'] ==
                  today,
            )
            .length;
        var nextMedDoc = _getNextMedicine(todaysMedicines, today);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: const Border(
                    left: BorderSide(color: Color(0xFF4DB6AC), width: 4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Merhaba $firstName,",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.blueGrey[300],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            "Bugünün Planı",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF263238),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: Color(0xFF4DB6AC),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _getFullDisplayDate(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF00695C),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEAF5F4),
                        border: Border.all(
                          color: const Color(0xFF4DB6AC).withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          firstName.isNotEmpty
                              ? firstName[0].toUpperCase()
                              : "E",
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00695C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildProgressCard(totalCount, takenCount),
            _buildNextDoseCard(
              nextMedDoc?.data() as Map<String, dynamic>?,
              nextMedDoc?.id,
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5C6BC0), Color(0xFF3949AB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A237E).withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "İlaç Listesi",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "$totalCount İlaç",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F9),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: todaysMedicines.isEmpty
                              ? const Center(child: Text("Bugünlük ilaç yok!"))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: todaysMedicines.length,
                                  itemBuilder: (context, index) {
                                    var medicine = todaysMedicines[index];
                                    var data =
                                        medicine.data() as Map<String, dynamic>;
                                    bool isTakenToday =
                                        data['lastTakenDate'] == today;
                                    bool isCritical =
                                        data['isCritical'] ?? false;
                                    String time =
                                        "${data['hour'].toString().padLeft(2, '0')}:${data['minute'].toString().padLeft(2, '0')}";
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: isTakenToday
                                            ? const Color(0xFF5C6BC0)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isTakenToday
                                                ? const Color(
                                                    0xFF3949AB,
                                                  ).withOpacity(0.3)
                                                : Colors.black.withOpacity(
                                                    0.04,
                                                  ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isTakenToday
                                                    ? Colors.white.withOpacity(
                                                        0.15,
                                                      )
                                                    : const Color(0xFFE8EAF6),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                time,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isTakenToday
                                                      ? Colors.white
                                                      : const Color(0xFF3F51B5),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 15),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      if (isCritical)
                                                        Icon(
                                                          Icons
                                                              .warning_amber_rounded,
                                                          size: 16,
                                                          color: isTakenToday
                                                              ? Colors.white70
                                                              : Colors.red,
                                                        ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          data['name'] ?? '',
                                                          style: GoogleFonts.poppins(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16,
                                                            decoration:
                                                                isTakenToday
                                                                ? TextDecoration
                                                                      .lineThrough
                                                                : null,
                                                            color: isTakenToday
                                                                ? Colors.white
                                                                : (isCritical
                                                                      ? Colors
                                                                            .red[700]
                                                                      : Colors
                                                                            .black87),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    "${data['dose'] ?? ''} • ${data['hungerStatus'] ?? ''}",
                                                    style: TextStyle(
                                                      color: isTakenToday
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.7,
                                                                )
                                                          : Colors.grey[500],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _showMedicineDetails(
                                                    data,
                                                    medicine.id,
                                                  ),
                                              icon: Icon(
                                                Icons.info_outline,
                                                color: isTakenToday
                                                    ? Colors.white70
                                                    : const Color(0xFF5C6BC0),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => _toggleTaken(
                                                medicine.id,
                                                isTakenToday,
                                                today,
                                              ),
                                              child: Icon(
                                                isTakenToday
                                                    ? Icons.check_circle
                                                    : Icons
                                                          .radio_button_unchecked,
                                                color: isTakenToday
                                                    ? Colors.white
                                                    : const Color(0xFF5C6BC0),
                                                size: 28,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
