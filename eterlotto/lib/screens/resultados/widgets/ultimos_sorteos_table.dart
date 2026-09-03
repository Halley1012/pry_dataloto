import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'resultados_shared.dart';

class UltimosSorteosTable extends StatelessWidget {
  final String subTitulo;
  final Widget tabSelector;
  final List<Map<String, dynamic>> listToRender;
  final int maxSeleccion;
  final bool tieneComplementario;
  final VoidCallback? onVerMas;

  const UltimosSorteosTable({
    super.key,
    required this.subTitulo,
    required this.tabSelector,
    required this.listToRender,
    this.maxSeleccion = 5,
    this.tieneComplementario = false,
    this.onVerMas,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l10n.resultados,
                style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (onVerMas != null)
                InkWell(
                  onTap: onVerMas,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Ver más",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFFFC107),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 11,
                          color: Color(0xFFFFC107),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          tabSelector,
          Text(
            subTitulo,
            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),

          // Header Tabla
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    l10n.sorteoLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38),
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Center(
                  child: Text(l10n.numerosGanadores, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)),
                ),
              ),
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    l10n.coberturaIA,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(l10n.aciertosSimple, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),

          // Filas Tabla
          Column(
            children: listToRender.where((item) {
              final raw = (item["nums"] as List<dynamic>? ?? []);
              final p = raw.map((e) => int.tryParse(e.toString()) ?? 0).toList();
              return p.any((n) => n > 0);
            }).map((item) {
              final rawNums = (item["nums"] as List<dynamic>? ?? []);
              final nums = rawNums
                  .map((e) => int.tryParse(e.toString()) ?? -1)
                  .where((n) => n >= 0)
                  .toList();
              final rawRed = item["red"];
              final red = (rawRed != null && (int.tryParse(rawRed.toString()) ?? -1) >= 0)
                  ? int.parse(rawRed.toString())
                  : null;
              final Color coverageColor = item["color"] as Color? ?? Colors.amber;

              final bool tieneComp = tieneComplementario || (nums.length > maxSeleccion);
              final List<int> mainBalls = nums.length > maxSeleccion
                  ? nums.sublist(0, maxSeleccion)
                  : nums;
              final int? compBall = (tieneComp && nums.length > maxSeleccion)
                  ? nums.last
                  : null;

              final int totalBalls = mainBalls.length +
                  (compBall != null ? 1 : 0) +
                  (red != null ? 1 : 0);

              final double ballSize = totalBalls <= 5
                  ? 27.0
                  : (totalBalls == 6 ? 26.0 : (totalBalls == 7 ? 23.0 : 21.0));
              final double ballPadding = totalBalls <= 5
                  ? 2.0
                  : (totalBalls == 6 ? 1.8 : (totalBalls == 7 ? 1.4 : 1.0));

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          item["fecha"].toString(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 12,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ...mainBalls.map((n) => Padding(
                                    padding: EdgeInsets.symmetric(horizontal: ballPadding),
                                    child: buildMiniBall(n, baseColor: coverageColor, size: ballSize),
                                  )),
                              if (compBall != null) ...[
                                SizedBox(width: ballPadding),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: ballPadding),
                                  child: buildMiniBall(compBall, baseColor: const Color(0xFF0D9488), size: ballSize),
                                ),
                              ],
                              if (red != null) ...[
                                SizedBox(width: ballPadding),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: ballPadding),
                                  child: buildMiniBall(red, baseColor: const Color(0xFFB91C1C), size: ballSize),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          item["cobertura"].toString(),
                          style: GoogleFonts.montserrat(fontSize: 12.5, fontWeight: FontWeight.bold, color: coverageColor),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          item["aciertos"].toString(),
                          style: GoogleFonts.montserrat(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (onVerMas != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onVerMas,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.verMasResultados,
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFFFFC107),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 11,
                      color: Color(0xFFFFC107),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
