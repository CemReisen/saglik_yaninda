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

### Ek: "Ertele" görünürlük mantığı (`_minutesLate`) — 1 saat eşiği ve gün sınırı düzeltmeleri

Yukarıdaki turun devamında, "Ertele" butonu 1+ saat gecikmiş ilaçlarda gizlenecek şekilde kısıtlandı (`_minutesLate(data) < 60`). Bunu doğrularken iki gerçek bug bulunup düzeltildi:
1. **Gece yarısı sınırı:** `_minutesLate` eskiden sadece "bugünün saat:dakikası - şu anki saat" farkına bakıyordu, hangi takvim gününe ait olduğunu bilmiyordu — gece yarısını geçince dünden kalma (ör. 23:00 saatli, alınmamış) bir ilaç "henüz vakti gelmemiş" gibi görünüyordu. Düzeltme: fonksiyon artık `repeatType`/`days`'e göre geriye doğru (en fazla 7 gün) en son PLANLI günü arayıp, o günün `lastTakenDate` ile eşleşip eşleşmediğine bakıyor.
2. **Regresyon (startDate eksikliği):** İlk düzeltme, henüz vakti gelmemiş YENİ eklenen bir ilaçta da Ertele'yi kaybettiriyordu — geriye dönük tarama, ilacın `startDate`'inden önceki günleri de "planlı ama alınmamış" sayıyordu. Düzeltme: `isScheduledDay` artık `startDate`/`endDate`'i de kontrol ediyor.

**Test süreci notu:** Bu iki düzeltme sonrası, önceden "gece yarısı" senaryosunda (23:00 planlı, alınmamış ilaç) Ertele'nin kaybolduğu doğrulanmıştı, ama `startDate` düzeltmesinden sonra AYNI ilaçta Ertele'nin tekrar göründüğü gözlemlenip bir tutarsızlık şüphesi doğdu. Gerçek Firestore verisini (kullanıcının kendi test ilacı) okuyup elle doğrulamak gerekiyordu; bu, production Firebase kimlik bilgileriyle bir script çalıştırmayı gerektirdiği için (backend'in `serviceAccountKey.json`'ı) otomatik olarak izin sınıflandırıcısı tarafından engellendi — kullanıcı yerine testi kendisi gerçek cihazda tekrarladı. **Sonuç: kod tarafında ek bir bug yoktu** — önceki "tutarsızlık" gözlemi, test ilacının kendisinin (muhtemelen `startDate` değeri, yeniden oluşturulmuş/değiştirilmiş bir test kaydı olduğu için) beklenenden farklı olmasından kaynaklanıyordu, `_minutesLate`'in mantığı değil. Kullanıcı ilacı sildi, mantığı kapsamlı test edip onayladı. `_minutesLate` şu anki haliyle (gece yarısı + startDate düzeltmeleriyle) doğru kabul edildi, kod tarafında ek değişiklik yapılmadı.

## Auth Sistemi Yenilendi: Google ile Giriş + Hızlı Başla + Kurtarma Kodu (2026-08-09 – 2026-08-10)

Aynı `ui-redesign` dalında devam, 9 commit + 1 IAM ayarı (kod dışı). Kapsam: `PRODUCT_NOTES_AUTH_UPDATE.md`'de planlanan telefon/SMS iptali + Google/Hızlı Başla/Kurtarma Kodu sisteminin tamamı uygulanıp uçtan uca test edildi (bkz. `PRODUCT_NOTES.md` → "4. Elder Kayıt / Giriş Akışı ve Yeni Cihaz Kurtarma" — ürün kararları orada, burada teknik detaylar).

### 1. Paket adı geçişi: `com.example.saglik_yaninda` → `com.cemreisen.saglikyaninda`
`applicationId`, Play Store'a çıktıktan sonra bir daha değiştirilemeyecek kalıcı bir karar olduğu için Google Sign-In kurulumundan önce yapıldı (commit `9ce02de`). Debug keystore'dan çıkarılan SHA-1/SHA-256 Firebase konsoluna eklendi.

