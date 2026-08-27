import 'package:flutter/material.dart';

/// Física de scroll que permite el rebote elástico (bouncing/rubber-band) ÚNICAMENTE
/// en la parte superior para dar la sensación táctil y natural de "Pull-to-Refresh",
/// pero es firme (clamping) en la parte inferior para evitar rebotes molestos
/// o activaciones accidentales al deslizar hacia arriba.
class TopBouncingScrollPhysics extends ScrollPhysics {
  const TopBouncingScrollPhysics({super.parent});

  @override
  TopBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TopBouncingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (offset > 0.0 && position.pixels <= position.minScrollExtent) {
      // Deslizando hacia abajo en el tope: resistencia elástica natural y firme (evita activación hipersensible)
      return const BouncingScrollPhysics().applyPhysicsToUserOffset(position, offset * 0.6);
    } else if (offset < 0.0 && position.pixels >= position.maxScrollExtent) {
      // Deslizando hacia arriba en el fondo: tope firme
      return const ClampingScrollPhysics().applyPhysicsToUserOffset(position, offset);
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      // Permite sobre-desplazamiento elástico en el tope (Top Overscroll)
      return 0.0;
    }
    if (value > position.pixels && position.pixels >= position.maxScrollExtent) {
      // Bloquea el sobre-desplazamiento en el fondo (Bottom Clamp)
      return value - position.pixels;
    }
    if (value < position.minScrollExtent && position.minScrollExtent < position.pixels) {
      return value - position.minScrollExtent;
    }
    if (position.pixels < position.maxScrollExtent && position.maxScrollExtent < value) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    if (position.outOfRange) {
      if (position.pixels < position.minScrollExtent) {
        return const BouncingScrollPhysics().createBallisticSimulation(position, velocity);
      }
      return const ClampingScrollPhysics().createBallisticSimulation(position, velocity);
    }
    if (velocity.abs() >= tolerance.velocity) {
      return const ClampingScrollPhysics().createBallisticSimulation(position, velocity);
    }
    return null;
  }
}
