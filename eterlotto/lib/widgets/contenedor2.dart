import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerBorderContainer extends StatelessWidget {
  final Widget child;

  const ShimmerBorderContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Capa de fondo del Container
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amberAccent.withOpacity(0.6),
              width: 1.5,
            ),
          ),
          child: child,
        ),
        // Capa de borde brillante animado
        Positioned.fill(
          child: Shimmer.fromColors(
            baseColor: Colors.transparent,
            highlightColor: Colors.amber.withOpacity(0.8),
            period: const Duration(seconds: 4),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white, // color "máscara" para el shimmer
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
