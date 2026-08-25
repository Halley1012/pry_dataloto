import 'dart:convert';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shimmer/shimmer.dart';
import '../utils/pais_helper.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';

class CrearPublicidadForm extends StatefulWidget {
  final Map<String, dynamic>? publicidad;
  const CrearPublicidadForm({super.key, this.publicidad});

  @override
  State<CrearPublicidadForm> createState() => _CrearPublicidadFormState();
}

class _CrearPublicidadFormState extends State<CrearPublicidadForm> {
  final _formKey = GlobalKey<FormState>();

  // --- Controladores ---
  final tituloController = TextEditingController();
  final descripcionController = TextEditingController();
  final telefonoController = TextEditingController();
  final direccionController = TextEditingController();
  final imagenUrlController = TextEditingController();
  final facebookController = TextEditingController();
  final instagramController = TextEditingController();
  final whatsappController = TextEditingController();
  final tiktokController = TextEditingController();
  final paginaController = TextEditingController();

  // --- Variables de selección ---
  int? paisSeleccionado;
  int? departamentoSeleccionado;
  int? ciudadSeleccionada;
  int? categoriaSeleccionada;

  List<Map<String, dynamic>> _paises = [];
  List<Map<String, dynamic>> _departamentos = [];
  List<Map<String, dynamic>> _ciudades = [];
  List<Map<String, dynamic>> _categorias = [];

  bool isSubmitting = false;
  bool _isLoading = true;

  String _selectedCountryCode = '+57';
  String _selectedWhatsAppCode = '+57';
  String _initialCountryCode = 'CO';

  // Cache global para countries.json
  static Map<String, String>? _cachedIsoMap;
  static Map<String, String>? _cachedPhoneMap;

  int descripcionLength = 0;
  final int descripcionMax = 90;

  final _storage = const FlutterSecureStorage();
  bool _esEdicion = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosOptimizado();
    descripcionController.addListener(() {
      setState(() => descripcionLength = descripcionController.text.length);
    });

