import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saglik_yaninda/main.dart';
import 'package:saglik_yaninda/services/notification_service.dart';

class AddMedicinePage extends StatefulWidget {
  const AddMedicinePage({super.key});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  final _formKey = GlobalKey<FormState>();

  // Controllerlar ve Focus Node
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Akıllı Ecza Deposu Veritabanı
  final List<String> _medicineDatabase = [
    "Parol 500mg Tablet",
    "Aspirin 100mg",
    "Majezik 100mg",
    "Arveles 25mg",
    "Dolorex 50mg",
    "Calpol 120mg Şurup",
    "Novalgine 500mg",
    "Lansor 30mg",
    "Gaviscon Şurup",
    "Efermag 365mg",
    "Ventolin İnhaler",
    "Tylolhot",
    "Deralin 40mg",
    "Coraspin 100mg",
    "Glifor 1000mg",
    "Euthyrox 50mcg",
    "Cipro 500mg",
    "Augmentin 1000mg",
    "Macrol 500mg",
    "Parol Plus",
    "Voltaren Krem",
    "Fucidin Krem",
    "Zyrtec 10mg",
    "Claritin 10mg",
    "Katarin Fort",
    "Theraflu Forte",
    "A-ferin",
    "Ibuprofen 400mg",
    "Panadol",
    "Minoset",
    "Nexium 40mg",
    "Bemiks Kompoze",
    "Devit-3 Damla",
    "Apireks Şurup",
    "Nurofen 200mg",
    "Avelox 400mg",
    "Klamoks 1000mg",
  ];

  // Hızlı Doz Seçenekleri
  final List<String> _quickDoses = [
    "1 Tablet",
    "Yarım Tablet",
    "2 Tablet",
    "1 Ölçek",
    "Yarım Ölçek",
    "1 Damla",
    "1 Puf",
    "1 Şase",
    "1 Ampul",
  ];

  // Değişkenler
  String _hungerStatus = "Tok Karnına";
  bool _isCritical = false;
  String _notificationType = "Standart";
  String _repeatType = "Her Gün";
  final List<String> _weekDays = [
    "Pzt",
    "Sal",
    "Çar",
    "Per",
    "Cum",
    "Cmt",
    "Paz",
  ];
  List<bool> _selectedDays = [false, false, false, false, false, false, false];

