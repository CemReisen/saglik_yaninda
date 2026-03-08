# 💊 Sağlık Yanında | Akıllı Sağlık ve İlaç Takip Uygulaması

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

**Sağlık Yanında**, yaşlı bireylerin ilaçlarını düzenli almalarını sağlarken, aile bireylerinin de bu süreci uzaktan takip edebilmesine olanak tanıyan, çapraz platform destekli ve bulut entegrasyonlu akıllı bir mobil sağlık asistanıdır. 

## ✨ Temel Özellikler (Features)

* 👥 **Rol Bazlı Erişim (RBAC):** "Kendi İlacım" veya "Yakınımın İlacı" seçenekleriyle farklı kullanıcılara (Yaşlı Birey / Bakıcı) tamamen bağımsız arayüzler ve deneyimler sunulur.
* 🔗 **Güvenli Aile Bağlantısı:** 6 haneli rastgele üretilen eşsiz kodlarla (Örn: AX7-B92) yaşlı birey ve bakıcı hesapları güvenli bir şekilde birbirine bağlanır.
* ⏰ **Çevrimdışı (Offline) Hatırlatıcılar:** `flutter_local_notifications` kullanılarak, kullanıcının interneti olmasa bile tam saatinde çalışan milisaniye hassasiyetli alarm ve bildirim sistemi.
* ☁️ **Gerçek Zamanlı Senkronizasyon:** `StreamBuilder` mimarisi sayesinde yaşlı birey ilacını içtiğinde veya puan kazandığında, bakıcının panelinde anında güncellenir.
* 🏆 **Oyunlaştırma (Gamification):** Kullanıcıların ilaçlarını zamanında içmesini teşvik eden, kümülatif olarak artan "Sağlık Puanı" ve günlük "İlerleme Çubuğu" (Progress Bar).
* 🛡️ **Veri Tutarlılığı (WriteBatch):** Firestore üzerinde aynı anda yapılan çoklu işlemlerde (Örn: Günde 3 doz ilaç ekleme) veritabanı bütünlüğünü %100 koruyan atomik işlemler.


## 📱 Ekran Görüntüleri

| Giriş ve Kayıt | Ana Sayfa (İlaç Takibi) | Takvim Görünümü |
| :---: | :---: | :---: |
| <img src="https://github.com/user-attachments/assets/f8b91caf-e8e6-4ca8-8d25-87cdff393650" width="130"/> | <img src="https://github.com/user-attachments/assets/7beefdac-d7db-4976-aa12-ae705caf63ae" width="130"/> | <img src= "https://github.com/user-attachments/assets/4f0d1917-e80a-49da-99fe-5516d5482274" width="130"/> |



| Bakıcı (Caregiver) Paneli | Yakın Ekleme | Profil ve Oyunlaştırma |
| :---: | :---: | :---: |
| <img src="assets/screenshots/caregiver.png" width="200"/> | <img src="assets/screenshots/add_relative.png" width="200"/> | <img src="assets/screenshots/profile.png" width="200"/> |

*(Not: Görselleri GitHub reponda `assets/screenshots/` klasörüne isimleri eşleşecek şekilde yüklemelisin.)*

## 🛠️ Kullanılan Teknolojiler (Tech Stack)

### Frontend & UI
* **Framework:** Flutter (v3.9.2)
* **Design & Icons:** Figma, `cupertino_icons`, `flutter_svg`, Google Fonts (Poppins)
* **UI Components:** `table_calendar` (Tarih tabanlı filtreleme), ModalBottomSheets, ListWheelScrollView

### Backend & Cloud (Firebase)
* **Authentication:** `firebase_auth` (Kayıt, Giriş, Şifre Sıfırlama)
* **Database:** `cloud_firestore` (Koleksiyonlar: users, medicines, schedules, relations)
* **Push Notifications:** `firebase_messaging` (FCM Token tabanlı iletişim)

### Core Logic
* **Local Notifications:** `flutter_local_notifications` & `timezone` (Çevrimdışı, zamanlanmış bildirimler)
* **Local Storage:** `shared_preferences` (Oturum yönetimi ve Beni Hatırla mekanizması)
* **Localization:** `intl` (Türkçe tarih ve metin formatlamaları)

## 🚀 Kurulum (Installation)

Projeyi kendi bilgisayarınızda derlemek ve çalıştırmak için aşağıdaki adımları izleyebilirsiniz:

1.  **Repoyu Klonlayın:**
    ```bash
    git clone [https://github.com/CemReisen/saglik_yaninda.git](https://github.com/CemReisen/saglik_yaninda.git)
    cd saglik_yaninda
    ```

2.  **Bağımlılıkları Yükleyin:**
    ```bash![profilePage](https://github.com/user-attachments/assets/e63854cc-f0ba-44fa-ae26-fd50171c499f)



    flutter pub get![Uploading profilePage.jpeg…]()

    ```

3.  **Firebase Yapılandırması:**
    * Bu proje Firebase kullanmaktadır. Kendi veritabanınızı bağlamak için Firebase Console üzerinden bir proje oluşturun.
    * `google-services.json` (Android) ve `GoogleService-Info.plist` (iOS) dosyalarını ilgili dizinlere yerleştirin.

4.  **Projeyi Çalıştırın:**
    ```bash
    flutter run
    ```

## 🧠 Gelecek Hedefleri (Roadmap)
* **Yapay Zekâ Asistanı:** OpenAI veya Hugging Face API entegrasyonu ile yaşlı kullanıcılara kişiselleştirilmiş haftalık sağlık özetleri ve motivasyon bildirimleri gönderilmesi.
* **Çapraz Bildirimler:** Yaşlı birey kritik ilacını unuttuğunda aile bireyine anlık Push bildirim iletilmesi.
* **İlaç Uyum Grafikleri:** `fl_chart` kullanılarak kullanıcının haftalık/aylık ilaç içme başarı yüzdesinin görselleştirilmesi.

---
**Geliştirici:** [Ersin Cem Kök](https://github.com/CemReisen)
