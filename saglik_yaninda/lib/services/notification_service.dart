import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _noti =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_stat_name');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _noti.initialize(settings);
    print("🔔 Bildirim Servisi Başlatıldı (Türkiye Saati ile).");

    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation = _noti
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  // 🔥 ANLIK BİLDİRİMLER İÇİN SESSİZ MOD KONTROLÜ 🔥
  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bool notificationsOn = prefs.getBool('notifications') ?? true;

    // 🔥 GÜNCEL: Artık "silentMode" (Sessiz Mod) değerini okuyoruz
    final bool silentMode = prefs.getBool('silentMode') ?? false;

    // Ses açık mı? (Sessiz mod kapalıysa ses açıktır)
    final bool soundOn = !silentMode;

    if (!notificationsOn) {
      print("🔕 Bildirimler kapalı, anlık bildirim ekrana basılmadı.");
      return;
    }

    AndroidNotificationDetails androidDetails =
        const AndroidNotificationDetails(
          'channel_instant',
          'Anlık Bildirimler',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: 'ic_stat_name',
          color: Color(0xFF4DB6AC),
        );

    if (!soundOn) {
      androidDetails = const AndroidNotificationDetails(
        'channel_silent',
        'Sessiz Bildirimler',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        icon: 'ic_stat_name',
        color: Color(0xFF4DB6AC),
      );
    }

    await _noti.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
    print("🔔 Anlık bildirim ekrana basıldı: $title");
  }

  // 🔥 GELECEKTEKİ ALARMLAR İÇİN SESSİZ MOD KONTROLÜ 🔥
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String notificationType,
    DateTimeComponents matchDateTimeComponents = DateTimeComponents.time,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bool notificationsOn = prefs.getBool('notifications') ?? true;

    // 🔥 GÜNCEL: "silentMode" değerini oku ve sesi tersine çevir
    final bool silentMode = prefs.getBool('silentMode') ?? false;
    final bool soundOn = !silentMode;

    if (!notificationsOn) {
      print("🔕 Bildirimler kapalı, alarm sisteme kurulmadı.");
      return;
    }

    String finalType = notificationType;
    if (!soundOn) {
      finalType = "Sessiz";
    }

    AndroidNotificationDetails androidDetails =
        const AndroidNotificationDetails(
          'channel_standard',
          'İlaç Hatırlatıcı',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: 'ic_stat_name',
          color: Color(0xFF4DB6AC),
        );

    if (finalType == "Sessiz") {
      androidDetails = const AndroidNotificationDetails(
        'channel_silent',
        'Sessiz Bildirimler',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        icon: 'ic_stat_name',
        color: Color(0xFF4DB6AC),
      );
    } else if (finalType == "Alarm") {
      androidDetails = const AndroidNotificationDetails(
        'channel_alarm',
        'Alarm Bildirimleri',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        icon: 'ic_stat_name',
        color: Color(0xFF4DB6AC),
      );
    }

    final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    await _noti.zonedSchedule(
      id,
      title,
      body,
      scheduledTZDate,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
    );

    print(
      "⏰ Alarm kuruldu ($finalType - Sessiz Mod: $silentMode): $id - ${scheduledTZDate.hour}:${scheduledTZDate.minute.toString().padLeft(2, '0')}",
    );
  }

  /// `Random().nextInt(1000000)` ile üretilen id'ler cihazda hâlâ etkin
  /// (pending) başka bir alarmla çakışırsa, `flutter_local_notifications`
  /// bunu hata vermeden sessizce üzerine yazar — biri sessizce kaybolur.
  /// Bu yüzden id üretirken cihazdaki gerçek pending listesine bakıyoruz
  /// (Firestore'daki `notificationIds` alanları değil — asıl kaynak bu,
  /// çünkü orada tutarsızlık olsa bile OS'ta hangi id'lerin dolu olduğunu
  /// kesin olarak bilen tek yer `pendingNotificationRequests()`).
  ///
  /// `exclude`: aynı kaydetme/düzenleme işlemi içinde bu çağrıdan ÖNCE
  /// üretilmiş ama henüz `scheduleNotification` ile cihaza kurulmadığı
  /// için pending listesinde daha görünmeyen id'ler (ör. aynı ilacın diğer
  /// dozları/günleri için üretilenler) — çağıran taraf bunları elinde
  /// tuttuğu listeyle (`allScheduledIds` gibi) geçirmeli.
  static Future<int> generateUniqueId({List<int> exclude = const []}) async {
    final List<PendingNotificationRequest> pending =
        await _noti.pendingNotificationRequests();
    final Set<int> taken = {...pending.map((r) => r.id), ...exclude};

    final Random random = Random();
    int candidate;
    int attempts = 0;
    do {
      candidate = random.nextInt(1 << 31);
      attempts++;
    } while (taken.contains(candidate) && attempts < 100);
    return candidate;
  }

  static Future<void> cancelNotification(int id) async {
    await _noti.cancel(id);
    print("🗑️ Alarm iptal edildi. ID: $id");
  }

  static Future<void> cancelNotifications(List<int> ids) async {
    for (final id in ids) {
      await cancelNotification(id);
    }
  }

  /// İlaç dokümanından zamanlanmış alarm id'lerini okur. Yeni kayıtlar
  /// `notificationIds` (liste, "Belirli Günler" için birden fazla alarm
  /// içerebilir) kullanır; eski kayıtlarda (hep "Her Gün" tipinde) sadece
  /// tekil `notificationId` alanı vardır — geriye dönük uyumluluk için o da
  /// desteklenir.
  static List<int> extractNotificationIds(Map<String, dynamic> data) {
    final rawList = data['notificationIds'];
    if (rawList is List) {
      return rawList.whereType<int>().toList();
    }
    final singleId = data['notificationId'];
    if (singleId is int) {
      return [singleId];
    }
    return [];
  }

  /// "Belirli Günler" alarmlarında kullanılan gün kısaltmaları — index+1,
  /// DateTime.weekday ile eşleşecek şekilde Pazartesi=1'den başlar.
  static const List<String> weekDays = [
    "Pzt",
    "Sal",
    "Çar",
    "Per",
    "Cum",
    "Cmt",
    "Paz",
  ];

  /// "d.m.yyyy" formatındaki (add_medicine_page.dart'ta yazılan) tarih
  /// string'ini parse eder.
  static DateTime? parseDdMmYyyy(String? value) {
    if (value == null) return null;
    final parts = value.split('.');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  /// Verilen haftanın gününe (1=Pzt..7=Paz) ve saate denk gelen, şu andan
  /// sonraki ilk tarihi döndürür.
  static DateTime nextInstanceOfWeekdayTime(int targetWeekday, TimeOfDay time) {
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
}