  // Zaman Listesi
  final List<Map<String, dynamic>> _doseTimes = [
    {
      "label": "Sabah",
      "time": const TimeOfDay(hour: 09, minute: 00),
      "isActive": true,
    },
    {
      "label": "Öğle",
      "time": const TimeOfDay(hour: 13, minute: 00),
      "isActive": false,
    },
    {
      "label": "Akşam",
      "time": const TimeOfDay(hour: 19, minute: 00),
      "isActive": false,
    },
    {
      "label": "Gece",
      "time": const TimeOfDay(hour: 23, minute: 00),
      "isActive": false,
    },
  ];

  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _doseController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int index) async {
    TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: _doseTimes[index]['time'],
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF4DB6AC),
            colorScheme: const ColorScheme.light(primary: Color(0xFF4DB6AC)),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (newTime != null) {
      setState(() {
        _doseTimes[index]['time'] = newTime;
        _doseTimes[index]['isActive'] = true;
      });
    }
  }

  Future<void> _pickDateRange() async {
    DateTime now = DateTime.now();
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF4DB6AC),
            colorScheme: const ColorScheme.light(primary: Color(0xFF4DB6AC)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  /// Verilen haftanın günü (1=Pzt..7=Paz) ve saatte, şimdiden sonraki ilk
  /// tekrarın tarihini hesaplar (bugün o gün ve saat henüz geçmediyse bugün,
  /// aksi halde önümüzdeki hafta içindeki ilk uygun gün).
  DateTime _nextInstanceOfWeekdayTime(int targetWeekday, TimeOfDay time) {
    final DateTime now = DateTime.now();
    DateTime candidate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    while (candidate.weekday != targetWeekday || candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  Future<void> _saveMedicine() async {
    // 🔥 GÜVENLİK 1: Form içindeki zorunlu alanlar (Ad ve Doz) dolu mu?
    if (!_formKey.currentState!.validate()) return;

    // 🔥 GÜVENLİK 2: Tarih Aralığı seçilmiş mi? (EN KRİTİK KONTROL)
    if (_dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⚠️ Lütfen ilacın kullanılacağı Tarih Aralığını seçiniz!",
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // 🔥 GÜVENLİK 3: En az 1 tane saat seçilmiş mi?
    bool anyTimeSelected = _doseTimes.any(
      (element) => element['isActive'] == true,
    );
    if (!anyTimeSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Lütfen ilacın içileceği en az bir Saat seçiniz!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<String> activeDayNames = [];

    if (_repeatType == "Her Gün") {
      activeDayNames = List.from(_weekDays);
    } else if (_repeatType == "Belirli Günler") {
      // 🔥 GÜVENLİK 4: Belirli günler seçildiyse en az 1 gün işaretlenmiş mi?
      bool anyDaySelected = _selectedDays.contains(true);
      if (!anyDaySelected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Lütfen ilacın kullanılacağı Günleri seçiniz!"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      for (int i = 0; i < _weekDays.length; i++) {
        if (_selectedDays[i]) activeDayNames.add(_weekDays[i]);
      }
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4DB6AC)),
      ),
    );

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 🔥 Bitiş tarihi geçmişte kalmışsa alarmı hiç kurma (baştan engelle) —
      // doküman yine de kaydedilir, sadece OS alarmı oluşturulmaz.
      final DateTime now = DateTime.now();
      final DateTime todayOnly = DateTime(now.year, now.month, now.day);
      final DateTime endDateOnly = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
      );
      final bool alreadyExpired = endDateOnly.isBefore(todayOnly);

      for (var dose in _doseTimes) {
        if (dose['isActive'] == true) {
          TimeOfDay time = dose['time'];

          DocumentReference docRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('medicines')
              .doc();

          List<int> notificationIds = [];

          if (!alreadyExpired) {
            if (_repeatType == "Her Gün") {
              int id = Random().nextInt(1000000);

              DateTime scheduledDate = DateTime(
                now.year,
                now.month,
                now.day,
                time.hour,
                time.minute,
              );
              if (scheduledDate.isBefore(now)) {
                scheduledDate = scheduledDate.add(const Duration(days: 1));
              }

              await NotificationService.scheduleNotification(
                id: id,
                title: "İlaç Vakti: ${_nameController.text.trim()}",
                body: "${_doseController.text.trim()} - $_hungerStatus",
                scheduledDate: scheduledDate,
                notificationType: _notificationType,
              );
              notificationIds.add(id);
            } else {
              // "Belirli Günler": flutter_local_notifications haftalık tekrarı
              // tek bir çağrıda birden fazla gün için desteklemiyor —
              // seçilen her gün için ayrı bir alarm kuruyoruz.
              for (int i = 0; i < _weekDays.length; i++) {
                if (!_selectedDays[i]) continue;

                int id = Random().nextInt(1000000);
                int targetWeekday = i + 1; // _weekDays[0] = Pzt = weekday 1
                DateTime scheduledDate = _nextInstanceOfWeekdayTime(
                  targetWeekday,
                  time,
                );

                await NotificationService.scheduleNotification(
                  id: id,
                  title: "İlaç Vakti: ${_nameController.text.trim()}",
                  body: "${_doseController.text.trim()} - $_hungerStatus",
                  scheduledDate: scheduledDate,
                  notificationType: _notificationType,
                  matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
                );
                notificationIds.add(id);
              }
            }
          }

          batch.set(docRef, {
            'name': _nameController.text.trim(),
            'dose': _doseController.text.trim(),
            'description': _descController.text.trim(),
            'hour': time.hour,
            'minute': time.minute,
            'label': dose['label'],
            'notificationIds': notificationIds,
            'isTaken': false,
            'repeatType': _repeatType == "Her Gün" ? "daily" : "custom",
            'days': activeDayNames,
            'hungerStatus': _hungerStatus,
            'isCritical': _isCritical,
            'notificationType': _notificationType,
            'startDate':
                "${_dateRange!.start.day}.${_dateRange!.start.month}.${_dateRange!.start.year}",
            'endDate':
                "${_dateRange!.end.day}.${_dateRange!.end.month}.${_dateRange!.end.year}",
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("İlaçlar başarıyla kaydedildi! ✅"),
            backgroundColor: Color(0xFF4DB6AC),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print("Hata Detayı: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  Widget _buildMedicineAutocomplete() {
    return RawAutocomplete<String>(
      textEditingController: _nameController,
      focusNode: _nameFocusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return _medicineDatabase.where((String option) {
          return option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return _buildTextField(
          controller: controller,
          focusNode: focusNode,
          label: "İlaç Adı (Ara veya Yaz)",
          icon: Icons.search,
          isRequired: true, // Zorunlu alan
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    leading: const Icon(
                      Icons.medication_liquid,
                      color: Color(0xFF4DB6AC),
                    ),
                    title: Text(
                      option,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDoseChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        children: _quickDoses.map((dose) {
          return InkWell(
            onTap: () {
              setState(() {
                _doseController.text = dose;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF4DB6AC).withOpacity(0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                dose,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00695C),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      appBar: AppBar(
        toolbarHeight: 40,
        title: Text(
          "Yeni İlaç Ekle",
          style: GoogleFonts.poppins(
            color: const Color(0xFF263238),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("İlaç Bilgileri"),
              const SizedBox(height: 12),

              _buildMedicineAutocomplete(),
              const SizedBox(height: 15),

              _buildTextField(
                controller: _doseController,
                label: "Doz (Örn: 1 Tablet)",
                icon: Icons.local_pharmacy,
                isRequired: true, // Zorunlu alan
              ),
              _buildDoseChips(),

              const SizedBox(height: 15),
              _buildTextField(
                controller: _descController,
                label: "Notlar (İsteğe Bağlı)",
                icon: Icons.notes,
                maxLines: 2,
                isRequired: false, // 🔥 ARTIK ZORUNLU DEĞİL
              ),

              const SizedBox(height: 25),
              _buildSectionTitle("Kullanım Detayları"),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDropdown(
                      label: "Kullanım:",
                      icon: Icons.restaurant,
                      currentValue: _hungerStatus,
                      items: ["Tok Karnına", "Aç Karnına", "Farketmez"],
                      onChanged: (val) => setState(() => _hungerStatus = val!),
                    ),
                    _buildDropdown(
                      label: "Tekrar:",
                      icon: Icons.update,
                      currentValue: _repeatType,
                      items: ["Her Gün", "Belirli Günler"],
                      onChanged: (val) => setState(() => _repeatType = val!),
                    ),

                    if (_repeatType == "Belirli Günler") ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Günleri Seçiniz:",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_weekDays.length, (index) {
                            bool isSelected = _selectedDays[index];
                            return GestureDetector(
                              onTap: () => setState(
                                () => _selectedDays[index] = !isSelected,
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
                                    _weekDays[index],
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const Divider(height: 30),
                    ],

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Bildirim Sesi:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNotificationOption(
                              "Standart",
                              Icons.notifications_active,
                            ),
                            _buildNotificationOption(
                              "Sessiz",
                              Icons.notifications_off,
                            ),
                            _buildNotificationOption(
                              "Alarm",
                              Icons.access_alarm,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 25),
                    SwitchListTile(
                      activeColor: Colors.redAccent,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Kritik İlaç",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        "Önemli ilaçlar için.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      value: _isCritical,
                      onChanged: (val) => setState(() => _isCritical = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),
              _buildSectionTitle("Zamanlama (Öğün Seç)"),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: List.generate(_doseTimes.length, (index) {
                    var item = _doseTimes[index];
                    return Column(
                      children: [
                        CheckboxListTile(
                          activeColor: const Color(0xFF4DB6AC),
                          title: Row(
                            children: [
                              Text(
                                item['label'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: item['isActive']
                                    ? () => _pickTime(index)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item['isActive']
                                        ? const Color(0xFFE0F2F1)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: item['isActive']
                                          ? const Color(0xFF4DB6AC)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Text(
                                    "${item['time'].hour.toString().padLeft(2, '0')}:${item['time'].minute.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                      color: item['isActive']
                                          ? const Color(0xFF009688)
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          value: item['isActive'],
                          onChanged: (val) => setState(
                            () => _doseTimes[index]['isActive'] = val ?? false,
                          ),
                        ),
                        if (index != _doseTimes.length - 1)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  }),
                ),
              ),

              const SizedBox(height: 25),
              _buildSectionTitle("Tarih Aralığı"),
              const SizedBox(height: 12),

              // 🔥 GÜNCEL: Seçim Yapılmamışsa Uyarı Rengi Ver
              GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _dateRange == null
                          ? Colors.orange.shade300
                          : Colors.grey.shade300,
                      width: _dateRange == null ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        color: _dateRange == null
                            ? Colors.orange
                            : const Color(0xFF4DB6AC),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _dateRange == null
                            ? "Tarih Aralığı Seçiniz (Zorunlu)"
                            : "${_dateRange!.start.day}.${_dateRange!.start.month} - ${_dateRange!.end.day}.${_dateRange!.end.month}",
                        style: TextStyle(
                          color: _dateRange == null
                              ? Colors.orange.shade700
                              : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _saveMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4DB6AC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Kaydet ve Planla",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String currentValue,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF4DB6AC)),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentValue,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF4DB6AC),
                    ),
                    dropdownColor: Colors.white,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                    items: items
                        .map(
                          (val) => DropdownMenuItem(
                            value: val,
                            child: Text(
                              val,
                              style: GoogleFonts.poppins(
                                color: val == currentValue
                                    ? const Color(0xFF4DB6AC)
                                    : Colors.black87,
                                fontWeight: val == currentValue
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 30),
      ],
    );
  }

  Widget _buildNotificationOption(String label, IconData icon) {
    bool isSelected = _notificationType == label;
    return GestureDetector(
      onTap: () => setState(() => _notificationType = label),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4DB6AC) : Colors.grey[100],
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4DB6AC).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF4DB6AC) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF37474F),
      ),
    );
  }

  // 🔥 GÜNCEL: Dinamik Zorunluluk Kontrolü (isRequired) Eklendi
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    FocusNode? focusNode,
    bool isRequired = true, // Varsayılan olarak zorunlu
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        // Zorunluysa boş mu diye kontrol et, değilse geç
        validator: isRequired
            ? (value) => (value == null || value.trim().isEmpty)
                  ? "Bu alan zorunludur"
                  : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF4DB6AC)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