**Bulunan bug:** `AndroidManifest.xml`'deki `package=` attribute'u yeni `applicationId`'ye güncellenmişti, ama bu AGP sürümünde manifest üzerinden namespace ayarlamak artık desteklenmiyor — `flutter build apk` "Setting the namespace via the package attribute... no longer supported" hatasıyla durdu. Düzeltme: `package=` attribute'u manifest'ten tamamen kaldırıldı; `namespace` (`build.gradle.kts`, hâlâ `com.example.saglik_yaninda`, `MainActivity.kt`'nin gerçek Kotlin paketiyle uyumlu) ile `applicationId` (`com.cemreisen.saglikyaninda`) bilinçli olarak farklı bırakıldı — Android'de tam desteklenen, `MainActivity.kt`'yi taşımadan çözen bir kurulum.

### 2. Google ile Giriş (`google_sign_in` ^7.2.0)
Commit `1e07fac` (temel akış), `96db451` + `ec484be` (bulunan buglar).

v7'nin singleton/initialize deseni kullanıldı: `main.dart`'ta `Firebase.initializeApp()` sonrası `GoogleSignIn.instance.initialize(serverClientId: ...)` (serverClientId = Firebase konsolundaki Web client OAuth ID, Android client ID DEĞİL). `login_page.dart`'a `authenticate()` → idToken → `GoogleAuthProvider.credential` → `signInWithCredential` akışı eklendi. İlk kez giriş yapan Google kullanıcısına elder/caregiver rolü soran bir dialog gösteriliyor (`register_page.dart`'taki "Kendi İlacım"/"Yakınımın İlacı" isimlendirmesiyle tutarlı) — Google girişi ikisinden de gelebildiği için register akışındaki gibi sabit bir rol varsayılamıyor.

