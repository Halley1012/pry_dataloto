import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';
import 'resultados_shared.dart';

class UltimoSorteoCard extends StatelessWidget {
  final String selectedLoteria;
  final String fechaSorteo;
  final bool hasRevanchaData;
  final String nombreSorteoPrincipal;
  final String nombreSorteoSecundario;
  final List<int> winningNums;
  final int? winningRed;
  final List<int> winningNumsRevancha;
  final int? winningRedRevancha;
  final int maxSeleccion;
  final bool tieneComplementario;
  final int? totalBalotasSorteo;

  const UltimoSorteoCard({
    Key? key,
    required this.selectedLoteria,
    required this.fechaSorteo,
    required this.hasRevanchaData,
    required this.nombreSorteoPrincipal,
    required this.nombreSorteoSecundario,
    required this.winningNums,
    this.winningRed,
    required this.winningNumsRevancha,
    this.winningRedRevancha,
    this.maxSeleccion = 5,
    this.tieneComplementario = false,
    this.totalBalotasSorteo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final bool tieneComp = tieneComplementario || (winningNums.length > maxSeleccion);

    // Separar balotas principales de complementarias
    final List<int> mainBalls = winningNums.length > maxSeleccion
        ? winningNums.sublist(0, maxSeleccion)
        : winningNums;
    final int? compBall = (tieneComp && winningNums.length > maxSeleccion)
        ? winningNums.last
        : null;

    final int totalBalls = mainBalls.length +
        (compBall != null ? 1 : 0) +
        (winningRed != null ? 1 : 0);

    final double ballSize = totalBalls <= 5
        ? 42.0
        : (totalBalls == 6 ? 38.0 : (totalBalls == 7 ? 34.0 : 30.0));
    final double ballPadding = totalBalls <= 5
        ? 3.5
        : (totalBalls == 6 ? 2.8 : (totalBalls == 7 ? 2.0 : 1.5));

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
              Text(
                l10n.resultadosLoteria(selectedLoteria),
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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

          // Fila Baloto Principal
          Text(
            l10n.numerosGanadores,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.amber,
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
                    child: build3DBall(nVal, baseColor: const Color(0xFF1E3A8A), size: ballSize),
                  )),
                  if (compBall != null) ...[
                    SizedBox(width: ballPadding),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: ballPadding),
                      child: build3DBall(compBall, baseColor: const Color(0xFF0D9488), size: ballSize),
                    ),
                  ],
                  if (winningRed != null) ...[
                    SizedBox(width: ballPadding * 1.5),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: ballPadding),
                      child: build3DBall(winningRed!, baseColor: const Color(0xFFB91C1C), isSpecial: true, size: ballSize),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Fila Revancha (si existe)
          if (hasRevanchaData && winningNumsRevancha.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              nombreSorteoSecundario,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.purpleAccent,
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
                    ...winningNumsRevancha.map((nVal) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: ballPadding),
                      child: build3DBall(nVal, baseColor: const Color(0xFF4C1D95), size: ballSize),
                    )),
                    if (winningRedRevancha != null) ...[
                      SizedBox(width: ballPadding * 1.5),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: ballPadding),
                        child: build3DBall(winningRedRevancha!, baseColor: const Color(0xFFB91C1C), isSpecial: true, size: ballSize),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
