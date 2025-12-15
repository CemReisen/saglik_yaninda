import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _noti =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

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
    print("🔔 Bildirim Servisi Başlatıldı.");
  }

  // 🔥 GÜNCELLENMİŞ ALARM FONKSİYONU
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String notificationType, // 🔥 Standart, Sessiz, Alarm
  }) async {
    // 1. Kanal Ayarlarını Belirle
    AndroidNotificationDetails androidDetails;

    if (notificationType == "Sessiz") {
      // 🔕 SESSİZ KANAL
      androidDetails = const AndroidNotificationDetails(
        'channel_silent', // Farklı ID şart
        'Sessiz Bildirimler',
        importance: Importance.low, // Düşük önem (Ekrana fırlar ama ses çıkmaz)
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
      );
    } else if (notificationType == "Alarm") {
      // 📢 ALARM KANALI (Israrlı)
      androidDetails = const AndroidNotificationDetails(
        'channel_alarm',
        'Alarm Bildirimleri',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true, // Ekranı uyandır
      );
    } else {
      // 🔔 STANDART KANAL
      androidDetails = const AndroidNotificationDetails(
        'channel_standard',
        'İlaç Hatırlatıcı',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
    }

    // 2. Alarmı Kur
    await _noti.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Her gün tekrar
    );

    print(
      "⏰ Alarm kuruldu ($notificationType): $id - ${scheduledDate.hour}:${scheduledDate.minute}",
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _noti.cancel(id);
    print("🗑️ Alarm iptal edildi. ID: $id");
  }
}
