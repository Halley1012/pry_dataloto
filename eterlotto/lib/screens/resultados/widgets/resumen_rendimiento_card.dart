import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'resultados_shared.dart';

class ResumenRendimientoCard extends StatelessWidget {
  final Map<String, List<double>> historialCoberturasPorSorteo;

  const ResumenRendimientoCard({
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
    final int maxPuntos = series.fold<int>(
      0,
      (maximo, entry) =>
          entry.value.length > maximo ? entry.value.length : maximo,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("📊", style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    l10n.tuRendimiento,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.nSorteosLabel(maxPuntos),
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  title: l10n.coberturaPromedio,
                  value: "${(avg * 100).round()}%",
                  color: Colors.amber,
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  title: l10n.mejorCobertura,
                  value: "${(maxCov * 100).round()}%",
                  color: Colors.greenAccent,
                  icon: Icons.arrow_upward,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  title: l10n.peorCobertura,
                  value: "${(minCov * 100).round()}%",
                  color: const Color(0xFFFB923C),
                  icon: Icons.arrow_downward,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}
