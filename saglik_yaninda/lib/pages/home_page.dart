import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saglik_yaninda/services/notification_service.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = FirebaseAuth.instance.currentUser;

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
    try {
      var relations = await FirebaseFirestore.instance
          .collection('relations')
          .where('elderId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'approved')
          .get();

      if (relations.docs.isEmpty) return;

      final serviceAccountJson = {
        "type": "service_account",
        "project_id": "saglik-yaninda-ec8d2",
        "private_key_id": "dc5936fc74222f26f17138383be1969169dae159",
        "private_key":
            "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCs62iSyZ+yO/l3\nR5yUVVAjZnvQ3wr+y1iX5Rk3Qrn8DUSPLF0adfoEPI2LdobLuldfn9C83H4RBGPO\nIz4EuMPvidw30wo0hZRi8YL0xkxx2h34IldAzPhrpCpTBlbdUiCbZsWZybR1Op42\nR1y345bO2SU7c62bWHjtvD4LZgJDJE0d4gzSQ9dciPqiZy8q0PXZTnu77UulfLOJ\nhinlnn/cbJHa6HDe2nNU/uPLPLvLC6X3Qabn6y6ByFCApeBGK6AQhn3eDpqrlIgp\nZn83ICP28lFq9JY/WcV1YmYlH3uCOHFefJrvKurJnTjpNRqLX8Hu6FVGGHZxN3QL\nDpM8GdIVAgMBAAECggEACF8OLTsLGukZ4usp2qmFq20Q9fPyV5L3G0VpUtpNYDUx\nOkAy0q7e93kJ/jQzAuZmx/eX9qizBrZgcZCVtktOmwhgy6gRIKlN3XtlNF3sQf/F\n/ycEc9voc+ea7/GI34aUEwnm65LPBHTdx3FtfO6M9L8g9Q+c2j4ufo3kMA+UcPUa\nz6C31hKczZFqfBIFFwFTwlSnlyn8p1o78X4/VEGdIFLG5MykofCIojCmsn2ECrY+\n+unEh0o7kAf9axtRRXoXuJWUk7nWwpwXjJXC+vJSr/ja2+st0lqVAMOn+g/2FC4g\n5r4fJ/lYgAiLN/dY6VpKDBjo/dMevmE6QQfSfiyYeQKBgQDZebLR4rSpXIjrFm1E\nPzF/JGqeByUzanGyQuEtF3wjjzRJqd4MPxWxDmRTzlcb9WHH8sStvMQJHCDVv8b5\n1Z/2rEAp2nSVWx+eN2OGRQnh/nONYFab7P06NBXGjp9D3DcrSR2J2Wb0LAUCVD/O\nXzkbxeoI1QXEEKEroY325Sq8mQKBgQDLjSVefs2fEYMIJRRj6J++tQShoQwg6t6F\nxBj4KlgROjSnWxiEz8OVQSeSf3jLh0sLXvqbm3LDBKoBSpWlZvmU9q1klzm4yWX+\nfHISxNZc5XhDkMbJPbvJVgXm4KMaaHwIWRs3kKbbiN/nTlTcce3aeYXD3B2arOtb\nStChV6xS3QKBgQCnDmQ99D9BRhLrO5wN69kyyJ+Z6vU5rM/P1q4wvDShADVzTKiE\nkcUw8FRDSGMD2BgXxzYsG7AfK1tRtvK7Ic2yaBkVzXj27ju4huXN06TG1HahKFr/\nhinzluUPVKmlMDm054JoTPdYI6RpaJxnBCDTY9HmnPTD6t5TrNNn0BxnKQKBgAxD\GHk00lY+y9H1yeCq5tSqOvkxpnVlMLqGMarhgiSniPx79GIr0fBv2F5u52v7Xn30\n3sv49VTiNwuU3qb0KRzcL13b7lI/b7GA9a5DxVYbTL9lPVRqL6HVWM2rwqeYm8A0\n/fq+8A5RlItuoJYXFukOYQyHehETUapSO3c8vNjRAoGADlXsYWSgxrqoox+XiWFJ\nnU/lixghqtFHTs2KXSal+FAO3tRfF8ulFqLyOC8PFHux9ormPLgnyX+84hgCDDtm\n8gbcV48ruW1RlRmy2OacwiOUrfSFardO0e4t/S2YnWkwZtw79C1ANApgb+iYwECa\nZtHb7XLVVuLQ5a9CaJLo2O4=\n-----END PRIVATE KEY-----\n",
        "client_email":
            "firebase-adminsdk-fbsvc@saglik-yaninda-ec8d2.iam.gserviceaccount.com",
        "client_id": "115323197056912168379",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url":
            "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url":
            "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40saglik-yaninda-ec8d2.iam.gserviceaccount.com",
        "universe_domain": "googleapis.com",
      };

      List<String> scopes = [
        "https://www.googleapis.com/auth/firebase.messaging",
      ];
      http.Client client = http.Client();
      AccessCredentials credentials =
          await obtainAccessCredentialsViaServiceAccount(
            ServiceAccountCredentials.fromJson(serviceAccountJson),
            scopes,
            client,
          );

      String bearerToken = credentials.accessToken.data;
      String projectId = serviceAccountJson["project_id"]!;

      for (var doc in relations.docs) {
        String caregiverId = doc['caregiverId'];

        var caregiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(caregiverId)
            .get();
        if (caregiverDoc.exists) {
          var data = caregiverDoc.data() as Map<String, dynamic>;
          String? fcmToken = data['fcmToken'];

          if (fcmToken != null && fcmToken.isNotEmpty) {
            String elderName = user!.displayName ?? "Yakınınız";

            await client.post(
              Uri.parse(
                'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
              ),
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $bearerToken',
              },
              body: jsonEncode({
                "message": {
                  "token": fcmToken,
                  "notification": {
                    "title": "💊 İlaç Alındı",
                    "body": "$elderName, \"$medicineName\" adlı ilacını içti!",
                  },
                },
              }),
            );
          }
        }
      }
      client.close();
    } catch (e) {
      print("Bildirim gönderme hatası: $e");
    }
  }

  Future<void> _sendSOSNotificationToCaregiver() async {
    try {
      var relations = await FirebaseFirestore.instance
          .collection('relations')
          .where('elderId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'approved')
          .get();

      if (relations.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Kayıtlı bir yakınınız bulunamadı! Lütfen önce bir yakın ekleyin.",
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final serviceAccountJson = {
        "type": "service_account",
        "project_id": "saglik-yaninda-ec8d2",
        "private_key_id": "dc5936fc74222f26f17138383be1969169dae159",
        "private_key":
            "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCs62iSyZ+yO/l3\nR5yUVVAjZnvQ3wr+y1iX5Rk3Qrn8DUSPLF0adfoEPI2LdobLuldfn9C83H4RBGPO\nIz4EuMPvidw30wo0hZRi8YL0xkxx2h34IldAzPhrpCpTBlbdUiCbZsWZybR1Op42\nR1y345bO2SU7c62bWHjtvD4LZgJDJE0d4gzSQ9dciPqiZy8q0PXZTnu77UulfLOJ\nhinlnn/cbJHa6HDe2nNU/uPLPLvLC6X3Qabn6y6ByFCApeBGK6AQhn3eDpqrlIgp\nZn83ICP28lFq9JY/WcV1YmYlH3uCOHFefJrvKurJnTjpNRqLX8Hu6FVGGHZxN3QL\nDpM8GdIVAgMBAAECggEACF8OLTsLGukZ4usp2qmFq20Q9fPyV5L3G0VpUtpNYDUx\nOkAy0q7e93kJ/jQzAuZmx/eX9qizBrZgcZCVtktOmwhgy6gRIKlN3XtlNF3sQf/F\n/ycEc9voc+ea7/GI34aUEwnm65LPBHTdx3FtfO6M9L8g9Q+c2j4ufo3kMA+UcPUa\nz6C31hKczZFqfBIFFwFTwlSnlyn8p1o78X4/VEGdIFLG5MykofCIojCmsn2ECrY+\n+unEh0o7kAf9axtRRXoXuJWUk7nWwpwXjJXC+vJSr/ja2+st0lqVAMOn+g/2FC4g\n5r4fJ/lYgAiLN/dY6VpKDBjo/dMevmE6QQfSfiyYeQKBgQDZebLR4rSpXIjrFm1E\nPzF/JGqeByUzanGyQuEtF3wjjzRJqd4MPxWxDmRTzlcb9WHH8sStvMQJHCDVv8b5\n1Z/2rEAp2nSVWx+eN2OGRQnh/nONYFab7P06NBXGjp9D3DcrSR2J2Wb0LAUCVD/O\nXzkbxeoI1QXEEKEroY325Sq8mQKBgQDLjSVefs2fEYMIJRRj6J++tQShoQwg6t6F\nxBj4KlgROjSnWxiEz8OVQSeSf3jLh0sLXvqbm3LDBKoBSpWlZvmU9q1klzm4yWX+\nfHISxNZc5XhDkMbJPbvJVgXm4KMaaHwIWRs3kKbbiN/nTlTcce3aeYXD3B2arOtb\nStChV6xS3QKBgQCnDmQ99D9BRhLrO5wN69kyyJ+Z6vU5rM/P1q4wvDShADVzTKiE\nkcUw8FRDSGMD2BgXxzYsG7AfK1tRtvK7Ic2yaBkVzXj27ju4huXN06TG1HahKFr/\nhinzluUPVKmlMDm054JoTPdYI6RpaJxnBCDTY9HmnPTD6t5TrNNn0BxnKQKBgAxD\GHk00lY+y9H1yeCq5tSqOvkxpnVlMLqGMarhgiSniPx79GIr0fBv2F5u52v7Xn30\n3sv49VTiNwuU3qb0KRzcL13b7lI/b7GA9a5DxVYbTL9lPVRqL6HVWM2rwqeYm8A0\n/fq+8A5RlItuoJYXFukOYQyHehETUapSO3c8vNjRAoGADlXsYWSgxrqoox+XiWFJ\nnU/lixghqtFHTs2KXSal+FAO3tRfF8ulFqLyOC8PFHux9ormPLgnyX+84hgCDDtm\n8gbcV48ruW1RlRmy2OacwiOUrfSFardO0e4t/S2YnWkwZtw79C1ANApgb+iYwECa\nZtHb7XLVVuLQ5a9CaJLo2O4=\n-----END PRIVATE KEY-----\n",
        "client_email":
            "firebase-adminsdk-fbsvc@saglik-yaninda-ec8d2.iam.gserviceaccount.com",
        "client_id": "115323197056912168379",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url":
            "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url":
            "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40saglik-yaninda-ec8d2.iam.gserviceaccount.com",
        "universe_domain": "googleapis.com",
      };

      List<String> scopes = [
        "https://www.googleapis.com/auth/firebase.messaging",
      ];
      http.Client client = http.Client();
      AccessCredentials credentials =
          await obtainAccessCredentialsViaServiceAccount(
            ServiceAccountCredentials.fromJson(serviceAccountJson),
            scopes,
            client,
          );

      String bearerToken = credentials.accessToken.data;
      String projectId = serviceAccountJson["project_id"]!;

      for (var doc in relations.docs) {
        String caregiverId = doc['caregiverId'];

        var caregiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(caregiverId)
            .get();
        if (caregiverDoc.exists) {
          var data = caregiverDoc.data() as Map<String, dynamic>;
          String? fcmToken = data['fcmToken'];

          if (fcmToken != null && fcmToken.isNotEmpty) {
            String elderName = user!.displayName ?? "Yakınınız";

            await client.post(
              Uri.parse(
                'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
              ),
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $bearerToken',
              },
              body: jsonEncode({
                "message": {
                  "token": fcmToken,
                  "notification": {
                    "title": "🚨 ACİL DURUM YARDIMI!",
                    "body":
                        "$elderName acil yardım çağrısında bulundu! Lütfen hemen iletişime geçin.",
                  },
                },
              }),
            );
          }
        }
      }
      client.close();

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
      print("SOS bildirim gönderme hatası: $e");
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

  void _showDeleteConfirmDialog(String docId, int notificationId) {
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
              _deleteMedicine(docId, notificationId);
            },
            child: const Text("Sil"),
          ),
        ],
      ),
    );
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
                      'isCritical': isCritical,
                      'hour': selectedTime.hour,
                      'minute': selectedTime.minute,
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
                    data['notificationId'] ?? 0,
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

  Widget _buildProgressCard(int total, int taken) {
    if (total == 0) return const SizedBox();
    double progress = taken / total;
    int percentage = (progress * 100).toInt();

    int hour = DateTime.now().hour;
    String greeting = (hour >= 6 && hour < 12)
        ? "Günaydın! ☀️"
        : (hour >= 12 && hour < 18)
        ? "İyi Günler! 🌤️"
        : (hour >= 18 && hour < 22)
        ? "İyi Akşamlar! 🌆"
        : "İyi Geceler! 🌙";
    String message = (progress == 0)
        ? "İlaçlarını almayı unutma."
        : (progress == 1.0)
        ? "Günlük hedefin bitti. 🎉"
        : "Harika gidiyorsun! 🚀";

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
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
                    "$taken / $total İlaç",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 75,
            height: 75,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Center(
                  child: Text(
                    "%$percentage",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
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
              child: const Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sıradaki İlacınız",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    nextMed['name'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "${nextMed['dose']} • Saat $formattedTime",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Giriş Yapılmalı"));
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 🔥 BURASI ANA DEĞİŞİKLİK: Firestore'dan 'name' bilgisini anlık dinleyen yapı
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots(),
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

        // İlaç listesi dinleyicisi içeride devam ediyor
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('medicines')
              .snapshots(),
          builder: (context, snapshot) {
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
              return ((dataA['hour'] as int) * 60 + (dataA['minute'] as int))
                  .compareTo(
                    (dataB['hour'] as int) * 60 + (dataB['minute'] as int),
                  );
            });

            int totalCount = todaysMedicines.length;
            int takenCount = todaysMedicines
                .where(
                  (doc) =>
                      (doc.data() as Map<String, dynamic>)['lastTakenDate'] ==
                      today,
                )
                .length;
            var nextMedDoc = _getNextMedicine(todaysMedicines, today);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
                                firstName.isNotEmpty
                                    ? firstName[0].toUpperCase()
                                    : "E",
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
                ),

                _buildProgressCard(totalCount, takenCount),
                _buildNextDoseCard(
                  nextMedDoc?.data() as Map<String, dynamic>?,
                  nextMedDoc?.id,
                ),

                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F0),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFFF19CBB),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "İlaç Listesi",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF424B7F),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8D7DA),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "$totalCount İlaç",
                                  style: TextStyle(
                                    color: const Color(0xFF842029),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                            child: todaysMedicines.isEmpty
                                ? const Center(
                                    child: Text("Bugünlük ilaç yok!"),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    itemCount: todaysMedicines.length,
                                    itemBuilder: (context, index) {
                                      var medicine = todaysMedicines[index];
                                      var data =
                                          medicine.data()
                                              as Map<String, dynamic>;
                                      bool isTakenToday =
                                          data['lastTakenDate'] == today;
                                      bool isCritical =
                                          data['isCritical'] ?? false;
                                      String time =
                                          "${data['hour'].toString().padLeft(2, '0')}:${data['minute'].toString().padLeft(2, '0')}";
                                      String medName = data['name'] ?? 'İlaç';

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isTakenToday
                                              ? const Color(0xFFF1F3F9)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.015,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 16,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isTakenToday
                                                      ? const Color(0xFFDDE1EE)
                                                      : const Color(0xFFE8EAF6),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  time,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: isTakenToday
                                                        ? Colors.indigo[900]
                                                        : const Color(
                                                            0xFF3F51B5,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 18),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        if (isCritical)
                                                          Icon(
                                                            Icons
                                                                .warning_amber_rounded,
                                                            size: 18,
                                                            color: isTakenToday
                                                                ? Colors
                                                                      .blueGrey[300]
                                                                : Colors.red,
                                                          ),
                                                        if (isCritical)
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                        Expanded(
                                                          child: Text(
                                                            medName,
                                                            style: GoogleFonts.poppins(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 17,
                                                              decoration:
                                                                  isTakenToday
                                                                  ? TextDecoration
                                                                        .lineThrough
                                                                  : null,
                                                              color:
                                                                  isTakenToday
                                                                  ? Colors
                                                                        .blueGrey[300]
                                                                  : (isCritical
                                                                        ? Colors
                                                                              .red[700]
                                                                        : Colors
                                                                              .black87),
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Text(
                                                      "${data['dose'] ?? ''} • ${data['hungerStatus'] ?? ''}",
                                                      style: TextStyle(
                                                        color: isTakenToday
                                                            ? Colors
                                                                  .blueGrey[200]
                                                            : Colors.grey[500],
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () =>
                                                    _showMedicineDetails(
                                                      data,
                                                      medicine.id,
                                                    ),
                                                icon: Icon(
                                                  Icons.info_outline,
                                                  color: isTakenToday
                                                      ? Colors.blueGrey[300]
                                                      : const Color(0xFF424B7F),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => _toggleTaken(
                                                  medicine.id,
                                                  medName,
                                                  isTakenToday,
                                                  today,
                                                ),
                                                child: Icon(
                                                  isTakenToday
                                                      ? Icons.check_circle
                                                      : Icons
                                                            .radio_button_unchecked,
                                                  color: isTakenToday
                                                      ? const Color(0xFF424B7F)
                                                      : const Color(
                                                          0xFF3949AB,
                                                        ).withOpacity(0.6),
                                                  size: 32,
                                                ),
                                              ),
                                            ],
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
    );
  }
}
