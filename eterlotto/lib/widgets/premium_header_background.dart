import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ✨ Fondo Premium nativo en Flutter con ondas doradas sutiles y micro-destellos de 4 puntas.
///
/// Diseñado para colocarse dentro de un [Stack] detrás del encabezado de la app.
/// El ciclo es de 7 segundos con curvas suaves (`Curves.easeInOut`), produciendo
/// un desplazamiento sutil y relajante tipo seda dorada.
/// Los destellos son estrellas limpias de 4 puntas (✦) con fade y escala muy pequeña,
/// sin halos circulares visibles.
class PremiumHeaderBackground extends StatefulWidget {
  final double? height;

  const PremiumHeaderBackground({
    super.key,
    this.height,
  });

  @override
  State<PremiumHeaderBackground> createState() =>
      _PremiumHeaderBackgroundState();
}

class _PremiumHeaderBackgroundState extends State<PremiumHeaderBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curvedAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curvedAnimation,
      builder: (context, _) {
        return CustomPaint(
          size: widget.height != null
              ? Size(double.infinity, widget.height!)
              : Size.infinite,
          painter: _PremiumGoldenWavesPainter(
            progress: _curvedAnimation.value,
          ),
        );
      },
    );
  }
}

class _PremiumGoldenWavesPainter extends CustomPainter {
  final double progress;

  _PremiumGoldenWavesPainter({required this.progress});

  // Coordenadas relativas fijas (x, y) de los micro-destellos estéticos
  static const List<Offset> _sparklePositions = [
    Offset(0.24, 0.40), // Centro-izq superior
    Offset(0.76, 0.28), // Derecha alta
    Offset(0.58, 0.38), // Centro-alto acompañando ondas (sin interferir con el saludo)
    Offset(0.86, 0.70), // Derecha baja
    Offset(0.12, 0.74), // Izquierda baja
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Resplandor ambiental cálido superior/central (Glow sutil muy elegante)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.3, -0.4),
        radius: 1.1,
        colors: [
          const Color(0xFFFFD700).withValues(alpha: 0.06),
          const Color(0xFFC89600).withValues(alpha: 0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glowPaint);

    // 2. Ondas Doradas Armónicas (2 curvas de Bézier fluidas y sutiles)
    final waveCycle = progress * 2 * math.pi;
    final shiftY1 = math.sin(waveCycle) * 4.5;
    final shiftY2 = math.cos(waveCycle) * 3.5;

    // --- Onda 1: Principal de seda dorada ---
    final path1 = Path();
    path1.moveTo(0, h * 0.72 + shiftY1);
    path1.cubicTo(
      w * 0.22,
      h * 0.56 - shiftY1,
      w * 0.45,
      h * 0.88 + shiftY2,
      w * 0.68,
      h * 0.68 + shiftY1,
    );
    path1.cubicTo(
      w * 0.82,
      h * 0.54 - shiftY2,
      w * 0.92,
      h * 0.76 + shiftY1,
      w,
      h * 0.62 + shiftY2,
    );

    final wavePaint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFFFFDF73).withValues(alpha: 0.25),
          const Color(0xFFFFD700).withValues(alpha: 0.65),
          const Color(0xFFFFDF73).withValues(alpha: 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.60, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path1, wavePaint1);

    // --- Onda 2: Línea armónica inferior secundaria ---
    final path2 = Path();
    path2.moveTo(0, h * 0.82 + shiftY2);
    path2.cubicTo(
      w * 0.28,
      h * 0.66 + shiftY1,
      w * 0.52,
      h * 0.92 - shiftY2,
      w * 0.74,
      h * 0.76 - shiftY1,
    );
    path2.cubicTo(
      w * 0.86,
      h * 0.68 + shiftY2,
      w * 0.95,
      h * 0.84 - shiftY1,
      w,
      h * 0.75 + shiftY1,
    );

    final wavePaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFFC89600).withValues(alpha: 0.15),
          const Color(0xFFFFDF73).withValues(alpha: 0.40),
          const Color(0xFFFFD700).withValues(alpha: 0.25),
          Colors.transparent,
        ],
        stops: const [0.0, 0.20, 0.55, 0.80, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path2, wavePaint2);

    // 3. Micro-destellos limpios en forma de estrella de 4 puntas (✦)
    // Sin círculos visibles, solo la estrella limpia con fade y escala pequeña.
    for (int i = 0; i < _sparklePositions.length; i++) {
      final pos = _sparklePositions[i];
      final phase = waveCycle + (i * (math.pi / 2.5));
      final rawPulse = (math.sin(phase) + 1.0) / 2.0; // 0.0 -> 1.0
      // Fade suave y controlado
      final opacity = (rawPulse * 0.70).clamp(0.0, 0.70);
      // Escala visible y nítida (entre 2.5px y 5.0px de radio => 5px a 10px punta a punta)
      final scale = 5.5 + (rawPulse * 5.5);

      if (opacity > 0.05) {
        _drawCleanFourPointStar(
          canvas,
          Offset(pos.dx * w, pos.dy * h),
          scale,
          opacity,
        );
      }
    }
  }

  /// Dibuja una estrella limpia de 4 puntas (✦) sin halos circulares
  void _drawCleanFourPointStar(
      Canvas canvas, Offset center, double radius, double opacity) {
    final paint = Paint()
      ..color = const Color(0xFFFFF9E0).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    final arm = radius;
    final inner = radius * 0.15; // Cintura fina y esbelta para que las 4 puntas sean bien definidas

    // Construcción de la estrella de 4 puntas con curvas cóncavas
    path.moveTo(center.dx, center.dy - arm);
    path.quadraticBezierTo(center.dx, center.dy - inner, center.dx + inner, center.dy);
    path.quadraticBezierTo(center.dx + inner, center.dy, center.dx + arm, center.dy);
    path.quadraticBezierTo(center.dx + inner, center.dy, center.dx, center.dy + inner);
    path.quadraticBezierTo(center.dx, center.dy + inner, center.dx, center.dy + arm);
    path.quadraticBezierTo(center.dx, center.dy + inner, center.dx - inner, center.dy);
    path.quadraticBezierTo(center.dx - inner, center.dy, center.dx - arm, center.dy);
    path.quadraticBezierTo(center.dx - inner, center.dy, center.dx, center.dy - inner);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PremiumGoldenWavesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
