import 'dart:convert';
import 'dart:async';
import 'package:eterlotto/screens/welcome.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:eterlotto/screens/registro.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:eterlotto/widgets/custom_dialogs.dart';
import 'resultados/widgets/resultados_shared.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../utils/secure_storage_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final storage = AppSecureStorage.instance;
  bool _obscureText = true; // State for password visibility

  bool isLoading = false;

  // Guardar token en SecureStorage
  Future<void> saveToken(String token) async {
    await storage.write(key: 'token', value: token);
  }

  Future<void> loginWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => isLoading = true);

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId:
            "705812334903-st0akd2g8mq0i7cqpvhm5ul0mkuhhj08.apps.googleusercontent.com",
        scopes: ['email', 'profile'],
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (!mounted) return;
      if (idToken == null) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al obtener token de Google")),
        );
        return;
      }

      final response = await ApiService.socialLogin("google", idToken);

      if (!mounted) return;
      setState(() => isLoading = false);

      if (response['success'] == true) {
        final user = response['user'];
        final int? userId = user?['id'];
        final int? paisId = user?['pais_id'];
        final int? departamentoId = user?['departamento_id'];

        if (userId != null) {
          await storage.write(key: "user_id", value: userId.toString());
        }
        if (paisId != null) {
          await storage.write(key: "pais_id", value: paisId.toString());
        }
        if (departamentoId != null) {
          await storage.write(key: "departamento_id", value: departamentoId.toString());
        }
        if (user?['pais_nombre'] != null) {
          await storage.write(key: "pais_nombre", value: user!['pais_nombre'].toString());
        }
        if (user?['name'] != null) {
          await storage.write(key: "name", value: user!['name'].toString());
        }
        if (user?['email'] != null) {
          await storage.write(key: "email", value: user!['email'].toString());
        }

        if (!mounted) return;

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
        if (!mounted) return;
        final errorMsg = response['error'] ?? "Error en inicio de sesión social";
        showEterSnackBar(
          context,
          message: errorMsg.toString(),
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showEterSnackBar(
        context,
        message: "${l10n.errorConexion}: $e",
        isError: true,
      );
    }
  }

  // Login usando ApiService
  Future<void> loginUser() async {
    final l10n = AppLocalizations.of(context)!;
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      showEterSnackBar(
        context,
        message: l10n.ingresaEmailContrasena,
        isError: true,
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

          final uId = response['user_id'];
          if (uId != null) await storage.write(key: "user_id", value: uId.toString());
          final pId = response['pais_id'];
          if (pId != null) await storage.write(key: "pais_id", value: pId.toString());
          final pNombre = response['pais_nombre'];
          if (pNombre != null) await storage.write(key: "pais_nombre", value: pNombre.toString());
          final dId = response['departamento_id'];
          if (dId != null) await storage.write(key: "departamento_id", value: dId.toString());
          final dNombre = response['departamento_nombre'];
          if (dNombre != null) await storage.write(key: "departamento_nombre", value: dNombre.toString());
          final name = response['name'];
          if (name != null) await storage.write(key: "name", value: name.toString());
          final email = response['email'];
          if (email != null) await storage.write(key: "email", value: email.toString());

          debugPrint(
            'Tokens saved: access_token=$accessToken, refresh_token=$refreshToken, user_id=$uId',
          );

          if (!mounted) return;

          context.read<SubscriptionProvider>().refreshSubscriptionStatus();

          // Redirigir al Home
          Navigator.pushReplacementNamed(context, "/home");
        } else {
          showEterSnackBar(
            context,
            message: l10n.errorObtenerTokens,
            isError: true,
          );
        }
      } else {
        final errorMsg = response['message']?.toString() ?? l10n.credencialesInvalidas;
        if (errorMsg.contains("EMAIL_NOT_VERIFIED")) {
          showEterSnackBar(
            context,
            message: "Tu cuenta no ha sido activada. Ingresa el código de activación enviado a tu correo.",
            isError: true,
          );
          _showEmailVerificationDialog(context, _emailController.text.trim());
        } else {
          showEterSnackBar(
            context,
            message: errorMsg,
            isError: true,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      final errorStr = e.toString();
      if (errorStr.contains("EMAIL_NOT_VERIFIED")) {
        showEterSnackBar(
          context,
          message: "Tu cuenta no ha sido activada. Ingresa el código de activación enviado a tu correo.",
          isError: true,
        );
        _showEmailVerificationDialog(context, _emailController.text.trim());
      } else {
        showEterSnackBar(
          context,
          message: "${l10n.errorConexion}: $e",
          isError: true,
        );
      }
    }
  }

  // Diálogo interactivo para activar cuenta si no ha sido verificada
  void _showEmailVerificationDialog(BuildContext context, String email) {
    final TextEditingController dialogCodeController = TextEditingController();
    bool dialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: cardBoxDecoration(),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Activa tu Cuenta",
                        style: AppTextStyles.tituloPrincipal,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Hemos enviado un código de 6 dígitos a $email para verificar tu correo.",
                        style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: dialogCodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        enableSuggestions: false,
                        autocorrect: false,
                        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                        style: AppTextStyles.h2.copyWith(
                          letterSpacing: 8,
                          color: AppColors.yellow,
                          decoration: TextDecoration.none,
                          decorationThickness: 0,
                          decorationColor: Colors.transparent,
                        ),
                        decoration: InputDecoration(
                          counterText: "",
                          hintText: "000000",
                          hintStyle: AppTextStyles.h2.copyWith(
                            letterSpacing: 8,
                            color: Colors.white24,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1E1E24),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: dialogLoading ? null : () => Navigator.pop(dialogCtx),
                              child: Text(
                                "Cancelar",
                                style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white54),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: LoadingButton(
                              isLoading: dialogLoading,
                              text: "Activar Cuenta",
                              onPressed: () async {
                                final code = dialogCodeController.text.trim();
                                if (code.length != 6) {
                                  showEterSnackBar(context, message: "Ingresa los 6 dígitos del código", isError: true);
                                  return;
                                }

                                setDialogState(() => dialogLoading = true);
                                final url = Uri.parse('${ApiService.baseUrl}/auth/verify-email');
                                try {
                                  final res = await http.post(
                                    url,
                                    headers: {'Content-Type': 'application/json'},
                                    body: jsonEncode({'email': email, 'code': code}),
                                  ).timeout(const Duration(seconds: 20));

                                  setDialogState(() => dialogLoading = false);

                                  if (res.statusCode == 200) {
                                    final data = jsonDecode(res.body);
                                    final storage = AppSecureStorage.instance;
                                    if (data['access_token'] != null) {
                                      await storage.write(key: "auth_token", value: data['access_token'].toString());
                                      await storage.write(key: "refresh_token", value: (data['refresh_token'] ?? "").toString());
                                    }

                                    final userMap = data['user'] is Map ? data['user'] as Map : null;
                                    if (userMap != null) {
                                      if (userMap['id'] != null) await storage.write(key: "user_id", value: userMap['id'].toString());
                                      if (userMap['name'] != null) await storage.write(key: "name", value: userMap['name'].toString());
                                      if (userMap['email'] != null) await storage.write(key: "email", value: userMap['email'].toString());
                                      if (userMap['pais_id'] != null) await storage.write(key: "pais_id", value: userMap['pais_id'].toString());
                                      if (userMap['pais_nombre'] != null) await storage.write(key: "pais_nombre", value: userMap['pais_nombre'].toString());
                                      if (userMap['departamento_id'] != null) await storage.write(key: "departamento_id", value: userMap['departamento_id'].toString());
                                      if (userMap['departamento_nombre'] != null) await storage.write(key: "departamento_nombre", value: userMap['departamento_nombre'].toString());
                                      if (userMap['avatar_url'] != null) await storage.write(key: "avatar_url", value: userMap['avatar_url'].toString());
                                    }

                                    if (dialogCtx.mounted) {
                                      Navigator.pop(dialogCtx);
                                      showEterSnackBar(
                                        context,
                                        message: "¡Cuenta activada con éxito! Bienvenido a Eterlotto.",
                                        isSuccess: true,
                                      );
                                      Navigator.pushReplacementNamed(context, '/home');
                                    }
                                  } else {
                                    String errorMsg = "Código incorrecto o expirado";
                                    try {
                                      final errData = jsonDecode(res.body);
                                      if (errData['detail'] != null) errorMsg = errData['detail'].toString();
                                    } catch (_) {}
                                    if (context.mounted) showEterSnackBar(context, message: errorMsg, isError: true);
                                  }
                                } catch (e) {
                                  setDialogState(() => dialogLoading = false);
                                  if (context.mounted) showEterSnackBar(context, message: "Error de conexión: $e", isError: true);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: dialogLoading
                            ? null
                            : () async {
                                final url = Uri.parse('${ApiService.baseUrl}/auth/resend-verification-code');
                                try {
                                  await http.post(
                                    url,
                                    headers: {'Content-Type': 'application/json'},
                                    body: jsonEncode({'email': email}),
                                  );
                                  if (context.mounted) {
                                    showEterSnackBar(context, message: "Código reenviado a $email", isSuccess: true);
                                  }
                                } catch (_) {}
                              },
                        child: Text(
                          "¿No recibiste el código? Reenviar",
                          style: AppTextStyles.caption.copyWith(color: AppColors.yellow),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Diálogo interactivo de 3 pasos: Correo -> Validar PIN -> Nueva Contraseña
  void _showFancyForgotPasswordDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController dialogEmailController = TextEditingController(text: _emailController.text.trim());
    final TextEditingController dialogCodeController = TextEditingController();
    final TextEditingController dialogNewPasswordController = TextEditingController();
    final TextEditingController dialogConfirmPasswordController = TextEditingController();

    int step = 1; // 1: Correo, 2: Validar Código PIN, 3: Nueva Contraseña
    bool dialogLoading = false;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      barrierDismissible: !dialogLoading,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String titleText = l10n.recuperarContrasena;
            String subtitleText = "Ingresa tu correo para recibir un código de seguridad de 6 dígitos.";
            String buttonText = "Enviar Código";

            if (step == 2) {
              titleText = "Verificar Código";
              subtitleText = "Ingresa el código de 6 dígitos enviado a ${dialogEmailController.text.trim()}";
              buttonText = "Verificar Código";
            } else if (step == 3) {
              titleText = "Nueva Contraseña";
              subtitleText = "Código verificado ✅. Ingresa tu nueva contraseña para completar el cambio.";
              buttonText = "Guardar Contraseña";
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: cardBoxDecoration(),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleText,
                        style: AppTextStyles.tituloPrincipal,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subtitleText,
                        style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // PASO 1: Ingreso de correo
                      if (step == 1) ...[
                        TextField(
                          controller: dialogEmailController,
                          keyboardType: TextInputType.emailAddress,
                          enableSuggestions: false,
                          autocorrect: false,
                          spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                          style: AppTextStyles.mensajeSecundario.copyWith(
                            decoration: TextDecoration.none,
                            decorationThickness: 0,
                            decorationColor: Colors.transparent,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.email,
                            labelStyle: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white60),
                            floatingLabelStyle: AppTextStyles.mensajeSecundario.copyWith(color: AppColors.yellow),
                            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.yellow),
                            filled: true,
                            fillColor: const Color(0xFF1E1E24),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
                            ),
                          ),
                        ),
                      ]
                      // PASO 2: Validación del PIN de 6 dígitos
                      else if (step == 2) ...[
                        TextField(
                          controller: dialogCodeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          enableSuggestions: false,
                          autocorrect: false,
                          spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                          style: AppTextStyles.h2.copyWith(
                            letterSpacing: 8,
                            color: AppColors.yellow,
                            decoration: TextDecoration.none,
                            decorationThickness: 0,
                            decorationColor: Colors.transparent,
                          ),
                          decoration: InputDecoration(
                            counterText: "",
                            hintText: "000000",
                            hintStyle: AppTextStyles.h2.copyWith(
                              letterSpacing: 8,
                              color: Colors.white24,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E1E24),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
                            ),
                          ),
                        ),
                      ]
                      // PASO 3: Ingreso de Nueva Contraseña
                      else if (step == 3) ...[
                        TextField(
                          controller: dialogNewPasswordController,
                          obscureText: obscureNewPassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                          style: AppTextStyles.mensajeSecundario.copyWith(
                            decoration: TextDecoration.none,
                            decorationThickness: 0,
                            decorationColor: Colors.transparent,
                          ),
                          decoration: InputDecoration(
                            labelText: "Nueva contraseña",
                            labelStyle: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white60),
                            floatingLabelStyle: AppTextStyles.mensajeSecundario.copyWith(color: AppColors.yellow),
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.yellow),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white54,
                              ),
                              onPressed: () {
                                setDialogState(() => obscureNewPassword = !obscureNewPassword);
                              },
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E1E24),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: dialogConfirmPasswordController,
                          obscureText: obscureConfirmPassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                          style: AppTextStyles.mensajeSecundario.copyWith(
                            decoration: TextDecoration.none,
                            decorationThickness: 0,
                            decorationColor: Colors.transparent,
                          ),
                          decoration: InputDecoration(
                            labelText: "Confirmar contraseña",
                            labelStyle: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white60),
                            floatingLabelStyle: AppTextStyles.mensajeSecundario.copyWith(color: AppColors.yellow),
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.yellow),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white54,
                              ),
                              onPressed: () {
                                setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword);
                              },
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E1E24),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: dialogLoading ? null : () => Navigator.pop(dialogCtx),
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
                              text: buttonText,
                              onPressed: () async {
                                final email = dialogEmailController.text.trim();

                                // ACCIÓN PASO 1: Enviar código al correo
                                if (step == 1) {
                                  if (email.isEmpty || !email.contains('@')) {
                                    showEterSnackBar(context, message: "Ingresa un correo electrónico válido", isError: true);
                                    return;
                                  }
                                  setDialogState(() => dialogLoading = true);
                                  final success = await _requestResetCode(email);
                                  setDialogState(() => dialogLoading = false);
                                  if (success) {
                                    setDialogState(() => step = 2);
                                  }
                                }
                                // ACCIÓN PASO 2: Validar el PIN de 6 dígitos antes de pedir contraseña
                                else if (step == 2) {
                                  final code = dialogCodeController.text.trim();
                                  if (code.length != 6) {
                                    showEterSnackBar(context, message: "Ingresa los 6 dígitos del código", isError: true);
                                    return;
                                  }
                                  setDialogState(() => dialogLoading = true);
                                  final isValid = await _verifyResetCode(email, code);
                                  setDialogState(() => dialogLoading = false);
                                  if (isValid) {
                                    setDialogState(() => step = 3);
                                  }
                                }
                                // ACCIÓN PASO 3: Guardar la nueva contraseña
                                else if (step == 3) {
                                  final code = dialogCodeController.text.trim();
                                  final newPwd = dialogNewPasswordController.text.trim();
                                  final confirmPwd = dialogConfirmPasswordController.text.trim();

                                  if (newPwd.length < 6) {
                                    showEterSnackBar(context, message: "La contraseña debe tener al menos 6 caracteres", isError: true);
                                    return;
                                  }
                                  if (newPwd != confirmPwd) {
                                    showEterSnackBar(context, message: "Las contraseñas no coinciden", isError: true);
                                    return;
                                  }

                                  setDialogState(() => dialogLoading = true);
                                  final success = await _submitNewPassword(email, code, newPwd);
                                  setDialogState(() => dialogLoading = false);
                                  if (success && dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                    _emailController.text = email;
                                    _passwordController.text = newPwd;
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      if (step == 2) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: dialogLoading ? null : () => setDialogState(() => step = 1),
                          child: Text(
                            "¿No recibiste el código? Volver a enviar",
                            style: AppTextStyles.caption.copyWith(color: AppColors.yellow),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Validar código PIN de 6 dígitos con el backend
  Future<bool> _verifyResetCode(String email, String code) async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/verify-reset-code');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (mounted) {
          showEterSnackBar(
            context,
            message: "Código verificado correctamente ✅",
            isSuccess: true,
          );
        }
        return true;
      } else {
        String errorMsg = "Código incorrecto o expirado";
        try {
          final data = jsonDecode(response.body);
          if (data['detail'] != null) errorMsg = data['detail'].toString();
        } catch (_) {}
        if (mounted) showEterSnackBar(context, message: errorMsg, isError: true);
        return false;
      }
    } catch (e) {
      if (mounted) showEterSnackBar(context, message: "Error de conexión: $e", isError: true);
      return false;
    }
  }

  // Solicitar código PIN de recuperación
  Future<bool> _requestResetCode(String email) async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/forgot-password');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        if (mounted) {
          showEterSnackBar(
            context,
            message: "Código de 6 dígitos enviado a $email",
            isSuccess: true,
          );
        }
        return true;
      } else {
        String errorMsg = "Error al solicitar código";
        try {
          final data = jsonDecode(response.body);
          if (data['detail'] != null) errorMsg = data['detail'].toString();
        } catch (_) {}
        if (mounted) showEterSnackBar(context, message: errorMsg, isError: true);
        return false;
      }
    } catch (e) {
      if (mounted) showEterSnackBar(context, message: "Error de conexión: $e", isError: true);
      return false;
    }
  }

  // Restablecer contraseña con código PIN
  Future<bool> _submitNewPassword(String email, String code, String newPassword) async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/reset-password');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        if (mounted) {
          showEterSnackBar(
            context,
            message: "¡Contraseña actualizada! Ya puedes iniciar sesión.",
            isSuccess: true,
          );
        }
        return true;
      } else {
        String errorMsg = "Código inválido o expirado";
        try {
          final data = jsonDecode(response.body);
          if (data['detail'] != null) errorMsg = data['detail'].toString();
        } catch (_) {}
        if (mounted) showEterSnackBar(context, message: errorMsg, isError: true);
        return false;
      }
    } catch (e) {
      if (mounted) showEterSnackBar(context, message: "Error de conexión: $e", isError: true);
      return false;
    }
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
      body: SafeArea(
        child: Center(
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
                  constraints: const BoxConstraints(
                    maxWidth: 400,
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enableSuggestions: false,
                        autocorrect: false,
                        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                        style: AppTextStyles.mensajeSecundario.copyWith(
                          decoration: TextDecoration.none,
                          decorationThickness: 0,
                          decorationColor: Colors.transparent,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.email,
                          labelStyle: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white60),
                          floatingLabelStyle: AppTextStyles.mensajeSecundario.copyWith(color: AppColors.yellow),
                          filled: true,
                          fillColor: const Color(0xFF1E1E24),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        obscureText:
                            _obscureText, // Use state variable for visibility
                        enableSuggestions: false,
                        autocorrect: false,
                        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                        style: AppTextStyles.mensajeSecundario.copyWith(
                          decoration: TextDecoration.none,
                          decorationThickness: 0,
                          decorationColor: Colors.transparent,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.contrasena,
                          labelStyle: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white60),
                          floatingLabelStyle: AppTextStyles.mensajeSecundario.copyWith(color: AppColors.yellow),
                          filled: true,
                          fillColor: const Color(0xFF1E1E24),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: Colors.white12, width: 1.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.yellow,
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: LoadingButton(
                    isLoading: isLoading,
                    text: l10n.ingresar,
                    onPressed: loginUser,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _showFancyForgotPasswordDialog(context),
                  child: Text(
                    l10n.olvidoContrasena,
                    style: AppTextStyles.mensajeSecundario.copyWith(
                      color: AppColors.yellow,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "o",
                          style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white54),
                        ),
                      ),
                      const Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : loginWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2F38),
                        foregroundColor: AppColors.yellow,
                        disabledBackgroundColor: const Color(0xFF22252C),
                        disabledForegroundColor: Colors.white54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      icon: const FaIcon(
                        FontAwesomeIcons.google,
                        color: Colors.red,
                        size: 20,
                      ),
                      label: Text(
                        "Continuar con Google",
                        style: AppTextStyles.button.copyWith(
                          color: isLoading ? Colors.white54 : AppColors.yellow,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
