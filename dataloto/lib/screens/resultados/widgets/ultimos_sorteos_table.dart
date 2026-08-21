import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';
import 'resultados_shared.dart';

class UltimosSorteosTable extends StatelessWidget {
  final String subTitulo;
  final Widget tabSelector;
  final List<Map<String, dynamic>> listToRender;

  const UltimosSorteosTable({
    Key? key,
    required this.subTitulo,
    required this.tabSelector,
    required this.listToRender,
  }) : super(key: key);

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
            children: [
              Text(
                l10n.resultados,
                style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
              Expanded(flex: 2, child: Text(l10n.fechaLabel, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38))),
              Expanded(flex: 11, child: Center(child: Text(l10n.numerosGanadores, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)))),
              Expanded(flex: 2, child: Center(child: Text(l10n.coberturaIA, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)))),
              Expanded(flex: 2, child: Align(alignment: Alignment.center
                  , child: Text(l10n.aciertosSimple, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)))),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),

          // Filas Tabla
          Column(
            children: listToRender.map((item) {
              final nums = item["nums"] as List<int>;
              final red = item["red"] as int?;
              final Color coverageColor = item["color"] as Color;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(

                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        item["fecha"].toString(),
                        style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                    ),
                    Expanded(
                      flex: 11,
                      child: Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ...nums.map((n) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                    child: buildMiniBall(n, baseColor: coverageColor, size: 19),
                                  )),
                              if (red != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                  child: buildMiniBall(red, baseColor: const Color(0xFFB91C1C), size: 19),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          item["cobertura"].toString(),
                          style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: coverageColor),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item["aciertos"].toString(),
                            style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 2),

                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
