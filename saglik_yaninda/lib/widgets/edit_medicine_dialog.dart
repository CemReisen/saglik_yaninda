import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:saglik_yaninda/core/theme/app_colors.dart';
import 'package:saglik_yaninda/services/notification_service.dart';

/// İlaç düzenleme dialog'u — home_page.dart ve calendar_page.dart'tan ortak
/// çağrılıyor. Eskiden home_page.dart'ta yerel bir `_showEditDialog` vardı ve
/// sadece isim/doz/notlar/saat/kullanım şekli/kritik durumu düzenletiyordu —
/// tekrar tipi, gün seçimi ve bitiş tarihi hiç gösterilmiyordu (bu alanlar
/// arka planda sessizce olduğu gibi korunuyordu). Kullanıcı bunun "sıfırdan
/// giriş yapıyormuş gibi" hissettirdiğini belirtti. Bu ortak sürüm artık
/// add_medicine_page.dart ile aynı kapsamda: tekrar tipi ("Her Gün" /
/// "Belirli Günler"), gün seçimi ve bitiş tarihi de düzenlenebiliyor.
///
/// Çağıran taraf, eğer bu dialog başka bir dialog'un (ör. ilaç detay
/// dialog'u) üzerinden açılıyorsa, kendi dialog'unu ÖNCE kapatmalı
/// (`Navigator.pop(context)`) — bu fonksiyon kendi dialog'unu açıp/kapatmayı
/// yönetir, altındaki başka bir route'a karışmaz (bkz. home_page.dart'taki
/// "Düzenle" çağrı sitesi).
void showEditMedicineDialog({
  required BuildContext context,
  required Map<String, dynamic> data,
  required String docId,
  required String uid,
}) {
  final TextEditingController nameCtrl = TextEditingController(
    text: data['name'],
  );
  final TextEditingController doseCtrl = TextEditingController(
    text: data['dose'],
  );
  final TextEditingController descCtrl = TextEditingController(
    text: data['description'],
  );
  TimeOfDay selectedTime = TimeOfDay(
    hour: data['hour'] ?? 0,
    minute: data['minute'] ?? 0,
  );
  String selectedHunger = data['hungerStatus'] ?? "Tok Karnına";
  bool isCritical = data['isCritical'] ?? false;

  // repeatType Firestore'da "daily"/"custom" (yeni kayıtlar) ya da "Her Gün"
  // (eski kayıtlar, bkz. NotificationService.extractNotificationIds'teki
  // benzer geriye dönük uyumluluk deseni) olarak tutuluyor — ikisini de tek
  // bir görünür değere normalize ediyoruz.
  String repeatType = (data['repeatType'] == 'custom')
      ? "Belirli Günler"
      : "Her Gün";
  final List<String> existingDays =
      (data['days'] as List?)?.whereType<String>().toList() ?? [];
  List<bool> selectedDays = NotificationService.weekDays
      .map((d) => existingDays.contains(d))
      .toList();

  DateTime endDate =
      NotificationService.parseDdMmYyyy(data['endDate'] as String?) ??
      DateTime.now();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  prefixIcon: Icon(Icons.medication, color: Color(0xFF4DB6AC)),
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
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondaryStrong,
                    ),
                  ),
                  DropdownButton<String>(
                    value: selectedHunger,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF4DB6AC),
                    ),
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
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
              const SizedBox(height: 12),
              // Tekrar tipi — add_medicine_page.dart'taki ile aynı iki
              // seçenek. "Belirli Günler" seçiliyken gün çipleri açılıyor.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tekrar",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondaryStrong,
                    ),
                  ),
                  DropdownButton<String>(
                    value: repeatType,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF4DB6AC),
                    ),
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                    underline: Container(
                      height: 2,
                      color: const Color(0xFF4DB6AC),
                    ),
                    items: ["Her Gün", "Belirli Günler"].map((val) {
                      return DropdownMenuItem(
                        value: val,
                        child: Text(
                          val,
                          style: TextStyle(
                            color: val == repeatType
                                ? const Color(0xFF4DB6AC)
                                : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setStateDialog(() => repeatType = val!),
                  ),
                ],
              ),
              if (repeatType == "Belirli Günler") ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Günleri Seçiniz:",
                    style: TextStyle(
                      color: AppColors.textSecondaryStrong,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      NotificationService.weekDays.length,
                      (index) {
                        bool isSelected = selectedDays[index];
                        return GestureDetector(
                          onTap: () => setStateDialog(
                            () => selectedDays[index] = !isSelected,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4DB6AC)
                                  : Colors.grey[100],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4DB6AC)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                NotificationService.weekDays[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondaryStrong,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
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
                    if (picked != null) {
                      setStateDialog(() => selectedTime = picked);
                    }
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "Bitiş Tarihi: ${endDate.day.toString().padLeft(2, '0')}.${endDate.month.toString().padLeft(2, '0')}.${endDate.year}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate.isBefore(now) ? now : endDate,
                      firstDate: now,
                      lastDate: DateTime(now.year + 2),
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
                    if (picked != null) {
                      setStateDialog(() => endDate = picked);
                    }
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
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4DB6AC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (repeatType == "Belirli Günler" &&
                  !selectedDays.contains(true)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "⚠️ Lütfen ilacın kullanılacağı günleri seçiniz!",
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // 🔥 Saat/tekrar/bitiş tarihi değiştiyse eski OS alarmları hâlâ
              // eski programda çalar — önce eskilerini iptal edip,
              // tamamlandığından emin olduktan SONRA yenilerini kuruyoruz.
              final List<int> oldNotificationIds =
                  NotificationService.extractNotificationIds(data);
              await NotificationService.cancelNotifications(oldNotificationIds);

              final String medName = nameCtrl.text.trim();
              final String medDose = doseCtrl.text.trim();
              final String notificationType =
                  data['notificationType'] ?? "Standart";
              final List<String> activeDayNames = repeatType == "Her Gün"
                  ? List<String>.from(NotificationService.weekDays)
                  : [
                      for (int i = 0; i < selectedDays.length; i++)
                        if (selectedDays[i]) NotificationService.weekDays[i],
                    ];

              final DateTime now = DateTime.now();
              final DateTime todayOnly = DateTime(now.year, now.month, now.day);
              final DateTime endDateOnly = DateTime(
                endDate.year,
                endDate.month,
                endDate.day,
              );
              final bool alreadyExpired = endDateOnly.isBefore(todayOnly);

              final List<int> newNotificationIds = [];

              if (!alreadyExpired) {
                if (repeatType == "Her Gün") {
                  final int id = await NotificationService.generateUniqueId(
                    exclude: newNotificationIds,
                  );
                  DateTime scheduledDate = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  if (scheduledDate.isBefore(now)) {
                    scheduledDate = scheduledDate.add(const Duration(days: 1));
                  }
                  await NotificationService.scheduleNotification(
                    id: id,
                    title: "İlaç Vakti: $medName",
                    body: "$medDose - $selectedHunger",
                    scheduledDate: scheduledDate,
                    notificationType: notificationType,
                  );
                  newNotificationIds.add(id);
                } else {
                  for (final dayName in activeDayNames) {
                    final int dayIndex = NotificationService.weekDays.indexOf(
                      dayName,
                    );
                    if (dayIndex == -1) continue;
                    final int id = await NotificationService.generateUniqueId(
                      exclude: newNotificationIds,
                    );
                    final DateTime scheduledDate =
                        NotificationService.nextInstanceOfWeekdayTime(
                          dayIndex + 1,
                          selectedTime,
                        );
                    await NotificationService.scheduleNotification(
                      id: id,
                      title: "İlaç Vakti: $medName",
                      body: "$medDose - $selectedHunger",
                      scheduledDate: scheduledDate,
                      notificationType: notificationType,
                      matchDateTimeComponents:
                          DateTimeComponents.dayOfWeekAndTime,
                    );
                    newNotificationIds.add(id);
                  }
                }
              }

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('medicines')
                  .doc(docId)
                  .update({
                    'name': medName,
                    'dose': medDose,
                    'description': descCtrl.text.trim(),
                    'hungerStatus': selectedHunger,
                    'isCritical': isCritical,
                    'hour': selectedTime.hour,
                    'minute': selectedTime.minute,
                    'repeatType': repeatType == "Her Gün" ? "daily" : "custom",
                    'days': activeDayNames,
                    'endDate':
                        "${endDate.day}.${endDate.month}.${endDate.year}",
                    'notificationIds': newNotificationIds,
                    'notificationsCancelled': alreadyExpired,
                  });
              if (context.mounted) Navigator.pop(context);
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
