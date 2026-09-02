import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:eterlotto/screens/welcome.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../utils/secure_storage_helper.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eterlotto/styles/colores.dart';
import '../utils/pais_helper.dart';
import 'package:eterlotto/widgets/custom_dialogs.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'resultados/widgets/resultados_shared.dart';
import 'package:eterlotto/widgets/user_balota_avatar.dart';



class RegistroScreen extends StatefulWidget {
  final Map<String, dynamic>? user; // Para edición u onboarding
  final int? userId; // ID del usuario (para PUT)
  final bool isSocialOnboarding;

  const RegistroScreen({
    super.key,
    this.user,
    this.userId,
    this.isSocialOnboarding = false,
  });

  @override
  State<RegistroScreen> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _aceptaTerminos = false;
  bool _esMayorEdad = false;

  // Nuevos estados
  List<dynamic> _paises = [];
  List<dynamic> _departamentos = [];
  int? _paisSeleccionado;
  int? _departamentoSeleccionado;
  bool _cargandoPaises = true;
  bool _cargandoDepartamentos = false;

  // Determina si es edición
  bool get _esEdicion => widget.user != null;

  @override
  void initState() {
    super.initState();
    _cargarDatosInicialesOptimizado();
  }

  // 🚀 CARGAR EN PARALELO PAÍSES Y DEPARTAMENTOS
  Future<void> _cargarDatosInicialesOptimizado() async {
    if (_esEdicion) {
      final u = widget.user!;
      _nameController.text = u['name']?.toString() ?? '';
      _emailController.text = u['email']?.toString() ?? '';
      _paisSeleccionado = u['pais_id'] as int?;
      _departamentoSeleccionado = u['departamento_id'] as int?;
    }

    if (!mounted) return;
    setState(() {
      _cargandoPaises = true;
      if (_paisSeleccionado != null) _cargandoDepartamentos = true;
    });

    try {
      final results = await Future.wait([
        ApiService.getPaises(),
        if (_paisSeleccionado != null)
          ApiService.getDepartamentosPorPais(_paisSeleccionado!)
        else
          Future.value(<dynamic>[]),
      ]);

      if (!mounted) return;

      setState(() {
        _paises = results[0];
        if (_paisSeleccionado != null) {
          _departamentos = results[1];
        }
        _cargandoPaises = false;
        _cargandoDepartamentos = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoPaises = false;
        _cargandoDepartamentos = false;
      });
    }
  }

  // Cargar departamentos al cambiar de país
  Future<void> _cargarDepartamentos(int paisId) async {
    if (!mounted) return;
    setState(() {
      _cargandoDepartamentos = true;
      _departamentos = [];
    });
    try {
      final departamentos = await ApiService.getDepartamentosPorPais(paisId);
      if (!mounted) return;
      setState(() {
        _departamentos = departamentos;
        _departamentoSeleccionado = null;
      });
    } catch (e) {
      // Error silencioso
    } finally {
      if (mounted) setState(() => _cargandoDepartamentos = false);
    }
  }

