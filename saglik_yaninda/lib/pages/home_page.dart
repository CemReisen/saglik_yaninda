import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saglik_yaninda/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // 🔥 YENİ: İNTERNET KONTROL PAKETİ

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = FirebaseAuth.instance.currentUser;

  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _medicinesStream;

  // 🔥 YENİ: Çevrimdışı durumu tutan değişken
  bool _isOffline = false;

  // 🔥 YENİ: Onaylı yakın (caregiver) ilişkilerini sürekli dinleyip state'te
  // tutuyoruz — SOS ve "ilaç alındı" bildirimleri artık tek seferlik bir
  // .get() sorgusuna değil, bu cache'e bakıyor. Böylece cihaz offline'a
  // düştüğünde bile (daha önce en az bir kez online'ken senkronize olduysa)
  // caregiver listesi elde mevcut olur; aksi halde offline'daki tek seferlik
  // .get() sorgusu cache boşsa sessizce başarısız olup bildirimi hiç
  // kuyruğa almadan kaybediyordu.
  List<QueryDocumentSnapshot> _approvedCaregiverRelations = [];
  bool _relationsLoaded = false;
  StreamSubscription<QuerySnapshot>? _relationsSubscription;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots();
      _medicinesStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('medicines')
          .snapshots();
      _relationsSubscription = FirebaseFirestore.instance
          .collection('relations')
          .where('elderId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'approved')
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              setState(() {
                _approvedCaregiverRelations = snapshot.docs;
                _relationsLoaded = true;
              });
            }
          });
    }

    // 🔥 YENİ: Uygulama açılır açılmaz interneti kontrol et
    _checkInitialConnectivity();

    // 🔥 YENİ: İnternet durumunu saniye saniye dinle
    Connectivity().onConnectivityChanged.listen((dynamic result) {
      if (mounted) {
        setState(() {
          // connectivity_plus paketinin yeni ve eski sürümlerine karşı koruma
          if (result is List) {
            _isOffline = result.contains(ConnectivityResult.none);
          } else {
            _isOffline = result == ConnectivityResult.none;
          }
        });
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        if (result is List) {
          _isOffline = result.contains(ConnectivityResult.none);
        } else {
          _isOffline = result == ConnectivityResult.none;
        }
      });
    }
  }

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

  Future<void> _sendPushNotificationToCaregiver(String medicineName) async {
    // 🔥 relations artık .snapshots() ile canlı dinleniyor (bkz. initState) —
    // offline'da bile son bilinen onaylı yakın listesi burada mevcut.
    if (_approvedCaregiverRelations.isEmpty) return;

    try {
      String elderName = "Yakınınız";
      var elderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (elderDoc.exists && elderDoc.data() != null) {
        String? dbName = elderDoc.data()!['name'];
        if (dbName != null && dbName.trim().isNotEmpty) {
          elderName = dbName;
        }
      }

      for (var doc in _approvedCaregiverRelations) {
        String caregiverId = doc['caregiverId'];
        // 🔥 Bu Firestore .add() çağrısı offline'da lokal kuyruğa alınır ve
        // bağlantı geri geldiğinde otomatik senkronize olur — internet
        // gerektiren kısım (push bildirimi) senkronizasyondan sonra
        // Cloud Function tarafından tetiklenir.
        await FirebaseFirestore.instance
            .collection('notification_requests')
            .add({
              'type': 'medicine_taken',
              'caregiverId': caregiverId,
              'elderId': user!.uid,
              'elderName': elderName,
              'callerName': elderName,
              'medicineName': medicineName,
              'timestamp': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      debugPrint("Bildirim isteği gönderme hatası: $e");
    }
  }

  /// `notification_requests`'e SOS kayıtlarını yazar. Bu Future, cihaz
  /// offline'dayken **sunucu ACK'i gelene kadar tamamlanmaz** (cloud_firestore
  /// native SDK davranışı — yazma yerel kuyruğa senkron olarak düşer ama
  /// döndürülen Future ancak bağlantı geri gelip yazma sunucuya ulaşınca
  /// resolve olur). Bu yüzden çağıran taraf, offline'da bu Future'ı UI geri
  /// bildirimi için beklememeli.
  Future<void> _writeSOSNotifications() async {
    String elderName = "Yakınınız";
    var elderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    if (elderDoc.exists && elderDoc.data() != null) {
      String? dbName = elderDoc.data()!['name'];
      if (dbName != null && dbName.trim().isNotEmpty) elderName = dbName;
    }

    for (var doc in _approvedCaregiverRelations) {
      String caregiverId = doc['caregiverId'];
      await FirebaseFirestore.instance.collection('notification_requests').add({
        'type': 'sos',
        'caregiverId': caregiverId,
        'elderId': user!.uid,
        'elderName': elderName,
        'callerName': elderName,
        'medicineName': '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _sendSOSNotificationToCaregiver() async {
    // 🔥 relations artık .snapshots() ile canlı dinleniyor (bkz. initState) —
    // offline'da bile son bilinen onaylı yakın listesi burada mevcut, tek
    // seferlik .get() sorgusunun cache boşken sessizce başarısız olma riski
    // yok.
    if (_approvedCaregiverRelations.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !_relationsLoaded
                  ? "Yakın bilgileriniz henüz yüklenemedi. Lütfen bağlantınızı kontrol edip tekrar deneyin, çok acilse doğrudan arayın."
                  : "Kayıtlı bir yakınınız bulunamadı! Lütfen önce bir yakın ekleyin.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final bool wasOffline = _isOffline;

    if (wasOffline) {
      // 🔥 Yazmanın sunucuya ulaşmasını (dolayısıyla Future'ın dönmesini)
      // beklemeden hemen bilgilendiriyoruz — yazma zaten bu noktada yerel
      // kuyruğa senkron olarak düştü. Gerçek gönderim arka planda
      // (fire-and-forget) devam ediyor; sonucunu UI'a yansıtmıyoruz, sadece
      // hata olursa loglanıyor. Bilinen risk: bağlantı hiç gelmezse ya da
      // senkronizasyon sırasında bir kural reddederse kullanıcı bunu asla
      // öğrenemez — kapsam dışı, ileride "gönderilemeyen SOS'lar" için ayrı
      // bir kontrol mekanizması gerekebilir.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "🚨 SOS kaydedildi, bağlantı sağlanınca yakınlarınıza iletilecek. Acil bir durumsa lütfen doğrudan arayın.",
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      unawaited(
        _writeSOSNotifications().catchError((e) {
          debugPrint("SOS bildirim gönderme hatası (offline kuyruk): $e");
        }),
      );
      return;
    }

    try {
      await _writeSOSNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚨 Acil durum çağrısı yakınlarınıza iletildi!"),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("SOS bildirim gönderme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "SOS gönderilirken bir sorun oluştu. Lütfen tekrar deneyin ya da doğrudan arayın.",
            ),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showSOSConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 32,
            ),
            SizedBox(width: 10),
            Text(
              "Acil Durum (SOS)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "Yakınlarınıza acil durum yardımı bildirimi göndermek istediğinize emin misiniz?",
          style: TextStyle(fontSize: 15),
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
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _sendSOSNotificationToCaregiver();
            },
            child: const Text(
              "Evet, Gönder",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// `lastTakenDate` ve `totalScore`'u günceller. Bu Future de SOS
  /// yazmalarıyla aynı sebepten (bkz. `_writeSOSNotifications`) offline'da
  /// sunucu ACK'i gelene kadar tamamlanmaz.
  Future<void> _applyMedicineTakenWrites(
    DocumentReference<Map<String, dynamic>> medRef,
    DocumentReference<Map<String, dynamic>> userRef,
    bool currentStatus,
    String today,
  ) async {
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
    }
  }

  Future<void> _toggleTaken(
    String docId,
    String medicineName,
    bool currentStatus,
    String today,
  ) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid);
    final medRef = userRef.collection('medicines').doc(docId);
    final bool wasOffline = _isOffline;
    final Future<void> writeFuture = _applyMedicineTakenWrites(
      medRef,
      userRef,
      currentStatus,
      today,
    );

    if (currentStatus) {
      // "Alındı" işaretini geri alma — online'da olduğu gibi sessiz, sadece
      // offline'da UI'ı bloklamıyoruz.
      if (wasOffline) {
        unawaited(
          writeFuture.catchError((e) {
            debugPrint("İlaç durumu geri alma hatası (offline kuyruk): $e");
          }),
        );
      } else {
        await writeFuture;
      }
      return;
    }

    if (wasOffline) {
      // 🔥 Yazmanın sunucuya ulaşmasını beklemeden hemen bilgilendiriyoruz —
      // yazma zaten yerel kuyruğa senkron olarak düştü. Puan güncellemesi ve
      // caregiver bildirimi arka planda (fire-and-forget) devam ediyor;
      // sonucunu UI'a yansıtmıyoruz, sadece hata olursa loglanıyor.
      unawaited(
        writeFuture.catchError((e) {
          debugPrint("İlaç alındı işaretleme hatası (offline kuyruk): $e");
        }),
      );
      unawaited(_sendPushNotificationToCaregiver(medicineName));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Kaydedildi! Bağlantı sağlanınca 100 Sağlık Puanı eklenecek ve yakınınıza bildirilecek.",
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    await writeFuture;
    await _sendPushNotificationToCaregiver(medicineName);

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

  void _showDeleteConfirmDialog(String docId, List<int> notificationIds) {
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
              _deleteMedicine(docId, notificationIds);
            },
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMedicine(String docId, List<int> notificationIds) async {
    try {
      await NotificationService.cancelNotifications(notificationIds);
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                // 🔥 Saat değiştiyse eski OS alarmları hâlâ eski saatte
                // çalar — önce eskilerini iptal edip, tamamlandığından emin
                // olduktan SONRA yenilerini kuruyoruz. Aksi halde yeni
                // id'ler (Random().nextInt) eskilerle çakışırsa
                // flutter_local_notifications tarafında belirsiz davranış
                // oluşabilir.
                final List<int> oldNotificationIds =
                    NotificationService.extractNotificationIds(data);
                await NotificationService.cancelNotifications(
                  oldNotificationIds,
                );

                final String medName = nameCtrl.text.trim();
                final String medDose = doseCtrl.text.trim();
                final String notificationType =
                    data['notificationType'] ?? "Standart";
                final String repeatType = data['repeatType'] ?? "daily";
                final List<String> days =
                    (data['days'] as List?)?.whereType<String>().toList() ??
                    [];
                final DateTime? endDate = NotificationService.parseDdMmYyyy(
                  data['endDate'] as String?,
                );
                final DateTime now = DateTime.now();
                final DateTime todayOnly = DateTime(
                  now.year,
                  now.month,
                  now.day,
                );
                final bool alreadyExpired =
                    endDate != null && endDate.isBefore(todayOnly);

                final List<int> newNotificationIds = [];

                if (!alreadyExpired) {
                  if (repeatType == "daily") {
                    final int id = Random().nextInt(1000000);
                    DateTime scheduledDate = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    if (scheduledDate.isBefore(now)) {
                      scheduledDate = scheduledDate.add(
                        const Duration(days: 1),
                      );
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
                    for (final dayName in days) {
                      final int dayIndex = NotificationService.weekDays
                          .indexOf(dayName);
                      if (dayIndex == -1) continue;
                      final int id = Random().nextInt(1000000);
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
                    .doc(user!.uid)
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
                      'notificationIds': newNotificationIds,
                      'notificationsCancelled': alreadyExpired,
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
                    NotificationService.extractNotificationIds(data),
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

  Widget _buildHeader(String firstName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Merhaba, $firstName 👋",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF263238),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getFullDisplayDate(),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey[400],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _showSOSConfirmDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "SOS",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEAF5F4),
                  border: Border.all(
                    color: const Color(0xFF4DB6AC).withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : "E",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00695C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isOffline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Asistan çevrimdışıyken kullanılamaz."),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AiAssistantPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: Color(0xFF4DB6AC), size: 26),
            SizedBox(width: 15),
            Text(
              "Asistana Sor...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            Spacer(),
            Icon(Icons.mic_none, color: Color(0xFF4DB6AC), size: 26),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            height: 75,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            height: 85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 100, height: 20, color: Colors.white),
                        Container(
                          width: 60,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(
                    3,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(int total, int taken) {
    if (total == 0) return const SizedBox();
    double progress = taken / total;
    int percentage = (progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF4DB6AC).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF4DB6AC),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Günlük İlaç Tamamlama",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "%$percentage",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4DB6AC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4DB6AC),
                    ),
                  ),
                ),
              ],
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
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF26A69A), Color(0xFF00897B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00897B).withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alarm, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "Sıradaki: ",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          nextMed['name'] ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Saat $formattedTime • ${nextMed['dose']}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 22, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Giriş Yapılmalı"));
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Column(
      children: [
        // 🔥 İŞTE O EFSANEVİ UYARI BARI
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isOffline ? 40 : 0,
          color: Colors.redAccent,
          child: _isOffline
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "İnternet bağlantısı yok (Çevrimdışı Mod)",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),

        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: _userStream,
            builder: (context, userSnap) {
              String firstName = "Kullanıcı";

              if (userSnap.hasData && userSnap.data!.exists) {
                var userData = userSnap.data!.data() as Map<String, dynamic>;
                String fullName = userData['name'] ?? "";
                if (fullName.isNotEmpty) {
                  firstName = fullName.trim().split(' ').first;
                } else {
                  firstName = user!.email?.split('@').first ?? "Kullanıcı";
                }
              }

              return StreamBuilder<QuerySnapshot>(
                stream: _medicinesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return Column(
                      children: [
                        _buildHeader(firstName),
                        _buildAssistantSearchBar(context),
                        Expanded(child: _buildSkeletonLoader()),
                      ],
                    );
                  }

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
                    return ((dataA['hour'] as int) * 60 +
                            (dataA['minute'] as int))
                        .compareTo(
                          (dataB['hour'] as int) * 60 +
                              (dataB['minute'] as int),
                        );
                  });

                  int totalCount = todaysMedicines.length;
                  int takenCount = todaysMedicines
                      .where(
                        (doc) =>
                            (doc.data()
                                as Map<String, dynamic>)['lastTakenDate'] ==
                            today,
                      )
                      .length;
                  var nextMedDoc = _getNextMedicine(todaysMedicines, today);

                  return Column(
                    children: [
                      _buildHeader(firstName),
                      _buildAssistantSearchBar(context),
                      _buildProgressCard(totalCount, takenCount),
                      _buildNextDoseCard(
                        nextMedDoc?.data() as Map<String, dynamic>?,
                        nextMedDoc?.id,
                      ),
                      const SizedBox(height: 4),

                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          padding: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F6F9),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(0xFFCFD8DC),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "İlaç Listesi",
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF424B7F),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2F1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "$totalCount İlaç",
                                        style: const TextStyle(
                                          color: Color(0xFF00695C),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),

                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(30),
                                    bottomRight: Radius.circular(30),
                                  ),
                                  child: todaysMedicines.isEmpty
                                      ? const Center(
                                          child: Text(
                                            "Bugünlük ilaç yok!",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          itemCount: todaysMedicines.length,
                                          itemBuilder: (context, index) {
                                            var medicine =
                                                todaysMedicines[index];
                                            var data =
                                                medicine.data()
                                                    as Map<String, dynamic>;
                                            bool isTakenToday =
                                                data['lastTakenDate'] == today;
                                            bool isCritical =
                                                data['isCritical'] ?? false;
                                            String time =
                                                "${data['hour'].toString().padLeft(2, '0')}:${data['minute'].toString().padLeft(2, '0')}";
                                            String medName =
                                                data['name'] ?? 'İlaç';
                                            String doseInfo =
                                                "${data['dose'] ?? ''} • ${data['hungerStatus'] ?? ''}";

                                            String doseString =
                                                (data['dose'] ?? '')
                                                    .toLowerCase();
                                            IconData medIcon = Icons.medication;
                                            if (doseString.contains('ölçek') ||
                                                doseString.contains('ml') ||
                                                doseString.contains('şurup')) {
                                              medIcon = Icons.local_drink;
                                            } else if (doseString.contains(
                                                  'ünite',
                                                ) ||
                                                doseString.contains('iğne') ||
                                                doseString.contains('flakon') ||
                                                doseString.contains(
                                                  'enjeksiyon',
                                                )) {
                                              medIcon = Icons.vaccines;
                                            } else if (doseString.contains(
                                              'damla',
                                            )) {
                                              medIcon = Icons.water_drop;
                                            } else if (doseString.contains(
                                                  'krem',
                                                ) ||
                                                doseString.contains('merhem')) {
                                              medIcon = Icons.health_and_safety;
                                            }

                                            return Card(
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              elevation: isTakenToday ? 0 : 2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              color: isTakenToday
                                                  ? Colors.grey.shade100
                                                  : Colors.white,
                                              child: InkWell(
                                                onTap: () =>
                                                    _showMedicineDetails(
                                                      data,
                                                      medicine.id,
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    border: Border(
                                                      left: BorderSide(
                                                        color: isTakenToday
                                                            ? Colors.green
                                                            : Colors.orange,
                                                        width: 5,
                                                      ),
                                                    ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 8,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        decoration:
                                                            BoxDecoration(
                                                              color:
                                                                  isTakenToday
                                                                  ? Colors
                                                                        .green
                                                                        .shade50
                                                                  : const Color(
                                                                      0xFFE0F2F1,
                                                                    ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                        child: Icon(
                                                          medIcon,
                                                          size: 24,
                                                          color: isTakenToday
                                                              ? Colors.green
                                                              : const Color(
                                                                  0xFF4DB6AC,
                                                                ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              time,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    isTakenToday
                                                                    ? Colors
                                                                          .grey
                                                                    : const Color(
                                                                        0xFF00695C,
                                                                      ),
                                                              ),
                                                            ),
                                                            Row(
                                                              children: [
                                                                if (isCritical)
                                                                  Icon(
                                                                    Icons
                                                                        .warning_amber_rounded,
                                                                    size: 16,
                                                                    color:
                                                                        isTakenToday
                                                                        ? Colors
                                                                              .grey[400]
                                                                        : Colors
                                                                              .redAccent,
                                                                  ),
                                                                if (isCritical)
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                Expanded(
                                                                  child: Text(
                                                                    medName,
                                                                    style: GoogleFonts.poppins(
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color:
                                                                          isTakenToday
                                                                          ? Colors.grey
                                                                          : Colors.black87,
                                                                      decoration:
                                                                          isTakenToday
                                                                          ? TextDecoration.lineThrough
                                                                          : null,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            Text(
                                                              doseInfo,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color:
                                                                    isTakenToday
                                                                    ? Colors
                                                                          .grey
                                                                          .shade400
                                                                    : Colors
                                                                          .grey
                                                                          .shade600,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      IconButton(
                                                        onPressed: () =>
                                                            _toggleTaken(
                                                              medicine.id,
                                                              medName,
                                                              isTakenToday,
                                                              today,
                                                            ),
                                                        icon: Icon(
                                                          isTakenToday
                                                              ? Icons
                                                                    .check_circle
                                                              : Icons
                                                                    .notifications_active,
                                                          color: isTakenToday
                                                              ? Colors.green
                                                              : Colors.orange,
                                                          size: 28,
                                                        ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
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
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _relationsSubscription?.cancel();
    super.dispose();
  }
}

//HUKUKİ KORUMALI CHATBOT SAYFASI (Sabit Kaldı)
class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isTyping = false;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [
    {
      "role": "ai",
      "text":
          "Merhaba! Ben Sağlık Yanında dijital asistanınızım. İlaç saatlerinizi takip etmenize yardımcı olabilirim. Ancak unutmayın, ben tıbbi bir uzman değilim. Sağlığınızla ilgili her türlü karar için lütfen doktorunuza danışın. ❤️",
    },
  ];

  // Build zamanında inject edilir: --dart-define=GEMINI_API_KEY=xxxx
  static const String _geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );
  bool get _hasApiKey => _geminiApiKey.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _textController.addListener(() {
      setState(() {});
    });
  }

  void _listen() async {
    FocusScope.of(context).unfocus();
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: 'tr_TR',
          onResult: (val) => setState(() {
            _textController.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    String userMessage = _textController.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": userMessage});
      _textController.clear();
    });
    FocusScope.of(context).unfocus();
    _scrollToBottom();

    if (!_hasApiKey) {
      setState(() {
        _messages.add({
          "role": "ai",
          "text":
              "⚠️ AI asistan şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.",
        });
      });
      _scrollToBottom();
      return;
    }

    setState(() => _isTyping = true);

    try {
      final String userId = FirebaseAuth.instance.currentUser?.uid ?? "";
      String ilaclarMetni = "";

      if (userId.isNotEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('medicines')
            .get();

        if (snapshot.docs.isNotEmpty) {
          ilaclarMetni = "Kullanıcının Veritabanındaki Aktif İlaçları:\n";
          for (var doc in snapshot.docs) {
            var data = doc.data();
            String saat =
                "${(data['hour'] ?? 0).toString().padLeft(2, '0')}:${(data['minute'] ?? 0).toString().padLeft(2, '0')}";
            ilaclarMetni +=
                "- İlaç: ${data['name']}, Saat: $saat, Doz: ${data['dose']}, Tokluk/Açlık: ${data['hungerStatus']}\n";
          }
        } else {
          ilaclarMetni =
              "Kullanıcının sistemde kayıtlı herhangi bir ilacı bulunmuyor.\n";
        }
      }

      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview',
        apiKey: _geminiApiKey.trim(),
      );

      final prompt =
          """
Sen yaşlı bireylere ilaç takibi ve sağlık konusunda yardımcı olan tonton, saygılı ve uzman bir dijital sağlık asistanısın. Adın 'Sağlık Yanında Asistanı'.

Kritik Güvenlik Talimatı: Sen tıbbi bir doktor veya hekim değilsin. Kullanıcıya ASLA kesin bir reçete, doz değişikliği, ilaç bırakma veya kesin tanı/teşhis önerisinde bulunamazsın. Eğer kullanıcı ilaç yan etkisi, dozaj değişikliği veya tehlikeli bir durum sorarsa, nazikçe bunun tıbbi bir durum olduğunu belirt ve MUTLAKA 'Hekiminize veya en yakın sağlık kuruluşuna başvurun' uyarısını yap.

Aşağıda kullanıcının sadece takvim takibi amacıyla veritabanından çekilen güncel ilaç bilgileri yer almaktadır:
$ilaclarMetni

Kullanıcının Sorusu: '$userMessage'

Lütfen bu güvenlik sınırları içinde kalarak amcaların/teyzelerin anlayacağı şekilde sade, şefkatli bir Türkçe ile cevap ver. Emojiler kullanabilirsin.
""";

      final response = await model.generateContent([Content.text(prompt)]);

      setState(() {
        _isTyping = false;
        if (response.text != null) {
          _messages.add({"role": "ai", "text": response.text!});
        } else {
          _messages.add({
            "role": "ai",
            "text": "Şu an cevap veremiyorum, lütfen tekrar dene.",
          });
        }
      });
      _scrollToBottom();
    } catch (e) {
      print("Gemini Hatası: $e");
      setState(() {
        _isTyping = false;
        _messages.add({
          "role": "ai",
          "text": "Bir bağlantı hatası oluştu. Lütfen internetini kontrol et.",
        });
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4DB6AC),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sağlık Asistanı",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _isTyping ? "Yazıyor..." : "Çevrimiçi",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.amber.shade200, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.gavel_rounded,
                  color: Colors.amber.shade800,
                  size: 18,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Yasal Uyarı: Bu asistan tıbbi tavsiye vermez. Acil durumlar ve teşhis için doktorunuza başvurunuz.",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message["role"] == "user";

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF4DB6AC) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message["text"]!,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: isUser ? Colors.white : const Color(0xFF263238),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, left: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Asistan düşünüyor...",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: _isListening
                              ? "Dinleniyor..."
                              : "Bir şeyler yaz...",
                          hintStyle: TextStyle(
                            color: _isListening
                                ? Colors.redAccent
                                : Colors.grey,
                          ),
                          border: InputBorder.none,
                          icon: Icon(
                            _isListening
                                ? Icons.mic
                                : Icons.keyboard_alt_outlined,
                            color: _isListening
                                ? Colors.redAccent
                                : Colors.grey,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      if (_textController.text.isNotEmpty) {
                        _sendMessage();
                      } else {
                        _listen();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isListening
                            ? Colors.redAccent
                            : const Color(0xFF4DB6AC),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4DB6AC).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        _textController.text.isNotEmpty
                            ? Icons.send_rounded
                            : Icons.mic,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
