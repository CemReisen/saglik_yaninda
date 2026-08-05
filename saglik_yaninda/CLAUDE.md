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

### Çözülmüş: SOS / "ilaç alındı" offline blokları gereksiz yere işlemi engelliyordu, offline geri bildirimi de hiç görünmüyordu (2026-08-02)
`connectivity_plus`'a dayalı `_isOffline` kontrolü (`home_page.dart`) SOS, "ilaç alındı" işaretleme, ilaç düzenleme ve ilaç silme gibi işlemleri cihaz offline'dayken tamamen bloke ediyordu — ama bu işlemlerin hiçbiri doğrudan bir Cloud Function çağrısı (`resolveConnectionCode` gibi) yapmıyor, sadece Firestore yazması yapıyor; Firestore'un offline persistence'ı bu yazmaları zaten yerel kuyruğa alıp bağlantı gelince otomatik senkronize ediyor. **AI Asistan** istisna: o, doğrudan Gemini API'sine (`GenerativeModel.generateContent`) ağ isteği atıyor, gerçekten internet gerektiriyor — bloğu korundu.

Kaldırılan bloklar için iki ek düzeltme gerekti:

1. **`relations` sorgusu artık canlı dinleniyor.** SOS ve "ilaç alındı" bildirimleri, hangi caregiver'a yazılacağını bulmak için önce `relations` koleksiyonunu okuyordu (`elderId == uid && status == approved`). Bu okuma elder tarafında hiçbir yerde sürekli dinlenmiyordu (sadece bu iki fonksiyonda tek seferlik `.get()`) — offline'da bu sorgu hiç cache'lenmemişse `.get()` sessizce başarısız oluyor, `catch` bloğu sadece `print` ile yutuyordu, bildirim hiç kuyruğa bile girmiyordu. Düzeltme: `initState`'te bu sorgu için bir `.snapshots()` listener kuruldu (`_approvedCaregiverRelations` state alanı, `_relationsLoaded` ile "hiç yüklenmedi" / "yüklendi ama boş" ayrımı yapılıyor), `dispose()`'da iptal ediliyor.

2. **cloud_firestore'un offline Future davranışı:** Gerçek cihazda uçak modunda SOS test edildiğinde, Firestore yazması ve gecikmeli senkronizasyon doğru çalıştı ama offline'ı bildiren turuncu SnackBar **hiç görünmedi**. Kök neden: Flutter'ın `cloud_firestore` paketi (native Android/iOS SDK'ları üzerine kurulu), Web SDK'sinin aksine, bir yazma çağrısının (`add`/`update`/`set`) döndürdüğü `Future`'ı **sunucu ACK'i gelene kadar tamamlamıyor** — yazma yerel kuyruğa senkron olarak düşüyor ama `await` bağlantı geri gelene kadar askıda kalıyor. SnackBar kodu bu `await`'lerden sonra durduğu için offline iken hiç çalışma fırsatı bulamıyordu; ancak bağlantı geri gelip `await` çözüldüğünde çalışıyordu — o an da `_isOffline` zaten `false` olduğundan yanlış (online) mesaj gösterilmiş olurdu ya da kullanıcı ekrandan ayrılmışsa hiç görünmezdi.

   Düzeltme (`_sendSOSNotificationToCaregiver`, `_toggleTaken`): `wasOffline = _isOffline` fonksiyon başında sabitleniyor. Offline ise: kullanıcıya uygun SnackBar ("🚨 SOS kaydedildi, bağlantı sağlanınca yakınlarınıza iletilecek...", "Kaydedildi! Bağlantı sağlanınca 100 Sağlık Puanı eklenecek ve yakınınıza bildirilecek.") yazma Future'ı **beklenmeden hemen** gösteriliyor; asıl yazma (`_writeSOSNotifications`, `_applyMedicineTakenWrites`) `unawaited(...)` ile arka planda fire-and-forget devam ediyor, hata olursa sadece `debugPrint` ile loglanıyor. Online iken davranış değişmedi (yaz → bekle → onayla).

   **Bilinen/kabul edilen risk:** Fire-and-forget yazmada kalıcı bir hata olursa (bağlantı hiç gelmezse ya da senkronizasyon sırasında bir Firestore kuralı reddederse) kullanıcı bunu asla öğrenemez — düşük ihtimal, şimdilik kapsam dışı. İleride "gönderilemeyen SOS'lar" için ayrı bir kontrol paneli/log düşünülebilir.

