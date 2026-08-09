import 'package:flutter/material.dart';

/// Uygulamanın kök Navigator'ına, herhangi bir sayfanın kendi (muhtemelen
/// geçersiz kılınmış) BuildContext'ine bağlı kalmadan erişmesini sağlar.
///
/// Neden gerekli: main.dart'taki authStateChanges() StreamBuilder'ı, kimlik
/// doğrulama durumu değiştiği anda (ör. signInWithCredential tamamlandığında)
/// `home:` widget'ını değiştirir (LoginPage -> MainLayout/CaregiverLayout) -
/// bu, LoginPage'in State'ini HEMEN dispose eder. Google ile girişte
/// signInWithCredential() döndüğü anda bu geçiş zaten tetiklenmiş oluyor;
/// LoginPage'in kendi context'ine bağlı bundan SONRAKİ bir showDialog/
/// Navigator çağrısı "Looking up a deactivated widget's ancestor is unsafe"
/// hatasıyla sessizce başarısız oluyordu (bkz. login_page.dart ->
/// _signInWithGoogle, 2026-08-09 tarihli bug raporu - users/{uid} dokümanı
/// hiç yazılmıyordu çünkü rol seçim dialogu bu hatayla patlıyordu ve catch
/// bloğu `if (!mounted) return;` ile hatayı sessizce yutuyordu).
///
/// MaterialApp'in kendisi bu geçişte dispose olmuyor (sadece `home:`
/// argümanına geçirilen widget değişiyor) - bu yüzden MaterialApp'e bağlı bu
/// GlobalKey üzerinden alınan context/Navigator her zaman canlı kalıyor.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
