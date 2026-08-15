import 'package:flutter/material.dart';
import '../styles/colores.dart';

class AppContainer4 extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppContainer4({
    super.key, 
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
