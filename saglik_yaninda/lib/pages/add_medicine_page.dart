import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddMedicinePage extends StatefulWidget {
  const AddMedicinePage({super.key});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  Map<String, bool> days = {
    "Pzt": false,
    "Salı": false,
    "Çarş": false,
    "Perş": false,
    "Cuma": false,
    "Cts": false,
    "Paz": false,
  };

  DateTime? endDate;
  // ⭐ Tekrar Durumu State
  String repeatType = "daily"; // "daily" = Her gün, "custom" = belirli günler

  TimeOfDay? selectedTime;
  DateTime? startDate;

  //final _descriptionController = TextEditingController();
  //final _doseController = TextEditingController();
  //final _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ⭐ İlaç Bilgileri controller'ları
  final TextEditingController medicineNameController = TextEditingController();
  final TextEditingController doseController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  Future<void> pickTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1ABC9C), // ⭐ Yeşil tema
              onPrimary: Colors.white, // Yazı rengi
              onSurface: Colors.black, // Saat değerlerinin rengi
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() => selectedTime = time);
    }
  }

  Future<void> pickStartDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1ABC9C), // ⭐ Yeşil tema
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => startDate = date);
    }
  }

  Future<void> pickEndDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1ABC9C), // ⭐ Yeşil tema
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => endDate = date);
    }
  }

  // ⭐ Ek özellikler state
  bool sendNotification = false;
  bool notifyFamily = false;
  bool voiceReminder = false;

  Future<void> saveMedicine() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print("Kullanıcı giriş yapmamış!");
        return;
      }

      // Gün listesi
      List<String> selectedDays = days.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("medicines")
          .add({
            "name": medicineNameController.text.trim(),
            "dose": doseController.text.trim(),
            "description": descriptionController.text.trim(),

            "time": selectedTime != null ? selectedTime!.format(context) : null,

            "startDate": startDate != null
                ? "${startDate!.day}.${startDate!.month}.${startDate!.year}"
                : null,

            "endDate": endDate != null
                ? "${endDate!.day}.${endDate!.month}.${endDate!.year}"
                : null,

            "repeatType": repeatType, // Her gün / Belirli günler
            "days": selectedDays, // Belirli günlerde seçilen günler

            "sendNotification": sendNotification,
            "notifyFamily": notifyFamily,
            "voiceReminder": voiceReminder,

            "createdAt": FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İlaç başarıyla kaydedildi!")),
      );
    } catch (e) {
      print("Hata: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  @override
  void dispose() {
    medicineNameController.dispose();
    doseController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,

      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFECEFF1), // Arka plan

        child: Column(
          children: [
            const SizedBox(height: 0), // 🔥 TOPBAR İLE ANA KART ARASI = 0 px

            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),

                child: Column(
                  children: [
                    Text(
                      "İlaç Ekle",
                      style: TextStyle(
                        fontSize: 20, // ⭐ daha küçük ve modern
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1ABC9C),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          children: [
                            // Alt kartları buraya ekleyeceğiz
                            // ⭐ 1. KART — İlaç Bilgileri
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "İlaç Bilgileri",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // 🔸 İlaç Adı
                                  TextField(
                                    controller: medicineNameController,

                                    cursorColor: Color(0xFF1ABC9C),

                                    decoration: InputDecoration(
                                      labelText: "İlaç Adı",
                                      labelStyle: const TextStyle(
                                        color: Colors.black54,
                                      ),

                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade400,
                                          width: 1.2,
                                        ),
                                      ),

                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(
                                            0xFF1ABC9C,
                                          ), // ⭐ uygulamanın yeşil tonu
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // 🔸 Doz Miktarı
                                  TextField(
                                    controller: doseController,

                                    cursorColor: Color(0xFF1ABC9C),

                                    decoration: InputDecoration(
                                      labelText: "Doz Miktarı",
                                      labelStyle: const TextStyle(
                                        color: Colors.black54,
                                      ),

                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade400,
                                          width: 1.2,
                                        ),
                                      ),

                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(
                                            0xFF1ABC9C,
                                          ), // ⭐ uygulamanın yeşil tonu
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // 🔸 Açıklama
                                  TextField(
                                    controller: descriptionController,

                                    cursorColor: Color(0xFF1ABC9C),

                                    decoration: InputDecoration(
                                      labelText: "Açıklama",
                                      labelStyle: const TextStyle(
                                        color: Colors.black54,
                                      ),

                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade400,
                                          width: 1.2,
                                        ),
                                      ),

                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(
                                            0xFF1ABC9C,
                                          ), // ⭐ uygulamanın yeşil tonu
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // ⭐ 2. KART — Zaman Bilgileri
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Zaman Bilgileri",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  Row(
                                    children: [
                                      // ⭐ İlaç Saati
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "İlaç Saati",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 6),

                                            GestureDetector(
                                              onTap: pickTime,
                                              child: Container(
                                                alignment: Alignment.center,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.grey.shade400,
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Text(
                                                  selectedTime == null
                                                      ? "--:--"
                                                      : selectedTime!.format(
                                                          context,
                                                        ),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      // ⭐ Başlangıç Tarihi
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Başlangıç Tarihi",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 6),

                                            GestureDetector(
                                              onTap: pickStartDate,
                                              child: Container(
                                                alignment: Alignment.center,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.grey.shade400,
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Text(
                                                  startDate == null
                                                      ? "Tarih"
                                                      : "${startDate!.day}.${startDate!.month}.${startDate!.year}",
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      // ⭐ Bitiş Tarihi
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Bitiş Tarihi",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 6),

                                            GestureDetector(
                                              onTap: pickEndDate,
                                              child: Container(
                                                alignment: Alignment.center,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.grey.shade400,
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Text(
                                                  endDate == null
                                                      ? "Tarih"
                                                      : "${endDate!.day}.${endDate!.month}.${endDate!.year}",
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // ⭐ 3. KART — Tekrar Durumu
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Tekrar Durumu",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // ⭐ Radio Button: Her Gün
                                  RadioListTile(
                                    activeColor: const Color(0xFF1ABC9C),
                                    contentPadding:
                                        EdgeInsets.zero, // ⭐ iç boşluk yok
                                    visualDensity: const VisualDensity(
                                      vertical: -4,
                                    ),
                                    title: const Text("Her Gün"),
                                    value: "daily",
                                    groupValue: repeatType,
                                    onChanged: (value) {
                                      setState(() {
                                        repeatType = value.toString();
                                      });
                                    },
                                  ),

                                  // ⭐ Radio Button: Belirli Günler
                                  RadioListTile(
                                    activeColor: const Color(0xFF1ABC9C),
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: const VisualDensity(
                                      vertical: -4,
                                    ),
                                    title: const Text("Belirli Günler"),
                                    value: "custom",
                                    groupValue: repeatType,
                                    onChanged: (value) {
                                      setState(() {
                                        repeatType = value.toString();
                                      });

                                      // ⭐ OTOMATİK SCROLL
                                      if (value == "custom") {
                                        Future.delayed(
                                          const Duration(milliseconds: 200),
                                          () {
                                            _scrollController.animateTo(
                                              _scrollController
                                                  .position
                                                  .maxScrollExtent,
                                              duration: const Duration(
                                                milliseconds: 350,
                                              ),
                                              curve: Curves.easeOut,
                                            );
                                          },
                                        );
                                      }
                                    },
                                  ),

                                  // ⭐ Eğer Belirli Günler seçildiyse gün checkboxlarını göster
                                  if (repeatType == "custom") ...[
                                    const SizedBox(height: 8),

                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: days.keys.map((day) {
                                        return FilterChip(
                                          label: Text(
                                            day,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),

                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),

                                          materialTapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap, // ⭐ KRİTİK

                                          selected: days[day]!,
                                          selectedColor: const Color(
                                            0xFF1ABC9C,
                                          ).withOpacity(0.25),
                                          checkmarkColor: const Color(
                                            0xFF1ABC9C,
                                          ),

                                          onSelected: (bool selected) {
                                            setState(() {
                                              days[day] = selected;
                                            });
                                          },

                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: BorderSide(
                                              color: days[day]!
                                                  ? const Color(0xFF1ABC9C)
                                                  : Colors.grey.shade400,
                                              width: 1,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // ⭐ 4. KART — Ek Özellikler (İsteğe Bağlı)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Ek Özellikler (İsteğe Bağlı)",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // ⭐ Bildirim Gönder
                                  CheckboxListTile(
                                    value: sendNotification,
                                    activeColor: const Color(0xFF1ABC9C),
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: const VisualDensity(
                                      vertical: -4,
                                    ),
                                    title: const Text("Bildirim Gönder"),
                                    onChanged: (value) {
                                      setState(() => sendNotification = value!);
                                    },
                                  ),

                                  // ⭐ Aile bireylerine bildir
                                  CheckboxListTile(
                                    value: notifyFamily,
                                    activeColor: const Color(0xFF1ABC9C),
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: const VisualDensity(
                                      vertical: -4,
                                    ),
                                    title: const Text(
                                      "Aile Bireylerine Bildir",
                                    ),
                                    onChanged: (value) {
                                      setState(() => notifyFamily = value!);
                                    },
                                  ),

                                  // ⭐ Sesli Hatırlatma
                                  CheckboxListTile(
                                    value: voiceReminder,
                                    activeColor: const Color(0xFF1ABC9C),
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: const VisualDensity(
                                      vertical: -4,
                                    ),
                                    title: const Text("Sesli Hatırlatma"),
                                    onChanged: (value) {
                                      setState(() => voiceReminder = value!);
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // ⭐ KAYDET BUTONU
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(
                                    0xFF1ABC9C,
                                  ), // ⭐ Yeşil tema
                                  foregroundColor: Colors.white, // ⭐ Yazı rengi
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      16,
                                    ), // ⭐ Kavis
                                  ),
                                  elevation: 4, // ⭐ Hafif gölge
                                ),
                                onPressed: () {
                                  // ⭐ İlaç bilgilerini kaydet
                                  saveMedicine();
                                },
                                child: const Text(
                                  "Kaydet",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
