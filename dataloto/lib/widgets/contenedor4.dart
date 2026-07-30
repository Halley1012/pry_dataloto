import 'package:flutter/material.dart';
import '../styles/colores.dart';

class AppContainer4 extends StatelessWidget {
  final Widget child;

  const AppContainer4({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [AppColors.black, AppColors.darkGray],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // transform: GradientRotation(0.785398), // 👈 45 grados si quieres
        ),
      ),
      child: child,
    );
  }
}
