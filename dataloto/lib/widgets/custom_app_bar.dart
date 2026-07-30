import 'package:dataloto/styles/colores.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dataloto/styles/app_text_styles.dart';

class CustomSliverAppBar extends StatelessWidget {
  final String title;
  final Color iconColor;
  final double iconSize;
  final bool pinned;
  final bool floating;
  final bool snap;
  final VoidCallback? onBackPressed;

  const CustomSliverAppBar({
    super.key,
    required this.title,
    this.iconColor = AppColors.yellow, // 👈 Estandarizado al color de la app
    this.iconSize = 24, // 👈 Tamaño estándar para íconos de AppBar
    this.pinned = true, // 👈 Siempre pinned para evitar movimiento
    this.floating = false, // 👈 Desactivado para no flotar/colapsar
    this.snap = false, // 👈 Desactivado para no "snap" (sin movimiento brusco)
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.blackfondo,
      elevation: 0,
      scrolledUnderElevation: 0, // 👈 evita cambio de color
      surfaceTintColor: Colors.transparent, // 👈 mantiene color estable
      pinned: pinned,
      floating: floating,
      snap: snap,
      toolbarHeight: kToolbarHeight, // 👈 Altura estándar (56px, sin compacto)
      title: Text(
        title,
        style: AppTextStyles.h2, // 👈 Estilo estándar de la app
      ),
      iconTheme: const IconThemeData(
        color: AppColors.yellow,
      ), // 👈 Estandarizado al tema de íconos de la app
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: iconSize, color: iconColor),
        onPressed: () {
          if (onBackPressed != null) {
            onBackPressed!();
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}

// Ejemplo de uso en un Scaffold (estandarizado con colores y estilos de la app)
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.blackfondo, // 👈 Fondo estándar de la app
        statusBarIconBrightness: Brightness.light, // Iconos claros
      ),
      child: Scaffold(
        backgroundColor: AppColors.blackfondo, // 👈 Fondo estándar de la app
        body: CustomScrollView(
          slivers: [
            const CustomSliverAppBar(title: "Mi App"),
            SliverFillRemaining(
              child: Center(
                child: Text(
                  "Contenido de la pantalla",
                  style: AppTextStyles.mensajeSecundario, // 👈 Estilo estándar
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
