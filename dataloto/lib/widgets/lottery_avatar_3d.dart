import 'package:flutter/material.dart';

class LotteryAvatar3D extends StatelessWidget {
  final String nombre;
  final double size;
  final Color? customColor;

  const LotteryAvatar3D({
    super.key,
    required this.nombre,
    this.size = 46,
    this.customColor,
  });

  static const List<Color> _palette = [
    Color(0xFFFFB300), // Amber Gold
    Color(0xFF00E5FF), // Electric Cyan
    Color(0xFFFF1744), // Crimson Red
    Color(0xFFE91E63), // Magenta
    Color(0xFF00E676), // Emerald Green
    Color(0xFF7C4DFF), // Purple
    Color(0xFFFF3D00), // Coral Orange
    Color(0xFF3D5AFE), // Royal Blue
    Color(0xFF00B0FF), // Light Blue
    Color(0xFFFF9100), // Deep Orange
  ];

  @override
  Widget build(BuildContext context) {
    final cleanName = nombre.trim();
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : "?";

    final baseColor = customColor ?? _palette[cleanName.toLowerCase().hashCode.abs() % _palette.length];
    final topColor = Color.lerp(baseColor, Colors.white, 0.65)!;
    final isLightText = ThemeData.estimateBrightnessForColor(baseColor) == Brightness.dark;

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
