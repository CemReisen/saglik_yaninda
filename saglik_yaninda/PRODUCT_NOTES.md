# Sağlık Yanında — Ürün Notları

Bu dosya, uygulamanın gelecek yönü hakkında alınan kararların ve tartışılan fikirlerin kaydıdır. Play Store lansmanı ve sonrası için referans olarak kullanılacaktır.

---

## 1. Temel Prensip

**Elder (yaşlı kullanıcı) tarafı her zaman tamamen ücretsiz ve kusursuz kalacak.** İlaç sayısı, hatırlatma sıklığı, SOS gibi hiçbir sağlık-kritik özellik asla kısıtlanmayacak veya paralı yapılmayacak.

> Tartışıldı ve kesin olarak reddedildi: İlaç sayısını sınırlayıp (örn. "4 ilaç ücretsiz, 5.si için öde") premium satmak. Bu, hem sağlık riski yaratır (kullanıcı ilacını hatırlatmasız bırakabilir) hem de "sağlık uygulamasında DLC satmak" gibi kötü bir izlenim bırakıp güven kaybettirir.

Tüm gelir modeli **caregiver (bakıcı/yakın) tarafından**, ek değer/güvence/rahatlık satarak kurulacak.

---

## 2. Monetizasyon — Premium Özellikler (Caregiver Tarafı)

### 2.1 Çoklu Caregiver Takibi
Bir yaşlıyı birden fazla kişi (örn. iki kardeş) aynı anda takip edebilsin.
- Ücretsiz: 1 caregiver bağlantısı
- Premium: sınırsız/çoklu caregiver bağlantısı

### 2.2 Bildirim Özelleştirme
- Standart (ücretsiz): ilaç sadece saatinde hatırlatılır (mevcut davranış).
- Premium: bildirim sıklığı ve ek hatırlatma türleri özelleştirilebilir (detaylar netleştirilecek).

### 2.3 Kaçırma Paterni Analizi + Eskalasyon
Bir ilaç art arda 2-3 kez unutulur/içilmezse, sistem bunu bir "pattern" olarak algılayıp caregiver'ı normal bildirimden daha güçlü/özel bir şekilde bilgilendirsin (örn. "Bu ilaç son 3 gündür düzenli aksıyor" uyarı modu).

### 2.4 Detaylı Geçmiş / Uyum Raporu *(konuşuldu, kesinleşmedi)*
Haftalık/aylık "ilaç uyum raporu" — hangi gün, hangi ilaç, ne zaman alındı/kaçırıldı. Doktor ziyaretine götürülebilecek bir PDF olması hedefleniyor.

### 2.5 Kişiselleştirilmiş Sesli Hatırlatma *(konuşuldu, kesinleşmedi)*
Caregiver kendi sesiyle kısa bir ses kaydı yapıp bildirim sesinin yerine koyabilsin (örn. "Anne, ilacını almayı unutma"). Duygusal açıdan güçlü, rakiplerde olmayan bir fark yaratıcı özellik olabilir.

### Kaçınılacaklar
- **Reklam** — sağlık + yaşlı kullanıcı segmentinde güven zedeler, UX'i bozar.
- **Veri satışı** — sağlık verisi hassas kategori, KVKK riski yüksek. *(Not: Bu konuda hukuki bir görüş değildir, gerekirse bir uzmana danışılmalı.)*
- **Tıbbi tavsiye içeren özellikler** (örn. ilaç etkileşim uyarısı) — sorumluluk/hukuki risk taşır, "hatırlatma" ile "tıbbi tavsiye" arasındaki çizgi net tutulmalı.

### Uzun Vadeli Fikirler *(MVP kapsamı dışı, ileride değerlendirilebilir)*
- Kurumsal/B2B satış (huzurevi, evde bakım şirketleri, sigorta şirketleri)
- Eczane/online eczane ortaklıkları
- Belediye/kamu sağlık programları

---

## 3. Onboarding / Kullanıcı Eğitimi

**Neden kritik:** En iyi arayüz bile açıklamasız kafa karıştırıcı olabilir (örn. "İçtim" butonu netleştirilene kadar ne olduğu belirsizdi).

