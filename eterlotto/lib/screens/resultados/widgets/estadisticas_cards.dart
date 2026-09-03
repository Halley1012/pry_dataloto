import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
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
              _buildDistribucionAciertosCard(context),
              const SizedBox(height: 14),
              _buildRachaActualCard(context),
              const SizedBox(height: 14),
              _buildHistorialCoberturaCard(context),
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _buildDistribucionAciertosCard(context)),
              const SizedBox(width: 10),
              Expanded(flex: 4, child: _buildRachaActualCard(context)),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: _buildHistorialCoberturaCard(context)),
            ],
          );
        }
      },
    );
  }

  Widget _buildDistribucionAciertosCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final int totalJugadas = misJugadas.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.distribucionAciertosTitulo,
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(l10n.tusJugadasGuardadasParentesis, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54)),
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
                        Text(totalJugadas == 1 ? l10n.jugadaSingular : l10n.jugadasPlural, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white54)),
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
                    _buildDonutLegendItem(Colors.grey, l10n.ceroAciertos, "${distribucionAciertos[0]}"),
                    _buildDonutLegendItem(Colors.blueAccent, l10n.unoDosAciertos, "${distribucionAciertos[1] + distribucionAciertos[2]}"),
                    _buildDonutLegendItem(Colors.amber, l10n.tresCuatroAciertos, "${distribucionAciertos[3] + distribucionAciertos[4]}"),
                    _buildDonutLegendItem(Colors.greenAccent, l10n.cincoAciertos, "${distribucionAciertos[5]}"),
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
                        ? l10n.distribucionCalculada(totalJugadas)
                        : l10n.agregaJugadasDistribucion,
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
    final l10n = AppLocalizations.of(context)!;
    final double avg = historialCoberturasList.isNotEmpty
        ? historialCoberturasList.reduce((a, b) => a + b) / historialCoberturasList.length
        : 0.8;
    final double maxCov = historialCoberturasList.isNotEmpty
        ? historialCoberturasList.reduce(math.max)
        : 0.8;
    final double minCov = historialCoberturasList.isNotEmpty
        ? historialCoberturasList.reduce(math.min)
        : 0.4;

    double range = maxCov - minCov;
    if (range <= 0) range = maxCov > 0 ? maxCov * 0.2 : 0.2;

    final double paddingY = range * 0.15;
    final double dynamicMinY = math.max(0.0, ((minCov - paddingY) * 100).floorToDouble() / 100);
    final double dynamicMaxY = math.min(1.0, ((maxCov + paddingY) * 100).ceilToDouble() / 100);

    final double span = dynamicMaxY - dynamicMinY;
    final double stepY = span <= 0.25
        ? 0.05
        : (span <= 0.50 ? 0.10 : 0.20);

    Widget buildLineChart({bool isFullScreen = false}) {
      return SizedBox(
        height: isFullScreen ? double.infinity : 200,
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
                        const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold),
                      );
                    }).toList();
                  },
                ),
              ),
              minY: dynamicMinY,
              maxY: dynamicMaxY,
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
                    reservedSize: 42,
                    interval: stepY,
                    getTitlesWidget: (value, meta) {
                      if (value < dynamicMinY - 0.001 || value > dynamicMaxY + 0.001) {
                        return const SizedBox.shrink();
                      }
                      final intVal = (value * 100).round();
                      return Text(
                        "$intVal%",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      );
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
                              color: Colors.white70,
                              fontSize: 10,
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
                  color: const Color(0xFFFFC107),
                  barWidth: isFullScreen ? 4 : 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3.5,
                        color: const Color(0xFFFFC107),
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

    final String titleStr = l10n.historialCoberturaTitulo;
    final String subtitleStr = l10n.promedioGeneralSorteos((avg * 100).round(), historialCoberturasList.length);

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
                      titleStr,
                      style: GoogleFonts.montserrat(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleStr,
                      style: GoogleFonts.montserrat(fontSize: 11.5, color: const Color(0xFFFFC107), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  FullScreenChartViewer.show(
                    context,
                    title: titleStr,
                    subtitle: subtitleStr,
                    chartWidget: buildLineChart(isFullScreen: true),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.open_in_full, color: Color(0xFFFFC107), size: 18),
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

  Widget _buildRachaActualCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardBoxDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.rachaActualTitulo,
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text("🔥", style: TextStyle(fontSize: 32)),
          Text(
            "$rachaActualCount",
            style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          Text(
            l10n.jugadasConsecutivasAciertos,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Text(l10n.mejorRachaTitulo, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white38)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("$mejorRachaCount ", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
              Text(
                mejorRachaCount == 1 ? l10n.jugadaSingular : l10n.jugadasPlural,
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
