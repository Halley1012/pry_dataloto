import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'resultados_shared.dart';

class EstadisticasCards extends StatelessWidget {
  final List<Map<String, dynamic>> misJugadas;
  final List<int> distribucionAciertos;
  final int rachaActualCount;
  final int mejorRachaCount;

  const EstadisticasCards({
    super.key,
    required this.misJugadas,
    required this.distribucionAciertos,
    required this.rachaActualCount,
    required this.mejorRachaCount,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildDistribucionAciertosCard(context)),
          const SizedBox(width: 10),
          Expanded(child: _buildRachaActualCard(context)),
        ],
      ),
    );
  }

  int _at(int index) =>
      index >= 0 && index < distribucionAciertos.length
          ? distribucionAciertos[index]
          : 0;

  int _sumFrom(int start) {
    if (start >= distribucionAciertos.length) return 0;
    return distribucionAciertos
        .skip(start)
        .fold<int>(0, (sum, value) => sum + value);
  }

  String _fivePlusLabel(String base) {
    if (distribucionAciertos.length <= 6) return base;
    return base.contains('5') ? base.replaceFirst('5', '5+') : '5+';
  }

  Widget _buildDistribucionAciertosCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final int totalJugadas = misJugadas.length;
    final int zeroHits = _at(0);
    final int oneTwoHits = _at(1) + _at(2);
    final int threeFourHits = _at(3) + _at(4);
    final int fiveOrMoreHits = _sumFrom(5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l10n.distribucionAciertosTitulo,
            style: GoogleFonts.montserrat(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            l10n.tusJugadasGuardadasParentesis,
            style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white54),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                painter: DonutChartPainter(
                  values: [
                    zeroHits,
                    oneTwoHits,
                    threeFourHits,
                    fiveOrMoreHits,
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$totalJugadas",
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        totalJugadas == 1
                            ? l10n.jugadaSingular
                            : l10n.jugadasPlural,
                        style: GoogleFonts.montserrat(
                          fontSize: 8.5,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildDonutLegendItem(
            Colors.grey,
            l10n.ceroAciertos,
            "$zeroHits",
          ),
          _buildDonutLegendItem(
            Colors.blueAccent,
            l10n.unoDosAciertos,
            "$oneTwoHits",
          ),
          _buildDonutLegendItem(
            Colors.amber,
            l10n.tresCuatroAciertos,
            "$threeFourHits",
          ),
          _buildDonutLegendItem(
            Colors.greenAccent,
            _fivePlusLabel(l10n.cincoAciertos),
            "$fiveOrMoreHits",
          ),
        ],
      ),
    );
  }

  Widget _buildRachaActualCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l10n.rachaActualTitulo,
            style: GoogleFonts.montserrat(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          const Text("🔥", style: TextStyle(fontSize: 24)),
          Text(
            "$rachaActualCount",
            style: GoogleFonts.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            l10n.jugadasConsecutivasAciertos,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(fontSize: 9.5, color: Colors.white60),
          ),
          const Spacer(),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  l10n.mejorRachaTitulo,
                  style: GoogleFonts.montserrat(fontSize: 9.5, color: Colors.white38),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$mejorRachaCount ",
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    Text(
                      mejorRachaCount == 1 ? l10n.jugadaSingular : l10n.jugadasPlural,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegendItem(Color color, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 9.5,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          Text(
            val,
            style: GoogleFonts.montserrat(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
