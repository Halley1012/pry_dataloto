import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'resultados_shared.dart';

class EstadisticasCards extends StatelessWidget {
  final List<Map<String, dynamic>> misJugadas;
  final List<int> distribucionAciertos;
  final List<double> historialCoberturasList;
  final int rachaActualCount;
  final int mejorRachaCount;

  const EstadisticasCards({
    Key? key,
    required this.misJugadas,
    required this.distribucionAciertos,
    required this.historialCoberturasList,
    required this.rachaActualCount,
    required this.mejorRachaCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth <= 750;

        if (isMobile) {
          return Column(
            children: [
              _buildDistribucionAciertosCard(),
              const SizedBox(height: 14),
              _buildHistorialCoberturaCard(),
              const SizedBox(height: 14),
              _buildRachaActualCard(),
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _buildDistribucionAciertosCard()),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: _buildHistorialCoberturaCard()),
              const SizedBox(width: 10),
              Expanded(flex: 4, child: _buildRachaActualCard()),
            ],
          );
        }
      },
    );
  }

  Widget _buildDistribucionAciertosCard() {
    final int totalJugadas = misJugadas.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Distribución de aciertos",
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text("(Tus jugadas guardadas)", style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: DonutChartPainter(values: [
                    distribucionAciertos[0],
                    distribucionAciertos[1] + distribucionAciertos[2],
                    distribucionAciertos[3] + distribucionAciertos[4],
                    distribucionAciertos[5],
                  ]),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("$totalJugadas", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(totalJugadas == 1 ? "jugada" : "jugadas", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDonutLegendItem(Colors.grey, "0 aciertos", "${distribucionAciertos[0]}"),
                    _buildDonutLegendItem(Colors.blueAccent, "1 - 2 aciertos", "${distribucionAciertos[1] + distribucionAciertos[2]}"),
                    _buildDonutLegendItem(Colors.amber, "3 - 4 aciertos", "${distribucionAciertos[3] + distribucionAciertos[4]}"),
                    _buildDonutLegendItem(Colors.greenAccent, "5 aciertos", "${distribucionAciertos[5]}"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_border, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    totalJugadas > 0
                        ? "Distribución calculada a partir de tus $totalJugadas jugada(s)."
                        : "Agrega jugadas para visualizar la distribución de aciertos.",
                    style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialCoberturaCard() {
    final double avg = historialCoberturasList.isNotEmpty
        ? historialCoberturasList.reduce((a, b) => a + b) / historialCoberturasList.length
        : 0.8;
    final double maxCov = historialCoberturasList.isNotEmpty
        ? historialCoberturasList.reduce(math.max)
        : 0.8;
    final double minCov = historialCoberturasList.isNotEmpty
        ? historialCoberturasList.reduce(math.min)
        : 0.4;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Historial de cobertura",
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text("(últimos ${historialCoberturasList.length} sorteos)", style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: const Size(double.infinity, 120),
              painter: LineChartPainter(coverages: historialCoberturasList),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric("Promedio general", "${(avg * 100).round()}%"),
              _buildMiniMetric("Mejor cobertura", "${(maxCov * 100).round()}%"),
              _buildMiniMetric("Peor cobertura", "${(minCov * 100).round()}%"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRachaActualCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardBoxDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Racha actual",
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text("🔥", style: TextStyle(fontSize: 32)),
          Text(
            "$rachaActualCount",
            style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          Text(
            "jugada(s) consecutiva(s) con aciertos",
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Text("Mejor racha", style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white38)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("$mejorRachaCount ", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
              Text(
                mejorRachaCount == 1 ? "jugada" : "jugadas",
                style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegendItem(Color color, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.montserrat(fontSize: 9, color: Colors.white70)),
            ],
          ),
          Text(val, style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String val, {String? sub}) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 8, color: Colors.white38)),
        Text(val, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        if (sub != null) Text(sub, style: GoogleFonts.montserrat(fontSize: 7, color: Colors.white38)),
      ],
    );
  }
}
