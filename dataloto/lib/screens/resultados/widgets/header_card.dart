import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dataloto/widgets/lottery_avatar_3d.dart';

import 'package:dataloto/utils/pais_helper.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

class HeaderCard extends StatelessWidget {
  final String selectedLoteria;
  final String fechaSorteo;
  final String jackpot;
  final bool canPop;

  const HeaderCard({
    Key? key,
    required this.selectedLoteria,
    required this.fechaSorteo,
    required this.jackpot,
    this.canPop = true,
  }) : super(key: key);

  static String getFallbackJackpot(String loteria) {
    final l = loteria.toLowerCase();
    if (l.contains("baloto")) return "\$24.500 millones";
    if (l.contains("revancha")) return "\$1.200 millones";
    if (l.contains("miloto")) return "\$220 millones";
    if (l.contains("colorloto") || l.contains("color loto")) return "\$1.000 millones";
    if (l.contains("double play") || l.contains("double_play")) return "\$10 Million";
    if (l.contains("lotto america") || l.contains("lotto_america")) return "\$2 Million";
    if (l.contains("millionaire") || l.contains("life")) return "\$1.000 / día";
    if (l.contains("powerball")) return "\$20 Million";
    if (l.contains("mega millions") || l.contains("megamillions")) return "\$20 Million";
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fallback = getFallbackJackpot(selectedLoteria);
    final parts = PaisHelper.getJackpotParts(jackpot, fallbackValue: fallback);
    String label = parts["label"]!;
    
    // Aplicar localización a la etiqueta "millones" si existe
    if (label.toLowerCase().contains("millon") || label.toLowerCase().contains("million")) {
      if (selectedLoteria.toLowerCase().contains("powerball") || 
          selectedLoteria.toLowerCase().contains("mega millions") ||
          selectedLoteria.toLowerCase().contains("lotto america") ||
          selectedLoteria.toLowerCase().contains("double play") ||
          selectedLoteria.toLowerCase().contains("millionaire")) {
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
                      Text(
                        selectedLoteria,
                        style: GoogleFonts.montserrat(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Sorteo: $fechaSorteo",
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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