### Çözülmüş: İlaç kaydında yerel alarm ile Firestore yazması arasında tutarsızlık riski ("hayalet alarm") (2026-08-02)
`add_medicine_page.dart` → `_saveMedicine`, her doz için önce yerel alarm(lar) kuruyor (`NotificationService.scheduleNotification`), sonra `WriteBatch`'e ekliyor, döngü bitince tek seferde `batch.commit()` çağırıyordu. Bir dozun alarmı kurulduktan sonra başka bir dozda hata olursa ya da `commit()` başarısız olursa, o ana kadar kurulmuş alarmlar hiç iptal edilmiyordu — Firestore'da kaydı olmayan ama cihazda çalmaya devam eden "hayalet alarm" oluşabiliyordu.

Sıralamayı ("önce Firestore'a yaz") değiştirmedik — bunun iki gerekçesi var: (1) `docRef.id` zaten client-side üretiliyor (`.doc()`), Firestore'a yazmanın ID için bir gerekçesi yok; (2) `await batch.commit()`'i alarm kurmanın önüne almak, offline'da alarmın hiç kurulmamasına yol açardı (bkz. bir üstteki madde — cloud_firestore'un offline Future davranışı). `WriteBatch` zaten atomik olduğu için Firestore tarafında kısmi yazma riski yok — tek risk alanı yerel alarmlardı.

Düzeltme:
- Bu save akışında kurulan **her** alarm id'si tek bir `allScheduledIds` listesinde toplanıyor. `catch` bloğunda (döngü içi bir alarm kurma hatası ya da `commit()`'in senkron attığı gerçek bir hata) `NotificationService.cancelNotifications(allScheduledIds)` ile o ana kadar kurulmuş tüm alarmlar iptal ediliyor — ya hepsi (doküman + alarmları) var oluyor ya hiçbiri.
- `add_medicine_page.dart`'a da `home_page.dart`'takiyle aynı `Connectivity`/`_isOffline` takibi eklendi. `wasOffline` fonksiyon başında sabitleniyor; offline ise `batch.commit()` beklenmeden "İlaçlar kaydedildi, bağlantı sağlanınca senkronize edilecek" mesajı gösteriliyor, commit `_commitMedicineBatchInBackground` ile arka planda (`unawaited`) devam ediyor. Arka planda kalıcı bir hata olursa (senkronizasyon sırasında kural reddi vb.) o save akışının alarmları sessizce iptal ediliyor — kullanıcı o an ekrandan ayrılmış olacağı için kendisine gösterilemiyor, SOS'takiyle aynı kategoride kabul edilmiş düşük ihtimalli risk.
- Bilinçli tasarım kararı: Firestore yazması başarılı olduktan SONRA bir alarm hatası olsaydı (mevcut sıralamada oluşmuyor ama kavramsal olarak), Firestore kaydı geri alınmaz (rollback yapılmaz) — çünkü rollback için gereken silme işlemi kendisi de bir ağ operasyonu, offline'da başarısız/askıda kalabilir. Bunun yerine kayıt tutulup kullanıcıya net bir hata gösterilir; gerekirse kullanıcı Home → Düzenle akışından (bkz. bir önceki madde) alarmı yeniden kurabilir.

### Not: test ortamı sınırlaması (gerçek bug değil)
Aynı araştırma sürecinde ayrıca fark edildi: **duplicate edilmiş emülatörler Firebase Installations ID'sini (dolayısıyla FCM token'ı) paylaşabiliyor** — elder ve caregiver hesapları klonlanmış bir emülatörde test edilirse ikisi de aynı token'a sahip olur ve bildirim "yanlış yerde" (aynı cihazda) görünür/görünmez gibi kafa karıştırıcı sonuçlar verir. Bu bir kod hatası değildi. **İleride test edilirken emülatör "Duplicate" ile değil "Create Device" ile bağımsız oluşturulmalı**, ya da gerçek cihaz + tek emülatör kombinasyonu tercih edilmeli.