**Bulunan/düzeltilen buglar (gerçek cihazda, sırayla):**
1. **`user.displayName` güvenilir dolmuyor.** `signInWithCredential` sonrası Firebase'in `User.displayName`'i idToken-only credential'da boş kalabiliyor (gözlemlendi: yeni hesapta `''`) — `home_page.dart`/`profile_page.dart`'ın "isim boşsa e-posta/'Kullanıcı' fallback'i" mantığı bunu tetikliyordu. Düzeltme: `googleUser.displayName` (paketten doğrudan, `authenticate()` sonrası senkron dolu) kullanılıyor, `user.displayName`'e sadece o da boşsa fallback ediliyor.
2. **connectionCode/name hiç yazılmıyordu — kök sebep context/dispose yarışı.** `main.dart`'taki kök `authStateChanges` `StreamBuilder`'ı, `signInWithCredential()` tamamlandığı AN `home:` widget'ını (`LoginPage` → `MainLayout`) değiştirip `LoginPage`'i dispose ediyor — bu, `signInWithCredential()`'ın kendisi tetiklediği için bizim `_signInWithGoogle()` kodumuz hâlâ çalışırken oluyor. Bundan sonra `_askRoleForNewGoogleUser()`'ın kendi (artık geçersiz) `context`'iyle açtığı `showDialog`, "Looking up a deactivated widget's ancestor is unsafe" hatasına çarpıyor; bu hata generic `catch`'in `if (!mounted) return;` guard'ı yüzünden **hiçbir iz bırakmadan yutuluyordu** — dialog hiç gösterilemediği için `userRef.set()`'e (connectionCode/name yazan kod) sıra gelmiyordu. **Düzeltme:** yeni `lib/core/app_navigator_key.dart` — `MaterialApp`'e bağlı, `LoginPage`'in kendi context'inden bağımsız bir `GlobalKey<NavigatorState>` (`rootNavigatorKey`; `MaterialApp` bu geçişte dispose olmadığı için ona bağlı context her zaman canlı kalıyor). Dialog VE akış-sonu yönlendirme (`Navigator.pushReplacementNamed` yerine `rootNavigatorKey.currentState`) artık buna bağlı — yönlendirme de kozmetik değil gerekliydi, çünkü kök `StreamBuilder` auth event anında Firestore'u BİR KEZ okuyup (rol dokümanı henüz yazılmamışken) varsayılan "elder" ile `MainLayout`'u göstermiş olabiliyor, caregiver seçen biri için bunu sonradan düzeltmek gerekiyor.
3. **`.update()` vs `.set(merge:true)`: dokümanın var olduğu garanti edilmeden `.update()` kullanmak `NOT_FOUND` fırlatıyordu.** Hem `login_page.dart`'taki backfill/`_saveDeviceToken`'da, hem de (asıl çökme kaynağı) **her iki "HESAPTAN ÇIKIŞ YAP" butonunda** (`profile_page.dart` → `_buildLogoutButton`, `caregiver_home_page.dart`'taki eşleniği) — o ikisi hiç try/catch içinde değildi, dokümanı olmayan bir hesapla çıkış denendiğinde uygulama gerçekten çöküyordu. Düzeltme: hepsi `.set(data, SetOptions(merge: true))`'a çevrildi (doküman varsa günceller, yoksa oluşturur — ikisinde de güvenli), çıkış butonları try/catch'e alındı ("yan işlem hatası ana aksiyonu bloklamamalı" prensibi — fcmToken temizlenemese bile kullanıcı çıkış yapabilmeli, hata sessizce loglanıyor).

### 3. Hızlı Başla (anonim giriş)
Commit `b9d82cb` (temel akış), `33c8a49` (fcmToken bug'ı).

Yeni dosyalar: `lib/pages/auth/quick_start_page.dart` (sadece isim-soyisim; "Devam Et" → `signInAnonymously()` → `users/{uid}` `.set(merge:true)` ile `authProvider: "anonymous"`, `role: "elder"` sabit — rol seçici yok — `name`, `email: ""`, `connectionCode`; yazıldıktan sonra aynı sayfada kod büyük+kopyalanabilir gösteriliyor, "telefonunuzu değiştirirseniz bu kodla hesabınıza geri dönebilirsiniz" uyarısıyla), `lib/services/connection_code_service.dart` (kod üretimi tek yere toplandı — `register_page.dart` ve `login_page.dart`'taki (Google akışı) private kopyalar bu servise bağlandı, üçüncü bir kopya hiç açılmadı).

**Mimari not (bilinçli tasarım, bu turun dersi mimariye taşındı):** Bu sayfa `login_page.dart`'tan `Navigator.pushNamed` ile (push, **replace DEĞİL**) açılıyor — kök `StreamBuilder` sadece `"/"` route'unun İÇERİĞİNİ değiştirdiği için, AYRI bir route olarak stack'te üstte kalan bu sayfa Google akışındaki context/dispose riskinden yapısal olarak muaf; `rootNavigatorKey`'e hiç gerek kalmadı. `recovery_code_page.dart` da aynı gerekçeyle aynı mimariyi kullanıyor.

**Bulunan bug:** `quick_start_page.dart`, `register_page.dart`/`login_page.dart` (Google akışı) akışlarının aksine `FirebaseMessaging`'den token alıp yazmıyordu — Hızlı Başla ile açılan hesaplarda `fcmToken` hiç oluşmuyordu (`main.dart`'taki `_syncFcmToken` de doküman henüz yokken tetiklenip `!snap.exists` nedeniyle atlıyor, bir sonraki uygulama açılışına kadar kendini düzeltmiyordu). Diğer iki akışla aynı desene getirildi.

### 4. Kurtarma kodu (`recoverWithCode` Cloud Function)
Commit `6e6e87d` (backend), `c6b0e9f` (client, `recovery_code_page.dart`).

`connectionCode` alanı hem bağlantı hem kurtarma kodu olarak kullanılıyor — **ayrı bir `recoveryCode` alanı bilinçli olarak yok** (tek kod, daha az kafa karışıklığı). `resolveConnectionCode`'dan KASITLI OLARAK ayrı bir fonksiyon: `request.auth` gerektirmiyor (çağıran yeni cihazda, henüz hiç giriş yapmamış olabilir), `uid` yerine **kodun kendisi** bazlı rate limit (`rate_limits/recoverWithCode_{code}`, 5 dk'da 5 deneme — `resolveConnectionCode`'daki sabit-pencere transaction deseniyle aynı, sadece anahtar farklı). Sorgu `connectionCode == code && authProvider == "anonymous"` — email/Google hesapları bu yoldan asla ele geçirilemez. Bulunamazsa/anonim değilse **TEK VE AYNI genel hata** (enumeration/oracle koruması), ayrıca `logger.warn` ile loglanıyor (kodun sadece son 3 karakteri). Bulunursa `admin.auth().createCustomToken(uid)` ile sadece `{ customToken }` döner (`resolveConnectionCode`'daki "minimum bilgi sızıntısı" prensibiyle tutarlı).

**App Check bilinçli olarak ERTELENDİ:** kod uzayı 36⁶ ≈ 2,1 milyar (kaba kuvvetle tarama pratik değil), tek kişilik proje + Play Store lansmanına yakınlık — projenin TÜM Firestore/Functions çağrılarını etkileyecek bir altyapı değişikliğini şimdi eklemek yerine kod-bazlı rate limit ile başlanması onaylandı; App Check ayrı bir sertleştirme fazı olarak `PRODUCT_NOTES.md`'ye not düşüldü.

**Bulunan iki ayrı, art arda gelen operasyonel bug (kod hatası değil, altyapı/dağıtım):**
1. **Fonksiyon yazılmış ama hiç deploy edilmemişti.** `node -c` + `require()` ile "yerel doğrulama" yapmak deploy anlamına gelmiyor — client'ın aldığı ilk hata (`NOT_FOUND`) aslında `recoverWithCode`'un production'da hiç var olmamasındandı, `firebase functions:list` bunu kanıtladı (fonksiyon listede yoktu). **Ders: Cloud Function eklerken/değiştirirken `node -c`/`require()` SADECE sözdizimi/modül yükleme kontrolü — canlıya çıkması için MUTLAKA `firebase deploy --only functions:<isim>` gerekiyor, aksi halde client tamamen makul ama yanlış bir "NOT_FOUND" hatası alır.**
2. **IAM: `admin.auth().createCustomToken()` için `roles/iam.serviceAccountTokenCreator` eksikti.** Deploy'dan sonra bu sefer `internal INTERNAL` hatası alındı; `firebase functions:log --only recoverWithCode` ile gerçek stack trace bulundu: `FirebaseAuthError: Permission 'iam.serviceAccounts.signBlob' denied`. Sebep: Cloud Functions **Gen 2** (bu projedeki TÜM fonksiyonlar Gen 2), custom token imzalamayı yerel bir private key ile değil **IAM Credentials API** üzerinden yapıyor — fonksiyonun çalıştığı servis hesabının (`308628032795-compute@developer.gserviceaccount.com`, GCP'nin varsayılan "Compute Engine default service account"ı) **kendi üzerinde** bu role sahip olması gerekiyor, varsayılan olarak verilmiyor. `resolveConnectionCode` `createCustomToken` hiç kullanmadığı için bu eksiklik proje boyunca hiç ortaya çıkmamıştı. Düzeltme: Google Cloud Console → IAM & Admin → IAM → ilgili servis hesabına "Service Account Token Creator" rolü elle eklendi (kod değişikliği/commit değil, saf IAM ayarı — `gcloud` CLI bu ortamda kurulu değildi, Console üzerinden kullanıcı tarafından uygulandı). **Ders: Gen 2 + `createCustomToken` kullanan HERHANGİ bir gelecek fonksiyon için bu rol bir önkoşuldur, unutulmamalı.**
   - **Yan not — log/veri erişimi sınırlaması:** Bu iki bug'ı ayırt etmeye çalışırken `firebase functions:log` bir noktada güncel/canlı log döndürmeyi bırakıp sabit/eski bir görünüme takılı kaldı (birden fazla `-n` değeriyle doğrulandı, `resolveConnectionCode`'un da günler öncesine ait loglar gösterdiği görüldü) — bu, önceki `_minutesLate` araştırmasındaki "production Firestore'a script ile erişim engellendi" kısıtlamasıyla aynı kategoride bir araç sınırlaması. Kullanıcı, Firebase Console üzerinden (CLI'dan daha güvenilir, gerçek zamanlı) doğrudan kontrol ederek süreci ilerletti.

### Test durumu (2026-08-10 itibarıyla)
- Google ile Giriş: tam test edildi (ilk kayıt, oturum kalıcılığı, çıkış/tekrar giriş) ✅
- E-posta akışı: regresyon kontrolü yapıldı, sorun yok ✅
- Hızlı Başla: tam test edildi (yeni hesap, çıkış) ✅
- Kurtarma kodu: doğru kod, yanlış kod, rate limit, yanlış-authProvider güvenlik testi — hepsi geçti ✅
- **YAPILMADI — bir sonraki oturumun ilk işi olmalı:** Hızlı Başla elder hesabı + Google/email caregiver bağlantısı çapraz testi — bildirimlerin (bağlantı isteği, ilaç alındı, SOS, dürtme) yeni auth yöntemleriyle açılmış hesaplarda da uçtan uca çalıştığının doğrulanması. Çift cihaz/hesap gerektiriyor, henüz test edilemedi.

**Doğrulama:** Her commit'te `flutter analyze` çalıştırıldı — 0 hata boyunca; info/warning sayısı oturum başındaki 88'den (eklenen yeni sayfalar + tekrarlayan `withOpacity` deseniyle) 91'e çıktı, yeni bir sorun kategorisi değil.

## Home: Otomatik/Manuel zaman dilimi toggle'ı + onboarding dalga 2 genişletildi (2026-08-10)

`ui-redesign` dalında, 3 commit: `84bc178` (özellik + ilk onboarding bağlantısı), `9614e66` (crash fix + ara UX düzeltmesi), `c2752d3` (**davranış baştan yeniden tasarlandı — bkz. aşağıdaki uyarı**).

**⚠️ Önemli — `84bc178`'in tanımını referans almayın:** İlk turda özellik "Tümünü Göster" olarak uygulanmıştı (buton açıkken kart, seçili zaman diliminden bağımsız günün TÜM ilaçlarını listeliyordu). Bu **yanlış anlaşılmıştı** ve `c2752d3`'te davranış tamamen değiştirildi. Aşağıdaki tanım GÜNCEL ve DOĞRU olanı — `home_page.dart`'ta `_showAllPeriods`/`_effectiveShowAllPeriods` gibi isimler artık YOK, hepsi `_manualPeriodMode`/`_effectiveManualMode` olarak yeniden adlandırıldı.

### Güncel/doğru davranış

İlaç Listesi kartının sağ üst köşesinde bir saat ikonu (`Icons.schedule` boş ↔ `Icons.access_time_filled` dolu, + renk farkı) **Otomatik** ile **Manuel** mod arasında geçiş yapar:

- **Otomatik (varsayılan, buton kapalı):** mevcut/eski davranışla birebir aynı — kart günün gerçek saatine göre otomatik dilim gösterir (`_periodForHour(DateTime.now().hour)`). Sabah/Öğle/Akşam/Gece çipleri dokunulabilir ("göz atma" — `_selectedPeriod`'u geçici değiştirir ama hiçbir yere kaydedilmez, bir sonraki açılışta yeniden gerçek saate göre hesaplanır).
- **Manuel (buton açık):** butonu **açarken** `_selectedPeriod` her zaman "Sabah"a sıfırlanır (saatten bağımsız sabit başlangıç noktası — son manuel seçim GERİ GETİRİLMİYOR, bilinçli ürün kararı). Sonrasında kullanıcının seçtiği çip SharedPreferences'a **"yapışkan"** kaydedilir (`home_manual_selected_period`) — uygulama kapanıp açılsa da, saat ilerlese de, buton tekrar kapatılıp açılana kadar değişmez. Çipler Manuel modda da tam aktif (Otomatik'ten hiçbir farkı yok — ara turda eklenen `IgnorePointer`/soluklaştırma denemesi kafa karıştırıcı bulunup tamamen kaldırıldı).
- Buton **kapatılınca**: otomatik moda dönülür, `_selectedPeriod` sıfırdan gerçek saate göre yeniden hesaplanır.
- Toggle'ın açık/kapalı durumu (`home_manual_period_mode`) ve manuel moddaki seçili dilim (`home_manual_selected_period`) ayrı ayrı SharedPreferences'ta kalıcı.

### Onboarding bağlantısı 1: `forceManualPeriod` (crash fix'i de içerir)

Dalga 2'nin (kart + toggle + İçtim) hedefi mevcut seçili dilimde yoksa (ör. akşam saatlerinde sabah dilimine ilaç eklenmişse) filtrelenmiş liste boş kalır, `skipIfTargetNotPresent` adımları sessizce atlar. Çözüm: tur başlamadan önce GEÇİCİ olarak Manuel moda geçilip hedef ilacın dilimi seçiliyor (`_onboardingForceManualMode` + `_selectedPeriodBeforeOnboardingOverride`, `home_page.dart` → `_runOnboardingSequence`) — kullanıcının kalıcı tercihine dokunulmuyor, tur bitince (`onFinish`/`onDismiss`/hata → `_restoreFromOnboardingPeriodOverride`) otomatik geri dönülüyor.

**Crash fix (`9614e66`):** Bu mekanizmanın ilk halinde eklenen koşulsuz ekstra `postFrameCallback`, Add sayfasından ilaç kaydedip `Navigator.pushAndRemoveUntil` ile yeni bir `MainLayout`/`HomePage` mount edilirken "No ShowcaseView registered for scope 'home_onboarding'" crash'ini tetikliyordu — kök sebep: showcaseview paketi (`ShowcaseService`) scope→ShowcaseView eşlemesini global, tek bir Map'te scope STRING'iyle tutuyor; Navigator'ın sayfa geçiş animasyonu yüzünden eski route'un `dispose()`'u (geç tetiklenen `unregister()`) yeni HomePage'in aynı scope string'i altındaki taze kaydını silebiliyor. Düzeltme: (a) ekstra frame bekleme artık sadece gerçekten gerekince (manuel tur ya da forced period) ekleniyor, (b) `startShowCase` çağrısı `try/catch`'e alındı — bu paket sınırlamasından kaynaklanan bir yarış olursa artık çökme yerine sessizce atlanıp bir sonraki Home ziyaretinde tekrar denenir.

### Onboarding bağlantısı 2: yeni tur adımı

Dalga 2 artık **3 adım**: kart → **Otomatik/Manuel dilim toggle'ı** (yeni, `_periodToggleShowcaseKey`) → İçtim. Toggle her zaman render edildiği için (ilaç sayısından bağımsız) bu adım hiç atlanmıyor; kart/İçtim'in hedefi hâlâ bugünün ilk alınmamış ilacı, yoksa `skipIfTargetNotPresent` ile ikisi de atlanıyor (dolayısıyla teorik bir uç durum var: o gün hiç ilacı olmayan bir kullanıcıda toggle adımı tek başına, kart/İçtim'siz görünebilir — bilinçli olarak ele alınmadı, düşük öncelik).

Toplam Home turu artık **8 adım** (bkz. PRODUCT_NOTES.md → "3. Onboarding").

**Kullanıcı cihazda test edip onayladı.** `flutter analyze`: her commit'te 0 yeni hata (95 info/warning, projede zaten var olan desenlerin tekrarı).

## Caregiver Onboarding Turu Eklendi (2026-08-17)

`ui-redesign` dalında, 1 commit: `683db67`. Elder Home/Profil turlarındaki AYNI mimariyle (showcaseview, zorunlu ilk tur + "Anladım" ile ilerleme, manuel tekrar modunda X ile kapatma, `onboardingCompleted` alanları hesap bazlı) caregiver tarafına da bir onboarding turu eklendi.

### Yeni flag'ler (`onboarding_service.dart` → `OnboardingFlags`)
`caregiverHomeIntro` (`onboardingCaregiverHomeIntroCompleted`), `caregiverHomeElder` (`onboardingCaregiverHomeElderCompleted`), `caregiverProfile` (`onboardingCaregiverProfileCompleted`) — elder'ın `homeIntro`/`homeMeds`/`profile` alanlarından bilinçli olarak AYRI adlarla: aynı `users/{uid}` dokümanı hem elder hem caregiver rolü için kullanıldığından, iki tarafın bayrakları karışmasın diye `caregiver` önekiyle ayrıştırıldı.

### Ana sayfa turu (`CaregiverHomePage`, `StatelessWidget`'tan `StatefulWidget`'a çevrildi) — 2 dalga, 4 adım
- **Dalga 1 (`caregiverHomeIntro`):** "Yardım Al" (yeni, mor `AppColors.helpAccent` #7E57C2, dairesel 40x40 ikon buton) → "Yeni Yakın". İkisi de her zaman render edilir (bağlı kimse olmasa da), skip riski yok — bayrak dalganın son adımında (Yardım Al) yazılır.
- **Dalga 2 (`caregiverHomeElder`):** İlk yakın kartı (`_buildElderCard`, `isFirst: index==0`) → dürtme/zil ikonu (aynı kartın içinde, `Icons.notifications_active_rounded`). Elder'ın kart/İçtim çiftinden farklı olarak bu ikisi **all-or-nothing DEĞİL**: kart en az 1 onaylı bağlantı varsa her zaman mevcut, ama zil ikonu SADECE o yakının o gün bekleyen (alınmamış) bir ilacı varsa render ediliyor (`totalMeds > 0 && takenMeds < totalMeds`).

**Flag stratejisi (kullanıcı onaylı, "Seçenek B"):** `caregiverHomeElder` bayrağı zil ikonu adımında DEĞİL, **kart adımında** yazılıyor. Gerekçe: elder'daki gibi "son adımda yaz" stratejisi burada kart+zil all-or-nothing olmadığı için sonsuz tekrar riski doğururdu — caregiver'ın yakını(ları) Home her açıldığında hiç bekleyen ilaç yoksa (gece geç saat, ya da yakın zaten hepsini içmişse) mini-tur her ziyarette sessizce yeniden denenmeye devam ederdi. Kart adımında yazmak bunu önlüyor; zil ikonu AYNI çalıştırmada (mevcutsa) hâlâ gösteriliyor, sadece flag'in tamamlanması ona bağlı değil — yedek erişim zaten "Yardım Al" ile manuel tekrarda her zaman mevcut (o her ikisini de, mevcutsa, sırayla gösterir).

**Tetikleme noktası:** Elder'daki aynı bug fix gerekçesiyle (`_maybeStartHomeOnboarding`), `_maybeStartCaregiverHomeOnboarding` caregiver'ın kendi user-doc stream'inden DEĞİL, **relations StreamBuilder'ının builder'ından** çağrılıyor — dalga 2'nin hedefi (ilk yakın kartı) en az bir kez gerçek veriyle render olmuş olmalı, aksi halde `skipIfTargetNotPresent` onu kalıcı olarak atlar.

### Profil sayfası turu (`CaregiverProfilePage`, `StatelessWidget`'tan `StatefulWidget`'a çevrildi) — tek adım
Hedef: "Takip Edilenleri Yönet" başlığı + liste (elder Profil'deki bağlantı kodu kartı muadili, aynı tek-adımlı desen). Elder'daki `_buildHelpRow` ile aynı görsel dilde (mor/lavanta ikon, `AppColors.helpAccent`, aynı ListTile deseni) yeni bir **"Tekrar Öğren"** satırı eklendi — CaregiverProfilePage'de böyle bir "ayarlar listesi" widget'ı hiç yoktu, kendi kartında tek başına bir satır olarak eklendi.

### Ek düzeltme: navbar tur-kilidi
`CaregiverLayout`'un alt navbar'ı (home.svg/profile.svg, 2 sekme) artık `home_tour_shared.dart`'taki paylaşılan `onboardingTourActiveNotifier`'ı kontrol ediyor — herhangi bir caregiver turu açıkken sekme değişimine izin verilmiyor. Bu, elder tarafında `main.dart` → `MainLayout`'un aynı notifier'ı zaten kontrol etmesinin gerekçesiyle birebir aynı: showcaseview'ın hedef overlay'i varsayılan olarak translucent olduğu için, tur açıkken gerçek bir sekme dokunuşu spotlight'lanan widget'a da ulaşıp o an tur gösteren sayfayı ortasında unmount edip overlay'i sahipsiz bırakabilirdi. İki rol aynı anda hiç mount edilmediği için (kullanıcı ya elder ya caregiver layout'unu görür) paylaşılan tek global notifier'ı iki tarafın da kullanması güvenli — ayrı bir caregiver-özel notifier'a gerek yok.

**Doğrulama:** `flutter analyze` — 0 yeni hata, 96 info (öncekiyle aynı `withOpacity` deseninin tekrarı). Kullanıcı cihazda test edip onayladı.