  // Validación de formato de correo y sugerencia de typos
  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return "El correo es requerido";
    final email = v.trim().toLowerCase();
    final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    if (!emailRegex.hasMatch(email)) {
      return "Ingresa un correo electrónico válido";
    }
    final domain = email.contains('@') ? email.split('@').last : '';
    final typos = {
      'gamil.com': 'gmail.com',
      'gmai.com': 'gmail.com',
      'gmial.com': 'gmail.com',
      'gmaill.com': 'gmail.com',
      'gemail.com': 'gmail.com',
      'hotmial.com': 'hotmail.com',
      'hotmai.com': 'hotmail.com',
      'homail.com': 'hotmail.com',
      'outlok.com': 'outlook.com',
      'outloo.com': 'outlook.com',
      'yahuo.com': 'yahoo.com',
      'yaho.com': 'yahoo.com',
    };
    if (typos.containsKey(domain)) {
      return "¿Quisiste decir @${typos[domain]}?";
    }
    return null;
  }

  // Diálogo interactivo para ingresar el código OTP de verificación de correo
  void _showEmailVerificationDialog(BuildContext context, String email, String name) {
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
                      SizedBox(
                        width: double.infinity,
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
                                  final finalName = userMap?['name']?.toString() ?? name;
                                  final finalEmail = userMap?['email']?.toString() ?? email;

                                  await storage.write(key: "name", value: finalName);
                                  await storage.write(key: "email", value: finalEmail);

                                  if (userMap != null) {
                                    if (userMap['id'] != null) await storage.write(key: "user_id", value: userMap['id'].toString());
                                    if (userMap['pais_id'] != null) await storage.write(key: "pais_id", value: userMap['pais_id'].toString());
                                    if (userMap['pais_nombre'] != null) await storage.write(key: "pais_nombre", value: userMap['pais_nombre'].toString());
                                    if (userMap['departamento_id'] != null) await storage.write(key: "departamento_id", value: userMap['departamento_id'].toString());
                                    if (userMap['departamento_nombre'] != null) await storage.write(key: "departamento_nombre", value: userMap['departamento_nombre'].toString());
                                    if (userMap['avatar_url'] != null) await storage.write(key: "avatar_url", value: userMap['avatar_url'].toString());
                                  }

                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString("username", finalName);

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
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: dialogLoading
                                ? null
                                : () {
                                    Navigator.pop(dialogCtx);
                                    showEterSnackBar(
                                      context,
                                      message: "Tu cuenta quedó pendiente de activación. Podrás activarla al iniciar sesión.",
                                    );
                                    Navigator.pushReplacementNamed(context, '/login');
                                  },
                            child: Text(
                              "Cancelar",
                              style: AppTextStyles.caption.copyWith(color: Colors.white54),
                            ),
                          ),
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

  // Registro de usuario
  void _registerUser() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final l10n = AppLocalizations.of(context)!;

    if (_paisSeleccionado == null || _departamentoSeleccionado == null) {
      showEterSnackBar(
        context,
        message: _paisSeleccionado == null
            ? l10n.seleccionaPais
            : l10n.seleccionaDepartamento,
        isError: true,
      );
      return;
    }

    if (!_esMayorEdad) {
      showEterSnackBar(
        context,
        message: "Debes confirmar que eres mayor de 18 años para registrarte",
        isError: true,
      );
      return;
    }

    if (!_aceptaTerminos) {
      showEterSnackBar(
        context,
        message: l10n.debesAceptarTerminos,
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    final userEmail = _emailController.text.trim();
    final userName = _nameController.text.trim();

    final body = {
      "name": userName,
      "email": userEmail,
      "password": _passwordController.text.trim(),
      "pais_id": _paisSeleccionado,
      "departamento_id": _departamentoSeleccionado,
      "is_adult": _esMayorEdad,
      "terms_accepted_at": DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await ApiService.post("/register", body, withAuth: false);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        showEterSnackBar(
          context,
          message: "Código de activación enviado a $userEmail",
          isSuccess: true,
        );

        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;
        // Abrir el diálogo para ingresar el código de verificación
        _showEmailVerificationDialog(context, userEmail, userName);
      } else {
        String errorMsg = "Error al registrar usuario";
        try {
          final data = jsonDecode(response.body);
          if (data is Map) {
            if (data["detail"] != null) {
              errorMsg = data["detail"].toString();
            } else if (data["message"] != null) {
              errorMsg = data["message"].toString();
            }
          }
        } catch (_) {}

        if (!mounted) return;

        showEterSnackBar(
          context,
          message: errorMsg,
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showEterSnackBar(
        context,
        message: "${l10n.errorConexion}: $e",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Actualizar usuario (edición u onboarding social)
  void _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;

    if (widget.isSocialOnboarding && (!_esMayorEdad || !_aceptaTerminos)) {
      showEterSnackBar(
        context,
        message: !_esMayorEdad
            ? "Debes confirmar que eres mayor de 18 años para continuar"
            : l10n.debesAceptarTerminos,
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    final updateData = <String, dynamic>{};
    if (_nameController.text.trim().isNotEmpty) {
      updateData['name'] = _nameController.text.trim();
    }
    if (_paisSeleccionado != null) {
      updateData['pais_id'] = _paisSeleccionado;
    }
    if (_departamentoSeleccionado != null) {
      updateData['departamento_id'] = _departamentoSeleccionado;
    }
    if (widget.isSocialOnboarding) {
      updateData['is_adult'] = _esMayorEdad;
      updateData['terms_accepted_at'] = DateTime.now().toUtc().toIso8601String();
    }

    if (updateData.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final result = await ApiService.updateUser(widget.userId!, updateData);

      if (!mounted) return; // Evita usar context si el widget ya se cerró

      // Actualizamos almacenamiento local
      final updatedUser = result['user'];
      final storage = AppSecureStorage.instance;

      if (updatedUser != null) {
        await storage.write(key: 'name', value: updatedUser['name']);
        await storage.write(key: 'email', value: updatedUser['email']);
        await storage.write(
          key: 'pais_id',
          value: updatedUser['pais_id']?.toString() ?? '',
        );
        await storage.write(
          key: 'pais_nombre',
          value: updatedUser['pais_nombre'] ?? '',
        );
        await storage.write(
          key: 'departamento_id',
          value: updatedUser['departamento_id']?.toString() ?? '',
        );
        await storage.write(
          key: 'departamento_nombre',
          value: updatedUser['departamento_nombre'] ?? '',
        );

        // 🔥 Sincronizar token FCM con el país/perfil actualizado
        PushNotificationService.syncToken();
      }

      if (!mounted) return;

      showEterSnackBar(
        context,
        message: "Perfil actualizado correctamente",
        isSuccess: true,
      );

      if (widget.isSocialOnboarding) {
        Navigator.pushNamedAndRemoveUntil(context, "/home", (route) => false);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      showEterSnackBar(
        context,
        message: "Error al actualizar perfil: $e",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String titulo = _esEdicion 
        ? l10n.editarPerfil 
        : l10n.registrarse;

    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      appBar: AppBar(
        backgroundColor: AppColors.blackfondo,
        scrolledUnderElevation: 0, // 👈 evita cambio de color
        surfaceTintColor: Colors.transparent, // 👈 mantiene color estable
        iconTheme: const IconThemeData(color: AppColors.yellow),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 30),
          onPressed: () async {
            if (widget.isSocialOnboarding) {
              final storage = AppSecureStorage.instance;
              await storage.deleteAll();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              );
            }
          },
        ),
        title: Text(titulo, style: AppTextStyles.h2),
        centerTitle: true,
      ),
      body: PopScope(
        canPop: !widget.isSocialOnboarding,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (widget.isSocialOnboarding) {
            final storage = AppSecureStorage.instance;
            await storage.deleteAll();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                (route) => false,
              );
            }
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      kToolbarHeight -
                      100,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                if (_esEdicion) ...[
                  Center(
                    child: UserBalotaAvatar(
                      avatarUrl: widget.user?['avatar_url'],
                      userName: widget.user?['name']?.toString() ?? '',
                      userId: widget.userId ?? 0,
                      radius: 50,
                      showGlow: true,
                      showBorder: true,
                      borderColor: AppColors.yellow,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  _esEdicion 
                      ? l10n.actualizaTusDatos 
                      : l10n.bienvenido,
                  style: AppTextStyles.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _esEdicion
                      ? l10n.modificaInformacion
                      : l10n.registroUsuario,
                  style: AppTextStyles.mensajeSecundario,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // FORMULARIO
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 👤 Usuario → editable siempre
                      CustomTextFormField(
                        controller: _nameController,
                        labelText: l10n.nombre,
                        readOnly: false, // ✅ siempre editable
                        validator: (v) => v != null && v.isNotEmpty
                            ? null
                            : l10n.usuarioRequerido,
                      ),
                      const SizedBox(height: 16),

                      // 📧 Correo electrónico → editable solo en registro
                      CustomTextFormField(
                        controller: _emailController,
                        labelText: l10n.email,
                        keyboardType: TextInputType.emailAddress,
                        readOnly: _esEdicion, // ✅ bloqueado en edición
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),

                      // 🔒 Contraseña → solo aparece en registro
                      if (!_esEdicion) ...[
                        CustomTextFormField(
                          controller: _passwordController,
                          labelText: l10n.contrasena,
                          obscureText: _obscurePassword,
                          validator: (v) => v != null && v.length >= 6
                              ? null
                              : l10n.contrasenaMinima,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.yellow,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ],

                      if (!_esEdicion) const SizedBox(height: 16),

                      // País
                      _cargandoPaises
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  color: AppColors.yellow,
                                ),
                              ),
                            )
                          : DropdownButtonFormField<int>(
                              dropdownColor: AppColors.blackfondo,
                              decoration: InputDecoration(
                                labelText: l10n.pais,
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
                              style: AppTextStyles.mensajeSecundario,
                              value: _paisSeleccionado,
                              items: _paises
                                  .map(
                                    (p) => DropdownMenuItem<int>(
                                      value: p["id"],
                                      child: PaisHelper.buildItemConBandera(
                                        p["nombre"].toString(),
                                        style: AppTextStyles.mensajeSecundario,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _paisSeleccionado = val;
                                  _departamentos = [];
                                  _departamentoSeleccionado = null;
                                });
                                if (val != null) _cargarDepartamentos(val);
                              },
                              validator: (v) =>
                                  v == null ? l10n.seleccionaPais : null,
                            ),

                      const SizedBox(height: 16),

                      // Departamento
                      _cargandoDepartamentos
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  color: Colors.amber,
                                ),
                              ),
                            )
                          : DropdownButtonFormField<int>(
                              dropdownColor: const Color(0xFF121212),
                              decoration: InputDecoration(
                                labelText: l10n.departamentoEstado,
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
                              style: AppTextStyles.mensajeSecundario,
                              value: _departamentoSeleccionado,
                              items: _departamentos
                                  .map(
                                    (d) => DropdownMenuItem<int>(
                                      value: d["id"],
                                      child: Text(
                                        d["nombre"].toString(),
                                        style: AppTextStyles.mensajeSecundario,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) => setState(
                                () => _departamentoSeleccionado = val,
                              ),
                              validator: (v) => v == null
                                  ? l10n.seleccionaDepartamento
                                  : null,
                            ),
                    ],
                  ),
                ),

                // 📜 Casillas de Mayoría de Edad y Términos (solo en registro / social onboarding)
                if (!_esEdicion || widget.isSocialOnboarding) ...[
                  const SizedBox(height: 16),
                  // 🔞 Mayor de 18 años
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _esMayorEdad,
                        activeColor: AppColors.yellow,
                        checkColor: AppColors.blackfondo,
                        side: const BorderSide(color: Colors.white54, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() => _esMayorEdad = val ?? false);
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _esMayorEdad = !_esMayorEdad);
                          },
                          child: Text(
                            "Declaro que soy mayor de 18 años (+18)",
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 📄 Términos y Condiciones
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _aceptaTerminos,
                        activeColor: AppColors.yellow,
                        checkColor: AppColors.blackfondo,
                        side: const BorderSide(color: Colors.white54, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() => _aceptaTerminos = val ?? false);
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            showJustifiedDialog(
                              context,
                              l10n.avisoLegal,
                              l10n.contenidoAvisoLegal,
                            );
                          },
                          child: Text.rich(
                            TextSpan(
                              text: l10n.aceptoLos,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                              ),
                              children: [
                                TextSpan(
                                  text: l10n.terminosCondicionesAviso,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.yellow,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.yellow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                LoadingButton(
                  isLoading: _isLoading,
                  text: _esEdicion ? l10n.guardarCambios : l10n.registrarse,
                  onPressed: _esEdicion ? _updateUser : _registerUser,
                ),

                const SizedBox(height: 20),

                // Solo mostrar enlace a login si es registro
                if (!_esEdicion)
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: Text(
                      l10n.yaTienesCuenta,
                      style: AppTextStyles.mensajeImportante,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
    ),
  );
}
}

// Campo de texto reutilizable
class CustomTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool readOnly; // 👈 Nuevo
  final TextInputType? keyboardType;

  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.obscureText = false,
    this.validator,
    this.suffixIcon,
    this.readOnly = false, // 👈 Valor por defecto
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly, // 👈 lo aplicamos aquí
      validator: validator,
      keyboardType: keyboardType,
      enableSuggestions: false,
      autocorrect: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      style: AppTextStyles.mensajeSecundario.copyWith(
        decoration: TextDecoration.none,
        decorationThickness: 0,
        decorationColor: Colors.transparent,
      ),
      decoration: InputDecoration(
        labelText: labelText,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
