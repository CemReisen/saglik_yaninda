import 'package:flutter/material.dart';
import 'package:saglik_yaninda/core/theme/app_colors.dart';

/// "Kodum var" — Hızlı Başla ile açılmış bir hesabı, kurtarma kodu
/// (bkz. quick_start_page.dart, ConnectionCodeService) girerek yeni bir
/// cihazda/kurulumda geri getirme akışı.
///
/// Şimdilik placeholder: gerçek akış (kod girişi -> recoverWithCode Cloud
/// Function -> custom token ile giriş) ADIM 4'te buraya eklenecek
/// (bkz. PRODUCT_NOTES_AUTH_UPDATE.md).
class RecoveryCodePage extends StatelessWidget {
  const RecoveryCodePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Kodum Var")),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.construction_rounded,
                  size: 56,
                  color: AppColors.textSecondaryStrong,
                ),
                const SizedBox(height: 16),
                Text(
                  "Bu özellik yakında burada olacak.",
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  "Kurtarma kodunuzla giriş yapma özelliği çok yakında eklenecek.",
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryStrong,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
