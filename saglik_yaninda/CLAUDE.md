# CLAUDE.md

## Firestore Security Rules

**Field-bazlı `.where()` sorgusu varsa, kural da `resource.data` üzerinden field-bazlı yazılmalı.**

Path/ID-bazlı bir kural koşulu (ör. doküman ID'sini `split()` ederek ya da `resource.id` üzerinden karar vermek) bir `list`/`.where()` sorgusuyla birlikte kullanılırsa, Firestore o sorguyu **topyekûn reddeder** (`PERMISSION_DENIED`) — dokümanları tek tek filtrelemez. Bu, path-bazlı kuralın "mantıken doğru" olup olmamasından bağımsızdır; Firestore bir `list` sorgusunu sadece kuralın `resource.data` alanları üzerinden, sorgunun kendi `where()` filtreleriyle **kanıtlanabilir şekilde** eşleştiği durumlarda güvenli sayar.

- `get()` (tek, bilinen bir doküman path'ine erişim) bu kısıtlamaya tabi değil — path/ID-bazlı kurallarla sorunsuz çalışır.
- Sadece `list`/`.where()`/`.orderBy()` gibi koleksiyon sorguları etkilenir.

**Örnek (bu projede yaşandı):** `relations/{elderId}_{caregiverId}` deterministik ID'sine dayanan bir kural (`relationId.split('_')`) yazılmıştı. `notifications_page.dart`, `main.dart` ve `caregiver_home_page.dart`'taki `.where('elderId', isEqualTo: ...)` / `.where('caregiverId', isEqualTo: ...)` sorguları bu kural altında sessizce `PERMISSION_DENIED` alıyordu — UI'da hata gösterilmediği için (StreamBuilder `snapshot.hasError` kontrolü yoktu) "veri yok" gibi görünüyordu.

**Düzeltme:** `allow read`'i `get` ve `list` olarak ayırıp, `list` için `resource.data.elderId == request.auth.uid || resource.data.caregiverId == request.auth.uid` gibi field-bazlı bir koşul kullanmak. `get` tarafında, doküman henüz yoksa (`resource == null`) da izin vermek gerekebilir (ör. "bu ilişki zaten var mı?" ön-kontrolleri için) — path-bazlı kural bu durumda hâlâ kullanılabilir çünkü `get()` etkilenmiyor.

**Doğrulama yöntemi:** Yeni bir Firestore kuralı yazıldığında/değiştirildiğinde, teorik akıl yürütmeye güvenmek yerine `@firebase/rules-unit-testing` + Firestore emulator ile (`firebase emulators:exec --only firestore "node test-script.js"`) gerçek client sorgularını simüle ederek doğrulamak — production'a dokunmadan, kesin sonuç verir.

## Proje Durumu (2026-08-01)

### Tamamlanan ve test edilen akışlar
- **Bağlantı kodu ile bağlanma** (caregiver → elder, `resolveConnectionCode` Cloud Function üzerinden) — çalışıyor.
- **İlaç ekleme / senkronizasyon** (`add_medicine_page.dart` → Firestore `medicines` alt koleksiyonu) — çalışıyor.
- **"İlaç alındı" bildirimi** (elder → caregiver, `notification_requests` + `type: "medicine_taken"` → `onNotificationRequestCreated` Cloud Function) — çalışıyor.
- **SOS bildirimi** (elder → caregiver, `type: "sos"`) — çalışıyor.

### Açık bug — bir sonraki oturumda buradan devam
**Caregiver'daki "dürtme/hatırlatma" butonu** (`caregiver_home_page.dart` → `_sendNudgeNotification`) "Hatırlatma başarıyla gönderildi! ✅" mesajı gösteriyor ama **elder'a push bildirimi ulaşmıyor**.

Kontrol edilecekler (sırayla):
1. `notification_requests` koleksiyonuna gerçekten `type: "nudge"` alanıyla bir doküman yazılıyor mu (serviceAccountKey.json ile canlı veriyi oku).
2. Yazılıyorsa: `onNotificationRequestCreated` Cloud Function bu dokümanı doğru işliyor mu — Cloud Functions loglarına bak (`firebase functions:log` ya da Console). `nudge` tipinde `recipientId`'nin `elderId` olması gerekiyor (caregiver/sos'un aksine, yön ters) — `MESSAGE_BUILDERS.nudge` mantığını doğrula.
3. Elder'ın `users/{elderId}` dokümanında `fcmToken` alanı gerçekten dolu mu (elder cihazda oturum açıp bildirim izni vermiş mi, token güncel mi).
4. `relations` içinde caregiver-elder arasında gerçekten `approved` bir ilişki var mı (yoksa `isApprovedRelation` reddeder, ama bu durumda "gönderildi" mesajı da görünmemesi beklenirdi — client tarafında `notification_requests.add()` her zaman "başarılı" sayılıyor çünkü yazma işlemi kurala uysun uymasın client sadece Firestore write'ının tamamlandığını görüyor, bildirimin gerçekten gönderilip gönderilmediğini bilmiyor).
