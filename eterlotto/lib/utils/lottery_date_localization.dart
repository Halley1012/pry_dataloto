import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';

class LotteryDateLocalization {
  const LotteryDateLocalization._();

  static DateTime? _parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw.trim();
    return DateTime.tryParse(clean) ??
        (clean.length >= 10 ? DateTime.tryParse(clean.substring(0, 10)) : null);
  }

  static String formatDate(
    BuildContext context,
    String? raw, {
    String fallback = '',
  }) {
    final parsed = _parse(raw);
    if (parsed == null) return raw?.trim().isNotEmpty == true ? raw!.trim() : fallback;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat('EEE, d MMM y', locale).format(parsed);
  }

  static String drawStatus(BuildContext context, String? raw) {
    final parsed = _parse(raw);
    if (parsed == null) return '';
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return l10n.sorteaHoy;
    if (diff == 1) return l10n.manana;
    if (diff > 1) return l10n.enDias(diff);
    if (diff == -1) return l10n.sorteadoAyer;
    return l10n.sorteadoHaceDias(diff.abs());
  }

  static String formatDateWithRelative(BuildContext context, String? raw) {
    final parsed = _parse(raw);
    if (parsed == null) return raw?.trim().isNotEmpty == true ? raw!.trim() : '--';
    final base = formatDate(context, raw);
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = target.difference(today).inDays;
    String? relative;
    if (diff == 0) relative = l10n.hoyParentesis;
    else if (diff == 1) relative = l10n.manana;
    else if (diff == -1) relative = l10n.ayerParentesis;
    else if (diff > 1) relative = l10n.enDias(diff);
    else if (diff < -1) relative = l10n.sorteadoHaceDias(diff.abs());
    return relative == null ? base : '$base ($relative)';
  }
}
