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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parts = PaisHelper.getJackpotParts(jackpot);
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  l10n.jackpotEstimado,
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  parts["value"]!,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: Colors.white54,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
