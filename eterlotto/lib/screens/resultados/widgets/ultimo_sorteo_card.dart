import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'resultados_shared.dart';

class UltimoSorteoCard extends StatelessWidget {
  final String selectedLoteria;
  final String fechaSorteo;
  final List<SubSorteoData> subSorteos;
  final int maxSeleccion;
  final bool tieneComplementario;
  final int? totalBalotasSorteo;

  const UltimoSorteoCard({
    super.key,
    required this.selectedLoteria,
    required this.fechaSorteo,
    required this.subSorteos,
    this.maxSeleccion = 5,
    this.tieneComplementario = false,
    this.totalBalotasSorteo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.resultadosLoteria(selectedLoteria),
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.sorteoFechaLabel(fechaSorteo),
            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 14),

          // Renderizar dinámicamente cada sub-sorteo (1, 2, 3 o N)
          ...subSorteos.asMap().entries.map((entry) {
            final int index = entry.key;
            final SubSorteoData sub = entry.value;

            final bool tieneComp = tieneComplementario || (sub.winningNums.length > maxSeleccion);
            final List<int> mainBalls = sub.winningNums.length > maxSeleccion
                ? sub.winningNums.sublist(0, maxSeleccion)
                : sub.winningNums;
            final int? compBall = (tieneComp && sub.winningNums.length > maxSeleccion)
                ? sub.winningNums.last
                : null;

            final int totalBalls = mainBalls.length +
                (compBall != null ? 1 : 0) +
                (sub.winningRed != null ? 1 : 0);

            final double ballSize = totalBalls <= 5
                ? 42.0
                : (totalBalls == 6 ? 38.0 : (totalBalls == 7 ? 34.0 : 30.0));
            final double ballPadding = totalBalls <= 5
                ? 3.5
                : (totalBalls == 6 ? 2.8 : (totalBalls == 7 ? 2.0 : 1.5));

            final List<Color> ballBgPalette = [
              const Color(0xFF1E3A8A), // Blue
              const Color(0xFF4C1D95), // Purple
              const Color(0xFF0F766E), // Teal
              const Color(0xFF9A3412), // Rust / Orange
            ];
            final Color baseBallColor = ballBgPalette[index % ballBgPalette.length];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (index > 0) const SizedBox(height: 14),
                Text(
                  subSorteos.length == 1
                      ? l10n.numerosGanadores
                      : sub.nombre,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sub.color,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...mainBalls.map((nVal) => Padding(
                              padding: EdgeInsets.symmetric(horizontal: ballPadding),
                              child: build3DBall(nVal, baseColor: baseBallColor, size: ballSize),
                            )),
                        if (compBall != null) ...[
                          SizedBox(width: ballPadding),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: ballPadding),
                            child: build3DBall(compBall, baseColor: const Color(0xFF0D9488), size: ballSize),
                          ),
                        ],
                        if (sub.winningRed != null) ...[
                          SizedBox(width: ballPadding * 1.5),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: ballPadding),
                            child: build3DBall(sub.winningRed!, baseColor: const Color(0xFFB91C1C), isSpecial: true, size: ballSize),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
