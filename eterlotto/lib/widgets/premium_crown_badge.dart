import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 👑 Icono de Corona Premium animada e independiente.
/// Ideal para AppBar actions, títulos de sección, cabeceras de pantallas.
///
/// Si [isPremium] es `false`, devuelve `const SizedBox.shrink()` con coste cero
/// (sin inicializar AnimationController ni consumir recursos de GPU).
///
/// Si [isPremium] es `true`, renderiza:
/// 1. Corona dorada estilizada con sombreado de gradiente oro brillante (#FFF7D6, #FFD700, #C89600).
/// 2. Sutil resplandor perimetral dorado.
/// 3. Micro-destello periódico de 4 puntas que titila suavemente durante ~1s cada 7 segundos.
class PremiumCrownIcon extends StatefulWidget {
  final bool isPremium;
  final double size;

  const PremiumCrownIcon({
    super.key,
    this.isPremium = false,
    this.size = 18.0,
  });

  @override
  State<PremiumCrownIcon> createState() => _PremiumCrownIconState();
}

class _PremiumCrownIconState extends State<PremiumCrownIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _sparkleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isPremium) {
      _startSparkleController();
    }
  }

  @override
  void didUpdateWidget(covariant PremiumCrownIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPremium && !oldWidget.isPremium) {
      _startSparkleController();
    } else if (!widget.isPremium && oldWidget.isPremium) {
      _disposeController();
    }
  }

  void _startSparkleController() {
    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    // El micro-brillo ocurre entre el 80% y 95% del ciclo (duración de ~1 segundo cada 7 segundos)
    _sparkleAnimation = CurvedAnimation(
      parent: _controller!,
      curve: const Interval(0.80, 0.95, curve: Curves.easeInOut),
    );
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _sparkleAnimation = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🟡 Usuario No Premium: Costo cero absoluto
    if (!widget.isPremium) {
      return const SizedBox.shrink();
    }

    // 👑 Usuario Premium: Corona dorada con shader gradient y sombra
    final crownWidget = ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF7D6),
            Color(0xFFFFD700),
            Color(0xFFC89600),
          ],
        ).createShader(bounds);
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.45),
              blurRadius: 5,
              spreadRadius: 0,
            ),
          ],
        ),
        child: FaIcon(
          FontAwesomeIcons.crown,
          size: widget.size,
          color: Colors.white,
        ),
      ),
    );

    if (_controller == null || _sparkleAnimation == null) {
      return crownWidget;
    }

    return AnimatedBuilder(
      animation: _sparkleAnimation!,
      builder: (context, child) {
        final progress = _sparkleAnimation!.value;
        final sparklePeak = math.sin(progress * math.pi);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            if (sparklePeak > 0.08)
              Positioned(
                top: -widget.size * 0.35,
                right: -widget.size * 0.22,
                child: Opacity(
                  opacity: sparklePeak.clamp(0.0, 0.75),
                  child: Transform.scale(
                    scale: 0.65 + (sparklePeak * 0.25),
                    child: Icon(
                      Icons.auto_awesome,
                      size: (widget.size * 0.5).clamp(8.0, 14.0),
                      color: const Color(0xFFFFF9E0),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: crownWidget,
    );
  }
}

/// 👑 Badge de Corona Premium reutilizable para avatares y perfiles.
///
/// Si [isPremium] es `false`, devuelve directamente [child] con coste computacional cero.
///
/// Si [isPremium] es `true`, decora el avatar con:
/// 1. Borde y sutil resplandor dorado.
/// 2. Corona dorada flotante externa ([PremiumCrownIcon]), ubicada en la parte superior derecha
///    sin invadir ni tapar el área de la foto del usuario.
/// 3. Micro-brillo periódico sutil cada 7 segundos.
class PremiumCrownBadge extends StatelessWidget {
  final Widget child;
  final bool isPremium;
  final double crownSize;
  final Offset crownOffset;
  final bool showBorderGlow;

  const PremiumCrownBadge({
    super.key,
    required this.child,
    this.isPremium = false,
    this.crownSize = 18.0,
    this.crownOffset = const Offset(-3, -12),
    this.showBorderGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    // 🟡 Usuario No Premium: Costo cero
    if (!isPremium) {
      return child;
    }

    // 👑 Usuario Premium
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Avatar hijo con halo sutil dorado si está habilitado
        if (showBorderGlow)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                  blurRadius: 7,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          )
        else
          child,

        // Corona Premium externa en la esquina superior derecha (sin invadir la foto)
        Positioned(
          top: crownOffset.dy,
          right: crownOffset.dx,
          child: PremiumCrownIcon(
            isPremium: true,
            size: crownSize,
          ),
        ),
      ],
    );
  }
}
