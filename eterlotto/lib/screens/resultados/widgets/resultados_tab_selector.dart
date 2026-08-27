import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ResultadosTabSelector extends StatelessWidget {
  final List<String> sorteos;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const ResultadosTabSelector({
    super.key,
    required this.sorteos,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (sorteos.length <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1116),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: sorteos.asMap().entries.map((entry) {
          final int idx = entry.key;
          final String name = entry.value;
          final bool isSelected = selectedIndex == idx;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    name,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
