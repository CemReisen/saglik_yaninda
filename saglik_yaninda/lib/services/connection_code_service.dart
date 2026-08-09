import 'dart:math';

/// "Aile Bağlantı Kodu" üretimi — register_page.dart, login_page.dart (Google
/// ile ilk giriş) ve quick_start_page.dart (Hızlı Başla / anonim giriş)
/// arasında paylaşılan tek doğruluk kaynağı. Hızlı Başla'da bu kod aynı
/// zamanda kurtarma kodu olarak da kullanılıyor (bkz. PRODUCT_NOTES_AUTH_UPDATE.md)
/// — bu yüzden format her yerde birebir aynı kalmalı.
class ConnectionCodeService {
  ConnectionCodeService._();

  static String generate() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    final code = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
    return "${code.substring(0, 3)}-${code.substring(3, 6)}";
  }
}
