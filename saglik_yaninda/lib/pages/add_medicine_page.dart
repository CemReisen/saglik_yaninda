import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saglik_yaninda/main.dart';

class AddMedicinePage extends StatefulWidget {
  const AddMedicinePage({super.key});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  final _formKey = GlobalKey<FormState>();

  // Controllerlar
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

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

  // 🔥 GARANTİLİ KAYDETME (BATCH YÖNTEMİ)
  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    // Seçim Kontrolleri
    bool anyTimeSelected = _doseTimes.any(
      (element) => element['isActive'] == true,
    );
    if (!anyTimeSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen en az bir saat seçiniz.")),
      );
      return;
    }

    List<String> activeDayNames = [];
    if (_repeatType == "Belirli Günler") {
      bool anyDaySelected = _selectedDays.contains(true);
      if (!anyDaySelected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lütfen en az bir gün seçiniz.")),
        );
        return;
      }
      for (int i = 0; i < _weekDays.length; i++) {
        if (_selectedDays[i]) activeDayNames.add(_weekDays[i]);
      }
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Yükleniyor göstergesi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 🔥 BATCH BAŞLATIYORUZ (Paket İşlemi)
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var dose in _doseTimes) {
        if (dose['isActive'] == true) {
          TimeOfDay time = dose['time'];
          int notificationId = Random().nextInt(1000000);

          // Yeni bir doküman referansı oluştur
          DocumentReference docRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('medicines')
              .doc(); // ID'yi otomatik üret

          // Veriyi pakete ekle (Henüz göndermiyoruz)
          batch.set(docRef, {
            'name': _nameController.text.trim(),
            'dose': _doseController.text.trim(),
            'description': _descController.text.trim(),
            'hour': time.hour,
            'minute': time.minute,
            'label': dose['label'],
            'notificationId': notificationId,
            'isTaken': false,
            'repeatType': _repeatType == "Her Gün" ? "daily" : "custom",
            'days': activeDayNames,
            'hungerStatus': _hungerStatus,
            'isCritical': _isCritical,
            'notificationType': _notificationType,
            'startDate': _dateRange != null
                ? "${_dateRange!.start.day}.${_dateRange!.start.month}.${_dateRange!.start.year}"
                : "",
            'endDate': _dateRange != null
                ? "${_dateRange!.end.day}.${_dateRange!.end.month}.${_dateRange!.end.year}"
                : "",
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 🔥 HEPSİNİ TEK SEFERDE GÖNDER
      await batch.commit();

      if (mounted) {
        // Yükleniyor dialogunu kapat
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("İlaçlar başarıyla kaydedildi! ✅")),
        );

        // 🔥 KESİN DÖNÜŞ (Tüm geçmişi silip Ana Sayfayı yeniden başlatır)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
          (route) => false, // Geri dönülecek sayfa bırakma
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dialogu kapat
      print("Hata Detayı: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),

      // 🔥 KOMPAKT BAŞLIK (Takvim Sayfasıyla Aynı)
      appBar: AppBar(
        toolbarHeight: 40, // Yüksekliği kıstık (Standart 56 idi)
        title: Text(
          "Yeni İlaç Ekle",
          style: GoogleFonts.poppins(
            color: const Color(0xFF263238),
            fontWeight: FontWeight.bold,
            fontSize: 18, // Fontu 1 tık küçülttük ki sığsın
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Geri butonu yok
      ),

      body: SingleChildScrollView(
        // Üstten boşluğu da biraz kıstık (20 yerine 10 yaptık)
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... Geri kalan kodların aynı devam edecek ...
              _buildSectionTitle("İlaç Bilgileri"),
              // ...
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameController,
                label: "İlaç Adı",
                icon: Icons.medication,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: _doseController,
                label: "Doz",
                icon: Icons.local_pharmacy,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: _descController,
                label: "Notlar",
                icon: Icons.notes,
                maxLines: 2,
              ),

              const SizedBox(height: 25),
              _buildSectionTitle("Kullanım Detayları"),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
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
                  boxShadow: [
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
              GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Color(0xFF4DB6AC)),
                      const SizedBox(width: 10),
                      Text(
                        _dateRange == null
                            ? "Tarih Aralığı Seçiniz"
                            : "${_dateRange!.start.day}.${_dateRange!.start.month} - ${_dateRange!.end.day}.${_dateRange!.end.month}",
                        style: TextStyle(
                          color: _dateRange == null
                              ? Colors.grey
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

  // Yardımcı Widgetlar (Aynı)
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
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
        maxLines: maxLines,
        validator: (value) => value!.isEmpty ? "Bu alan zorunludur" : null,
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
