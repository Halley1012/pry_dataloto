import 'package:flutter/material.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import 'package:eterlotto/screens/registro.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;
  final storage = const FlutterSecureStorage();

  Future<void> _loginWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId:
            "705812334903-st0akd2g8mq0i7cqpvhm5ul0mkuhhj08.apps.googleusercontent.com",
        scopes: ['email', 'profile'],
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (!mounted) return;
      if (idToken == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al obtener token de Google")),
        );
        return;
      }

      final response = await ApiService.socialLogin("google", idToken);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response['success'] == true) {
        final user = response['user'];
        final int? userId = user?['id'];
        final int? paisId = user?['pais_id'];
        final int? departamentoId = user?['departamento_id'];

        if (paisId == null || departamentoId == null) {
          // Redirigir a Onboarding de Ubicación
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RegistroScreen(
                user: user,
                userId: userId,
                isSocialOnboarding: true,
              ),
            ),
          );
        } else {
          Navigator.pushReplacementNamed(context, "/home");
        }
      } else {
        final errorMsg = response['error'] ?? "Error en inicio de sesión social";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg.toString())),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${l10n.errorConexion}: $e")),
      );
    }
  }

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

              Text(l10n?.bienvenido ?? "¡Bienvenido a Eterlotto!", style: AppTextStyles.h2),
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

              // Botón Continuar con Google
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400, minWidth: 220),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.amber),
                        )
                      : ElevatedButton.icon(
                          onPressed: _loginWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 2,
                          ),
                          icon: const FaIcon(
                            FontAwesomeIcons.google,
                            color: Colors.red,
                            size: 20,
                          ),
                          label: const Text(
                            "Continuar con Google",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 30),

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
