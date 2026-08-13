import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    Key? key,
    required this.selectedLoteria,
    required this.misJugadas,
    required this.winningNums,
    this.winningRed,
    required this.hasRevanchaData,
    required this.winningNumsRevancha,
    this.winningRedRevancha,
    required this.nombreSorteoPrincipal,
    required this.nombreSorteoSecundario,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                "Comparación Mis Jugadas vs Resultado",
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
                      _buildDotLegend(Colors.greenAccent, "Aciertos"),
                      _buildDotLegend(Colors.redAccent, "Balota"),
                      _buildDotLegend(Colors.white38, "Sin acierto"),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Tus jugadas guardadas vs Números ganadores del sorteo",
            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 12),

          // Lista de Jugadas del usuario con resaltado de coincidencias
          if (misJugadas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  "Aún no tienes jugadas guardadas para esta lotería.",
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            titulo,
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                          if (hasRevanchaData)
                            Row(
                              children: [
                                Text(
                                  "$nombreSorteoPrincipal: $hitsCountBaloto",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: hitsCountBaloto > 0 ? Colors.greenAccent : Colors.white38,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "$nombreSorteoSecundario: $hitsCountRev",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: hitsCountRev > 0 ? Colors.greenAccent : Colors.white38,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              "$hitsCountBaloto acierto(s)",
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
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
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
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
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
                          ],
                        ),
                      ] else ...[
                        // Fila estándar si no hay Revancha
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
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
}
