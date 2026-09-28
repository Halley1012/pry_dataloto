import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/services/api_service.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;

  Locale? get locale => _locale;

  LocaleProvider() {
    unawaited(_cargarLocaleGuardado());
  }

  Future<void> _cargarLocaleGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language_code');

    if (langCode != null && langCode.trim().isNotEmpty) {
      _locale = Locale(langCode.trim());
      notifyListeners();

      // Importante: versiones anteriores guardaban el idioma sólo en el
      // dispositivo. Al iniciar, lo sincronizamos también con el backend para
      // que FCM use el mismo idioma aunque el usuario no vuelva a abrir Perfil.
      await _syncBackendLanguage(_locale!.languageCode);
      return;
    }

    // Si se usa "Idioma del sistema", sincronizamos el idioma efectivo que
    // Flutter realmente puede mostrar. No hay una lista duplicada hardcodeada:
    // se toma de AppLocalizations.supportedLocales.
    await _syncBackendLanguage(_effectiveSystemLanguage());
  }

  Future<void> setLocale(Locale loc) async {
    final normalized = Locale(loc.languageCode);
    final changed = _locale != normalized;

    _locale = normalized;
    if (changed) {
      notifyListeners();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', normalized.languageCode);
    await _syncBackendLanguage(normalized.languageCode);
  }

  Future<void> clearLocale() async {
    final changed = _locale != null;
    _locale = null;
    if (changed) {
      notifyListeners();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('language_code');
    await _syncBackendLanguage(_effectiveSystemLanguage());
  }

  String _effectiveSystemLanguage() {
    final supported = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode.toLowerCase())
        .toSet();

    // Android puede entregar una lista de preferencias. Elegimos la primera
    // que la versión instalada de Eterlotto realmente soporte.
    for (final locale in PlatformDispatcher.instance.locales) {
      final code = locale.languageCode.toLowerCase();
      if (supported.contains(code)) {
        return code;
      }
    }

    // Coincide con el primer locale soportado por la app y se adapta
    // automáticamente cuando se amplíe supportedLocales en el futuro.
    return AppLocalizations.supportedLocales.first.languageCode.toLowerCase();
  }

  Future<void> _syncBackendLanguage(String languageCode) async {
    final code = languageCode.trim().toLowerCase();
    if (code.isEmpty) return;

    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId <= 0) return;

      final result = await ApiService.updateUser(
        userId,
        <String, dynamic>{'idioma': code},
      );

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('backend_language_code', code);
        debugPrint('[I18N] Idioma sincronizado con backend: $code');
      }
    } catch (e) {
      // Cambiar el idioma de la interfaz no debe fallar porque el backend esté
      // temporalmente sin conexión. Se reintentará al próximo arranque/cambio.
      debugPrint('[I18N] No fue posible sincronizar idioma: ${e.runtimeType}');
    }
  }
}
