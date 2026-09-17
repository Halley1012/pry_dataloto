import 'package:flutter/material.dart';
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

      final languageCode = Localizations.localeOf(context).languageCode;
      final title = switch (languageCode) {
        'en' => 'Your session has expired',
        'pt' => 'Sua sessão expirou',
        'fr' => 'Votre session a expiré',
        _ => 'Tu sesión ha vencido',
      };
      final message = switch (languageCode) {
        'en' => 'For your security, please sign in again to continue.',
        'pt' => 'Por segurança, entre novamente para continuar.',
        'fr' => 'Pour votre sécurité, reconnectez-vous pour continuer.',
        _ => 'Por seguridad, inicia sesión nuevamente para continuar.',
      };
      final button = switch (languageCode) {
        'en' => 'Sign in again',
        'pt' => 'Entrar novamente',
        'fr' => 'Se reconnecter',
        _ => 'Ingresar nuevamente',
      };

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
