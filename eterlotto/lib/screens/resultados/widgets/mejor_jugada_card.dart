import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'resultados_shared.dart';

class MejorJugadaCard extends StatelessWidget {
  final List<Map<String, dynamic>> misJugadas;
  final List<SubSorteoData> subSorteos;
  final int maxSeleccion;
  final VoidCallback? onCrearJugada;

  const MejorJugadaCard({
    super.key,
    required this.misJugadas,
    required this.subSorteos,
    required this.maxSeleccion,
    this.onCrearJugada,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (misJugadas.isEmpty) {
      return const SizedBox.shrink();
    }

    // Identificar la mejor jugada y en qué sub-sorteo tuvo su pico
    Map<String, dynamic>? bestPlay;
    SubSorteoData? bestSub;
    int maxHits = -1;
    bool bestRedHit = false;
    double bestPercent = 0.0;
    List<int> playHitCounts = [];

    for (final jugada in misJugadas) {
      final nums = (jugada["nums"] as List)
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .toList();
      final red = jugada["red"] as int?;

      int playMaxHits = 0;
      bool playBestRedHit = false;
      SubSorteoData? playBestSub;

      for (final sub in subSorteos) {
        final hits = nums.where((n) => sub.winningNums.contains(n)).length;
        final bool redHit = (red != null && red == sub.winningRed);

        // Ponderar aciertos principales y desempate por balota roja
        if (hits > playMaxHits || (hits == playMaxHits && redHit && !playBestRedHit)) {
          playMaxHits = hits;
          playBestRedHit = redHit;
          playBestSub = sub;
        }
      }

      playHitCounts.add(playMaxHits);

      if (playMaxHits > maxHits || (playMaxHits == maxHits && playBestRedHit && !bestRedHit)) {
        maxHits = playMaxHits;
        bestRedHit = playBestRedHit;
        bestPlay = jugada;
        bestSub = playBestSub ?? (subSorteos.isNotEmpty ? subSorteos.first : null);
      }
    }

    // Solo se muestra si hubo al menos un acierto en balotas principales o balota especial
    if (bestPlay == null || bestSub == null || (maxHits <= 0 && !bestRedHit)) {
      return const SizedBox.shrink();
    }

    final int totalBalotas = maxSeleccion > 0
        ? maxSeleccion
        : (bestSub.winningNums.isNotEmpty ? bestSub.winningNums.length : 5);
    bestPercent = totalBalotas > 0
        ? ((maxHits / totalBalotas) * 100).clamp(0.0, 100.0)
        : 0.0;

    final bestNums = (bestPlay["nums"] as List)
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .toList();
    final int? bestRed = bestPlay["red"] as int?;
    final String playTitle = bestPlay["titulo"]?.toString() ?? "Jugada #1";

    // Calcular percentil comparativo con otras jugadas del usuario
    String insightText = l10n.tuMejorJugadaSorteo;
    if (misJugadas.length > 1) {
      final int lowerPlays = playHitCounts.where((h) => h < maxHits).length;
      final int percentile = ((lowerPlays / (misJugadas.length - 1)) * 100).round();
      if (percentile > 0) {
        insightText = l10n.superoRendimientoJugadas(percentile);
      }
    }

    final Color accentColor = bestPercent >= 60
        ? Colors.greenAccent
        : (bestPercent >= 30 ? Colors.amber : const Color(0xFFFFC107));

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header con Trofeo y Sub-sorteo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("🏆", style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    l10n.mejorJugadaTitulo,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              if (subSorteos.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: bestSub.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: bestSub.color.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    bestSub.nombre,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: bestSub.color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Título de la Jugada y Aciertos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                playTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              Text(
                l10n.aciertosConPorcentaje(maxHits, totalBalotas, bestPercent.round()),
                style: GoogleFonts.montserrat(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Fila de Balotas con aciertos destacados (centrada)
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ...bestNums.map((n) {
                  final isHit = bestSub!.winningNums.contains(n);
                  return buildPlayBall(n, isHit: isHit);
                }),
                if (bestRed != null)
                  buildPlayBall(
                    bestRed,
                    isHit: (bestRed == bestSub.winningRed),
                    isRed: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Badge Comparativo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              insightText,
              style: GoogleFonts.montserrat(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
