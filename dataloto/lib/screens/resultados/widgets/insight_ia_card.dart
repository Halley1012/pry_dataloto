import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InsightIaCard extends StatelessWidget {
  final String insightIAText;
  final String selectedLoteria;
  final int probablesCount;
  final double coberturaPorcentaje;
  final List<int> winningNums;
  final int? winningRed;
  final String fechaSorteo;
  final List<int>? predictionNumeros;
  final List<int>? predictionBalotaroja;

  const InsightIaCard({
    Key? key,
    required this.insightIAText,
    required this.selectedLoteria,
    required this.probablesCount,
    required this.coberturaPorcentaje,
    required this.winningNums,
    this.winningRed,
    required this.fechaSorteo,
    this.predictionNumeros,
    this.predictionBalotaroja,
  }) : super(key: key);

  int _getTopLimit() {
    final lower = selectedLoteria.toLowerCase();
    if (lower.contains("powerball")) return 34;
    if (lower.contains("megamillions") || lower.contains("mega millions")) return 35;
    if (lower.contains("double play") || lower.contains("double_play")) return 34;
    if (lower.contains("lotto america") || lower.contains("lotto_america")) return 26;
    if (lower.contains("millionaire") || lower.contains("millionaire_life")) return 29;
    if (lower.contains("miloto") || lower.contains("mloto")) return 20;
    if (lower.contains("colorloto")) return 10;
    return 21; // Default/Baloto
  }

  Widget _build3DBall(int? numero, {Color baseColor = const Color(0xFFF33A21), double size = 45}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            baseColor.withValues(alpha: 0.95),
            baseColor.withValues(alpha: 0.8),
            baseColor.withValues(alpha: 0.6),
          ],
          center: Alignment.topLeft, radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), offset: const Offset(3, 3), blurRadius: 6),
          BoxShadow(color: baseColor.withValues(alpha: 0.4), offset: const Offset(-2, -2), blurRadius: 4),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "",
          style: TextStyle(
            fontSize: size * 0.4, fontWeight: FontWeight.bold, color: Colors.white,
            shadows: numero != null ? [Shadow(color: Colors.black.withValues(alpha: 0.6), offset: const Offset(1, 1), blurRadius: 2)] : null,
          ),
        ),
      ),
    );
  }

  void _showProbablesDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Tendencias IA",
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final limit = _getTopLimit();
        final hasSpecial = predictionBalotaroja != null && predictionBalotaroja!.isNotEmpty;
        final screenWidth = MediaQuery.of(context).size.width;
        final crossAxisCount = 10;
        final double spacing = screenWidth < 360 ? 4.0 : 6.0;
        // El diálogo tiene un padding de 16 a los costados y 20 interno.
        final availableWidth = screenWidth - 32.0 - 40.0;
        final double ballSize = ((availableWidth - (spacing * 9)) / 10).floorToDouble();

        final scaleValue = anim1.value;
        final opacityValue = anim1.value;

        return Transform.scale(
          scale: 0.85 + (scaleValue * 0.15),
          child: Opacity(
            opacity: opacityValue,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 580),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1E1E), Color(0xFF2C2F38)],
                    transform: GradientRotation(12),
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "Tendencias IA - $selectedLoteria",
                              style: GoogleFonts.montserrat(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Sorteo del $fechaSorteo",
                            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white38),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Acierto IA",
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Mostrar los números que cayeron (Resultado real)
                      Row(
                        children: [
                          Text(
                            "Resultado real: ",
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ...winningNums.map((num) {
                            final isHit = predictionNumeros?.contains(num) ?? false;
                            final baseColor = isHit ? Colors.amber : const Color(0xFF607D8B);
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: _build3DBall(
                                num,
                                baseColor: baseColor,
                                size: 26,
                              ),
                            );
                          }).toList(),
                          if (winningRed != null) ...[
                            const SizedBox(width: 4),
                            _build3DBall(
                              winningRed,
                              baseColor: Colors.redAccent,
                              size: 26,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Balotas Principales",
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Números ordenados de mayor a menor probabilidad.",
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  color: Colors.white38,
                                ),
                              ),
                              SizedBox(height: 0),
                              predictionNumeros == null || predictionNumeros!.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                                      child: Text(
                                        "No hay tendencias detalladas guardadas para este sorteo.",
                                        style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54),
                                      ),
                                    )
                                  : GridView.count(
                                      crossAxisCount: crossAxisCount,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: spacing,
                                      mainAxisSpacing: spacing,
                                      children: predictionNumeros!.asMap().entries.map((entry) {
                                        int index = entry.key;
                                        int num = entry.value;
                                        final isHit = winningNums.contains(num);
                                        
                                        Color baseColor = isHit
                                            ? Colors.amber
                                            : (index < limit ? Colors.redAccent : const Color(0xFF607D8B));
                                        
                                        return _build3DBall(
                                          num,
                                          baseColor: baseColor,
                                          size: ballSize,
                                        );
                                      }).toList(),
                                    ),
                              if (hasSpecial) ...[
                                const SizedBox(height: 10),
                                Text(
                                  "Balotas Rojas / Especiales",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Números ordenados de mayor a menor probabilidad.",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    color: Colors.white38,
                                  ),
                                ),
                                SizedBox(height: 0),
                                GridView.count(
                                  crossAxisCount: crossAxisCount,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: spacing,
                                  mainAxisSpacing: spacing,
                                  children: predictionBalotaroja!.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    int num = entry.value;
                                    final isHit = winningRed == num;
                                    Color baseColor = isHit
                                        ? Colors.amber
                                        : Colors.redAccent;
                                    
                                    return _build3DBall(
                                      num,
                                      baseColor: baseColor,
                                      size: ballSize,
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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
                    GestureDetector(
                      onTap: () => _showProbablesDialog(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                    ),
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
