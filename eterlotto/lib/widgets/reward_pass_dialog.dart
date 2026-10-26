import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/reward_backend_service.dart';
import '../styles/app_text_styles.dart';
import '../styles/colores.dart';

class RewardPassDialog extends StatelessWidget {
  const RewardPassDialog({
    super.key,
    required this.status,
    required this.loading,
    required this.loadFailed,
    required this.demoAds,
  });
  final RewardBackendStatus? status;
  final bool loading;
  final bool loadFailed;
  final bool demoAds;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final strings = RewardBackendTexts(locale.languageCode);
    final status = this.status;
    final active = status?.passActive ?? false;
    final available = status?.passesAvailable ?? 0;
    final expiry = status?.challengeExpiresAt;
    final expiryText = expiry == null
        ? null
        : DateFormat.yMd(locale.toString()).format(expiry);
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.amber.withValues(alpha: 0.28)),
      ),
      title: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.title,
              style: AppTextStyles.h2.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading) const LinearProgressIndicator(color: AppColors.amber),
            if (loadFailed)
              Text(
                strings.unavailable,
                style: const TextStyle(color: Colors.white70),
              ),
            if (demoAds) ...[
              Text(
                strings.testAdsNeedSsv,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
            ],
            if (status != null) ...[
              Text(
                strings.progress(status.videosCompleted, status.videosRequired),
                style: const TextStyle(
                  color: Color(0xFF86D9A2),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: status.videosRequired <= 0
                    ? 0
                    : status.videosCompleted / status.videosRequired,
                color: const Color(0xFF86D9A2),
                backgroundColor: Colors.white24,
              ),
              const SizedBox(height: 12),
              Text(
                strings.continueChallenge,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              if (expiryText != null) ...[
                const SizedBox(height: 8),
                Text(
                  strings.deadline(expiryText),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
              if (available > 0) ...[
                const SizedBox(height: 12),
                Text(
                  strings.ready,
                  style: const TextStyle(color: Color(0xFF86D9A2)),
                ),
              ],
              if (active) ...[
                const SizedBox(height: 12),
                Text(
                  strings.active,
                  style: const TextStyle(color: Color(0xFF86D9A2)),
                ),
                Text(
                  strings.remaining(strings.formatDuration(status.remaining)),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'close'),
          child: Text(AppLocalizations.of(context)!.cerrar),
        ),
        // El regalo permite ganar más créditos incluso con un pase activo.
        TextButton.icon(
          onPressed: status == null || demoAds
              ? null
              : () => Navigator.pop(context, 'watch'),
          icon: const Icon(
            Icons.play_circle_outline_rounded,
            color: AppColors.amber,
          ),
          label: Text(
            strings.watch,
            style: const TextStyle(color: AppColors.amber),
          ),
        ),
        if (!active && available > 0)
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'activate'),
            child: Text(strings.activate),
          ),
      ],
    );
  }
}
