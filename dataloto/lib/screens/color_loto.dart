import 'package:flutter/material.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

class ColorLotoScreen extends StatefulWidget {
  @override
  _ColorLotoScreenState createState() => _ColorLotoScreenState();
}

class _ColorLotoScreenState extends State<ColorLotoScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  late AnimationController _shineController;

  final List<int> numerosSuerte = [28, 27, 16, 36, 8];

  @override
  void initState() {
    super.initState();

    // Animación de rebote
    _bounceController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 800));
    _bounceAnimation = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    );
    _bounceController.forward();

    // Animación de brillo
    _shineController =
        AnimationController(vsync: this, duration: Duration(seconds: 3))
          ..repeat();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n?.noDisponible ?? "No disponible por el momento...",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
              SizedBox(height: 20),

              // Balotas con animación
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: numerosSuerte.map((num) {
                  return ScaleTransition(
                    scale: _bounceAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Balota dorada con brillo
                        RotationTransition(
                          turns: Tween(begin: 0.0, end: 1.0)
                              .animate(_shineController),
                          child: ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.2),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: [0.2, 0.5, 0.8],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcATop,
                            child: Image.asset(
                               "assets/images/yellow-ball.png",
                              width: 70,
                              height: 70,
                            ),
                          ),
                        ),

                        // Número en el centro
                        Text(
                          "$num",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black,
                                offset: Offset(1, 1),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
