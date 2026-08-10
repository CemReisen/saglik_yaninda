import 'package:flutter/material.dart';

/// Home onboarding turunun `ShowcaseView.register(scope: ...)` çağrısında
/// kullandığı scope adı. showcaseview widget'ları (Showcase) ve kontrolcüsü
/// (ShowcaseView) birbirini widget ağacı hiyerarşisi üzerinden DEĞİL, bu
/// scope string'i + GlobalKey üzerinden buluyor — bu yüzden navbar gibi
/// HomePage'in DIŞINDA (main.dart → MainLayout) yaşayan bir hedef de aynı
/// scope'u paylaşarak aynı tura dahil olabiliyor. Tek doğruluk kaynağı
/// burası olsun diye home_page.dart kendi private bir kopyasını tutmuyor.
const String homeTourScope = 'home_onboarding';

/// Alt navbar (main.dart → MainLayout) HomePage'in değil, MainLayout'un
/// widget ağacının bir parçası — ama Home turunun 5. adımı (navbar tanıtımı)
/// navbar'ın kendisini spotlight'lamak zorunda. Anahtarı iki dosyanın da
/// import edebileceği bu paylaşılan dosyada tutuyoruz.
final GlobalKey homeNavbarShowcaseKey = GlobalKey();

/// Home turu şu an "manuel" modda mı (Yardım Al ile tetiklendi, X ile
/// kapatılabilir) çalışıyor? main.dart'taki navbar adımının tooltip kartı
/// bunu okuyup kapatma ikonunu göstermeli/gizlemeli — HomePage'in kendi
/// private `_onboardingTourIsManual` alanına main.dart'tan erişilemediği
/// için bu bilgi de paylaşılan bir ValueNotifier üzerinden akıyor.
final ValueNotifier<bool> homeTourIsManualNotifier = ValueNotifier<bool>(false);

/// Home/Ekle/Profil onboarding turlarından HERHANGİ biri o an aktifken true.
/// main.dart'taki alt navbar bunu kontrol edip tur sırasında sekme değişimini
/// engelliyor — aksi halde gerçek bir sekme dokunuşu (showcaseview'ın hedef
/// overlay'i varsayılan olarak translucent olduğu için spotlight'lanan
/// widget'a dokunuş arkasındaki gerçek GestureDetector'a da ulaşabiliyor,
/// bkz. home_page.dart'taki ilgili yorumlar), o an tur gösteren sayfayı
/// (Home/Ekle/Profil) ortasında unmount edip showcaseview overlay'ini
/// sahipsiz bırakırdı.
final ValueNotifier<bool> onboardingTourActiveNotifier = ValueNotifier<bool>(
  false,
);