    if (widget.publicidad != null) {
      _esEdicion = true;
      // Precarga después de tener los datos
    }
  }

  @override
  void dispose() {
    tituloController.dispose();
    descripcionController.dispose();
    telefonoController.dispose();
    direccionController.dispose();
    imagenUrlController.dispose();
    facebookController.dispose();
    instagramController.dispose();
    whatsappController.dispose();
    tiktokController.dispose();
    paginaController.dispose();
    super.dispose();
  }

  // OPTIMIZADO: Paralelo + cache + sin delays
  Future<void> _cargarDatosOptimizado() async {
    setState(() => _isLoading = true);

    try {
      // 1. CARGAR EN PARALELO
      final results = await Future.wait([
        ApiService.getPaises(),
        ApiService.getCategorias(),
        _cargarCountriesJson(), // Cacheado
      ]);

      final paisesAPI = results[0] as List<Map<String, dynamic>>;
      final categoriasAPI = results[1] as List<Map<String, dynamic>>;
      final maps = results[2] as Map<String, Map<String, String>>;

      if (paisesAPI.isEmpty || categoriasAPI.isEmpty) {
        throw Exception("Datos vacíos desde el servidor");
      }

      // 2. GUARDAR EN CACHE
      _cachedIsoMap = maps['iso'];
      _cachedPhoneMap = maps['phone'];

      // 3. MAPA RÁPIDO: id → nombre
      final Map<int, String> paisIdToName = {
        for (var p in paisesAPI)
          p['id'] as int: p['nombre'].toString().toLowerCase(),
      };

      if (!mounted) return;
      setState(() {
        _paises = paisesAPI;
        _categorias = categoriasAPI;
      });

      // 4. PAÍS POR DEFECTO (rápido con mapa)
      final paisNombre = await _storage.read(key: "pais_nombre");
      int? paisIdDefault;

      if (paisNombre != null && paisNombre != "Todos") {
        paisIdDefault = paisIdToName.entries
            .firstWhere(
              (e) => e.value.contains(paisNombre.toLowerCase()),
              orElse: () => const MapEntry(-1, ""),
            )
            .key;
        if (paisIdDefault == -1) paisIdDefault = null;
      }

      if (paisIdDefault == null) {
        paisIdDefault = paisIdToName.entries
            .firstWhere(
              (e) => e.value.contains("colombia"),
              orElse: () => const MapEntry(-1, ""),
            )
            .key;
        if (paisIdDefault == -1) paisIdDefault = null;
      }

      // 5. CARGAR DEPARTAMENTOS SI HAY PAÍS
      if (paisIdDefault != null) {
        paisSeleccionado = paisIdDefault;
        final countryName = paisIdToName[paisIdDefault] ?? "colombia";
        _updatePhoneCodes(countryName);
        await _cargarDepartamentos(paisIdDefault);
      }

      // 6. EDICIÓN: Precargar después de tener todo
      if (_esEdicion) {
        _precargarDatosEdicion(paisIdToName);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Carga countries.json con cache
  Future<Map<String, Map<String, String>>> _cargarCountriesJson() async {
    if (_cachedIsoMap != null && _cachedPhoneMap != null) {
      return {'iso': _cachedIsoMap!, 'phone': _cachedPhoneMap!};
    }

    final String jsonString = await rootBundle.loadString(
      'assets/countries/countries.json',
    );
    final List<dynamic> list = jsonDecode(jsonString);

    final isoMap = <String, String>{};
    final phoneMap = <String, String>{};

    for (var c in list) {
      final name = (c['name']?['common'] ?? '').toString().toLowerCase();
      final iso = (c['cca2'] ?? '').toString().toUpperCase();
      final root = (c['idd']?['root'] ?? '').toString();
      final suffixes = c['idd']?['suffixes'] ?? [];
      final prefix = suffixes.isNotEmpty ? '$root${suffixes[0]}' : root;

      if (name.isNotEmpty && iso.isNotEmpty && prefix.isNotEmpty) {
        isoMap[name] = iso;
        phoneMap[name] = prefix;
      }
    }

    _cachedIsoMap = isoMap;
    _cachedPhoneMap = phoneMap;

    return {'iso': isoMap, 'phone': phoneMap};
  }

  void _updatePhoneCodes(String countryName) {
    final iso = _cachedIsoMap?[countryName] ?? 'CO';
    final code = _cachedPhoneMap?[countryName] ?? '+57';
    setState(() {
      _selectedCountryCode = code;
      _selectedWhatsAppCode = code;
      _initialCountryCode = iso;
    });
  }

  Future<void> _cargarDepartamentos(int paisId) async {
    try {
      final data = await ApiService.getDepartamentos(paisId: paisId);
      setState(() {
        _departamentos = data;
        departamentoSeleccionado = null;
        ciudadSeleccionada = null;
        _ciudades = [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error departamentos: $e")));
      }
    }
  }

  Future<void> _cargarCiudades(int departamentoId) async {
    if (!_mostrarCampoCiudad()) {
      setState(() => _ciudades = []);
      return;
    }

    try {
      final data = await ApiService.getCiudadesPorDepartamento(
        departamentoId: departamentoId,
      );
      setState(() {
        _ciudades = data;
        ciudadSeleccionada = null;
      });
    } catch (e) {
      setState(() => _ciudades = []);
    }
  }

  // Precarga edición con mapa rápido
  void _precargarDatosEdicion(Map<int, String> paisIdToName) {
    final pub = widget.publicidad!;
    tituloController.text = pub["titulo"] ?? "";
    descripcionController.text = pub["descripcion"] ?? "";
    direccionController.text = pub["direccion"] ?? "";
    imagenUrlController.text = pub["imagen_url"] ?? "";
    facebookController.text =
        (pub["facebook_url"] as String?)?.replaceFirst(
          "https://www.facebook.com/",
          "",
        ) ??
        "";
    instagramController.text =
        (pub["instagram_url"] as String?)?.replaceFirst(
          "https://www.instagram.com/",
          "",
        ) ??
        "";
    tiktokController.text =
        (pub["tiktok_url"] as String?)?.replaceFirst(
          "https://www.tiktok.com/",
          "",
        ) ??
        "";
    paginaController.text =
        (pub["pagina_url"] as String?)?.replaceFirst("https://", "") ?? "";

    final telefono = pub["telefono"] as String?;
    if (telefono != null && telefono.contains(" ")) {
      final parts = telefono.split(" ");
      _selectedCountryCode = parts[0];
      telefonoController.text = parts
          .sublist(1)
          .join("")
          .replaceAll(RegExp(r'[^\d]'), '');
    }

    final whatsapp = pub["whatsapp_url"] as String?;
    if (whatsapp != null && whatsapp.contains("wa.me/")) {
      final digitos = whatsapp
          .split("wa.me/")
          .last
          .replaceAll(RegExp(r'[^\d]'), '');
      if (digitos.length > 2) {
        final codigoLength = digitos.length > 10 ? 2 : 1;
        final codigo = digitos.substring(0, codigoLength);
        _selectedWhatsAppCode = "+$codigo";
        whatsappController.text = digitos.substring(codigoLength);
      }
    }

    paisSeleccionado = pub["pais_id"];
    departamentoSeleccionado = pub["departamento_id"];
    ciudadSeleccionada = pub["ciudad_id"];
    categoriaSeleccionada = pub["categoria_id"];

    // Actualizar códigos de país
    final countryName = paisIdToName[paisSeleccionado] ?? "colombia";
    _updatePhoneCodes(countryName);

    // Cargar departamentos y ciudades si aplica
    if (paisSeleccionado != null) {
      _cargarDepartamentos(paisSeleccionado!).then((_) {
        if (departamentoSeleccionado != null && _mostrarCampoCiudad()) {
          _cargarCiudades(departamentoSeleccionado!);
        }
      });
    }
  }

  // === RESTO DEL CÓDIGO SIN CAMBIOS (enviar, UI, etc.) ===
  // (Todo igual: _enviarFormulario, _buildTextField, etc.)

  Future<void> _enviarFormulario(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;

    if (paisSeleccionado == null ||
        departamentoSeleccionado == null ||
        categoriaSeleccionada == null)
      return;
    if (_mostrarCampoCiudad() && ciudadSeleccionada == null) return;

    final numeroLimpio = telefonoController.text.trim().replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    if (numeroLimpio.length < 7) return;

    final numeroWhatsAppLimpio = whatsappController.text.trim().replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    if (numeroWhatsAppLimpio.length < 7) return;

    setState(() => isSubmitting = true);

    try {
      final telefonoCompleto = '$_selectedCountryCode $numeroLimpio';
      final codigoLimpio = _selectedWhatsAppCode.replaceAll('+', '');
      final whatsappFinal = '$codigoLimpio$numeroWhatsAppLimpio';

      final data = {
        "pais_id": paisSeleccionado,
        "departamento_id": departamentoSeleccionado,
        "ciudad_id": _mostrarCampoCiudad() ? ciudadSeleccionada : null,
        "categoria_id": categoriaSeleccionada,
        "titulo": tituloController.text.trim(),
        "descripcion": descripcionController.text.trim(),
        "imagen_url": imagenUrlController.text.trim(),
        "telefono": telefonoCompleto,
        "facebook_url": facebookController.text.trim(),
        "instagram_url": instagramController.text.trim(),
        "whatsapp_url": whatsappFinal,
        "tiktok_url": tiktokController.text.trim(),
        "pagina_url": paginaController.text.trim(),
        "direccion": direccionController.text.trim(),
      };

      dynamic response;
      if (_esEdicion) {
        final id = widget.publicidad!["id"];
        response = await ApiService.actualizarPublicidad(id, data);
      } else {
        response = await ApiService.crearPublicidad(data);
      }

      if (response["success"] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _esEdicion ? l10n.anuncioActualizado : l10n.anuncioCreado,
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          if (_esEdicion) {
            Navigator.pop(context, true);
          } else {
            _resetForm();
          }
        }
      } else {
        throw Exception(response["message"] ?? l10n.errorGuardar);
      }
    } catch (e) {
      // Silencioso
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    tituloController.clear();
    descripcionController.clear();
    telefonoController.clear();
    direccionController.clear();
    imagenUrlController.clear();
    facebookController.clear();
    instagramController.clear();
    whatsappController.clear();
    tiktokController.clear();
    paginaController.clear();

    setState(() {
      paisSeleccionado = null;
      departamentoSeleccionado = null;
      ciudadSeleccionada = null;
      categoriaSeleccionada = null;
      _departamentos = [];
      _ciudades = [];
      _selectedCountryCode = '+57';
      _selectedWhatsAppCode = '+57';
      _initialCountryCode = 'CO';
      descripcionLength = 0;
    });
  }

  bool _mostrarCampoCiudad() {
    if (paisSeleccionado == null) return false;
    final nombre = _paises.firstWhere(
      (p) => p['id'] == paisSeleccionado,
      orElse: () => {"nombre": ""},
    )["nombre"];
    return nombre.toString().toLowerCase().contains("colombia");
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      appBar: AppBar(
        backgroundColor: AppColors.blackfondo,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.yellow),
        title: Text(
          _esEdicion ? l10n.editarAnuncio : l10n.crearPublicidad,
          style: AppTextStyles.h2,
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildSkeletonLoader()
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _esEdicion ? l10n.editarAnuncio.toLowerCase() : l10n.crearNuevoAnuncio,
                      style: AppTextStyles.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.promocionaNegocioStyle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.mensajeSecundario.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(tituloController, l10n.titulo, true, l10n),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descripcionController,
                      style: AppTextStyles.mensajeSecundario,
                      decoration: _inputStyle(l10n.descripcion).copyWith(
                        counterText: "$descripcionLength / $descripcionMax",
                      ),
                      maxLength: descripcionMax,
                      maxLines: 4,
                      validator: (v) =>
                          v?.isEmpty ?? true ? l10n.descripcionObligatoria : null,
                    ),
                    const SizedBox(height: 16),
                    FormField<String>(
                      validator: (_) {
                        final n = telefonoController.text.replaceAll(
                          RegExp(r'[^\d]'),
                          '',
                        );
                        return n.length >= 7 ? null : l10n.telefonoObligatorio;
                      },
                      builder: (field) => IntlPhoneField(
                        decoration: _inputStyle(
                          l10n.telefono,
                        ).copyWith(errorText: field.errorText),
                        style: AppTextStyles.mensajeSecundario,
                        initialCountryCode: _initialCountryCode,
                        dropdownTextStyle: AppTextStyles.mensajeSecundario,
                        disableLengthCheck: true,
                        onChanged: (phone) {
                          telefonoController.text = phone.number;
                          _selectedCountryCode = phone.countryCode;
                          field.didChange(phone.number);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(direccionController, l10n.direccion, true, l10n),
                    const SizedBox(height: 16),
                    _buildTextField(imagenUrlController, l10n.imagenUrl, true, l10n),
                    const SizedBox(height: 24),
                    _buildDropdown(l10n.pais, paisSeleccionado, _paises, (val) {
                      setState(() {
                        paisSeleccionado = val;
                        departamentoSeleccionado = null;
                        ciudadSeleccionada = null;
                        _departamentos = [];
                        _ciudades = [];
                      });
                      if (val != null) {
                        _cargarDepartamentos(val);
                        final nombre = _paises
                            .firstWhere(
                              (p) => p['id'] == val,
                              orElse: () => {"nombre": "colombia"},
                            )["nombre"]
                            .toString()
                            .toLowerCase();
                        _updatePhoneCodes(nombre);
                      }
                    }, l10n),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      l10n.estadoProvincia,
                      departamentoSeleccionado,
                      _departamentos,
                      (val) {
                        setState(() {
                          departamentoSeleccionado = val;
                          ciudadSeleccionada = null;
                          _ciudades = [];
                        });
                        if (val != null && _mostrarCampoCiudad())
                          _cargarCiudades(val);
                      },
                      l10n,
                    ),
                    const SizedBox(height: 16),
                    if (_mostrarCampoCiudad())
                      _buildDropdown(
                        l10n.ciudad,
                        ciudadSeleccionada,
                        _ciudades,
                        (val) => setState(() => ciudadSeleccionada = val),
                        l10n,
                      ),
                    if (_mostrarCampoCiudad()) const SizedBox(height: 16),
                    _buildDropdown(
                      l10n.categoria,
                      categoriaSeleccionada,
                      _categorias,
                      (val) => setState(() => categoriaSeleccionada = val),
                      l10n,
                    ),
                    const SizedBox(height: 24),
                    Text(l10n.redesSociales, style: AppTextStyles.caption),
                    const SizedBox(height: 16),
                    _buildTextField(facebookController, "Facebook", false, l10n),
                    const SizedBox(height: 16),
                    _buildTextField(instagramController, "Instagram", false, l10n),
                    const SizedBox(height: 16),
                    _buildTextField(tiktokController, "TikTok", false, l10n),
                    const SizedBox(height: 16),
                    _buildTextField(paginaController, l10n.paginaWeb, false, l10n),
                    const SizedBox(height: 16),
                    FormField<String>(
                      validator: (_) {
                        final n = whatsappController.text.replaceAll(
                          RegExp(r'[^\d]'),
                          '',
                        );
                        return n.length >= 7 ? null : l10n.whatsappObligatorio;
                      },
                      builder: (field) => IntlPhoneField(
                        decoration: _inputStyle(
                          "WhatsApp",
                        ).copyWith(errorText: field.errorText),
                        style: AppTextStyles.mensajeSecundario,
                        initialCountryCode: _initialCountryCode,
                        dropdownTextStyle: AppTextStyles.mensajeSecundario,
                        disableLengthCheck: true,
                        onChanged: (phone) {
                          whatsappController.text = phone.number;
                          _selectedWhatsAppCode = phone.countryCode;
                          field.didChange(phone.number);
                        },
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : () => _enviarFormulario(l10n),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              _esEdicion
                                  ? l10n.guardarCambios
                                  : l10n.crearPublicidad,
                              style: AppTextStyles.button,
                            ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: List.generate(
            8,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String label) => InputDecoration(
    labelText: label,
    labelStyle: AppTextStyles.mensajeSecundario,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
  );

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    bool required,
    AppLocalizations l10n, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      style: AppTextStyles.mensajeSecundario,
      decoration: _inputStyle(label),
      maxLines: maxLines,
      validator: required
          ? (v) => v?.isEmpty ?? true ? l10n.campoRequerido(label) : null
          : null,
    );
  }

  Widget _buildDropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> items,
    Function(int?) onChanged,
    AppLocalizations l10n,
  ) {
    return DropdownButtonFormField<int>(
      dropdownColor: AppColors.blackfondo,
      decoration: _inputStyle(label),
      style: AppTextStyles.mensajeSecundario,
      value: value != null && items.any((e) => e['id'] == value) ? value : null,
      items: items
          .map(
            (e) => DropdownMenuItem<int>(
              value: e['id'],
              child: PaisHelper.buildItemConBandera(
                e['nombre'].toString(),
                style: AppTextStyles.mensajeSecundario,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? l10n.seleccionaCampo(label) : null,
    );
  }
}
