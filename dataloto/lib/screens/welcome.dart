import 'package:flutter/material.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                "assets/images/logo_letras_.png",
                fit: BoxFit.contain,
                height: 400,
              ),
              const SizedBox(height: 1),

              Text(l10n?.bienvenido ?? "¡Bienvenido a DataLoto!", style: AppTextStyles.h2),
              const SizedBox(height: 20),

              Text(
                l10n?.descripcionBienvenida ?? "Estamos emocionados de ayudarte con predicciones inteligentes y hacer que disfrutes al máximo la emoción de cada sorteo.",
                textAlign: TextAlign.center,
                style: AppTextStyles.mensajeSecundario,
              ),
              const SizedBox(height: 40),

              // Botón Iniciar sesión
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400, minWidth: 220),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: Text(l10n?.iniciarSesion ?? "Iniciar sesión", style: AppTextStyles.button),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              InkWell(
                onTap: () =>
                    Navigator.pushReplacementNamed(context, '/registro'),
                child: Text(l10n?.registrarse ?? "Crear cuenta", style: AppTextStyles.mensajeImportante),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
