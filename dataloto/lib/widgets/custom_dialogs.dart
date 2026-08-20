import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../styles/colores.dart';
import '../styles/app_text_styles.dart';

void showJustifiedDialog(BuildContext context, String title, String content) {
  final l10n = AppLocalizations.of(context)!;
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.cerrar,
            style: const TextStyle(color: AppColors.yellow),
          ),
        ),
      ],
    ),
  );
}

void showAcercaDeDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showJustifiedDialog(context, l10n.acercaDe, l10n.contenidoAcercaDe);
}
