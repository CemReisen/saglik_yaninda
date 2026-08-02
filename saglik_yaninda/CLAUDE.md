# CLAUDE.md

## Firestore Security Rules

**Field-bazlı `.where()` sorgusu varsa, kural da `resource.data` üzerinden field-bazlı yazılmalı.**

Path/ID-bazlı bir kural koşulu (ör. doküman ID'sini `split()` ederek ya da `resource.id` üzerinden karar vermek) bir `list`/`.where()` sorgusuyla birlikte kullanılırsa, Firestore o sorguyu **topyekûn reddeder** (`PERMISSION_DENIED`) — dokümanları tek tek filtrelemez. Bu, path-bazlı kuralın "mantıken doğru" olup olmamasından bağımsızdır; Firestore bir `list` sorgusunu sadece kuralın `resource.data` alanları üzerinden, sorgunun kendi `where()` filtreleriyle **kanıtlanabilir şekilde** eşleştiği durumlarda güvenli sayar.

- `get()` (tek, bilinen bir doküman path'ine erişim) bu kısıtlamaya tabi değil — path/ID-bazlı kurallarla sorunsuz çalışır.
- Sadece `list`/`.where()`/`.orderBy()` gibi koleksiyon sorguları etkilenir.

**Örnek (bu projede yaşandı):** `relations/{elderId}_{caregiverId}` deterministik ID'sine dayanan bir kural (`relationId.split('_')`) yazılmıştı. `notifications_page.dart`, `main.dart` ve `caregiver_home_page.dart`'taki `.where('elderId', isEqualTo: ...)` / `.where('caregiverId', isEqualTo: ...)` sorguları bu kural altında sessizce `PERMISSION_DENIED` alıyordu — UI'da hata gösterilmediği için (StreamBuilder `snapshot.hasError` kontrolü yoktu) "veri yok" gibi görünüyordu.

**Düzeltme:** `allow read`'i `get` ve `list` olarak ayırıp, `list` için `resource.data.elderId == request.auth.uid || resource.data.caregiverId == request.auth.uid` gibi field-bazlı bir koşul kullanmak. `get` tarafında, doküman henüz yoksa (`resource == null`) da izin vermek gerekebilir (ör. "bu ilişki zaten var mı?" ön-kontrolleri için) — path-bazlı kural bu durumda hâlâ kullanılabilir çünkü `get()` etkilenmiyor.

**Doğrulama yöntemi:** Yeni bir Firestore kuralı yazıldığında/değiştirildiğinde, teorik akıl yürütmeye güvenmek yerine `@firebase/rules-unit-testing` + Firestore emulator ile (`firebase emulators:exec --only firestore "node test-script.js"`) gerçek client sorgularını simüle ederek doğrulamak — production'a dokunmadan, kesin sonuç verir.

## Proje Durumu (2026-08-02)

### Durum: bildirim mimarisinin tamamı doğrulandı ✅
Tüm bildirim akışları (bağlantı isteği, ilaç eklendi, ilaç alındı, SOS, dürtme/hatırlatma) gerçek cihaz + emülatör kombinasyonuyla uçtan uca test edildi, sorunsuz çalışıyor.

### Tamamlanan ve test edilen akışlar
- **Bağlantı kodu ile bağlanma / bağlantı isteği** (caregiver → elder, `resolveConnectionCode` Cloud Function üzerinden) — çalışıyor.
- **İlaç ekleme / senkronizasyon** (`add_medicine_page.dart` → Firestore `medicines` alt koleksiyonu) — çalışıyor.
- **"İlaç alındı" bildirimi** (elder → caregiver, `notification_requests` + `type: "medicine_taken"` → `onNotificationRequestCreated` Cloud Function) — çalışıyor.
- **SOS bildirimi** (elder → caregiver, `type: "sos"`) — çalışıyor.
- **"Dürtme/hatırlatma" bildirimi** (caregiver → elder, `type: "nudge"`) — çalışıyor.

### Çözülmüş: FCM token senkronizasyon eksikliği (2026-08-02)
"Dürtme" bildirimi araştırılırken ortaya çıkan asıl kök neden: **`fcmToken` sadece login/register anında bir kere yazılıyordu**, hiçbir yerde `onTokenRefresh` dinlenmiyordu. FCM token cihazda rotasyona uğradığında Firestore'daki değer bayatlıyor, Cloud Function `admin.messaging().send()` başarılı log/message ID döndürse bile bildirim cihaza hiç ulaşmıyordu (`messaging/registration-token-not-registered`).

Düzeltme:
- `lib/main.dart`: `FirebaseAuth.instance.authStateChanges().listen(...)` ile her oturum açılışında (`_syncFcmToken`) token Firestore'daki değerle karşılaştırılıp farklıysa güncelleniyor; `FirebaseMessaging.instance.onTokenRefresh.listen(...)` ile token her yenilendiğinde anında Firestore'a yazılıyor.
- `functions/index.js` (`onNotificationRequestCreated`): `error.code === "messaging/registration-token-not-registered"` durumunda ilgili kullanıcının `fcmToken` alanı otomatik siliniyor (`FieldValue.delete()`) — geçersiz token'lar veritabanında birikmiyor, bir sonraki senkronizasyonda taze token otomatik yazılıyor.
- `caregiver_home_page.dart` → `_sendNudgeNotification`: catch bloğu artık gerçek hatayı da gösteriyor (`debugPrint` + kullanıcıya kırmızı SnackBar), önceden sessizce `print` ile yutuluyordu.

### Çözülmüş: İlaç alarmlarında "belirli gün" ve "bitiş tarihi" uygulanmıyordu (2026-08-02)
İki bug gerçek cihazda test edilip doğrulandı ✅:

1. **"Belirli Günler" seçimi gerçek alarma yansımıyordu** — `NotificationService.scheduleNotification` her zaman `DateTimeComponents.time` (günlük tekrar) kullanıyordu, gün filtresi sadece UI listelerinde uygulanıyordu. `flutter_local_notifications` (v17.2.4) tek çağrıda çoklu-gün tekrarı desteklemiyor (`DateTimeComponents.dayOfWeekAndTime` sadece TEK bir haftanın günü için haftalık tekrar kurar) — bu yüzden `add_medicine_page.dart`'ta artık seçilen **her gün için ayrı bir alarm** kuruluyor, üretilen id'ler `notificationIds` (liste) alanında Firestore'a yazılıyor. Eski tekil `notificationId` alanı artık yazılmıyor; okuma tarafı (`NotificationService.extractNotificationIds`) geriye dönük uyumluluk için hâlâ destekliyor (eski kayıtlar hep "Her Gün" tipinde olduğundan tek id yeterli).
2. **Bitiş tarihi (`endDate`) alarmda hiç hesaba katılmıyordu** — paket seviyesinde "şu tarihten sonra durdur" desteği yok, bu yüzden iki parçalı çözüm uygulandı: (a) `add_medicine_page.dart`'ta `endDate` zaten geçmişse alarm hiç kurulmuyor (`notificationIds: []`); (b) `main.dart`'ta `_cancelExpiredMedicineAlarms(uid)` taraması — süresi dolan ilaçların alarmlarını iptal edip `notificationsCancelled: true` işaretliyor. Bu tarama hem `authStateChanges` (her oturum açılışı) hem de yeni `_AppLifecycleObserver` ile `AppLifecycleState.resumed`'e (uygulama her ön plana geldiğinde) bağlı — ek bir arka plan görevi paketi (workmanager vb.) gerekmeden daha sık kontrol sağlıyor. **Bilinen sınır:** Uygulama hiç açılmazsa/öne getirilmezse alarm bir sonraki açılışa kadar çalmaya devam edebilir — tam native "auto-expire" değil, ama "sonsuza kadar çalar" bug'ını pratikte "en geç bir sonraki açılışa kadar çalar"a indiriyor.

`home_page.dart`'taki silme akışı da (`_deleteMedicine`) artık tek id yerine `notificationIds` listesindeki tüm alarmları iptal ediyor.

### Çözülmüş: İlaç düzenlenince (Home → "Düzenle") eski alarm yeniden kurulmuyordu (2026-08-02)
`home_page.dart` → `_showEditDialog`'daki "Kaydet" sadece Firestore'daki `hour`/`minute` alanını güncelliyordu, eski `notificationId(ler)` ile kurulmuş OS alarmını hiç iptal edip yeniden kurmuyordu — saat değiştirildiğinde alarm eski saatte çalmaya devam ediyordu. Gerçek cihazda test edilip doğrulandı ✅ (saat değişince eski alarm susuyor, yeni saatte doğru çalıyor, art arda düzenlemelerde de tutarlı).

Düzeltme:
- `NotificationService`'e paylaşılan static yardımcılar eklendi: `weekDays`, `parseDdMmYyyy`, `nextInstanceOfWeekdayTime` — `add_medicine_page.dart`/`main.dart`'taki eşdeğer private mantığın tekilleştirilmiş hali (tek doğruluk kaynağı; o dosyalardaki private kopyalara dokunulmadı).
- `_showEditDialog`'un Kaydet handler'ı artık: (1) `NotificationService.extractNotificationIds(data)` ile eski id'leri alıp `await NotificationService.cancelNotifications(...)` ile **sırayla, tamamlanmasını bekleyerek** iptal ediyor, (2) `data['repeatType']`/`data['days']`/`data['endDate']`'e göre yeni saatte alarm(lar)ı yeniden kuruyor ("daily" → tek alarm, "custom" → seçili her gün için ayrı alarm), (3) `endDate` geçmişse hiç alarm kurmuyor. Eski-yeni iptal/kurulum sırası bilinçli: `Random().nextInt(1000000)` ile üretilen yeni id'ler eskilerle çakışabileceğinden, önce eskilerin iptalinin **tamamlandığından emin olunuyor**, sonra yenileri kuruluyor.
- Firestore güncellemesine `notificationIds` (liste) ve `notificationsCancelled` alanları da eklendi — eski tekil `notificationId` alanlı legacy kayıtlar düzenlendiğinde otomatik olarak yeni liste formatına geçiyor.

### Not: test ortamı sınırlaması (gerçek bug değil)
Aynı araştırma sürecinde ayrıca fark edildi: **duplicate edilmiş emülatörler Firebase Installations ID'sini (dolayısıyla FCM token'ı) paylaşabiliyor** — elder ve caregiver hesapları klonlanmış bir emülatörde test edilirse ikisi de aynı token'a sahip olur ve bildirim "yanlış yerde" (aynı cihazda) görünür/görünmez gibi kafa karıştırıcı sonuçlar verir. Bu bir kod hatası değildi. **İleride test edilirken emülatör "Duplicate" ile değil "Create Device" ile bağımsız oluşturulmalı**, ya da gerçek cihaz + tek emülatör kombinasyonu tercih edilmeli.
