import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saglik_yaninda/services/notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // 1. KISA GÜN ADI
  String _getShortDayName() {
    List<String> weekDays = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
    return weekDays[DateTime.now().weekday - 1];
  }

  // 2. TAM TARİH
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
        ).showSnackBar(const SnackBar(content: Text("İlaç silindi 🗑️")));
    } catch (e) {
      debugPrint("Hata: $e");
    }
  }

  Future<void> _toggleTaken(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('medicines')
        .doc(docId)
        .update({'isTaken': !currentStatus});
  }

  // 🔥 YENİ FONKSİYON: İLAÇ DÜZENLEME EKRANI
  // 🔥 TAM KAPSAMLI VE RENKLİ DÜZENLEME EKRANI
  void _showEditDialog(Map<String, dynamic> data, String docId) {
    TextEditingController nameCtrl = TextEditingController(text: data['name']);
    TextEditingController doseCtrl = TextEditingController(text: data['dose']);
    TextEditingController descCtrl = TextEditingController(
      text: data['description'],
    );

    int hour = data['hour'];
    int minute = data['minute'];
    TimeOfDay selectedTime = TimeOfDay(hour: hour, minute: minute);

    String selectedHunger = data['hungerStatus'] ?? "Tok Karnına";
    String selectedNotif = data['notificationType'] ?? "Standart";
    bool isCritical = data['isCritical'] ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
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
                    // 1. İLAÇ ADI
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
                    const SizedBox(height: 10),

                    // 2. DOZ
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
                    const SizedBox(height: 10),

                    // 3. NOTLAR
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

                    const SizedBox(height: 25),

                    // 4. KULLANIM (AÇ/TOK) - RENKLENDİRİLDİ 🟢
                    Row(
                      children: [
                        const Icon(
                          Icons.restaurant,
                          color: Color(0xFF4DB6AC),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Kullanım:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<String>(
                            value: selectedHunger,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF4DB6AC),
                            ), // Yeşil Ok
                            underline: Container(
                              height: 1.5,
                              color: const Color(0xFF4DB6AC).withOpacity(0.5),
                            ), // Yeşil Çizgi
                            dropdownColor: Colors.white,
                            items: ["Tok Karnına", "Aç Karnına", "Farketmez"]
                                .map((String val) {
                                  bool isSelected = val == selectedHunger;
                                  return DropdownMenuItem(
                                    value: val,
                                    child: Text(
                                      val,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF4DB6AC)
                                            : Colors
                                                  .black87, // Seçili olan Yeşil
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                            onChanged: (val) {
                              setStateDialog(() => selectedHunger = val!);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 5. BİLDİRİM TİPİ - RENKLENDİRİLDİ 🟢
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active,
                          color: Color(0xFF4DB6AC),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Bildirim:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<String>(
                            value: selectedNotif,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF4DB6AC),
                            ), // Yeşil Ok
                            underline: Container(
                              height: 1.5,
                              color: const Color(0xFF4DB6AC).withOpacity(0.5),
                            ), // Yeşil Çizgi
                            dropdownColor: Colors.white,
                            items: ["Standart", "Sessiz", "Alarm"].map((
                              String val,
                            ) {
                              bool isSelected = val == selectedNotif;
                              return DropdownMenuItem(
                                value: val,
                                child: Text(
                                  val,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF4DB6AC)
                                        : Colors.black87, // Seçili olan Yeşil
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setStateDialog(() => selectedNotif = val!);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 6. KRİTİK İLAÇ
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.redAccent,
                      title: const Text(
                        "Kritik İlaç",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      value: isCritical,
                      onChanged: (val) {
                        setStateDialog(() => isCritical = val);
                      },
                    ),

                    const Divider(),

                    // 7. SAAT DEĞİŞTİRME
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.access_time_filled,
                          color: Color(0xFF00695C),
                        ),
                      ),
                      title: Text(
                        "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      trailing: TextButton(
                        child: const Text(
                          "Değiştir",
                          style: TextStyle(
                            color: Color(0xFF4DB6AC),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  primaryColor: const Color(0xFF4DB6AC),
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF4DB6AC),
                                  ),
                                  buttonTheme: const ButtonThemeData(
                                    textTheme: ButtonTextTheme.primary,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              selectedTime = picked;
                            });
                          }
                        },
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
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4DB6AC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                          'notificationType': selectedNotif,
                          'isCritical': isCritical,
                          'hour': selectedTime.hour,
                          'minute': selectedTime.minute,
                        });

                    if (mounted) {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("İlaç bilgileri güncellendi! ✅"),
                        ),
                      );
                    }
                  },
                  child: const Text("Kaydet"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // DETAY PENCERESİ
  // 🔥 GÜNCELLENMİŞ DETAY PENCERESİ (SİL BUTONU EKLENDİ)
  void _showMedicineDetails(Map<String, dynamic> data, String docId) {
    String name = data['name'] ?? 'İsimsiz İlaç';
    String description = data['description'] ?? 'Açıklama yok.';
    String dose = data['dose'] ?? 'Belirtilmemiş';
    String hungerStatus = data['hungerStatus'] ?? 'Belirtilmemiş';
    bool isCritical = data['isCritical'] ?? false;
    String notificationType = data['notificationType'] ?? 'Standart';
    String repeatType = data['repeatType'] ?? 'Her Gün';
    List<dynamic> days = data['days'] ?? [];
    int hour = data['hour'] ?? 0;
    int minute = data['minute'] ?? 0;
    int notificationId = data['notificationId'] ?? 0; // Silme için lazım
    String formattedTime =
        "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
    String startDate = data['startDate'] ?? '-';
    String endDate = data['endDate'] ?? '-';
    String daysText = repeatType == "Her Gün" ? "Her Gün" : days.join(", ");

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                        Text(
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
                    _buildDetailBox(Icons.medication, dose, "Doz"),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildDetailBox(Icons.restaurant, hungerStatus, "Kullanım"),
                    const SizedBox(width: 10),
                    _buildDetailBox(
                      notificationType == "Sessiz"
                          ? Icons.notifications_off
                          : (notificationType == "Alarm"
                                ? Icons.access_alarm
                                : Icons.notifications_active),
                      notificationType,
                      "Bildirim",
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoRow(Icons.update, "Tekrar:", daysText),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.date_range,
                  "Tarih:",
                  "$startDate - $endDate",
                ),
                const SizedBox(height: 20),
                Text(
                  "Notlar:",
                  style: GoogleFonts.poppins(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    description.isEmpty ? "Not eklenmemiş." : description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // 🔥 SİL BUTONU (KIRMIZI)
            TextButton(
              onPressed: () {
                // Silme Onay Kutusu
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("İlacı Sil"),
                    content: const Text(
                      "Bu ilacı kalıcı olarak silmek istiyor musunuz?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Vazgeç"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Onay kutusunu kapat
                          Navigator.pop(context); // Detay kutusunu kapat
                          _deleteMedicine(docId, notificationId); // Sil
                        },
                        child: const Text(
                          "Sil",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: const Column(
                children: [
                  Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  Text(
                    "Sil",
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ),
            ),

            const Spacer(), // Araya boşluk atar
            // DÜZENLE BUTONU
            TextButton(
              onPressed: () => _showEditDialog(data, docId),
              child: const Column(
                children: [
                  Icon(Icons.edit, color: Colors.blueGrey, size: 20),
                  Text(
                    "Düzenle",
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                  ),
                ],
              ),
            ),

            // TAMAM BUTONU
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4DB6AC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
              ),
              child: const Text(
                "Tamam",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
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
    String greeting = "";
    if (hour >= 6 && hour < 12)
      greeting = "Günaydın! ☀️";
    else if (hour >= 12 && hour < 18)
      greeting = "İyi Günler! 🌤️";
    else if (hour >= 18 && hour < 22)
      greeting = "İyi Akşamlar! 🌆";
    else
      greeting = "İyi Geceler! 🌙";

    String message = "$greeting İlaçlarını almayı unutma.";
    if (progress > 0 && progress < 0.5)
      message = "Güzel başlangıç, devam et! 🚀";
    else if (progress >= 0.5 && progress < 1.0)
      message = "Yarıladın! Harika gidiyorsun. 💪";
    else if (progress == 1.0)
      message = "Tebrikler! Günlük hedefin bitti. 🎉";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          const SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Giriş Yapılmalı"));
    String todayShortName = _getShortDayName();
    String displayDate = _getFullDisplayDate();

    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('medicines')
            .orderBy('hour')
            .orderBy('minute')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          var allMedicines = snapshot.data?.docs ?? [];
          var todaysMedicines = allMedicines.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String repeatType = data['repeatType'] ?? 'daily';
            List<dynamic> days = data['days'] ?? [];
            if (repeatType == 'daily' || repeatType == 'Her Gün') return true;
            if (days.contains(todayShortName)) return true;
            return false;
          }).toList();

          int totalCount = todaysMedicines.length;
          int takenCount = todaysMedicines
              .where((doc) => (doc.data() as Map)['isTaken'] == true)
              .length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 5),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bugünün İlaçları",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF263238),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              size: 16,
                              color: Color(0xFF4DB6AC),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              displayDate,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (totalCount > 0) _buildProgressCard(totalCount, takenCount),
              Expanded(
                child: todaysMedicines.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        itemCount: todaysMedicines.length,
                        itemBuilder: (context, index) {
                          var medicine = todaysMedicines[index];
                          var data = medicine.data() as Map<String, dynamic>;
                          String name = data['name'] ?? '';
                          String dose = data['dose'] ?? '';
                          int hour = data['hour'] ?? 0;
                          int minute = data['minute'] ?? 0;
                          int notificationId = data['notificationId'] ?? 0;
                          bool isTaken = data['isTaken'] ?? false;
                          bool isCritical = data['isCritical'] ?? false;
                          String hungerStatus = data['hungerStatus'] ?? '';
                          String formattedTime =
                              "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

                          return Card(
                            elevation: 2,
                            surfaceTintColor: Colors.transparent,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: isTaken
                                ? const Color(0xFFE8F5E9)
                                : Colors.white,

                            child: Padding(
                              // InkWell yerine Padding kullandık, butonlar ayrı çalışsın
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                12,
                              ),
                              child: Row(
                                children: [
                                  // SAAT KUTUSU
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isTaken
                                          ? const Color(0xFFA5D6A7)
                                          : const Color(0xFFE0F2F1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isTaken
                                            ? Colors.green
                                            : const Color(0xFFB2DFDB),
                                      ),
                                    ),
                                    child: Text(
                                      formattedTime,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isTaken
                                            ? Colors.green[800]
                                            : const Color(0xFF00695C),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // İSİM VE DETAYLAR
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (isCritical)
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                child: Icon(
                                                  Icons.warning_amber_rounded,
                                                  size: 16,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  decoration: isTaken
                                                      ? TextDecoration
                                                            .lineThrough
                                                      : null,
                                                  color: isTaken
                                                      ? Colors.grey[600]
                                                      : (isCritical
                                                            ? Colors.red[700]
                                                            : Colors.black87),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "$dose • $hungerStatus",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 🔥 YENİ BUTONLAR: BİLGİ (i) ve TİK (✔)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 1. BİLGİ BUTONU (Detay ve Silme için)
                                      IconButton(
                                        onPressed: () => _showMedicineDetails(
                                          data,
                                          medicine.id,
                                        ),
                                        icon: const Icon(
                                          Icons.info_outline,
                                          color: Color(0xFF4DB6AC),
                                          size: 26,
                                        ),
                                        tooltip: "Detaylar",
                                      ),

                                      const SizedBox(width: 4),

                                      // 2. ALDIM BUTONU (Tik)
                                      InkWell(
                                        onTap: () =>
                                            _toggleTaken(medicine.id, isTaken),
                                        borderRadius: BorderRadius.circular(20),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isTaken
                                                ? const Color(0xFF4DB6AC)
                                                : Colors
                                                      .transparent, // Dolu veya Boş
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(
                                                0xFF4DB6AC,
                                              ), // Yeşil Çerçeve
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.check,
                                            color: isTaken
                                                ? Colors.white
                                                : const Color(
                                                    0xFF4DB6AC,
                                                  ), // İkon Rengi
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({String message = "Bugün için ilaç planın yok! 🎉"}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
