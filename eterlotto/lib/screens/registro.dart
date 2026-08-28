import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eterlotto/screens/welcome.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eterlotto/styles/colores.dart';
import '../utils/pais_helper.dart';
import 'package:eterlotto/widgets/custom_dialogs.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';



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

    if (!_aceptaTerminos) {
      showEterSnackBar(
        context,
        message: l10n.debesAceptarTerminos,
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    final body = {
      "name": _nameController.text.trim(),
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
      "pais_id": _paisSeleccionado,
      "departamento_id": _departamentoSeleccionado,
      "terms_accepted_at": DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await ApiService.post("/register", body, withAuth: false);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("username", (body["name"] as String?) ?? "");

        if (!mounted) return;

        showEterSnackBar(
          context,
          message: "¡Registro exitoso! Ya puedes iniciar sesión.",
          isSuccess: true,
        );

        Navigator.pushReplacementNamed(context, '/login');
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

    if (widget.isSocialOnboarding && !_aceptaTerminos) {
      showEterSnackBar(
        context,
        message: l10n.debesAceptarTerminos,
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
      const storage = FlutterSecureStorage();

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
              const storage = FlutterSecureStorage();
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
            const storage = FlutterSecureStorage();
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight -
                  50,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                        readOnly: _esEdicion, // ✅ bloqueado en edición
                        validator: (v) => v != null && v.contains("@")
                            ? null
                            : l10n.correoInvalido,
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
                                labelStyle: AppTextStyles.mensajeSecundario,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
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
                                labelStyle: AppTextStyles.mensajeSecundario,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
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

                // 📜 Casilla de Términos y Condiciones (solo en registro / social onboarding)
                if (!_esEdicion || widget.isSocialOnboarding) ...[
                  const SizedBox(height: 16),
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

  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.obscureText = false,
    this.validator,
    this.suffixIcon,
    this.readOnly = false, // 👈 Valor por defecto
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly, // 👈 lo aplicamos aquí
      validator: validator,
      style: AppTextStyles.mensajeSecundario,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: AppTextStyles.mensajeSecundario,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