### Gereksinimler
- İlk açılışta **zorunlu, atlanamaz** bir tanıtım turu.
- Her kritik ekran/özellik için ayrı bir öğretici adım.
- Kullanıcı "anladım" demeden bir sonraki adıma geçemez.
- Adım sayısı az tutulmalı — sadece gerçekten kritik olanlar: **SOS, İçtim butonu, ilaç ekleme, bağlantı kodu paylaşımı.**
- Gösterim şekli: gerçek ekran üzerinde spotlight/vurgu tarzı (soyut slayt değil, gerçek butonun üzerine ışık tutan bir overlay).

### "Nasıl Kullanılır" Butonu — Her Zaman Erişilebilir
- **Konum:** SOS butonunun yanında, aynı satırda. Şu anki dev SOS butonu ikiye bölünür gibi düşünülebilir: solda SOS, sağda "Nasıl Kullanılır".
- **Görsel ağırlık:** Büyük ve dikkat çekici olmalı ama SOS'un kırmızısıyla **karışmamalı** — farklı bir renkte olmalı ki SOS'un aciliyet algısı gölgelenmesin.
- Ayrıca Profil sayfasında da erişilebilir bir "Tekrar Öğren" seçeneği bulunmalı (yedek erişim noktası).

### Uygulama Durumu — Elder tarafı TAMAMLANDI ✅ (son güncelleme 2026-08-10), Caregiver tarafı TAMAMLANDI ✅ (2026-08-17)
Yukarıdaki gereksinimler **hem elder hem caregiver tarafında** uygulandı. Her iki tur da showcaseview paketiyle spotlight/vurgu tarzında, aynı prensiplerle (zorunlu ilk tur, "Anladım" ile ilerleme, manuel tekrar modunda X ile kapatma, `onboardingCompleted` alanları hesap bazlı).

