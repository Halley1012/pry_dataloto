import 'package:flutter/material.dart';

class LotteryAvatar3D extends StatelessWidget {
  final String nombre;
  final double size;

  const LotteryAvatar3D({
    super.key,
    required this.nombre,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "?";
    final n = nombre.toLowerCase().trim();

    Color baseColor;
    Color topColor;

    if (n.contains("baloto")) {
      baseColor = const Color(0xFFFFB300); // Amber Dorado 3D
      topColor = const Color(0xFFFFF59D);
    } else if (n.contains("colorloto")) {
      baseColor = const Color(0xFFE91E63); // Neon Magenta 3D
      topColor = const Color(0xFFF8BBD0);
    } else if (n.contains("miloto")) {
      baseColor = const Color(0xFF00E5FF); // Electric Cyan 3D
      topColor = const Color(0xFFE0F7FA);
    } else if (n.contains("powerball")) {
      baseColor = const Color(0xFFFF1744); // Crimson Red 3D
      topColor = const Color(0xFFFFCDD2);
    } else if (n.contains("mega millions")) {
      baseColor = const Color(0xFFFFC400); // Gold 3D
      topColor = const Color(0xFFFFF9C4);
    } else if (n.contains("lotto america")) {
      baseColor = const Color(0xFF3D5AFE); // Royal Blue 3D
      topColor = const Color(0xFFC5CAE9);
    } else if (n.contains("double play")) {
      baseColor = const Color(0xFFFF3D00); // Coral Orange 3D
      topColor = const Color(0xFFFFCCBC);
    } else if (n.contains("millionaire")) {
      baseColor = const Color(0xFF00E676); // Emerald Green 3D
      topColor = const Color(0xFFC8E6C9);
    } else {
      final colors = [
        const Color(0xFFFF1744),
        const Color(0xFF00E5FF),
        const Color(0xFFFFB300),
        const Color(0xFFE91E63),
        const Color(0xFF7C4DFF),
        const Color(0xFF00E676),
        const Color(0xFFFF3D00),
      ];
      final index = initial.codeUnitAt(0) % colors.length;
      baseColor = colors[index];
      topColor = Colors.white;
    }

    final isLightText = !(n.contains("baloto") || n.contains("mega millions"));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.85,
          colors: [
            topColor,
            baseColor,
            Color.lerp(baseColor, Colors.black, 0.6)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(1, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: isLightText ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.44,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
