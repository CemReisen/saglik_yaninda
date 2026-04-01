import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _noti =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. BÜYÜK DÜZELTME: Zaman dilimlerini yükle ve lokasyonu Türkiye'ye (İstanbul) ayarla!
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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

    // 2. BÜYÜK DÜZELTME: Android 13+ için açıkça bildirim ve alarm izni iste
    await _requestPermissions();
  }

  // 🔥 YENİ EKLENEN İZİN İSTEME FONKSİYONU
  static Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation = _noti
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      // Bildirim gönderme izni (Android 13+)
      await androidImplementation.requestNotificationsPermission();
      // Tam zamanında alarm kurma izni (Android 12+)
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  // 🔥 GÜNCELLENMİŞ ALARM FONKSİYONU
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String notificationType, // Standart, Sessiz, Alarm
  }) async {
    // 1. Kanal Ayarlarını Belirle
    AndroidNotificationDetails androidDetails;

    if (notificationType == "Sessiz") {
      androidDetails = const AndroidNotificationDetails(
        'channel_silent',
        'Sessiz Bildirimler',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
      );
    } else if (notificationType == "Alarm") {
      androidDetails = const AndroidNotificationDetails(
        'channel_alarm',
        'Alarm Bildirimleri',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        'channel_standard',
        'İlaç Hatırlatıcı',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
    }

    // Seçilen saati Türkiye yerel saatine (TZDateTime) çevir
    final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    // 2. Alarmı Kur
    await _noti.zonedSchedule(
      id,
      title,
      body,
      scheduledTZDate,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode
          .exactAllowWhileIdle, // Android 14 uyumlu yeni parametre
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // Her gün aynı saatte tekrar et
    );

    print(
      "⏰ Alarm kuruldu ($notificationType): $id - ${scheduledTZDate.hour}:${scheduledTZDate.minute.toString().padLeft(2, '0')}",
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _noti.cancel(id);
    print("🗑️ Alarm iptal edildi. ID: $id");
  }
}
