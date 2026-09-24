import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/widgets/lottery_avatar_3d.dart';

import 'package:eterlotto/utils/pais_helper.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:eterlotto/providers/subscription_provider.dart';
import 'package:eterlotto/widgets/premium_crown_badge.dart';

class HeaderCard extends StatelessWidget {
  final String selectedLoteria;
  final String fechaSorteo;
  final String jackpot;
  final bool canPop;
  final String? jackpotIso;

  const HeaderCard({
    super.key,
    required this.selectedLoteria,
    required this.fechaSorteo,
    required this.jackpot,
    this.canPop = true,
    this.jackpotIso,
  });

  ({String date, String status}) _separarFechaYEstado() {
    final match = RegExp(r'^(.*) \(([^()]+)\)$').firstMatch(
      fechaSorteo.trim(),
    );
    return match == null
        ? (date: fechaSorteo, status: '')
        : (date: match.group(1)!.trim(), status: match.group(2)!.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fecha = _separarFechaYEstado();
    final parts = PaisHelper.getJackpotParts(
      jackpot,
      loteriaRoute: selectedLoteria,
      fallbackValue: "--",
    );
    String label = parts["label"] ?? "";
    
    // Aplicar localización a la etiqueta "millones" según formato
    if (label.toLowerCase().contains("millon") || label.toLowerCase().contains("million")) {
      if (jackpot.toLowerCase().contains("usd") || jackpot.toLowerCase().contains("million") || jackpot.toLowerCase().contains("millón")) {
        label = l10n.millonesUSD;
      } else {
        label = l10n.millonesCOP;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (canPop) const SizedBox(width: 8),
                LotteryAvatar3D(nombre: selectedLoteria, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              selectedLoteria,
                              style: AppTextStyles.tituloPrincipal.copyWith(
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Consumer<SubscriptionProvider>(
                            builder: (_, sub, __) => PremiumCrownIcon(
                              isPremium: sub.isPremium,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.sorteoFechaLabel(fecha.date),
                        style: AppTextStyles.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (fecha.status.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          fecha.status,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white38,
                            fontSize: 10.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF191B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              image: (jackpotIso != null && jackpotIso!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(
                        'https://flagcdn.com/w320/$jackpotIso.png',
                      ),
                      fit: BoxFit.cover,
                      opacity: 0.40,
                      onError: (_, __) {},
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.jackpotEstimado,
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 2),
                Text(
                  parts["value"]!,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                  textAlign: TextAlign.right,
                ),
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: Colors.white54,
                    ),
                    textAlign: TextAlign.right,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