#### Elder — Home ekranı turu, iki dalgalı, **8 adımlı**
- **Dalga 1 (5 adım):** SOS, Yardım Al (yukarıdaki "Nasıl Kullanılır" butonunun karşılığı — SOS'un yanında, ayrı renkte), İlaç Listesi, zaman dilimi filtreleri (Sabah/Öğle/Akşam/Gece çipleri), alt navbar.
- **Dalga 2 (3 adım, ilk ilaç eklendikten sonra tetiklenir):** tekil ilaç kartı → **Otomatik/Manuel zaman dilimi toggle'ı** (2026-08-10) → İçtim butonu.

Add ve Profil sayfalarının da kendi (ayrı, tek adımlı) tanıtım turları var. "Yardım Al" butonu turu istenildiği zaman baştan tekrar başlatabiliyor.

**Otomatik/Manuel zaman dilimi toggle'ı — ne işe yarar:** İlaç Listesi kartı normalde günün 4 zaman dilimine (sabah/öğle/akşam/gece) göre otomatik filtreleniyor - kullanıcı sadece o anki dilimi görüyor. Sorun: kullanıcı sadece sabah ilacı kullanıyorsa, öğleden sonra kart hep boş görünüyordu. Kartın sağ üst köşesindeki saat ikonu bunu çözüyor:
- **Otomatik (varsayılan):** kart günün gerçek saatine göre dilim gösterir (mevcut/eski davranış), çipler "göz atma" amaçlı dokunulabilir ama seçim hiçbir yere kaydedilmez.
- **Manuel:** butonu açarken kart her zaman "Sabah"tan başlar; kullanıcının seçtiği dilim kalıcı ("yapışkan") olarak hatırlanır — saat ilerlese/uygulama kapanıp açılsa da buton tekrar kapatılana kadar değişmez. Kapatılınca otomatik moda döner.

#### Caregiver — Home + Profil turları, **4+1 adım** (2026-08-17 eklendi)
Elder'daki AYNI mimariyle, ayrı flag alanlarıyla (`caregiver` önekli — aynı `users/{uid}` dokümanı iki rol için de kullanıldığından karışmasın diye).

- **Home turu, 2 dalga, 4 adım:** Dalga 1 — "Yardım Al" (yeni, mor #7E57C2, dairesel ikon buton, "Yeni Yakın"ın solunda) → "Yeni Yakın". Dalga 2 — ilk yakın kartı → dürtme/zil ikonu (sadece o yakının o gün bekleyen ilacı varsa render edilir, kartın aksine garanti değil). Dalga 2'nin flag'i bilinçli olarak zil adımında değil **kart adımında** yazılıyor — sonsuz tekrar riskini önlemek için (detaylı gerekçe `CLAUDE.md`'de).
- **Profil turu, tek adım:** "Takip Edilenleri Yönet" bölümü, + aynı sayfaya elder'daki `_buildHelpRow` görsel diliyle yeni bir "Tekrar Öğren" satırı eklendi (yedek erişim noktası).
- Caregiver'ın alt navbar'ı da artık tur açıkken sekme değişimini engelliyor (elder'daki aynı crash-önleme korumasının caregiver muadili).

Teknik detaylar, mimari kararlar ve commit geçmişi (elder + caregiver) için bkz. `CLAUDE.md`.

---

## 4. Elder Kayıt / Giriş Akışı ve Yeni Cihaz Kurtarma

### Sorun
Yaşlı kullanıcı email/şifre/Google girişini hatırlamayabilir veya hiç bilmeyebilir.

### Karar Geçmişi: Telefon+SMS reddedildi, Google + Email + Hızlı Başla'ya geçildi — TAMAMLANDI ✅
İlk planlanan çözüm **telefon numarası + SMS doğrulama** idi. Bu fikir **maliyet nedeniyle iptal edildi** — Firebase Phone Authentication 2024'ten beri hiçbir ücretsiz kotası olmayan, her SMS için ücretlendirilen bir servis; ölçek büyüdükçe maliyet öngörülemez şekilde artabilirdi. Email ve Google ile giriş ise 50.000 aktif kullanıcıya kadar tamamen ücretsiz.

Yerine kurulan sistem **2026-08-09/10'da uygulanıp uçtan uca test edildi** (`ui-redesign` dalı — commit'ler ve teknik detaylar için bkz. `CLAUDE.md` → "Auth Sistemi Yenilendi" bölümü).

### Giriş Ekranında Sunulan 3 Yöntem
1. **Hızlı Başla** (BİRİNCİL/en üstte, yaşlı kullanıcı hedef kitlesi için önce geliyor) — sadece **isim-soyisim**, email/şifre gerekmez. Bu, misafir girişi **değildir** — arka planda Firebase Anonymous Authentication ile kalıcı, veri kaybı riski olmayan gerçek bir hesap açılıyor. Aynı zamanda üretilen "Aile Bağlantı Kodu" bu hesap için **kurtarma kodu** olarak da işlev görüyor; ekranda net bir uyarıyla gösteriliyor: *"Bu kodu bir yere yazın veya yakınınıza söyleyin — telefonunuzu değiştirirseniz bu kodla hesabınıza geri dönebilirsiniz."*
2. **E-posta ile Giriş** — mevcut sistem, değişmedi.
3. **Google ile Giriş** — ücretsiz, bazı yaşlı kullanıcıların zaten alışkın olabileceği bir yöntem. İlk girişte elder/caregiver rolü soruluyor (Google girişi ikisinden de gelebiliyor, register akışındaki gibi sabit bir rol varsayılamıyor).

**Küçük UX düzeltmesi (2026-08-17):** E-posta ile kayıt olan caregiver akışına giden "Kayıt Olun" linki eskiden sayfanın en altındaydı (kaydırmadan görünmüyordu) — "Kodum var"ın hemen altına taşınarak görünürlüğü artırıldı. Teknik detaylar `CLAUDE.md` → "Login Ekranı Düzenlemeleri" bölümünde.

### Kurtarma Akışı (Telefon/Uygulama Değişikliği Durumunda)
1. Yeni cihazda uygulama açılır, "Kodum var" seçilir.
2. Kullanıcı kurtarma kodunu girer.
3. Bir Cloud Function (`recoverWithCode`), bu kodu `users` koleksiyonunda arayıp (`connectionCode == code && authProvider == "anonymous"`) doğrulayan ve `admin.auth().createCustomToken(uid)` ile bir custom token üreten, `request.auth` gerektirmeyen bir callable.
4. Kullanıcı bu token ile (`signInWithCustomToken`) giriş yapar → **aynı hesaba, aynı ilaç geçmişine, aynı caregiver bağlantısına geri döner.** Hiçbir veri kaybı olmaz.

### Değerlendirilip Reddedilen Fikir: Opsiyonel PIN
İlk düşünülen "4 haneli PIN, yeni cihazda ekstra sorulur" fikri **kaldırıldı** — çünkü "PIN unutuldu + caregiver yok" senaryosunda kurtarma mekanizması kurulamıyordu (destek ekibi olmayan, tek kişilik bir proje için çözülemeyen bir sorun yaratıyordu). Kabul edilen kurtarma kodu modeli bu sorunu taşımıyor: kod kaybolursa, caregiver'a bağlıysa ondan tekrar öğrenilebilir, ya da yeni bir hesap açılıp caregiver tekrar bağlanabilir — veri kaybı riski var ama kalıcı bir kilitlenme yok.

### Güvenlik Notu (Kurtarma Kodu)
Bu yöntem, email/Google kadar güçlü bir kimlik doğrulama değildir (kod başkası tarafından görülürse/ele geçirilirse hesaba erişilebilir). Ama:
- Kod uzayı geniş (6 karakter, 36 sembol → 36⁶ ≈ 2,1 milyar kombinasyon) — kaba kuvvetle tarama pratik değil.
- `recoverWithCode` sadece `authProvider == "anonymous"` hesapları hedefleyebiliyor — **email/Google hesapları bu yoldan asla ele geçirilemez.**
- Kod-bazlı rate limit (5 dakikada en fazla 5 deneme, `uid` yok çünkü çağıran henüz giriş yapmamış olabilir) + bulunamama/anonim-olmama arasında ayrım göstermeyen genel bir hata mesajı (enumeration/oracle koruması) uygulandı.
- **Firebase App Check bilinçli olarak ERTELENDİ** — projenin TÜM Firestore/Functions çağrılarını etkileyecek bir altyapı değişikliği olurdu, tek kişilik bir projede Play Store lansmanına yakın bu riski şimdi almak yerine kod-bazlı rate limit ile başlanması tercih edildi. *(İleride değerlendirilebilir — bkz. aşağıdaki "İleride Düşünülebilir".)*
- Zaten planlanan "yeni cihaz girişinde caregiver'a onay bildirimi" katmanı (aşağıda) burada da ekstra güvenlik sağlayabilir.

### Firestore Şema
`users/{uid}` dokümanına `authProvider` alanı eklendi: `"password" | "google" | "anonymous"`. Anonim kullanıcılar için `email` alanı boş kalıyor. **Ayrı bir `recoveryCode` alanı YOK** — `connectionCode` hem bağlantı hem kurtarma kodu olarak kullanılıyor (bilinçli tasarım kararı: tek kod, kullanıcı için daha az kafa karışıklığı).

### Caregiver'ın Eksik Bilgileri Tamamlaması *(henüz uygulanmadı — ileride)*
- Caregiver, bağlandığı elder'ın profili eksikse (örn. email yok) bir uyarı görür: *"Ersin'in profili eksik, tamamlamak ister misiniz?"*
- Caregiver isterse bu bilgileri elder adına doldurabilir. Sorumluluk elder'a değil, caregiver'a devredilir.

### Kayıt Sırasında Caregiver Bağlama Teşviki *(henüz uygulanmadı — ileride)*
Elder kayıt akışının sonunda net bir mesaj gösterilecek:
> *"Güvenliğiniz için bir yakınınızın (oğlunuz/kızınız) sizi takip etmesini öneriyoruz — bağlantı kodunuzu paylaşın."*

Zorunlu değil, ama güçlü şekilde teşvik edilen bir adım. Hem güvenlik hem ürünün asıl amacı (biri seni takip etsin) için önemli.

### İleride Düşünülebilir (v1 kapsamı dışı)
- **Yeni cihaz girişinde caregiver onayı:** Caregiver varsa, yeni cihazdan/kurtarma koduyla giriş tespit edilirse bağlı caregiver'a *"Bu siz miydiniz?"* bildirimi/onayı gitsin — kurtarma kodunun üzerine ekstra bir güvenlik katmanı.
- **Firebase App Check:** yukarıda ertelenen karar, kullanıcı tabanı büyüdükçe/lansman sonrası yeniden değerlendirilebilir.
- Kullanıcı tabanı büyürse ayrıca destek süreci eklenebilir.

### Bilinen eksik test (bir sonraki oturumun ilk işi olmalı)
Hızlı Başla ile açılmış bir elder hesabının, Google/email ile açılmış bir caregiver hesabına bağlanması ve bildirimlerin (bağlantı isteği, ilaç alındı, SOS, dürtme) bu yeni auth yöntemleriyle açılmış hesaplarda da uçtan uca çalıştığının doğrulanması — çift cihaz/hesap gerektirdiği için henüz test edilemedi.

---

## 5. Platform Stratejisi — iOS/Android Uyumsuzluğu

### Sorun
İlk sürüm sadece **Play Store'da (Android)** yayınlanacak. Türkiye'de yaşlı kullanıcılar genelde Android, çocukları/torunları (caregiver adayları) genelde iPhone kullanıyor. Bu, caregiver'ın uygulamayı hiç indirememesi riskini doğuruyor — ürünün temel değer önerisi ("biri seni takip etsin") bazı ailelerde çalışmayabilir.

### Karar: Caregiver İçin Web Sayfası
- Caregiver tarafı için **hafif, responsive bir web sayfası** sunulacak.
- iOS kullanıcıları native uygulama indirmeden, mobil tarayıcıdan giriş yapıp elder'ı takip edebilecek (en azından temel seviyede: ilaç durumu görme, bildirim alma).
- Teknik olarak mantıklı: Firestore zaten backend, bir web arayüzü aynı veriye bağlanabilir.

### Kapsam ve Zamanlama
- Bu, **ilk Play Store lansmanını bekletmemeli.**
- İlk versiyon Android-Android (elder + caregiver ikisi de Android) senaryosunu tam kapsayarak çıkabilir.
- Web dashboard, lansman sonrası ayrı bir faz/iterasyon olarak planlanmalı.

---

## Özet — Öncelik Sırası (Önerilen)

1. **Kusursuz elder deneyimi** (mevcut UI revizyonu, bugüne kadarki çalışma) — devam ediyor.
2. ~~Onboarding turu~~ → **TAMAMLANDI ✅ (elder + caregiver)** — Elder: Home (8 adım, iki dalga, Otomatik/Manuel zaman dilimi toggle'ı dahil) + Add/Profil (tek adımlı). Caregiver (2026-08-17): Home (4 adım, iki dalga) + Profil (tek adımlı, "Tekrar Öğren" satırıyla). Bkz. yukarısı "3. Onboarding / Kullanıcı Eğitimi → Uygulama Durumu" ve `CLAUDE.md`.
3. ~~Telefon+SMS giriş akışı~~ → **Google + Email + Hızlı Başla + Kurtarma Kodu — TAMAMLANDI ✅ (2026-08-10)**, bkz. "4. Elder Kayıt / Giriş Akışı ve Yeni Cihaz Kurtarma" + `CLAUDE.md`. Kalan tek açık madde: Hızlı Başla × caregiver bağlantı çapraz testi (bkz. yukarısı, "Bilinen eksik test").
4. **Play Store lansmanı** (Android-only, web dashboard olmadan).
5. **Lansman sonrası:** monetizasyon özellikleri, caregiver web dashboard, iOS stratejisi.

**Sıradaki öncelik netleşmedi** — `ui-redesign` dalının merge edilmesi mi (henüz `main`'e/`feature/ui-shell`'e merge bekliyor), yoksa yukarıdaki eksik çapraz test mi önce gelmeli? Bir sonraki oturumda netleştirilmeli.

---

*Bu dosya, ilerleyen konuşmalarda güncellenmeye devam edecektir. Yeni kararlar alındıkça ilgili bölümlere eklenmeli.*