## Küçük temizlik maddeleri (2026-08-05)

### Çözülmüş: Bildirim id'lerinde çakışma riski
`add_medicine_page.dart` ve `home_page.dart`'taki alarm kurulumları `Random().nextInt(1000000)` ile id üretiyordu — hem aynı kaydetme/düzenleme işlemi içindeki diğer doz/gün alarmlarıyla hem de kullanıcının **başka** ilaçları için cihazda hâlâ etkin (pending) alarmlarla çakışma ihtimali vardı. `flutter_local_notifications` id çakışmasında hata fırlatmıyor, sessizce üzerine yazıyor — çakışan iki alarmdan biri kullanıcı hiç fark etmeden kayboluyordu.

Düzeltme: `NotificationService.generateUniqueId({List<int> exclude})` eklendi — id üretirken `_noti.pendingNotificationRequests()` ile cihazdaki gerçek pending alarm id'lerine bakıyor (Firestore'daki `notificationIds` alanları değil; OS'ta hangi id'lerin dolu olduğunu kesin bilen tek kaynak bu), `exclude` ile de aynı işlem içinde henüz cihaza kurulmamış ama zaten üretilmiş id'leri (`allScheduledIds`/`newNotificationIds`) dışlıyor. Üç çağrı sitesi (`add_medicine_page.dart`'ta 2, `home_page.dart`'ın Düzenle akışında 2) bu yardımcıya geçirildi; `home_page.dart`'ta eskiler zaten yenilerden ÖNCE iptal edildiği için ek bir çakışma riski yok (bkz. bir üstteki madde).

### Çözülmüş: Ölü kod temizliği
- `lib/models/medicine_model.dart` (`MedicineModel`) — hiçbir yerde import edilmiyordu, silindi.
- `fl_chart` paketi (`pubspec.yaml`) — hiçbir dosyada `fl_chart` import'u yoktu, kaldırıldı.
- `add_medicine_page.dart`'ta ilaç dokümanına yazılan `'isTaken': false` alanı — hiçbir yerde okunmuyordu; gerçek "bugün alındı mı" takibi `lastTakenDate` alanı üzerinden yapılıyor (`home_page.dart` → `_applyMedicineTakenWrites`/`_toggleTaken`). Yazma satırı kaldırıldı.

### Çözülmüş: Gemini model adı doğrulaması
`home_page.dart`'taki AI Asistan `GenerativeModel(model: 'gemini-3.1-flash-lite-preview', ...)` kullanıyordu. Google'ın resmi model listesi (ai.google.dev/gemini-api/docs/models) doğrulandığında bu preview model'in **kapatıldığı** ("Shut down", "Previous models" altında) görüldü — kararlı karşılığı `gemini-3.1-flash-lite`. Model adı güncellendi; aksi halde AI Asistan sohbeti sessizce hata veriyor olabilirdi (bu oturumda gerçek API çağrısıyla ayrıca doğrulanmadı, sadece resmî dokümantasyon üzerinden).

**Not (2026-08-05):** Model adı düzeltmesinden sonra kullanıcı "Bir bağlantı hatası oluştu" hatası almaya devam etti (internet bağlıyken). Araştırma sırasında (a) `catch` bloğunun gerçek exception'ı yutup genel bir mesaj gösterdiği, (b) `GEMINI_API_KEY`'in `--dart-define` ile build'e doğru şekilde geçtiği (aksi halde farklı bir "kullanılamıyor" mesajı görünürdü), (c) `google_generative_ai` paketinin (0.4.7, pub.dev'deki en güncel ama **deprecated** ilan edilmiş sürüm) model adını client-side doğrulamadığı tespit edildi — kesin kök neden (muhtemelen API key sorunu) canlı testle doğrulanamadan, aşağıdaki karar nedeniyle araştırma sonlandırıldı.

