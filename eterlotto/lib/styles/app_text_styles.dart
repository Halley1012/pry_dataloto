import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  /// Encabezados grandes (ej. pantallas principales)
  static final h1 = GoogleFonts.montserrat(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: const Color.fromARGB(255, 19, 19, 19),
  );

  /// Subtítulos o encabezados secundarios
  static final h2 = GoogleFonts.montserrat(
    fontSize: 18,
    //fontWeight: FontWeight.w600,
    color: Colors.white70,
  );

  /// Titulo principal pantallas
  static final tituloPrincipal = GoogleFonts.montserrat(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  /// Texto normal principal
  static final body = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: const Color.fromARGB(255, 19, 19, 19),
  );

  /// Texto secundario (ej. descripciones)
  static final bodySmall = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: const Color.fromARGB(255, 100, 100, 100),
  );

  /// Texto muy pequeño, como captions o hints
  static final caption = GoogleFonts.montserrat(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: const Color.fromARGB(255, 247, 245, 245),
  );

  /// Texto muy pequeño, como captions o hints
  static final caption2 = GoogleFonts.montserrat(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: const Color.fromARGB(255, 247, 245, 245),
  );

  /// Texto para botones
  static final button = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF1E1E1E),
  );

  // Texto para alertas o mensajes importantes
  static final mensajeImportante = GoogleFonts.montserrat(
    color: Colors.white70,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

// Texto para alertas o mensajes importantes
  static final fechasResultado = GoogleFonts.montserrat(
    color: const Color.fromARGB(255, 247, 245, 245),
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
  /// Texto para alertas o mensajes secundarios
  static final mensajeSecundario = GoogleFonts.montserrat(
    color: Colors.white70,
    fontSize: 14,
    decoration: TextDecoration.none,
    decorationThickness: 0,
    decorationColor: Colors.transparent,
  );
}

////////////////////////////////////////////////////
// Widget personalizado para campos de texto
class CustomTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final String? Function(String?)? validator;
  final double? width; // 🔹 Nuevo: ancho opcional

  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.validator,
    this.width, // 🔹 Recibe ancho opcional
  });

  @override
  Widget build(BuildContext context) {
    Widget field = TextFormField(
      controller: controller,
      obscureText: obscureText,
      enableSuggestions: false,
      autocorrect: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      style: GoogleFonts.montserrat(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        decoration: TextDecoration.none,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.montserrat(
          color: Colors.white54,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );

    // 🔹 Si se pasó un width, lo aplicamos con SizedBox; si no, ocupa todo el ancho disponible
    return width != null ? SizedBox(width: width, child: field) : field;
  }
}

////////////////////////////////////////////////////
//estitlos botones

class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final double borderRadius;

  const LoadingButton({
    super.key,
    required this.isLoading,
    required this.text,
    required this.onPressed,
    this.backgroundColor = Colors.amber,
    this.borderRadius = 30,
  });

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.amber))
        : ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            onPressed: onPressed,
            child: Text(text, style: AppTextStyles.button),
          );
  }
}


