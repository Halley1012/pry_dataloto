import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ResultadosTabSelector extends StatelessWidget {
  final bool hasRevanchaData;
  final int selectedResultadosTab;
  final String nombreSorteoPrincipal;
  final String nombreSorteoSecundario;
  final ValueChanged<int> onTabChanged;

  const ResultadosTabSelector({
    Key? key,
    required this.hasRevanchaData,
    required this.selectedResultadosTab,
    required this.nombreSorteoPrincipal,
    required this.nombreSorteoSecundario,
    required this.onTabChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!hasRevanchaData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1116),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selectedResultadosTab == 0 ? Colors.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    nombreSorteoPrincipal,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selectedResultadosTab == 0 ? Colors.black : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selectedResultadosTab == 1 ? Colors.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    nombreSorteoSecundario,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selectedResultadosTab == 1 ? Colors.black : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
