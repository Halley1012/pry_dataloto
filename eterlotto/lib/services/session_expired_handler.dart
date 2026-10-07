import 'package:flutter/material.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/config/navigation.dart';

class SessionExpiredHandler {
  SessionExpiredHandler._();

  static bool _dialogVisible = false;

  /// Lleva primero al login para que ninguna pantalla privada quede visible y
  /// después explica por qué se solicitó autenticación nuevamente.
  static Future<void> show() async {
    if (_dialogVisible) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    _dialogVisible = true;
    try {
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);

      // Esperar a que /login tenga un contexto estable antes de abrir diálogo.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final context = navigatorKey.currentContext;
      if (context == null) return;

      final l10n = AppLocalizations.of(context)!;
      final title = l10n.sessionExpiredTitle;
      final message = l10n.sessionExpiredMessage;
      final button = l10n.sessionExpiredButton;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(button),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _dialogVisible = false;
    }
  }
}
