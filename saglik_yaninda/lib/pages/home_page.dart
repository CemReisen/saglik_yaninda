import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saglik_yaninda/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // 🔥 YENİ: İNTERNET KONTROL PAKETİ
import 'package:saglik_yaninda/core/theme/app_colors.dart';

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

  /// Bugünün henüz alınmamış ilaçları arasından saati en yakın olanı döner.
  /// Bilinçli olarak "şu andan sonraki" ile sınırlamıyoruz: saati geçmiş ama
  /// hâlâ işaretlenmemiş (gecikmiş) bir ilaç, eskiden bu filtreden sessizce
  /// düşüp "sıradaki" kartından kayboluyordu — oysa gecikmiş bir doz, henüz
  /// vakti gelmemiş bir dozdan daha acil gösterilmeyi hak ediyor.
  QueryDocumentSnapshot? _getNextMedicine(
    List<QueryDocumentSnapshot> medicines,
    String today,
  ) {
    final untaken = medicines
        .where(
          (doc) =>
              (doc.data() as Map<String, dynamic>)['lastTakenDate'] != today,
        )
        .toList();
    if (untaken.isEmpty) return null;
    untaken.sort((a, b) {
      var dataA = a.data() as Map<String, dynamic>;
      var dataB = b.data() as Map<String, dynamic>;
      return ((dataA['hour'] as int) * 60 + (dataA['minute'] as int)).compareTo(
        (dataB['hour'] as int) * 60 + (dataB['minute'] as int),
      );
    });
    return untaken.first;
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
                // olduktan SONRA yenilerini kuruyoruz. Yeni id'ler artık
                // NotificationService.generateUniqueId ile cihazdaki pending
                // alarmlara bakılarak üretiliyor; eskiler burada zaten iptal
                // edildiği için onlarla çakışma riski yok.
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
                    (data['days'] as List?)?.whereType<String>().toList() ?? [];
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
                          fontSize: 16,
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
                  fontSize: 16,
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
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
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
                        style: TextStyle(color: Colors.redAccent, fontSize: 14),
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
                        style: TextStyle(color: Colors.blueGrey, fontSize: 14),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondaryStrong,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildInfoRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: AppColors.textSecondaryStrong),
      const SizedBox(width: 8),
      Text(
        "$label ",
        style: const TextStyle(
          color: AppColors.textSecondaryStrong,
          fontSize: 16,
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    );
  }

  /// SOS artık başlık satırındaki küçük bir "hap" buton değil, kendi
  /// tam-genişlik satırında — acil durum eylemi için daha büyük/belirgin
  /// bir dokunma hedefi. Davranış (onTap) değişmedi, sadece boyut/konum.
  Widget _buildSOSButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: GestureDetector(
        onTap: () => _showSOSConfirmDialog(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE53935),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 8),
              Text(
                "SOS",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
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
              // Bu Column'un içeriği sabit yükseklikte (başlık satırı +
              // 3x70dp item) ve dıştaki Expanded ona tight bir yükseklik
              // constraint'i veriyor (ekranın kalan boşluğu ne kadarsa o
              // kadar). Üstteki SOS butonu artık kendi tam-genişlik satırına
              // taşındığı için (bkz. _buildSOSButton) bu Expanded'a kalan
              // boşluk daraldı — küçük ekranlarda (bildirilen: 25px)
              // RenderFlex overflow oluşuyordu. Bu sadece geçici bir
              // shimmer placeholder olduğu için içeriği "sıkıştırmak"
              // yerine SingleChildScrollView ile sarmak en güvenlisi:
              // veri geldiğinde zaten kayboluyor, en kötü ihtimalle çok
              // dar bir ekranda son item'ın altı hafifçe kırpılır/kaydırılır
              // ama sert bir overflow hatası hiç oluşmaz.
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
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
                          Container(
                            width: 100,
                            height: 20,
                            color: Colors.white,
                          ),
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
          ),
        ],
      ),
    );
  }

  /// Ana ekranın en dikkat çekici alanı: bugünün henüz alınmamış ilaçları
  /// arasından saati en yakın olanı (bkz. _getNextMedicine) büyük, teal
  /// gradyanlı bir kartta öne çıkarır. Eskiden burada soyut bir "Günlük
  /// İlaç Tamamlama %X" ilerleme çubuğu vardı — yaşlı kullanıcı için somut
  /// bir bilgi taşımıyordu, kaldırıldı.
  ///
  /// totalCount == 0: bugün hiç ilaç yok, kart tamamen gizli.
  /// nextMed == null (ama totalCount > 0): bugünün tüm ilaçları alınmış,
  /// tebrik mesajı gösterilir.
  Widget _buildNextDoseCard(
    Map<String, dynamic>? nextMed,
    String? docId,
    int totalCount,
  ) {
    if (totalCount == 0) return const SizedBox();

    if (nextMed == null || docId == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF26A69A), Color(0xFF00897B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Text("🎉", style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                "Bugünkü tüm ilaçlarını aldın!",
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    String formattedTime =
        "${nextMed['hour'].toString().padLeft(2, '0')}:${nextMed['minute'].toString().padLeft(2, '0')}";

    return InkWell(
      onTap: () => _showMedicineDetails(nextMed, docId),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF26A69A), Color(0xFF00897B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alarm, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Sıradaki",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$formattedTime - ${nextMed['name'] ?? ''}",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${nextMed['dose'] ?? ''}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          height: _isOffline ? 44 : 0,
          color: Colors.redAccent,
          child: _isOffline
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "İnternet bağlantısı yok (Çevrimdışı Mod)",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
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
                        _buildSOSButton(),
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
                  var nextMedDoc = _getNextMedicine(todaysMedicines, today);

                  return Column(
                    children: [
                      _buildHeader(firstName),
                      _buildSOSButton(),
                      _buildNextDoseCard(
                        nextMedDoc?.data() as Map<String, dynamic>?,
                        nextMedDoc?.id,
                        totalCount,
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
                                          fontSize: 15,
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
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    isTakenToday
                                                                    ? AppColors
                                                                          .textSecondaryStrong
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
                                                                    size: 18,
                                                                    color:
                                                                        isTakenToday
                                                                        ? AppColors
                                                                              .textSecondaryStrong
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
                                                                          18,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color:
                                                                          isTakenToday
                                                                          ? AppColors.textSecondaryStrong
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
                                                              style: const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                // Tek renk: eskiden alındığında grey.shade400
                                                                // metin grey.shade100 kart zemininde neredeyse
                                                                // okunmuyordu (kontrast < 2:1). textSecondaryStrong
                                                                // hem beyaz hem grey.shade100 zeminde ~5:1+ verir.
                                                                color: AppColors
                                                                    .textSecondaryStrong,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (isTakenToday)
                                                        // İlaç zaten alınmış: mevcut davranış korunuyor -
                                                        // kompakt yeşil check ikonu, tekrar dokununca
                                                        // "alınmadı"ya geri alınabiliyor (_toggleTaken iki
                                                        // yönlü çalışıyor).
                                                        IconButton(
                                                          onPressed: () =>
                                                              _toggleTaken(
                                                                medicine.id,
                                                                medName,
                                                                isTakenToday,
                                                                today,
                                                              ),
                                                          icon: const Icon(
                                                            Icons.check_circle,
                                                            color: Colors.green,
                                                            size: 28,
                                                          ),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(),
                                                        )
                                                      else
                                                        // Alınmamış durum: eskiden belirsiz bir zil
                                                        // ikonuydu (ne anlama geldiği net değildi) -
                                                        // artık ikon + "İçtim" yazılı, hap şeklinde
                                                        // kompakt bir buton. Min 48dp dokunma alanı
                                                        // (SizedBox height: 48) korunuyor, ama tam
                                                        // genişlik kaplamıyor - alt alta birden fazla
                                                        // ilaç kartı olduğunda dikey yer israf etmiyor.
                                                        Material(
                                                          color: Colors
                                                              .transparent,
                                                          child: InkWell(
                                                            onTap: () =>
                                                                _toggleTaken(
                                                                  medicine.id,
                                                                  medName,
                                                                  isTakenToday,
                                                                  today,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  24,
                                                                ),
                                                            child: Container(
                                                              height: 48,
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        14,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    const Color(
                                                                      0xFF4DB6AC,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      24,
                                                                    ),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  const Icon(
                                                                    Icons.check,
                                                                    color: Colors
                                                                        .white,
                                                                    size: 20,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 6,
                                                                  ),
                                                                  Text(
                                                                    "İçtim",
                                                                    style: GoogleFonts.poppins(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          15,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
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
