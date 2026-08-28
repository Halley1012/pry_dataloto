import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../styles/colores.dart';
import '../styles/app_text_styles.dart';

void showJustifiedDialog(BuildContext context, String title, String content) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.blackfondo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: AppTextStyles.h2.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Text(
          content,
          textAlign: TextAlign.justify,
          style: AppTextStyles.mensajeSecundario,
        ),
      ),
    ),
  );
}

void showAcercaDeDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showJustifiedDialog(context, l10n.acercaDe, l10n.contenidoAcercaDe);
}

/// 🎨 SnackBar estilizado con la identidad visual de Eterlotto
void showEterSnackBar(
  BuildContext context, {
  required String message,
  bool isError = false,
  bool isSuccess = false,
  Duration duration = const Duration(seconds: 4),
}) {
  final Color accentColor = isError
      ? Colors.redAccent
      : (isSuccess ? AppColors.yellow : Colors.white70);

  final IconData iconData = isError
      ? Icons.error_outline
      : (isSuccess ? Icons.check_circle_outline : Icons.info_outline);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: duration,
      backgroundColor: AppColors.darkGray,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withValues(alpha: 0.8), width: 1.2),
      ),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(iconData, color: accentColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.mensajeSecundario.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

