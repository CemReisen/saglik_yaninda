# Auth Kararı Güncellemesi — PRODUCT_NOTES.md'ye Eklenecek

> **✅ TAMAMLANDI VE BİRLEŞTİRİLDİ (2026-08-10).** Bu dosyanın içeriği artık `PRODUCT_NOTES.md`'nin "4. Elder Kayıt / Giriş Akışı ve Yeni Cihaz Kurtarma" bölümüne taşındı (ürün kararları) ve `CLAUDE.md`'nin "Auth Sistemi Yenilendi" bölümüne (teknik detaylar, bulunan buglar, commit hash'leri) işlendi — sistem uygulanıp uçtan uca test edildi. **Bu dosya artık gereksiz, silinebilir.** Sadece o oturumun orijinal planlama notu olarak burada bırakıldı.

> Bu bölüm, mevcut `PRODUCT_NOTES.md` dosyasındaki "Elder Kayıt / Giriş Akışı" bölümünün yerini alır. Telefon/SMS doğrulama fikri, maliyet nedeniyle (Firebase'de SMS doğrulama hiçbir zaman ücretsiz değil, Blaze planında SMS başına ~$0.01-0.06 arası ücretlendiriliyor) iptal edildi.

---

## Güncel Karar: Google + Email + "Hızlı Başla" (Anonim + Kurtarma Kodu)

### Neden telefon/SMS iptal edildi
Firebase Phone Authentication, 2024'ten beri hiçbir ücretsiz kotası olmayan, her SMS için ücretlendirilen bir servis. Ölçek büyüdükçe bu maliyet öngörülemez şekilde artabilir. Email ve Google ile giriş ise 50.000 aktif kullanıcıya kadar tamamen ücretsiz — bu yüzden birincil yöntemler olarak seçildi.

### Giriş Ekranında Sunulacak 3 Yöntem

**1. Google ile Giriş** — ücretsiz, bazı yaşlı kullanıcıların zaten alışkın olabileceği bir yöntem.

**2. Email ile Giriş** — mevcut sistem, ücretsiz.

**3. Hızlı Başla (telefonun yerini alan çözüm)** — Email/Google bilmeyen/hatırlamayan yaşlı kullanıcılar için:
- Kullanıcı sadece **isim-soyisim** girer, e-posta/şifre istenmez.
- Sistem arka planda **Firebase Anonymous Authentication** ile bir hesap oluşturur.
- Aynı zamanda mevcut "Aile Bağlantı Kodu" mekanizması (örn. `6J8-DOS`) bu hesap için de üretilir ve **kurtarma kodu** olarak işlev görür.
- Ekranda net bir uyarı gösterilir: *"Bu kodu bir yere yazın veya yakınınıza söyleyin — telefonunuzu değiştirirseniz bu kodla hesabınıza geri dönebilirsiniz."*

### Kurtarma Akışı (Telefon/Uygulama Değişikliği Durumunda)
1. Yeni cihazda uygulama açılır, "Kodum var" seçeneği seçilir.
2. Kullanıcı kurtarma kodunu girer.
3. Bir **Cloud Function**, bu kodu doğrulayıp güvenli bir custom token üretir.
4. Kullanıcı bu token ile giriş yapar → aynı hesaba, aynı ilaç geçmişine, aynı caregiver bağlantısına geri döner.

### Maliyet
**Sıfır ek maliyet** — SMS gibi üçüncü parti bir servise ihtiyaç yok, zaten var olan Cloud Functions altyapısı kullanılıyor.

### Güvenlik Notu
Bu yöntem, email/telefon kadar güçlü bir kimlik doğrulama değildir (kod başkası tarafından görülürse/ele geçirilirse hesaba erişilebilir). Ama:
- Daha önce reddedilen "PIN" fikrindeki "unuttum, kurtaramıyorum" sorunu burada yok (kod kaybolursa, caregiver'a bağlıysa ondan tekrar öğrenilebilir, ya da yeni bir hesap açılıp caregiver tekrar bağlanabilir — veri kaybı riski var ama kalıcı bir kilitlenme yok).
- Zaten planlanan "yeni cihaz girişinde caregiver'a onay bildirimi" katmanı burada da ekstra güvenlik sağlar.

### Firestore Şema Etkisi
`users/{uid}` dokümanına `authProvider` alanı eklenecek: `"password" | "google" | "anonymous"`. Anonim kullanıcılar için `email` alanı boş kalır, `recoveryCode` (bağlantı koduyla aynı ya da ayrı) saklanır.

---

## Uygulama Planı (Sıradaki Oturum İçin Hazır)

Token yenilendiğinde Claude Code'a doğrudan yapıştırılabilecek görev:

```
Authentication sistemine Google ile Giriş ve "Hızlı Başla" (anonim + kurtarma kodu) 
ekliyoruz. Telefon/SMS doğrulama planı iptal edildi (maliyet nedeniyle), bu konuda 
daha önce yaptığın araştırma raporundan sadece Google Sign-In kısmı geçerli kalıyor.

Önce şunu araştır ve raporla (henüz kodlama):

1. Önceki oturumda çıkardığın auth araştırma raporunu hatırla (google_sign_in paketi 
   eksikliği, SHA fingerprint gereksinimi, v7 API değişikliği) - bunlar hâlâ geçerli, 
   Google Sign-In için hazırlığı özetle.

2. Firebase Anonymous Authentication'ın (signInAnonymously()) mevcut projede nasıl 
   entegre edileceğini araştır - ek paket gerekiyor mu (hayır, firebase_auth içinde 
   zaten var), Firestore'a nasıl bir doküman yazılacağını mevcut register akışıyla 
   karşılaştır.

3. Kurtarma kodu akışı için bir Cloud Function tasarımı öner: kullanıcı "Kodum var" 
   deyip kodu girdiğinde, bu kodu users koleksiyonunda arayıp (connectionCode alanına 
   benzer bir şema kullanılabilir mi, yoksa ayrı bir recoveryCode alanı mı gerekir) 
   doğrulayan ve bir custom token üreten (admin.auth().createCustomToken(uid)) bir 
   callable function tasarla - resolveConnectionCode fonksiyonuna benzer bir desen 
   kullanılabilir.

4. login_page.dart ve register_page.dart'a bu üç yöntemin (Email - mevcut, Google - 
   yeni, Hızlı Başla - yeni) nasıl sekme/segment yapısıyla sunulacağını öner.

5. Firestore şema genişletmesini öner: authProvider ("password"|"google"|"anonymous") 
   alanı, anonim kullanıcılar için recoveryCode alanı.

Raporunu ve uygulama planını özetle, onayımı bekle - kodlamaya başlamadan önce.
```

---

*Bu güncelleme, ana `PRODUCT_NOTES.md` dosyasındaki "4. Elder Kayıt / Giriş Akışı" ve "5. Yeni Cihaz Güvenliği" bölümlerinin yerini alacak şekilde birleştirilmelidir.*
