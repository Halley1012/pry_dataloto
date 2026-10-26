import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../styles/colores.dart';

class LanguageSelectionDialog extends StatefulWidget {
  const LanguageSelectionDialog({super.key});

  @override
  State<LanguageSelectionDialog> createState() =>
      _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends State<LanguageSelectionDialog> {
  bool _changing = false;
  String? _error;

  Future<void> _select(Locale? locale) async {
    if (_changing) return;
    final l10n = AppLocalizations.of(context)!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.seleccionarIdioma),
        content: Text(l10n.confirmarCambioIdioma),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelar),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.si),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    setState(() {
      _changing = true;
      _error = null;
    });
    // Paint the progress state before applying/rebuilding the locale.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      final provider = context.read<LocaleProvider>();
      if (locale == null) {
        await provider.clearLocale();
      } else {
        await provider.setLocale(locale);
      }
      if (!mounted) return;
      // Close this selector only; backend synchronization runs independently.
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _changing = false;
        _error = AppLocalizations.of(context)!.languageChangeFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_changing,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.seleccionarIdioma,
          style: const TextStyle(color: Colors.white),
        ),
        actions: _changing
            ? null
            : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cerrar),
                ),
              ],
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_changing) ...[
                const LinearProgressIndicator(color: AppColors.yellow),
                const SizedBox(height: 12),
                Text(
                  l10n.changingLanguage,
                  style: const TextStyle(color: Colors.white70),
                ),
              ] else ...[
                for (final option in const [
                  ('es', '🇪🇸', 'Español'),
                  ('en', '🇺🇸', 'English'),
                  ('pt', '🇧🇷', 'Português'),
                  ('fr', '🇫🇷', 'Français'),
                ])
                  ListTile(
                    leading: Text(
                      option.$2,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(
                      option.$3,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => _select(Locale(option.$1)),
                  ),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(
                    Icons.settings_suggest,
                    color: AppColors.yellow,
                  ),
                  title: Text(
                    l10n.idiomaSistema,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () => _select(null),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
