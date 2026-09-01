import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

// --- HELPERS VISUALES Y BOLAS ---
Widget build3DBall(int numero, {Color baseColor = const Color(0xFF1E3A8A), bool isSpecial = false, double size = 44}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          baseColor.withValues(alpha: 0.95),
          baseColor.withValues(alpha: 0.75),
          baseColor.withValues(alpha: 0.4),
        ],
        center: Alignment.topLeft,
        radius: 0.85,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          offset: const Offset(2, 3),
          blurRadius: 5,
        ),
      ],
      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
    ),
    child: Center(
      child: Text(
        "$numero",
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          fontSize: size * 0.41,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.0,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.6), offset: const Offset(1, 1), blurRadius: 2),
          ],
        ),
      ),
    ),
  );
}

Widget buildMiniBall(int numero, {Color baseColor = const Color(0xFF1E3A8A), double size = 24}) {
  final bool isBright = baseColor == Colors.amber ||
      baseColor == Colors.greenAccent ||
      baseColor.computeLuminance() > 0.45;
  final Color textColor = isBright ? const Color(0xFF111827) : Colors.white;

  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          baseColor.withValues(alpha: 0.95),
          baseColor.withValues(alpha: 0.75),
          baseColor.withValues(alpha: 0.5),
        ],
        center: Alignment.topLeft,
        radius: 0.85,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          offset: const Offset(1, 1.5),
          blurRadius: 2.5,
        ),
      ],
      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.8),
    ),
    child: Center(
      child: Text(
        "$numero",
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          fontSize: size * 0.46,
          fontWeight: FontWeight.bold,
          color: textColor,
          height: 1.0,
        ),
      ),
    ),
  );
}

Widget buildPlayBall(int num, {required bool isHit, bool isRed = false}) {
  final Color bg = isRed
      ? (isHit ? const Color(0xFFDC2626) : const Color(0xFF450A0A))
      : (isHit ? const Color(0xFF15803D) : const Color(0xFF262933));

  final Color borderColor = isRed
      ? (isHit ? Colors.redAccent : Colors.red.withValues(alpha: 0.3))
      : (isHit ? Colors.greenAccent : Colors.white24);

  return Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: bg,
      border: Border.all(color: borderColor, width: isHit ? 1.5 : 1),
    ),
    child: Center(
      child: Text(
        "$num",
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isHit ? Colors.white : Colors.white60,
          height: 1.0,
        ),
      ),
    ),
  );
}

BoxDecoration cardBoxDecoration() {
  return BoxDecoration(
    color: const Color(0xFF14161D),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

// --- PAINTER 1: GAUGE CIRCULAR ---
class CircularGaugePainter extends CustomPainter {
  final double percentage;
  final Color? activeColor;

  CircularGaugePainter({required this.percentage, this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;

    // Track de fondo (Gris Oscuro)
    final bgPaint = Paint()
      ..color = const Color(0xFF232733)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Track activo
    final Color colorA = activeColor ?? const Color(0xFFFFD700);
    final Color colorB = activeColor != null ? activeColor!.withOpacity(0.6) : const Color(0xFFFFA500);

    final fgPaint = Paint()
      ..shader = LinearGradient(
        colors: [colorA, colorB],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5 * percentage,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- PAINTER 2: DONUT CHART ---
class DonutChartPainter extends CustomPainter {
  final List<int> values;
  DonutChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 12.0;

    final total = values.fold(0, (a, b) => a + b);
    if (total == 0) {
      final bgPaint = Paint()
        ..color = const Color(0xFF232733)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);
      return;
    }

    final colors = [
      const Color(0xFF4B5563),
      const Color(0xFF2563EB),
      const Color(0xFFD97706),
      const Color(0xFF16A34A),
    ];

    double startAngle = -math.pi / 2;
    final int activeSlicesCount = values.where((v) => v > 0).length;

    for (int i = 0; i < values.length && i < colors.length; i++) {
      if (values[i] == 0) continue;
      final sweepAngle = (values[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - (activeSlicesCount > 1 ? 0.05 : 0),
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- PAINTER 3: SPARKLINE / LINE CHART ---
class LineChartPainter extends CustomPainter {
  final List<double> coverages;
  LineChartPainter({required this.coverages});

  @override
  void paint(Canvas canvas, Size size) {
    if (coverages.isEmpty) return;

    final double stepX = coverages.length > 1 ? size.width / (coverages.length - 1) : size.width;
    final List<Offset> points = [];

    for (int i = 0; i < coverages.length; i++) {
      final x = i * stepX;
      final y = size.height * (1.0 - coverages[i].clamp(0.0, 1.0) * 0.7 - 0.15);
      points.add(Offset(x, y));
    }

    // Grid horizontal
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.8;

    for (int i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Línea conectora
    final linePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Puntos
    final dotPaint = Paint()..color = const Color(0xFFF59E0B);
    for (var pt in points) {
      canvas.drawCircle(pt, 3, dotPaint);
    }

    // Tooltip en el último punto
    final lastPt = points.last;
    final lastValPercent = "${(coverages.last * 100).round()}%";
    final tooltipBg = Paint()..color = const Color(0xFFF59E0B);
    final rect = RRect.fromLTRBR(
      lastPt.dx - 18,
      lastPt.dy - 22,
      lastPt.dx + 18,
      lastPt.dy - 6,
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, tooltipBg);

    const textStyle = TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold);
    final textSpan = TextSpan(text: lastValPercent, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(lastPt.dx - (textPainter.width / 2), lastPt.dy - 20));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SubSorteoData {
  final String nombre;
  final List<int> winningNums;
  final int? winningRed;
  final int? compBall;
  final double coberturaPorcentaje;
  final int topHitsCount;
  final List<int> hitsInTop;
  final Color color;

  const SubSorteoData({
    required this.nombre,
    required this.winningNums,
    this.winningRed,
    this.compBall,
    required this.coberturaPorcentaje,
    required this.topHitsCount,
    required this.hitsInTop,
    required this.color,
  });
}

