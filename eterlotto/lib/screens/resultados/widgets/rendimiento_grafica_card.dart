import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import '../../../widgets/fullscreen_chart_viewer.dart';
import 'resultados_shared.dart';

class RendimientoGraficaCard extends StatelessWidget {
  final Map<String, List<double>> historialCoberturasPorSorteo;

  const RendimientoGraficaCard({
    super.key,
    required this.historialCoberturasPorSorteo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final series = historialCoberturasPorSorteo.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();
    final coberturas = series.expand((entry) => entry.value).toList();

    if (coberturas.isEmpty) {
      return const SizedBox.shrink();
    }

    final double avg = coberturas.reduce((a, b) => a + b) / coberturas.length;
    final double maxCov = coberturas.reduce(math.max);
    final double minCov = coberturas.reduce(math.min);
    final maxPuntos = series.fold<int>(
      0,
      (maximo, entry) =>
          entry.value.length > maximo ? entry.value.length : maximo,
    );

    Color colorDeSerie(int index) {
      const palette = [
        Color(0xFFFFC107), // Ámbar / Oro
        Color(0xFFC084FC), // Morado pastel
        Color(0xFF2DD4BF), // Turquesa
        Color(0xFFFB923C), // Naranja
        Color(0xFF60A5FA), // Azul cielo
        Color(0xFFF472B6), // Rosa
        Color(0xFFA3E635), // Verde lima
      ];
      if (index < palette.length) return palette[index];
      return HSVColor.fromAHSV(
        1,
        (index * 137.508) % 360,
        0.72,
        0.98,
      ).toColor();
    }

    double range = maxCov - minCov;
    if (range <= 0) range = maxCov > 0 ? maxCov * 0.2 : 0.2;

    final double paddingY = range * 0.15;
    final double dynamicMinY = math.max(
      0.0,
      ((minCov - paddingY) * 100).floorToDouble() / 100,
    );
    final double dynamicMaxY = math.min(
      1.0,
      ((maxCov + paddingY) * 100).ceilToDouble() / 100,
    );

    final double span = dynamicMaxY - dynamicMinY;
    final double stepY = span <= 0.25 ? 0.05 : (span <= 0.50 ? 0.10 : 0.20);

    Widget buildLineChart({bool isFullScreen = false}) {
      final chart = Padding(
        padding: const EdgeInsets.only(
          right: 16.0,
          top: 12.0,
          bottom: 8.0,
          left: 8.0,
        ),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                  return touchedSpots.map((touchedSpot) {
                    final serie = series[touchedSpot.barIndex];
                    final valor = (touchedSpot.y * 100).round();
                    return LineTooltipItem(
                      '${serie.key}: $valor%',
                      TextStyle(
                        color: colorDeSerie(touchedSpot.barIndex),
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            minY: dynamicMinY,
            maxY: dynamicMaxY,
            minX: 1,
            maxX: math.max(2, maxPuntos).toDouble(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  interval: stepY,
                  getTitlesWidget: (value, meta) {
                    if (value < dynamicMinY - 0.001 ||
                        value > dynamicMaxY + 0.001) {
                      return const SizedBox.shrink();
                    }
                    final intVal = (value * 100).round();
                    return Text(
                      '$intVal%',
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
                    if ((value - intVal).abs() > 0.001 ||
                        intVal < 1 ||
                        intVal > maxPuntos) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '$intVal',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: List.generate(series.length, (serieIndex) {
              final serie = series[serieIndex];
              final color = colorDeSerie(serieIndex);
              return LineChartBarData(
                spots: List.generate(
                  serie.value.length,
                  (index) => FlSpot((index + 1).toDouble(), serie.value[index]),
                ),
                isCurved: true,
                preventCurveOverShooting: true,
                color: color,
                barWidth: isFullScreen ? 4 : 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 3.5,
                        color: color,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                ),
              );
            }),
          ),
        ),
      );
      return isFullScreen ? chart : SizedBox(height: 190, child: chart);
    }

    Widget buildLeyenda() {
      return Wrap(
        spacing: 12,
        runSpacing: 6,
        children: List.generate(series.length, (index) {
          final serie = series[index];
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: colorDeSerie(index),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  serie.key,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        }),
      );
    }

    final String titleStr = l10n.rendimientoUltimosSorteos(maxPuntos);
    final String subtitleStr = l10n.promedioGeneralSorteos(
      (avg * 100).round(),
      maxPuntos,
    );

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
                      style: GoogleFonts.montserrat(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleStr,
                      style: GoogleFonts.montserrat(
                        fontSize: 11.5,
                        color: const Color(0xFFFFC107),
                        fontWeight: FontWeight.w600,
                      ),
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
                    chartWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (series.length > 1) ...[
                          buildLeyenda(),
                          const SizedBox(height: 12),
                        ],
                        Expanded(child: buildLineChart(isFullScreen: true)),
                      ],
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          if (series.length > 1) ...[
            const SizedBox(height: 10),
            buildLeyenda(),
          ],
          const SizedBox(height: 10),
          buildLineChart(),
        ],
      ),
    );
  }
}
