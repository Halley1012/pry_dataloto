import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
                "Resultados",
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
              Expanded(flex: 3, child: Text("Fecha", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38))),
              Expanded(flex: 7, child: Center(child: Text("Números ganadores", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)))),
              Expanded(flex: 3, child: Center(child: Text("Cobertura IA", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)))),
              Expanded(flex: 3, child: Align(alignment: Alignment.center
                  , child: Text("Aciertos", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)))),
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
                      flex: 3,
                      child: Text(
                        item["fecha"].toString(),
                        style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ...nums.map((n) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                    child: buildMiniBall(n, baseColor: coverageColor, size: 20),
                                  )),
                              if (red != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                  child: buildMiniBall(red, baseColor: const Color(0xFFB91C1C), size: 20),
                                ),
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
                          style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: coverageColor),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
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
