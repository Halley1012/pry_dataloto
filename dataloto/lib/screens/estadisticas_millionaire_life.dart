import 'package:flutter/material.dart';
import '../styles/colores.dart';
import '../styles/app_text_styles.dart';

class EstadisticasMillionaireLifeScreen extends StatelessWidget {
  const EstadisticasMillionaireLifeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: AppColors.blackfondo, title: Text("Estadísticas Millionaire for Life", style: AppTextStyles.h2)),
      body: const Center(child: Text("Estadísticas en desarrollo...")),
    );
  }
}
