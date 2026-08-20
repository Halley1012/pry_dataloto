import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';
import 'package:dataloto/widgets/custom_dialogs.dart';
import 'resultados_shared.dart';

class CoberturaGaugeCard extends StatelessWidget {
  final bool hasRevanchaData;
  final String nombreSorteoPrincipal;
  final String nombreSorteoSecundario;
  final double coberturaPorcentaje;
  final double coberturaPorcentajeRevancha;
  final int topHitsCount;
  final int topHitsCountRevancha;
  final int probablesCount;
  final int totalWinningCount;

  const CoberturaGaugeCard({
    Key? key,
    required this.hasRevanchaData,
    required this.nombreSorteoPrincipal,
    required this.nombreSorteoSecundario,
    required this.coberturaPorcentaje,
    required this.coberturaPorcentajeRevancha,
    required this.topHitsCount,
    required this.topHitsCountRevancha,
    required this.probablesCount,
    required this.totalWinningCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardBoxDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.coberturaResultado,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              GestureDetector(
                onTap: () => showAcercaDeDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (hasRevanchaData) ...[
            // MODO DUAL: BALOTO + REVANCHA
            Row(
              children: [
                Expanded(
                  child: _buildSingleGauge(
                    context,
                    nombreSorteoPrincipal,
                    coberturaPorcentaje,
                    topHitsCount,
                    Colors.amber,
                  ),
                ),
                Container(
                  width: 1,
                  height: 110,
                  color: Colors.white12,
                ),
                Expanded(
                  child: _buildSingleGauge(
                    context,
                    nombreSorteoSecundario,
                    coberturaPorcentajeRevancha,
                    topHitsCountRevancha,
                    Colors.purpleAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.numerosEnTopIA(probablesCount),
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54),
            ),
          ] else ...[
            // MODO INDIVIDUAL NORMAL
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: coberturaPorcentaje),
              duration: const Duration(milliseconds: 1800),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                final int percentInt = (val * 100).round();
                return SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(130, 130),
                        painter: CircularGaugePainter(percentage: val),
                      ),
                      Text(
                        "$percentInt%",
                        style: GoogleFonts.montserrat(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              l10n.coberturaIndividualDetalle(topHitsCount, totalWinningCount, probablesCount),
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Text(
                coberturaPorcentaje >= 0.6 ? l10n.excelenteResultado : l10n.buenDesempeno,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleGauge(BuildContext context, String label, double val, int hits, Color color) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: val),
          duration: const Duration(milliseconds: 1800),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) {
            final int percentInt = (v * 100).round();
            return SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(100, 100),
                    painter: CircularGaugePainter(percentage: v, activeColor: color),
                  ),
                  Text(
                    "$percentInt%",
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          l10n.hitsDeAciertos(hits, totalWinningCount),
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }
}
