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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool tieneBalotaExtra = !selectedLoteria.toLowerCase().contains("miloto") &&
        !selectedLoteria.toLowerCase().contains("colorloto");

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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...winningNums.map((nVal) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: build3DBall(nVal, baseColor: const Color(0xFF1E3A8A)),
                  )),
                  if (tieneBalotaExtra && winningRed != null) ...[
                    const SizedBox(width: 10),
                    build3DBall(winningRed!, baseColor: const Color(0xFFB91C1C), isSpecial: true),
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...winningNumsRevancha.map((nVal) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: build3DBall(nVal, baseColor: const Color(0xFF4C1D95)),
                    )),
                    if (tieneBalotaExtra && winningRedRevancha != null) ...[
                      const SizedBox(width: 10),
                      build3DBall(winningRedRevancha!, baseColor: const Color(0xFFB91C1C), isSpecial: true),
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
