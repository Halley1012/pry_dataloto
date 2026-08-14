import 'dart:convert';
import 'dart:async';
import 'package:dataloto/screens/welcome.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:dataloto/l10n/generated/app_localizations.dart';
import 'resultados/widgets/resultados_shared.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final storage = const FlutterSecureStorage();
  bool _obscureText = true; // State for password visibility

  bool isLoading = false;

  // Guardar token en SecureStorage
  Future<void> saveToken(String token) async {
    await storage.write(key: 'token', value: token);
  }

  // Login usando ApiService
  Future<void> loginUser() async {
    final l10n = AppLocalizations.of(context)!;
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ingresaEmailContrasena)),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      if (response['success']) {
        // Guardar access_token y refresh_token
        final accessToken = response['access_token'];
        final refreshToken = response['refresh_token'];

        if (accessToken != null && refreshToken != null) {
          await storage.write(key: "auth_token", value: accessToken);
          await storage.write(key: "refresh_token", value: refreshToken);
          debugPrint(
            'Tokens saved: access_token=$accessToken, refresh_token=$refreshToken',
          );

          // Redirigir al Home
          Navigator.pushReplacementNamed(context, "/home");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorObtenerTokens)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.credencialesInvalidas)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${l10n.errorConexion}: $e")));
    }
  }

  // Función para enviar correo de recuperación
  Future<void> _sendResetEmail(String email) async {
    final l10n = AppLocalizations.of(context)!;
    final url = Uri.parse('${ApiService.baseUrl}/auth/forgot-password');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.enviadoEnlace(email))),
        );
      } else {
        String errorMsg = l10n.errorEnviarCorreo;
        try {
          final body = jsonDecode(response.body);
          if (body['detail'] != null) {
            errorMsg = body['detail'].toString();
          }
        } catch (_) {}
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorConexion)), // O un mensaje de "Servidor lento"
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${l10n.errorConexion}: $e")),
      );
    }
  }

  // Diálogo animado de "Olvidé mi contraseña"
  void _showFancyForgotPasswordDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController dialogEmailController = TextEditingController();
    bool dialogLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: cardBoxDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.recuperarContrasena,
                      style: AppTextStyles.tituloPrincipal,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: dialogEmailController,
                      style: AppTextStyles.mensajeSecundario,
                      decoration: InputDecoration(
                        labelText: l10n.email,
                        labelStyle: AppTextStyles.mensajeSecundario,
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.yellow),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: dialogLoading ? null : () => Navigator.pop(context),
                            child: Text(
                              l10n.cancelarButton,
                              style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white54),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: LoadingButton(
                            isLoading: dialogLoading,
                            text: l10n.enviarButton,
                            onPressed: () async {
                              if (dialogEmailController.text.trim().isEmpty) return;
                              setState(() => dialogLoading = true);
                              await _sendResetEmail(dialogEmailController.text.trim());
                              setState(() => dialogLoading = false);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.amber),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 30),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              );
            }
          },
        ),
        title: Text(l10n.iniciarSesion, style: AppTextStyles.h2),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.bienvenido,
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.iniciaSesionParaContinuar,
                style: AppTextStyles.mensajeSecundario,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.90,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTextStyles.mensajeSecundario,
                      decoration: InputDecoration(
                        labelText: l10n.email,
                        labelStyle: AppTextStyles.mensajeSecundario,
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText:
                          _obscureText, // Use state variable for visibility
                      style: AppTextStyles.mensajeSecundario,
                      decoration: InputDecoration(
                        labelText: l10n.contrasena,
                        labelStyle: AppTextStyles.mensajeSecundario,
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.yellow
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText; // Toggle visibility
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              LoadingButton(
                isLoading: isLoading,
                text: l10n.ingresar,
                onPressed: loginUser,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _showFancyForgotPasswordDialog(context),
                child: Text(
                  l10n.olvidoContrasena,
                  style: AppTextStyles.mensajeSecundario.copyWith(
                    color: AppColors.yellow,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