## AI Asistan özelliği tamamen kaldırıldı (2026-08-05)

**Karar:** Gemini API için sürekli ödeme/kota yönetimi istenmiyor; özellik hedef kitle (yaşlı kullanıcılar) için öncelikli değildi. Yukarıdaki "bağlantı hatası" sorunu araştırılırken bu karar alındı — kök neden bulunup düzeltilmek yerine özellik komple kaldırıldı.

Kaldırılanlar:
- `lib/pages/home_page.dart`: `AiAssistantPage`/`_AiAssistantPageState` sınıfları (chat UI, Gemini çağrısı, `GEMINI_API_KEY`/`String.fromEnvironment` okuması dahil ~410 satır) ve ona navigate eden `_buildAssistantSearchBar` arama çubuğu widget'ı (hem skeleton-loading hem normal `Column` dallarındaki çağrı siteleri) silindi.
- `pubspec.yaml`: `google_generative_ai` (kullanıcının istediği) ve `speech_to_text` (yalnızca AI Asistan'ın mikrofon girişi için kullanılıyordu, kaldırıldıktan sonra tamamen ölü kalıyordu — birlikte kaldırıldı) bağımlılıkları kaldırıldı.
- `flutter analyze`: 0 hata (sadece projede zaten var olan, ilgisiz `withOpacity`/`print` gibi info/warning'ler kaldı).

`android/app/src/main/AndroidManifest.xml`'deki `RECORD_AUDIO` izni de kaldırıldı (yalnızca `speech_to_text` için ekliydi, kullanıcı onayıyla).

**Artık gerekli değil:** `flutter run`/`build` komutlarına `--dart-define=GEMINI_API_KEY=...` geçirmeye gerek yok — kod hiçbir yerde bu env var'ı okumuyor.

Commit: `2c8e8dc` (`feature/ui-shell` dalına push edildi).

## Proje Durumu (2026-08-05) — güncel özet

- **AI Asistan özelliği tamamen kaldırıldı.** Gemini API için sürekli ödeme/kota yönetimi istenmediği ve hedef kitle (yaşlı kullanıcılar) için öncelikli bir özellik olmadığı için özellik komple sökülüp atıldı (bkz. yukarıdaki bölüm) — kısmi bir bug fix değil, bilinçli bir kapsam kararı.
- **Altyapı temizlik maddeleri tamamlandı:** bildirim id çakışma riski (`NotificationService.generateUniqueId`), ölü kod (`MedicineModel`, `fl_chart`, kullanılmayan `isTaken` alanı) — bkz. "Küçük temizlik maddeleri" bölümü.
- `flutter analyze` temiz (0 hata), gerçek cihazda test edildi.

### Not: `saglik-yaninda-backend` ayrı bir Node.js backend (2026-08-05)
`../saglik-yaninda-backend` klasöründe ayrı bir git deposu ve ayrı bir Node.js backend var (Render'da deploy ediliyor). Bugün bu backend'de kritik bir güvenlik açığı (sızdırılmış servis hesabı anahtarı — `serviceAccountKey.json` GitHub'da açıkta duruyordu) tespit edilip düzeltildi. **Detaylar o klasörün kendi `CLAUDE.md`'sinde.**

## UI Revizyonu tamamlandı: yaşlı kullanıcılar için hedefli iyileştirmeler (2026-08-05)

**Kapsam:** Baştan yazım değil — mevcut tasarım (teal/yeşil-mavi, kart tabanlı) korunarak yaşlı kullanıcı kitlesi için okunabilirlik/kullanılabilirlik iyileştirmeleri. `ui-redesign` dalında (`feature/ui-shell`'den açıldı), 10 commit.

**Yapılanlar:**
- **Design token'ları genişletildi** (`app_theme.dart`, `app_colors.dart`): `TextTheme` yaşlı-dostu skalaya çekildi (bodyLarge 16→18, bodyMedium 14→16), kontrast-güvenli yeni bir ikincil metin rengi eklendi (`AppColors.textSecondaryStrong`, #616161 — `textSecondary` #757575 açık gri zeminlerde ~4.4:1'de sınırda kalıyordu, yeni renk ~5:1+ veriyor).
- **Alt nav bar'a etiket eklendi** (`main.dart`): 5 ikonun altına kısa etiket (Ana Sayfa, Takvim, Ekle, Bildirimler, Profil), 13sp kalın — nav etiketleri için bilinçli olarak genel "ikincil metin ≥16sp" kuralının istisnası (ikon zaten anlamı taşıyor), ikon boyutu (28/34px) korundu.
- **SOS butonu büyütüldü ve öne çıkarıldı** (`home_page.dart`): başlıktaki küçük "hap" butondan, kendi tam-genişlik satırındaki büyük kırmızı butona (`_buildSOSButton`) taşındı. Davranış (`_showSOSConfirmDialog`) değişmedi.
- **Font/kontrast düzeltmeleri 6 sayfada:** `home_page.dart`, `calendar_page.dart`, `notifications_page.dart`, `add_medicine_page.dart`, `profile_page.dart`, `caregiver_home_page.dart` — hepsinde aynı tekrarlayan desen bulundu ve düzeltildi: (a) ikincil/açıklama metinleri 10-13sp → 16sp+, (b) "gri metin üzerine gri zemin" kombinasyonları (özellikle "alınmış ilaç" durumundaki kartlarda: `Colors.grey.shade400` metin `Colors.grey.shade100` zemin üzerinde neredeyse hiç okunmuyordu) `textSecondaryStrong`'a çekildi.

**Yol boyunca bulunan 2 layout bug'ı (gerçek cihazda, Samsung A53):**
1. **Nav bar yatay overflow ("~12px").** Kök neden: her nav item'ın etiketi sabit `SizedBox(width: 68)` içindeydi (ikon kutusundan geniş olduğu için Column genişliğini bu belirliyordu) → 5×68=340dp sabit minimum genişlik, bar'ın kullanılabilir genişliği (ekran genişliği − margin 32dp − padding 24dp) A53'te (~391dp) bunun altına düşüyordu. Emülatörün daha geniş dp genişliği açığı gizlemişti. **Düzeltme:** her item `Expanded` ile sarıldı (sabit width yerine esnek 1/5), etiket `SizedBox(width: double.infinity)` + `FittedBox(fit: BoxFit.scaleDown)` kullanıyor — en uzun etiket ("Bildirimler") dar bir ekranda bile kesilmeden (ellipsis yerine) orantılı küçülerek sığıyor.
2. **Skeleton loader dikey overflow ("25px").** Font büyütmeleriyle ilgisizdi (o widget hiç Text/font kullanmıyor, tamamen dekoratif gri kutular) — asıl sebep SOS butonunun `_buildHeader`'dan çıkarılıp kendi satırına taşınmasıydı: bu, skeleton'ı saran `Expanded`'a kalan dikey boşluğu daralttı, küçük ekranlarda sabit içerikli Column artık sığmıyordu. **Düzeltme:** `SingleChildScrollView` (physics: `NeverScrollableScrollPhysics`) ile sarıldı — bir shimmer placeholder'ın kaydırılabilir görünmesi istenmediği için scroll jesti kapalı, ama `SingleChildScrollView` yine de height constraint'ini gevşettiği için overflow hatası hiç oluşmuyor.

**Doğrulama:** `flutter analyze` her commit'te çalıştırıldı — 0 yeni hata (projede zaten var olan info/warning'ler sabit kaldı). Emülatörde (nav bar etiketleri, SOS, doz çipleri) ve gerçek Samsung A53 cihazında (her iki layout bug'ı) test edildi, ikisi de düzeltmelerden sonra doğrulandı. Görsel doğrulama için oluşturulan geçici test hesabı (`uitest.elder.20260805@example.com`) Firebase Auth + Firestore'dan silindi.

**Sırada:** `ui-redesign` dalı `feature/ui-shell`'e (ya da `main`'e) merge edilmeyi bekliyor.

## UI İyileştirmeleri Turu 2 (2026-08-06)

Aynı `ui-redesign` dalında devam, 13 commit. Ağırlıklı olarak `home_page.dart` (ana ekran ilaç kartları), artı `edit_medicine_dialog.dart` (yeni), `calendar_page.dart`, `notification_service.dart`.

**Yapılanlar:**
- **Splash/spinner rengi** (`app_theme.dart`, `pubspec.yaml`): Auth state beklenirken görünen varsayılan mor `CircularProgressIndicator`, `progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.primary)` ile teal'e çevrildi. Native splash zemin rengi (`flutter_native_splash: color`) `#F4F6F9`'dan `AppColors.background` (`#F8F9FA`) ile birebir eşleşecek şekilde güncellenip `dart run flutter_native_splash:create` ile yeniden üretildi — native splash'ten ilk Flutter frame'ine geçişte ufak bir zemin rengi sıçraması vardı, gitti.
- **"Günlük İlaç Tamamlama %X" ilerleme çubuğu kaldırıldı**, yerine zaten var olan (ama kullanılmayan bir bug'la gizlenen) "Sıradaki İlaç" kartı (`_buildNextDoseCard`) öne çıkarıldı: `_getNextMedicine` eskiden sadece "şu andan sonraki" ilaçlara bakıyordu, saati geçmiş-ama-içilmemiş bir ilaç sessizce kartdan kayboluyordu — artık bugünün tüm alınmamış ilaçları arasından saati en erken olanı (gecikmiş olsa da) gösteriyor. Bugünün tüm ilaçları alınmışsa tebrik mesajı ("Bugünkü tüm ilaçlarını aldın! 🎉"). Kart iki turda küçültüldü (ilk tur yetersiz kaldı, ikinci turda padding 12/10, başlık 16sp, ikon dairesi ~%18 küçültüldü) — kullanıcı onayladı.
- **"İçtim" butonu**: belirsiz turuncu zil ikonu yerine, alınmamış durumda ikon+"İçtim" yazılı teal hap buton (min 48dp dokunma alanı, tam genişlik kaplamıyor). Alınmış durumdaki yeşil check ikonu davranışı korundu.
- **Kart layout düzeltmesi**: doz/kullanım bilgisi ("Yarım Tablet • Tok Karnına") eskiden isim/saat ile aynı `Expanded` alanı paylaşıyordu, uzun metinler kesiliyordu — kart iki satıra bölündü, doz bilgisi artık kendi tam genişlikli satırında.
- **Sıralama + geçiş animasyonu**: ilaç listesi artık önce alınmamışlar (saat sırasına göre), sonra alınmışlar şeklinde sıralanıyor (canlı, Firestore stream tetiklemesiyle otomatik güncelleniyor). Kart `Card`'dan `AnimatedContainer` + `ValueKey(medicine.id)`'e çevrildi — alınma durumu değiştiğinde renk/kenarlık yumuşak fade ile geçiyor (bilinçli olarak tam pozisyon-kayması/reorder animasyonu değil, sadece renk geçişi).
- **"Ertele" butonu** (+15 dk): `_postponeMedicine`, `NotificationService.scheduleNotification`'ın artık nullable olan `matchDateTimeComponents` parametresini `null` geçirerek gerçek TEK SEFERLİK bir alarm kuruyor — ilacın mevcut günlük/haftalık tekrarlı alarm PROGRAMINA dokunmuyor (varsayılan `.time` günlük tekrar ürettiği için "iptal et + yeniden kur" mantığı kullanılsaydı ilacın normal alarmı her ertelemede kalıcı olarak kayardı). Yeni alarm id'si Firestore'daki `notificationIds` listesine EKLENİYOR (üzerine yazılmıyor) — hem mevcut alarmlar kaybolmasın hem bu geçici alarm "hayalet alarm" olarak kalmasın diye. `lastTakenDate`/alınma durumuna dokunulmuyor, backend cron'un tespiti bağımsız kalıyor.
- **İçtim/Ertele dikey hizalama — 3 denemelik teşhis serüveni:** İlk iki düzeltme (Row/Column'a `crossAxisAlignment`/`mainAxisAlignment: center` eklemek) gerçek cihazda işe yaramadı. Kök sebep widget ağacı satır satır çıkarılarak bulundu: İçtim+Ertele'yi saran `Column` `mainAxisSize.min` olduğundan asla kendi içeriğinden (~84px) fazla yükseklik almıyordu — dolayısıyla o Column'a eklenen `mainAxisAlignment: center` ölü kodmuş. Asıl mekanik: Row'un `crossAxisAlignment.center`'ı her çocuğu KENDİ boyutuna göre ortalıyor (Row'un toplam yüksekliğine stretch etmiyor); satırın en uzun çocuğu (İçtim+Ertele bloğu, ~84px) isim/saat bloğundan (~42px) çok daha uzun olduğu için satırın tamamını kaplıyor, İçtim tepeye yapışık görünüyordu. **Gerçek çözüm alignment değil, yapı değişikliği oldu:** üst satır yeniden sadece [ikon, isim/saat, İçtim] (benzer yükseklikte, `.center` doğal çalışıyor); "Ertele" doz bilgisinin (alt satır) sağına taşındı (`Expanded(doseInfo) + TextButton("Ertele")`, sadece alınmamışsa görünüyor).
- **Ortak edit dialog'a çıkarma + kapsam genişletme** (`lib/widgets/edit_medicine_dialog.dart`, yeni dosya): `home_page.dart`'taki yerel `_showEditDialog` (~310 satır) kaldırılıp top-level `showEditMedicineDialog()` fonksiyonuna taşındı. Aynı zamanda kapsam genişletildi — eski dialog sadece isim/doz/notlar/saat/kullanım şekli/kritik durumu düzenletiyordu, **tekrar tipi ("Her Gün"/"Belirli Günler"), gün seçimi ve bitiş tarihi hiç gösterilmiyordu** (kullanıcı "sıfırdan giriş yapıyormuş gibi" hissettiğini bildirdi) — artık `add_medicine_page.dart` ile aynı kapsamda, üçü de düzenlenebiliyor. Çağrı sitesi deseni: dialog kendi açılış/kapanışını tek `Navigator.pop` ile yönetiyor, başka bir dialog'un (ör. ilaç detay dialog'u) üzerinden açılıyorsa çağıran taraf önce KENDİ dialog'unu kapatıyor.
- **Takvim sayfası bilgi butonu bağlandı** (`calendar_page.dart`): `info_outline_rounded` ikonu eskiden hiçbir `GestureDetector`/`InkWell` içinde değildi, tamamen tepkisizdi — `IconButton`'a çevrilip aynı ortak `showEditMedicineDialog`'u açacak şekilde bağlandı.
- **Zaman dilimi filtre çipleri**: "İlaç Listesi" başlığının altına Sabah (05:00-11:59) / Öğle (12:00-16:59) / Akşam (17:00-20:59) / Gece (21:00-04:59, gece yarısını sarıyor) çipleri eklendi — sekme değil, aynı ekranda listeyi filtreleyen basit bir seçim satırı, `initState`'te şu anki saate göre otomatik seçiliyor. Filtre **sadece listenin görünümünü** etkiliyor — toplam sayaç ve "Sıradaki İlaç" kartı bilinçli olarak filtresiz kalıp günün tamamına bakmaya devam ediyor (kart yanıltıcı "0 ilaç" durumuna düşmesin diye).

**Doğrulama:** Her commit'te `flutter analyze` çalıştırıldı — proje genelinde 0 yeni hata boyunca; toplam info/warning sayısı oturum başında 89'dan (yerel `_showEditDialog` kopyasının kaldırılmasıyla) 87'ye düştü, yeni eklenen `withOpacity` çağrılarıyla (mevcut deprecation deseninin tekrarı) 88'e çıktı. Kullanıcı gerçek cihazda ara test yaptı (1-4 arası commit'lerden sonra) ve son turun tamamını (İçtim ortalaması, Ertele konumu, Sıradaki İlaç kart boyutu, zaman dilimi çipleri) onayladı.
