import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saglik_yaninda/core/theme/app_colors.dart';

/// Onboarding turlarının (Showcase.withWidget) ortak tooltip kartı.
///
/// Paketin varsayılan title/description tooltip'i yerine bilinçli olarak
/// tam-özel bir kart kullanılıyor — PRODUCT_NOTES'un "kullanıcı 'anladım'
/// demeden bir sonraki adıma geçemez" gereksinimi, paketin varsayılan
/// "Next"/"Skip" aksiyon butonlarıyla değil, buradaki tek "Anladım" butonuyla
/// karşılanıyor (tek yol: bu buton).
///
/// [showCloseButton] sadece manuel ("Yardım Al"/"Tekrar Öğren" ile başlatılan)
/// modda true geçilir — ilk-kurulumdaki zorunlu turda kapatma yolu yok.
class OnboardingTooltipCard extends StatelessWidget {
  const OnboardingTooltipCard({
    super.key,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onNext,
    this.showCloseButton = false,
    this.onClose,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onNext;
  final bool showCloseButton;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF263238),
                  ),
                ),
              ),
              if (showCloseButton)
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: AppColors.textSecondaryStrong,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.helpAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonLabel,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
