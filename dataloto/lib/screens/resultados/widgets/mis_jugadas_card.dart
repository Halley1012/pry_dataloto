import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';
import 'resultados_shared.dart';

class MisJugadasCard extends StatelessWidget {
  final String selectedLoteria;
  final List<Map<String, dynamic>> misJugadas;
  final List<int> winningNums;
  final int? winningRed;
  final bool hasRevanchaData;
  final List<int> winningNumsRevancha;
  final int? winningRedRevancha;
  final String nombreSorteoPrincipal;
  final String nombreSorteoSecundario;

  const MisJugadasCard({
    super.key,
    required this.selectedLoteria,
    required this.misJugadas,
    required this.winningNums,
    this.winningRed,
    required this.hasRevanchaData,
    required this.winningNumsRevancha,
    this.winningRedRevancha,
    required this.nombreSorteoPrincipal,
    required this.nombreSorteoSecundario,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                final nums = jugada["nums"] as List<int>;
                final red = jugada["red"] as int?;
                final titulo = jugada["titulo"].toString();

                int hitsCountBaloto = nums.where((n) => winningNums.contains(n)).length;
                bool redHitBaloto = (red != null && red == winningRed);

                int hitsCountRev = hasRevanchaData ? nums.where((n) => winningNumsRevancha.contains(n)).length : 0;
                bool redHitRev = hasRevanchaData && (red != null && red == winningRedRevancha);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1E27),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (hitsCountBaloto >= 3 || hitsCountRev >= 3) ? Colors.amber.withValues(alpha: 0.4) : Colors.white10,
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
                          if (hasRevanchaData)
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              alignment: WrapAlignment.end,
                              children: [
                                Text(
                                  "$nombreSorteoPrincipal: ${l10n.cantidadAciertos(hitsCountBaloto)}${_getHitsEmoji(hitsCountBaloto, redHitBaloto, red != null)}",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: hitsCountBaloto > 0 ? Colors.greenAccent : Colors.white38,
                                  ),
                                ),
                                Text(
                                  "$nombreSorteoSecundario: ${l10n.cantidadAciertos(hitsCountRev)}${_getHitsEmoji(hitsCountRev, redHitRev, red != null)}",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: hitsCountRev > 0 ? Colors.greenAccent : Colors.white38,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              "${l10n.cantidadAciertos(hitsCountBaloto)}${_getHitsEmoji(hitsCountBaloto, redHitBaloto, red != null)}",
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: hitsCountBaloto > 0 ? Colors.greenAccent : Colors.white38,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (hasRevanchaData) ...[
                        // Fila Baloto
                        Row(
                          children: [
                            SizedBox(
                              width: 65,
                              child: Text(
                                nombreSorteoPrincipal,
                                style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
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
                                        final isHit = winningNums.contains(n);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                          child: buildPlayBall(n, isHit: isHit),
                                        );
                                      }),
                                      if (red != null) ...[
                                        const SizedBox(width: 6),
                                        buildPlayBall(red, isHit: redHitBaloto, isRed: true),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Fila Revancha
                        Row(
                          children: [
                            SizedBox(
                              width: 65,
                              child: Text(
                                nombreSorteoSecundario,
                                style: GoogleFonts.montserrat(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.w500),
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
                                        final isHit = winningNumsRevancha.contains(n);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                          child: buildPlayBall(n, isHit: isHit),
                                        );
                                      }),
                                      if (red != null) ...[
                                        const SizedBox(width: 6),
                                        buildPlayBall(red, isHit: redHitRev, isRed: true),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Fila estándar si no hay Revancha
                        Row(
                          children: [
                            SizedBox(
                              width: 65,
                              child: Text(
                                selectedLoteria,
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
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
                                        final isHit = winningNums.contains(n);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                          child: buildPlayBall(n, isHit: isHit),
                                        );
                                      }),
                                      if (red != null) ...[
                                        const SizedBox(width: 6),
                                        buildPlayBall(red, isHit: redHitBaloto, isRed: true),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (hasRevanchaData) ...[
                        if (_buildFeedbackBanner(hitsCountBaloto, redHitBaloto, red != null, nombreSorteoPrincipal) != null)
                          _buildFeedbackBanner(hitsCountBaloto, redHitBaloto, red != null, nombreSorteoPrincipal)!,
                        if (_buildFeedbackBanner(hitsCountRev, redHitRev, red != null, nombreSorteoSecundario) != null)
                          _buildFeedbackBanner(hitsCountRev, redHitRev, red != null, nombreSorteoSecundario)!,
                      ] else ...[
                        if (_buildFeedbackBanner(hitsCountBaloto, redHitBaloto, red != null, selectedLoteria) != null)
                          _buildFeedbackBanner(hitsCountBaloto, redHitBaloto, red != null, selectedLoteria)!,
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

  String _getHitsEmoji(int hits, bool redHit, bool hasRedBall) {
    final isJackpot = (hits == 5 && (!hasRedBall || redHit));
    if (isJackpot) return " 🏆";
    if (hits == 5) return " 🌟";
    if (hits == 4) return " ✨";
    if (hits == 3) return " 👍";
    return "";
  }

  Widget? _buildFeedbackBanner(int hits, bool redHit, bool hasRedBall, String drawName) {
    String? message;
    IconData? icon;
    Color? color;

    final isJackpot = (hits == 5 && (!hasRedBall || redHit));

    if (isJackpot) {
      message = "¡Felicidades! Eres el ganador del Premio Mayor de $drawName 🏆🎉";
      icon = Icons.emoji_events;
      color = Colors.amber;
    } else if (hits == 5) {
      message = "¡Increíble! Acertaste 5 números en $drawName 🥳🌟";
      icon = Icons.star;
      color = Colors.amberAccent;
    } else if (hits == 4) {
      message = "¡Excelente! Acertaste 4 números en $drawName 👏✨";
      icon = Icons.thumb_up;
      color = Colors.greenAccent;
    } else if (hits == 3) {
      message = "¡Buen intento! Acertaste 3 números en $drawName. ¡Sigue así! 👍";
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
