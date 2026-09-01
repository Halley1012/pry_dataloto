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

/// 🎨 SnackBar estilizado con la identidad visual de Eterlotto (igual al diseño oficial)
void showEterSnackBar(
  BuildContext context, {
  required String message,
  bool isError = false,
  bool isSuccess = false,
  Duration duration = const Duration(seconds: 3),
}) {
  final Color backgroundColor = isError
      ? const Color(0xFFD32F2F) // Rojo para errores y validaciones
      : AppColors.amber;         // Amarillo/Ámbar de Eterlotto para alertas y éxitos

  final Color textColor = isError
      ? Colors.white
      : const Color(0xFF1E1E1E);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: duration,
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      content: Text(
        message,
        style: AppTextStyles.mensajeImportante.copyWith(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

