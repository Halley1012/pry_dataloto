import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'resultados_shared.dart';

class MisJugadasCard extends StatelessWidget {
  final String selectedLoteria;
  final List<Map<String, dynamic>> misJugadas;
  final List<SubSorteoData> subSorteos;

  const MisJugadasCard({
    super.key,
    required this.selectedLoteria,
    required this.misJugadas,
    required this.subSorteos,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool hasMultipleDraws = subSorteos.length > 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header sin overflow
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.comparacionJugadas,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "",
                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildDotLegend(Colors.greenAccent, l10n.aciertosLabel),
                      _buildDotLegend(Colors.redAccent, l10n.balotaLabel),
                      _buildDotLegend(Colors.white38, l10n.sinAciertoLabel),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.tusJugadasVsGanadores,
            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 12),

          // Lista de Jugadas del usuario con resaltado de coincidencias
          if (misJugadas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  l10n.noRealizasteJugadas,
                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white38, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            Column(
              children: misJugadas.map((jugada) {
                final nums = (jugada["nums"] as List).map((e) => int.tryParse(e.toString()) ?? 0).toList();
                final red = jugada["red"] as int?;
                final titulo = jugada["titulo"]?.toString() ?? "Jugada";

                int maxHitsAcrossAll = 0;
                bool anyRedHit = false;

                final List<Map<String, dynamic>> drawStats = subSorteos.map((sub) {
                  int hits = nums.where((n) => sub.winningNums.contains(n)).length;
                  bool redHit = (red != null && red == sub.winningRed);
                  if (hits > maxHitsAcrossAll) maxHitsAcrossAll = hits;
                  if (redHit) anyRedHit = true;
                  return {
                    "sub": sub,
                    "hits": hits,
                    "redHit": redHit,
                  };
                }).toList();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1E27),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: maxHitsAcrossAll >= 3 ? Colors.amber.withValues(alpha: 0.4) : Colors.white10,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado de la Jugada
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              titulo,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (hasMultipleDraws)
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              alignment: WrapAlignment.end,
                              children: drawStats.map((stat) {
                                final SubSorteoData sub = stat["sub"];
                                final int hits = stat["hits"];
                                final bool redHit = stat["redHit"];
                                return Text(
                                  "${sub.nombre}: ${l10n.cantidadAciertos(hits)}${_getHitsEmoji(hits, redHit, red != null, sub.winningNums.length)}",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: hits > 0 ? Colors.greenAccent : Colors.white38,
                                  ),
                                );
                              }).toList(),
                            )
                          else if (drawStats.isNotEmpty)
                            Text(
                              "${l10n.cantidadAciertos(drawStats.first["hits"])}${_getHitsEmoji(drawStats.first["hits"], drawStats.first["redHit"], red != null, subSorteos.first.winningNums.length)}",
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: drawStats.first["hits"] > 0 ? Colors.greenAccent : Colors.white38,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Filas de cada sub-sorteo
                      ...subSorteos.asMap().entries.map((entry) {
                        final int idx = entry.key;
                        final SubSorteoData sub = entry.value;
                        final bool redHit = (red != null && red == sub.winningRed);

                        return Padding(
                          padding: EdgeInsets.only(bottom: idx < subSorteos.length - 1 ? 8.0 : 0.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 75,
                                child: Text(
                                  hasMultipleDraws ? sub.nombre : selectedLoteria,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: sub.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ...nums.map((n) {
                                          final isHit = sub.winningNums.contains(n);
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 3),
                                            child: buildPlayBall(n, isHit: isHit),
                                          );
                                        }),
                                        if (red != null) ...[
                                          const SizedBox(width: 6),
                                          buildPlayBall(red, isHit: redHit, isRed: true),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (_buildFeedbackBanner(maxHitsAcrossAll, anyRedHit, red != null, selectedLoteria, subSorteos.isNotEmpty ? subSorteos.first.winningNums.length : 6) != null) ...[
                        const SizedBox(height: 10),
                        _buildFeedbackBanner(maxHitsAcrossAll, anyRedHit, red != null, selectedLoteria, subSorteos.isNotEmpty ? subSorteos.first.winningNums.length : 6)!,
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDotLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white60)),
      ],
    );
  }

  String _getHitsEmoji(int hits, bool redHit, bool hasRedBall, [int totalBalls = 5]) {
    final int maxBalls = totalBalls > 0 ? totalBalls : 5;
    final isJackpot = (hits >= maxBalls && (!hasRedBall || redHit));
    if (isJackpot) return " 🏆";
    if (hits >= maxBalls) return " 🌟";
    if (hits == maxBalls - 1) return " ✨";
    if (hits >= maxBalls - 2 && hits >= 3) return " 👍";
    return "";
  }

  Widget? _buildFeedbackBanner(int hits, bool redHit, bool hasRedBall, String drawName, [int totalBalls = 5]) {
    String? message;
    IconData? icon;
    Color? color;

    final int maxBalls = totalBalls > 0 ? totalBalls : 5;
    final isJackpot = (hits >= maxBalls && (!hasRedBall || redHit));

    if (isJackpot) {
      message = "¡Felicidades! Eres el ganador del Premio Mayor de $drawName 🏆🎉";
      icon = Icons.emoji_events;
      color = Colors.amber;
    } else if (hits >= maxBalls) {
      message = "¡Increíble! Acertaste $hits números en $drawName 🥳🌟";
      icon = Icons.star;
      color = Colors.amberAccent;
    } else if (hits == maxBalls - 1) {
      message = "¡Excelente! Acertaste $hits números en $drawName 👏✨";
      icon = Icons.thumb_up;
      color = Colors.greenAccent;
    } else if (hits >= maxBalls - 2 && hits >= 3) {
      message = "¡Buen intento! Acertaste $hits números en $drawName. ¡Sigue así! 👍";
      icon = Icons.sentiment_satisfied_alt;
      color = Colors.blueAccent;
    } else {
      return null;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
