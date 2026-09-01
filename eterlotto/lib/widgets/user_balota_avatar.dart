import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/styles/colores.dart';

/// 🎱 Widget de Avatar con estilo Balota de Lotería 3D y animación cromática suave.
///
/// Si [avatarUrl] está presente y no vacío, muestra la foto de perfil enmarcada.
/// Si no hay avatar, muestra una balota 3D con animación de espectro multicolor
/// (estilo flor/arcoíris) y la inicial tipográfica de alta fidelidad.
class UserBalotaAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String? userName;
  final int? userId;
  final double radius;
  final bool animateGradient;
  final bool showGlow;
  final bool showBorder;
  final Color? borderColor;
  final Color? customStaticColor;

  const UserBalotaAvatar({
    super.key,
    this.avatarUrl,
    this.userName,
    this.userId,
    this.radius = 22.0,
    this.animateGradient = true,
    this.showGlow = true,
    this.showBorder = true,
    this.borderColor,
    this.customStaticColor,
  });

  @override
  State<UserBalotaAvatar> createState() => _UserBalotaAvatarState();
}

class _UserBalotaAvatarState extends State<UserBalotaAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  // Espectro de color continuo inspirado en la paleta cromática multicolor (Flor/Arcoíris)
  static const List<Color> _spectrum = [
    Color(0xFFFF007F), // Magenta / Rosa vivo
    Color(0xFF8A2BE2), // Violeta azulado / Púrpura
    Color(0xFF0070F3), // Azul real eléctrico
    Color(0xFF00E5FF), // Cian brillante
    Color(0xFF00E676), // Verde esmeralda vivo
    Color(0xFFFFEA00), // Amarillo oro radiante
    Color(0xFFFF6D00), // Naranja cálido
    Color(0xFFFF1744), // Rojo carmesí intenso
  ];

  bool get _hasAvatarUrl =>
      widget.avatarUrl != null && widget.avatarUrl!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_hasAvatarUrl && widget.animateGradient) {
      _initAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant UserBalotaAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasAvatarUrl && widget.animateGradient) {
      if (_controller == null) {
        _initAnimation();
      } else if (!_controller!.isAnimating) {
        _controller!.repeat();
      }
    } else {
      _controller?.stop();
    }
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Color _getInterpolatedColor(double progress) {
    final double pos = progress % 1.0;
    final double scaled = pos * _spectrum.length;
    final int index1 = scaled.floor() % _spectrum.length;
    final int index2 = (index1 + 1) % _spectrum.length;
    final double t = scaled - scaled.floor();
    return Color.lerp(_spectrum[index1], _spectrum[index2], t)!;
  }

  @override
  Widget build(BuildContext context) {
    final double diameter = widget.radius * 2;
    final String name = widget.userName?.trim() ?? "";
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

    // Si tiene foto de perfil cargada
    if (_hasAvatarUrl) {
      return Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: widget.showBorder
              ? Border.all(
                  color: widget.borderColor ?? AppColors.yellow,
                  width: (widget.radius * 0.09).clamp(1.5, 2.5),
                )
              : null,
          boxShadow: widget.showGlow
              ? [
                  BoxShadow(
                    color: (widget.borderColor ?? AppColors.yellow)
                        .withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: Image.network(
            widget.avatarUrl!,
            width: diameter,
            height: diameter,
            cacheWidth: (diameter * 3).toInt(),
            cacheHeight: (diameter * 3).toInt(),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildBalota(diameter, initial, 0.0),
          ),
        ),
      );
    }

    // Si NO tiene avatar y se solicita animación
    if (widget.animateGradient && _controller != null) {
      return AnimatedBuilder(
        animation: _controller!,
        builder: (context, _) {
          return _buildBalota(diameter, initial, _controller!.value);
        },
      );
    }

    // Balota 3D estática (ej: para listas de comentarios o mini avatares)
    return _buildBalota(diameter, initial, 0.0);
  }

  Widget _buildBalota(double size, String initial, double animProgress) {
    final Color baseColor = widget.customStaticColor ??
        AppColors.getAvatarColor(
          widget.userName ?? "",
          userId: widget.userId,
        );

    final Color activeColor = widget.animateGradient
        ? _getInterpolatedColor(animProgress)
        : baseColor;

    final Color topLight = Color.lerp(activeColor, Colors.white, 0.45)!;
    final Color bottomDark = Color.lerp(activeColor, Colors.black, 0.70)!;
    final Color glowColor = widget.borderColor ?? activeColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (widget.showGlow)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.45),
              blurRadius: widget.radius > 20 ? 10 : 5,
              spreadRadius: widget.radius > 20 ? 1.5 : 0.5,
              offset: const Offset(0, 2),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Capa de Fondo 3D Esférico con Desvanecimiento Suave de Color (Fade)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                radius: 0.9,
                colors: [
                  topLight,
                  activeColor,
                  bottomDark,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // 2. Capa de Brillo Especular 3D (Efecto Balota de Lotería esférica)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.4, -0.4),
                radius: 0.65,
                colors: [
                  Color.fromRGBO(255, 255, 255, 0.8),
                  Color.fromRGBO(255, 255, 255, 0.25),
                  Colors.transparent,
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // 3. Capa de Sombra de Profundidad 3D y Borde de Cristal
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(0.45, 0.45),
                radius: 0.85,
                colors: [
                  Colors.transparent,
                  Color.fromRGBO(0, 0, 0, 0.2),
                  Color.fromRGBO(0, 0, 0, 0.65),
                ],
                stops: [0.35, 0.7, 1.0],
              ),
              border: widget.showBorder
                  ? Border.all(
                      color: widget.borderColor ?? const Color.fromRGBO(255, 255, 255, 0.55),
                      width: (widget.radius * 0.08).clamp(1.2, 2.4),
                    )
                  : Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.35),
                      width: 1.0,
                    ),
            ),
          ),

          // 4. Inicial Tipográfica Estilo Balota Oficial
          Center(
            child: Text(
              initial,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: widget.radius * 0.96,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.0,
                shadows: const [
                  Shadow(
                    color: Color.fromRGBO(0, 0, 0, 0.85),
                    offset: Offset(1.2, 1.5),
                    blurRadius: 3.5,
                  ),
                  Shadow(
                    color: Color.fromRGBO(0, 0, 0, 0.45),
                    offset: Offset(0, 2.5),
                    blurRadius: 6.0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}