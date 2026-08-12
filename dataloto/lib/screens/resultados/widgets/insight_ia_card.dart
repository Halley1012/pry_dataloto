import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InsightIaCard extends StatelessWidget {
  final String insightIAText;
  final String selectedLoteria;
  final int probablesCount;
  final double coberturaPorcentaje;
  final List<int> winningNums;
  final String fechaSorteo;

  const InsightIaCard({
    Key? key,
    required this.insightIAText,
    required this.selectedLoteria,
    required this.probablesCount,
    required this.coberturaPorcentaje,
    required this.winningNums,
    required this.fechaSorteo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = insightIAText.isNotEmpty
        ? insightIAText
        : "De los $probablesCount números con mayor probabilidad generados por la IA para $selectedLoteria, cayeron ${(coberturaPorcentaje * winningNums.length).round()} números.";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141A1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF064E3B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.show_chart, color: Colors.greenAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("💡", style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      "Insights IA",
                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), height: 1.3),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fechaSorteo, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
