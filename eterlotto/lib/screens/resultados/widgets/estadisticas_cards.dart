import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import '../../../widgets/fullscreen_chart_viewer.dart';
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
              _buildRachaActualCard(),
              const SizedBox(height: 14),
              _buildHistorialCoberturaCard(context),
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _buildDistribucionAciertosCard()),
              const SizedBox(width: 10),
              Expanded(flex: 4, child: _buildRachaActualCard()),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: _buildHistorialCoberturaCard(context)),
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

  Widget _buildHistorialCoberturaCard(BuildContext context) {
    final double avg = historialCoberturasList.isNotEmpty
        ? historialCoberturasList.reduce((a, b) => a + b) / historialCoberturasList.length
        : 0.8;
    final double maxCov = historialCoberturasList.isNotEmpty
        ? historialCoberturasList.reduce(math.max)
        : 0.8;
    final double minCov = historialCoberturasList.isNotEmpty
        ? historialCoberturasList.reduce(math.min)
        : 0.4;

    double minY = minCov;
    double maxY = maxCov;
    if (minY == maxY) {
      minY = math.max(0.0, minY - 0.1);
      maxY = math.min(1.0, maxY + 0.1);
    }
    final finalMaxY = (maxY * 1.20).toDouble();

    Widget buildLineChart({bool isFullScreen = false}) {
      return SizedBox(
        height: isFullScreen ? double.infinity : 120,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 12.0, bottom: 8.0, left: 8.0),
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      final int val = (touchedSpot.y * 100).round();
                      return LineTooltipItem(
                        "$val%",
                        const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                      );
                    }).toList();
                  },
                ),
              ),
              minY: minY,
              maxY: finalMaxY,
              minX: 0,
              maxX: historialCoberturasList.isNotEmpty ? (historialCoberturasList.length - 1).toDouble() : 0,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 0.1,
                    getTitlesWidget: (value, meta) {
                      final intVal = (value * 100).round();
                      final intMin = (meta.min * 100).round();
                      final intMax = (meta.max * 100).round();
                      final isMin = intVal == intMin;
                      final isMax = intVal == intMax;
                      final isStep = intVal % 20 == 0 && intVal > intMin && intVal < intMax;

                      if (isMin || isMax || isStep) {
                        return Text(
                          "$intVal%",
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final intVal = value.toInt();
                      final isLast = intVal == historialCoberturasList.length - 1;
                      if (intVal % 2 == 0 || isLast) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "$intVal",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    historialCoberturasList.length,
                    (idx) => FlSpot(idx.toDouble(), historialCoberturasList[idx]),
                  ),
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: const Color(0xFFF59E0B),
                  barWidth: isFullScreen ? 4 : 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3.5,
                        color: const Color(0xFFF59E0B),
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Historial de cobertura",
                      style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      "Promedio general: ${(avg * 100).round()}% (últimos ${historialCoberturasList.length} sorteos)",
                      style: GoogleFonts.montserrat(fontSize: 11, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  FullScreenChartViewer.show(
                    context,
                    title: "Historial de cobertura",
                    subtitle: "Promedio general: ${(avg * 100).round()}% (últimos ${historialCoberturasList.length} sorteos)",
                    chartWidget: buildLineChart(isFullScreen: true),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.open_in_full, color: Color(0xFFF59E0B), size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          buildLineChart(isFullScreen: false),
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


}
