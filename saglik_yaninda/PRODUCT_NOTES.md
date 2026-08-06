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

---

## 4. Elder Kayıt / Giriş Akışı

### Sorun
Yaşlı kullanıcı email/şifre/Google girişini hatırlamayabilir veya hiç bilmeyebilir.

### Çözüm: Telefon Numarası + SMS Doğrulama
- Elder girişi: **telefon numarası + SMS doğrulama kodu**, ardından sadece **isim-soyisim** sorulur. Email/şifre gerekmez.
- Bu, misafir girişi **değildir** — kalıcı, veri kaybı riski olmayan gerçek bir hesap (Firebase Auth, telefon numarasına bağlı).
- Elder'ın profili bu haliyle "eksik" (email vb. opsiyonel alanlar boş) sayılır.

### Senaryo: Telefon Değişikliği / Uygulama Silinmesi
Yaşlı kullanıcı telefonunu kırar/değiştirir ya da uygulamayı yanlışlıkla siler:
1. Uygulamayı yeniden kurar.
2. Sadece telefon numarasını girer.
3. SMS kodu ile doğrular.
4. Firebase Auth aynı numarayı tanır → **aynı hesaba, aynı ilaç geçmişine, aynı caregiver bağlantısına otomatik geri döner.**
5. Hiçbir veri kaybı olmaz. (WhatsApp'a benzer, tanıdık bir deneyim.)

### Caregiver'ın Eksik Bilgileri Tamamlaması
- Caregiver, bağlandığı elder'ın profili eksikse (örn. email yok) bir uyarı görür: *"Ersin'in profili eksik, tamamlamak ister misiniz?"*
- Caregiver isterse bu bilgileri elder adına doldurabilir. Sorumluluk elder'a değil, caregiver'a devredilir.

### Kayıt Sırasında Caregiver Bağlama Teşviki
Elder kayıt akışının sonunda net bir mesaj gösterilecek:
> *"Güvenliğiniz için bir yakınınızın (oğlunuz/kızınız) sizi takip etmesini öneriyoruz — bağlantı kodunuzu paylaşın."*

Zorunlu değil, ama güçlü şekilde teşvik edilen bir adım. Hem güvenlik hem ürünün asıl amacı (biri seni takip etsin) için önemli.

---

## 5. Yeni Cihaz Güvenliği

### Risk
SMS-only girişte, telefon numarası ele geçirilirse (SIM swap gibi düşük olasılıklı ama var olan bir risk) hesap ele geçirilebilir. Asıl tehlike veri hırsızlığından çok, **bildirimlerin kapatılıp elder'ın ilaçsız kalması** gibi fiziksel bir risktir.

### Değerlendirilip Reddedilen Fikir: Opsiyonel PIN
İlk düşünülen "4 haneli PIN, yeni cihazda ekstra sorulur" fikri **kaldırıldı** — çünkü "PIN unutuldu + caregiver yok" senaryosunda kurtarma mekanizması kurulamıyor (destek ekibi olmayan, tek kişilik bir proje için çözülemeyen bir sorun yaratıyordu).

### Kabul Edilen Basit Model
1. **Caregiver varsa (öncelikli):** Yeni cihazdan giriş tespit edilirse, bağlı caregiver'a *"Bu siz miydiniz?"* bildirimi/onayı gider.
2. **Caregiver yoksa:** Sadece SMS kodu ile giriş — WhatsApp ve benzer uygulamaların kabul ettiği standart risk seviyesi.

### İleride Düşünülebilir (v1 kapsamı dışı)
Kullanıcı tabanı büyürse email tabanlı kurtarma veya destek süreci eklenebilir.

---

## 6. Platform Stratejisi — iOS/Android Uyumsuzluğu

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
2. **Onboarding turu** — yüksek öncelik, temel kullanılabilirlik sorunu.
3. **Telefon+SMS giriş akışı** — mevcut giriş sistemini değiştirecek önemli bir mimari karar, dikkatli planlanmalı.
4. **Play Store lansmanı** (Android-only, web dashboard olmadan).
5. **Lansman sonrası:** monetizasyon özellikleri, caregiver web dashboard, iOS stratejisi.

---

*Bu dosya, ilerleyen konuşmalarda güncellenmeye devam edecektir. Yeni kararlar alındıkça ilgili bölümlere eklenmeli.*
