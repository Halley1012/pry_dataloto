import 'package:flutter/material.dart';

class AppColors {
  static const Color darkBlue = Color(0xFF192230); // #192230
  static const Color grayBlue = Color(0xFF3D474E); // #3d474e
  static const Color yellow = Colors.amber;   // #ffcd00
  static const Color amber = Colors.amber;    // #ffcd00
  static const Color darkGray = Color(0xFF2C2F38); // #2c2f38
  static const Color black = Color(0xFF1E1E1E);
  static const Color blackfondo = Color(0xFF121212); // #6c7075
  
  static const Color white = Colors.white70; // Naranja

  /// 🎨 Genera un color vibrante y único para el avatar según el usuario
  static Color getAvatarColor(String userName, {int? userId}) {
    final List<Color> avatarColors = [
      const Color(0xFFE53935), // Red
      const Color(0xFFD81B60), // Pink
      const Color(0xFF8E24AA), // Purple
      const Color(0xFF5E35B1), // Deep Purple
      const Color(0xFF3949AB), // Indigo
      const Color(0xFF1E88E5), // Blue
      const Color(0xFF039BE5), // Light Blue
      const Color(0xFF00ACC1), // Cyan
      const Color(0xFF00897B), // Teal
      const Color(0xFF43A047), // Green
      const Color(0xFF7CB342), // Light Green
      const Color(0xFFFB8C00), // Orange
      const Color(0xFFF4511E), // Deep Orange
      const Color(0xFF6D4C41), // Brown
      const Color(0xFF546E7A), // Blue Grey
    ];

    if (userName.trim().isEmpty && userId == null) {
      return const Color(0xFF3949AB);
    }

    final keyString = userName.trim().toLowerCase();
    int hash = 0;
    for (int i = 0; i < keyString.length; i++) {
      hash = keyString.codeUnitAt(i) + ((hash << 5) - hash);
    }

    if (userId != null && userId > 0) {
      hash += userId;
    }

    final index = hash.abs() % avatarColors.length;
    return avatarColors[index];
  }
}

