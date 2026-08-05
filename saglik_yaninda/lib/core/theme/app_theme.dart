import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

ThemeData buildLightTheme() {
  final base = ThemeData.light();

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
        color: AppColors.primary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
    ),
    // Varsayılan CircularProgressIndicator()/LinearProgressIndicator() rengi
    // (renk verilmemiş her çağrı) Material'ın varsayılan mor tonu yerine
    // marka rengini (teal) kullansın — ör. main.dart'taki auth state
    // bekleme ekranı, native splash'ten sonra gelen ilk frame'de "uyumsuz
    // mor spinner" izlenimi vermesin.
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.navbarBg,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.navbarInactive,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    textTheme: TextTheme(
      titleLarge: GoogleFonts.poppins(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      // Kart/bölüm başlıkları için (ör. ilaç adı) — yaşlı kullanıcı hedefi:
      // gövde metni ≥18sp.
      titleMedium: GoogleFonts.poppins(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      // Gövde metni: 16 → 18.
      bodyLarge: GoogleFonts.nunito(color: AppColors.textPrimary, fontSize: 18),
      // İkincil/açıklama metni: 14 → 16 (yaşlı kullanıcı hedefi: ≥16sp).
      bodyMedium: GoogleFonts.nunito(
        color: AppColors.textSecondary,
        fontSize: 16,
      ),
    ),
  );
}
