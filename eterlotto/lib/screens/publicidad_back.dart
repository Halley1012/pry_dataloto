import 'dart:convert';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import '../utils/pais_helper.dart';
import '../utils/secure_storage_helper.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';

class CrearPublicidadForm extends StatefulWidget {
  final Map<String, dynamic>? publicidad;
  final int? initialPaisId;
  final int? initialDepartamentoId;
  const CrearPublicidadForm({
    super.key,
    this.publicidad,
    this.initialPaisId,
    this.initialDepartamentoId,
  });

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

  // --- Horarios de Atención ---
  bool _esAtencion24Horas = true;
  TimeOfDay _horaApertura = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _horaCierre = const TimeOfDay(hour: 20, minute: 0);
  String _diasAtencion = "Lunes a Sábado";
  final List<String> _opcionesDias = [
    "Todos los días",
    "Lunes a Sábado",
    "Lunes a Viernes",
    "Fines de semana",
  ];

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
  String? _catalogError;

  int _catalogRequestId = 0;
  int _departamentosRequestId = 0;
  int _ciudadesRequestId = 0;

  String _selectedCountryCode = '+57';
  String _selectedWhatsAppCode = '+57';
  String _initialCountryCode = 'CO';

  // Cache global para countries.json
  static Map<String, String>? _cachedIsoMap;
  static Map<String, String>? _cachedPhoneMap;

  int descripcionLength = 0;
  final int descripcionMax = 90;

  final _storage = AppSecureStorage.instance;
  bool _esEdicion = false;

  @override
  void initState() {
    super.initState();

    _esEdicion = widget.publicidad != null;

    if (_esEdicion) {
      _precargarCamposBasicosEdicion();
    }

    descripcionController.addListener(_onDescripcionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cargarDatosOptimizado();
      }
    });
  }

  void _onDescripcionChanged() {
    if (!mounted) return;
    final next = descripcionController.text.length;
    if (next == descripcionLength) return;
    setState(() => descripcionLength = next);
  }

  @override
  void dispose() {
    descripcionController.removeListener(_onDescripcionChanged);
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

  // Carga de catálogos sin bloquear el formulario.
  Future<void> _cargarDatosOptimizado() async {
    final requestId = ++_catalogRequestId;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _catalogError = null;
      });
    }

    try {
      final results = await Future.wait([
        ApiService.getPaises(),
        ApiService.getCategorias(),
        _cargarCountriesJson(),
      ]);

      if (!mounted || requestId != _catalogRequestId) return;

      final paisesAPI = results[0] as List<Map<String, dynamic>>;
      final categoriasAPI = results[1] as List<Map<String, dynamic>>;
      final maps = results[2] as Map<String, Map<String, String>>;

      _cachedIsoMap = maps['iso'];
      _cachedPhoneMap = maps['phone'];

      if (paisesAPI.isEmpty) {
        throw Exception("No se pudieron cargar los países");
      }

      final Map<int, String> paisIdToName = {
        for (final p in paisesAPI)
          if (_toInt(p['id']) != null)
            _toInt(p['id'])!: p['nombre']?.toString() ?? '',
      };

      int? paisIdDefault =
          _esEdicion ? _toInt(widget.publicidad?['pais_id']) : null;

      if (paisIdDefault == null &&
          widget.initialPaisId != null &&
          paisIdToName.containsKey(widget.initialPaisId)) {
        paisIdDefault = widget.initialPaisId;
      }

      if (paisIdDefault == null) {
        final stored = await _storage.read(key: "pais_id");
        final storedId = int.tryParse(stored ?? '');
        if (storedId != null && paisIdToName.containsKey(storedId)) {
          paisIdDefault = storedId;
        }
      }

      if (paisIdDefault == null) {
        final storedName =
            (await _storage.read(key: "pais_nombre"))?.trim().toLowerCase();
        if (storedName != null && storedName.isNotEmpty) {
          for (final entry in paisIdToName.entries) {
            final apiName = entry.value.trim().toLowerCase();
            if (apiName == storedName ||
                apiName.contains(storedName) ||
                storedName.contains(apiName)) {
              paisIdDefault = entry.key;
              break;
            }
          }
        }
      }

      paisIdDefault ??= paisIdToName.keys.first;

      final countryName = paisIdToName[paisIdDefault] ?? '';
      final countryNorm = countryName.toLowerCase().trim();
      final iso =
          _cachedIsoMap?[countryNorm] ?? PaisHelper.getIsoCode(countryNorm);
      final dial =
          _cachedPhoneMap?[countryNorm] ?? PaisHelper.getDialCode(countryNorm);

      List<Map<String, dynamic>> deps = [];
      int? dptoIdDefault;

      if (paisIdDefault != null) {
        deps = await ApiService.getDepartamentos(paisId: paisIdDefault);
        if (!mounted || requestId != _catalogRequestId) return;

        dptoIdDefault =
            _esEdicion ? _toInt(widget.publicidad?['departamento_id']) : null;

        if (dptoIdDefault != null &&
            !deps.any((d) => _toInt(d['id']) == dptoIdDefault)) {
          dptoIdDefault = null;
        }

        if (dptoIdDefault == null &&
            widget.initialDepartamentoId != null &&
            deps.any(
              (d) => _toInt(d['id']) == widget.initialDepartamentoId,
            )) {
          dptoIdDefault = widget.initialDepartamentoId;
        }

        if (dptoIdDefault == null) {
          final stored = await _storage.read(key: "departamento_id");
          final storedId = int.tryParse(stored ?? '');
          if (storedId != null &&
              deps.any((d) => _toInt(d['id']) == storedId)) {
            dptoIdDefault = storedId;
          }
        }

        if (dptoIdDefault == null) {
          final storedName = (await _storage.read(key: "departamento_nombre"))
              ?.trim()
              .toLowerCase();
          if (storedName != null && storedName.isNotEmpty) {
            for (final d in deps) {
              if ((d['nombre']?.toString() ?? '').trim().toLowerCase() ==
                  storedName) {
                dptoIdDefault = _toInt(d['id']);
                break;
              }
            }
          }
        }
      }

      List<Map<String, dynamic>> cities = [];
      int? cityIdDefault =
          _esEdicion ? _toInt(widget.publicidad?['ciudad_id']) : null;

      final mostrarCiudad = countryNorm.contains('colombia');
      if (mostrarCiudad && dptoIdDefault != null) {
        cities = await ApiService.getCiudadesPorDepartamento(
          departamentoId: dptoIdDefault,
        );
        if (!mounted || requestId != _catalogRequestId) return;

        if (cityIdDefault != null &&
            !cities.any((c) => _toInt(c['id']) == cityIdDefault)) {
          cityIdDefault = null;
        }
      } else {
        cityIdDefault = null;
      }

      int? categoryId =
          _esEdicion ? _toInt(widget.publicidad?['categoria_id']) : null;
      if (categoryId != null &&
          !categoriasAPI.any((c) => _toInt(c['id']) == categoryId)) {
        categoryId = null;
      }

      if (!mounted || requestId != _catalogRequestId) return;
      setState(() {
        _paises = paisesAPI;
        _categorias = categoriasAPI;
        _departamentos = deps;
        _ciudades = cities;

        paisSeleccionado = paisIdDefault;
        departamentoSeleccionado = dptoIdDefault;
        ciudadSeleccionada = cityIdDefault;
        if (_esEdicion) {
          categoriaSeleccionada = categoryId;
        }

        _initialCountryCode = iso;
        _selectedCountryCode = dial;
        _selectedWhatsAppCode = dial;

        _isLoading = false;
        _catalogError = null;
      });

      if (_esEdicion) {
        _normalizarTelefonosEdicion();
      }
    } catch (_) {
      if (!mounted || requestId != _catalogRequestId) return;
      setState(() {
        _isLoading = false;
        _catalogError =
            "No fue posible actualizar los catálogos. Puedes reintentar.";
      });
    }
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  // Carga countries.json con cache
  Future<Map<String, Map<String, String>>> _cargarCountriesJson() async {
    if (_cachedIsoMap != null && _cachedPhoneMap != null) {
      return {'iso': _cachedIsoMap!, 'phone': _cachedPhoneMap!};
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/countries/countries.json',
      );
      final List<dynamic> list = jsonDecode(jsonString);

      final isoMap = <String, String>{};
      final phoneMap = <String, String>{};

      for (var c in list) {
        final commonName = (c['name']?['common'] ?? '').toString().toLowerCase().trim();
        final officialName = (c['name']?['official'] ?? '').toString().toLowerCase().trim();
        final iso = (c['cca2'] ?? '').toString().toUpperCase().trim();
        final root = (c['idd']?['root'] ?? '').toString().trim();
        final suffixes = c['idd']?['suffixes'] ?? [];
        final prefix = suffixes.isNotEmpty ? '$root${suffixes[0]}' : root;

        if (iso.isNotEmpty && prefix.isNotEmpty) {
          if (commonName.isNotEmpty) {
            isoMap[commonName] = iso;
            phoneMap[commonName] = prefix;
          }
          if (officialName.isNotEmpty) {
            isoMap[officialName] = iso;
            phoneMap[officialName] = prefix;
          }
          final spaCommon = (c['translations']?['spa']?['common'] ?? '').toString().toLowerCase().trim();
          final spaOfficial = (c['translations']?['spa']?['official'] ?? '').toString().toLowerCase().trim();
          if (spaCommon.isNotEmpty) {
            isoMap[spaCommon] = iso;
            phoneMap[spaCommon] = prefix;
          }
          if (spaOfficial.isNotEmpty) {
            isoMap[spaOfficial] = iso;
            phoneMap[spaOfficial] = prefix;
          }
        }
      }

      _cachedIsoMap = isoMap;
      _cachedPhoneMap = phoneMap;

      return {'iso': isoMap, 'phone': phoneMap};
    } catch (_) {
      return {'iso': {}, 'phone': {}};
    }
  }

  void _updatePhoneCodes(String countryName) {
    final norm = countryName.toLowerCase().trim();
    final iso = _cachedIsoMap?[norm] ?? PaisHelper.getIsoCode(norm);
    final code = _cachedPhoneMap?[norm] ?? PaisHelper.getDialCode(norm);

    if (!mounted) {
      _selectedCountryCode = code;
      _selectedWhatsAppCode = code;
      _initialCountryCode = iso;
      return;
    }

    setState(() {
      _selectedCountryCode = code;
      _selectedWhatsAppCode = code;
      _initialCountryCode = iso;
    });
  }

  Future<void> _cargarDepartamentos(int paisId) async {
    final requestId = ++_departamentosRequestId;

    try {
      final data = await ApiService.getDepartamentos(paisId: paisId);
      if (!mounted ||
          requestId != _departamentosRequestId ||
          paisSeleccionado != paisId) {
        return;
      }

      setState(() {
        _departamentos = data;
      });
    } catch (_) {
      if (!mounted ||
          requestId != _departamentosRequestId ||
          paisSeleccionado != paisId) {
        return;
      }
      setState(() => _departamentos = []);
    }
  }

  Future<void> _cargarCiudades(int departamentoId) async {
    if (!_mostrarCampoCiudad()) {
      if (mounted) {
        setState(() {
          _ciudades = [];
          ciudadSeleccionada = null;
        });
      }
      return;
    }

    final requestId = ++_ciudadesRequestId;

    try {
      final data = await ApiService.getCiudadesPorDepartamento(
        departamentoId: departamentoId,
      );

      if (!mounted ||
          requestId != _ciudadesRequestId ||
          departamentoSeleccionado != departamentoId) {
        return;
      }

      setState(() {
        _ciudades = data;
      });
    } catch (_) {
      if (!mounted ||
          requestId != _ciudadesRequestId ||
          departamentoSeleccionado != departamentoId) {
        return;
      }
      setState(() => _ciudades = []);
    }
  }

  void _precargarCamposBasicosEdicion() {
    final pub = widget.publicidad;
    if (pub == null) return;

    String cleanSocial(dynamic value, String prefix) {
      final raw = value?.toString() ?? '';
      return raw.replaceFirst(prefix, '').replaceFirst('https://', '');
    }

    tituloController.text = pub["titulo"]?.toString() ?? "";
    descripcionController.text = pub["descripcion"]?.toString() ?? "";
    descripcionLength = descripcionController.text.length;
    direccionController.text = pub["direccion"]?.toString() ?? "";
    imagenUrlController.text = pub["imagen_url"]?.toString() ?? "";

    facebookController.text = cleanSocial(
      pub["facebook_url"],
      "https://www.facebook.com/",
    );
    instagramController.text = cleanSocial(
      pub["instagram_url"],
      "https://www.instagram.com/",
    );
    tiktokController.text = cleanSocial(
      pub["tiktok_url"],
      "https://www.tiktok.com/",
    );

    paginaController.text =
        (pub["pagina_url"]?.toString() ?? '').replaceFirst("https://", "");

    paisSeleccionado = _toInt(pub["pais_id"]);
    departamentoSeleccionado = _toInt(pub["departamento_id"]);
    ciudadSeleccionada = _toInt(pub["ciudad_id"]);
    categoriaSeleccionada = _toInt(pub["categoria_id"]);

    final telefono = pub["telefono"]?.toString().trim();
    if (telefono != null && telefono.isNotEmpty) {
      if (telefono.contains(" ")) {
        final parts = telefono.split(RegExp(r'\s+'));
        if (parts.first.startsWith('+')) {
          _selectedCountryCode = parts.first;
          telefonoController.text = parts
              .skip(1)
              .join("")
              .replaceAll(RegExp(r'[^\d]'), '');
        } else {
          telefonoController.text =
              telefono.replaceAll(RegExp(r'[^\d]'), '');
        }
      } else {
        telefonoController.text =
            telefono.replaceAll(RegExp(r'[^\d]'), '');
      }
    }

    final whatsappRaw = pub["whatsapp_url"]?.toString() ?? '';
    if (whatsappRaw.isNotEmpty) {
      whatsappController.text =
          whatsappRaw.replaceAll(RegExp(r'[^\d]'), '');
    }

    if (pub["es_24_7"] != null) {
      _esAtencion24Horas = pub["es_24_7"] == true;
    }

    final apertura = pub["hora_apertura"]?.toString();
    if (apertura != null && apertura.contains(":")) {
      final parts = apertura.split(":");
      _horaApertura = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

    final cierre = pub["hora_cierre"]?.toString();
    if (cierre != null && cierre.contains(":")) {
      final parts = cierre.split(":");
      _horaCierre = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 20,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

    final dias = pub["dias_atencion"]?.toString();
    if (dias != null && dias.isNotEmpty && _opcionesDias.contains(dias)) {
      _diasAtencion = dias;
    }
  }

  void _normalizarTelefonosEdicion() {
    if (!_esEdicion || !mounted) return;

    final dialDigits = _selectedCountryCode.replaceAll(RegExp(r'[^\d]'), '');
    if (dialDigits.isEmpty) return;

    final waDigits = whatsappController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (waDigits.startsWith(dialDigits) &&
        waDigits.length > dialDigits.length + 6) {
      whatsappController.text = waDigits.substring(dialDigits.length);
    }

    final telDigits = telefonoController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (telDigits.startsWith(dialDigits) &&
        telDigits.length > dialDigits.length + 6) {
      telefonoController.text = telDigits.substring(dialDigits.length);
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

      final horaAperturaStr = "${_horaApertura.hour.toString().padLeft(2, '0')}:${_horaApertura.minute.toString().padLeft(2, '0')}";
      final horaCierreStr = "${_horaCierre.hour.toString().padLeft(2, '0')}:${_horaCierre.minute.toString().padLeft(2, '0')}";

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
        "es_24_7": _esAtencion24Horas,
        "hora_apertura": _esAtencion24Horas ? "00:00" : horaAperturaStr,
        "hora_cierre": _esAtencion24Horas ? "23:59" : horaCierreStr,
        "dias_atencion": _esAtencion24Horas ? "Todos los días" : _diasAtencion,
        "estado_texto": _esAtencion24Horas ? "Abierto 24/7" : "Abierto ahora",
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
      _esAtencion24Horas = true;
      _horaApertura = const TimeOfDay(hour: 8, minute: 0);
      _horaCierre = const TimeOfDay(hour: 20, minute: 0);
      _diasAtencion = "Lunes a Sábado";
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
      body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                    if (_isLoading) ...[
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: AppColors.yellow,
                        backgroundColor: Colors.white10,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_catalogError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orangeAccent),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              color: Colors.orangeAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _catalogError!,
                                style: AppTextStyles.mensajeSecundario,
                              ),
                            ),
                            TextButton(
                              onPressed: _cargarDatosOptimizado,
                              child: const Text("Reintentar"),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
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
                      style: AppTextStyles.mensajeSecundario.copyWith(
                        decoration: TextDecoration.none,
                        decorationThickness: 0,
                        decorationColor: Colors.transparent,
                      ),
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
                        key: ValueKey("telefono_$_initialCountryCode"),
                        controller: telefonoController,
                        decoration: _inputStyle(
                          l10n.telefono,
                        ).copyWith(errorText: field.errorText),
                        style: AppTextStyles.mensajeSecundario,
                        initialCountryCode: _initialCountryCode,
                        dropdownTextStyle: AppTextStyles.mensajeSecundario,
                        disableLengthCheck: true,
                        onChanged: (phone) {
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
                    _buildCategoryDropdown(l10n),

                    // --- SECCIÓN HORARIOS DE ATENCIÓN ---
                    const SizedBox(height: 24),
                    Text("Horario de Atención", style: AppTextStyles.caption),
                    const SizedBox(height: 12),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _esAtencion24Horas
                              ? const Color(0xFF00E676).withValues(alpha: 0.4)
                              : Colors.white12,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_filled,
                                color: _esAtencion24Horas ? const Color(0xFF00E676) : Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Atención 24 Horas (24/7)",
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _esAtencion24Horas,
                            activeThumbColor: const Color(0xFF00E676),
                            activeTrackColor: const Color(0xFF00E676).withValues(alpha: 0.3),
                            inactiveThumbColor: Colors.white54,
                            inactiveTrackColor: Colors.white12,
                            onChanged: (val) => setState(() => _esAtencion24Horas = val),
                          ),
                        ],
                      ),
                    ),

                    if (!_esAtencion24Horas) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimePickerTile(
                              label: "Apertura",
                              time: _horaApertura,
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _horaApertura,
                                  builder: (context, child) => Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: AppColors.yellow,
                                        surface: Color(0xFF1E1E24),
                                      ),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _horaApertura = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTimePickerTile(
                              label: "Cierre",
                              time: _horaCierre,
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _horaCierre,
                                  builder: (context, child) => Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: AppColors.yellow,
                                        surface: Color(0xFF1E1E24),
                                      ),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _horaCierre = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _diasAtencion,
                        decoration: _inputStyle("Días de atención"),
                        dropdownColor: AppColors.blackfondo,
                        style: AppTextStyles.mensajeSecundario,
                        items: _opcionesDias
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d, style: AppTextStyles.mensajeSecundario),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _diasAtencion = val);
                        },
                      ),
                    ],

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
                        key: ValueKey("whatsapp_$_initialCountryCode"),
                        controller: whatsappController,
                        decoration: _inputStyle(
                          "WhatsApp",
                        ).copyWith(errorText: field.errorText),
                        style: AppTextStyles.mensajeSecundario,
                        initialCountryCode: _initialCountryCode,
                        dropdownTextStyle: AppTextStyles.mensajeSecundario,
                        disableLengthCheck: true,
                        onChanged: (phone) {
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
            ),
            ),
            ),
    );
  }

  InputDecoration _inputStyle(String label) => InputDecoration(
    labelText: label,
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
      style: AppTextStyles.mensajeSecundario.copyWith(
        decoration: TextDecoration.none,
        decorationThickness: 0,
        decorationColor: Colors.transparent,
      ),
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

  Widget _buildCategoryDropdown(AppLocalizations l10n) {
    return DropdownButtonFormField<int>(
      dropdownColor: AppColors.blackfondo,
      decoration: _inputStyle(l10n.categoria),
      style: AppTextStyles.mensajeSecundario,
      value: categoriaSeleccionada != null &&
              _categorias.any(
                (e) => _toInt(e['id']) == categoriaSeleccionada,
              )
          ? categoriaSeleccionada
          : null,
      items: _categorias
          .map((category) {
            final id = _toInt(category['id']);
            if (id == null) return null;

            final rawIcon =
                category['icon']?.toString() ??
                category['icono']?.toString();

            return DropdownMenuItem<int>(
              value: id,
              child: Row(
                children: [
                  Icon(
                    _categoryIcon(rawIcon),
                    color: AppColors.yellow,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category['nombre']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mensajeSecundario,
                    ),
                  ),
                ],
              ),
            );
          })
          .whereType<DropdownMenuItem<int>>()
          .toList(),
      onChanged: (value) {
        if (!mounted) return;
        setState(() => categoriaSeleccionada = value);
      },
      validator: (value) =>
          value == null ? l10n.seleccionaCampo(l10n.categoria) : null,
    );
  }

  IconData _categoryIcon(String? rawName) {
    final name = rawName?.trim().toLowerCase();

    const map = <String, IconData>{
      'restaurant': Icons.restaurant,
      'restaurants': Icons.restaurant,
      'coffee': Icons.coffee,
      'local_cafe': Icons.local_cafe,
      'local_bar': Icons.local_bar,
      'fastfood': Icons.fastfood,
      'fast_food': Icons.fastfood,
      'hotel': Icons.hotel,
      'travel_explore': Icons.travel_explore,
      'flight': Icons.flight,
      'directions_car': Icons.directions_car,
      'local_taxi': Icons.local_taxi,
      'two_wheeler': Icons.two_wheeler,
      'local_shipping': Icons.local_shipping,
      'health_and_safety': Icons.health_and_safety,
      'medical_services': Icons.medical_services,
      'dentistry': Icons.medical_services,
      'local_pharmacy': Icons.local_pharmacy,
      'spa': Icons.spa,
      'fitness_center': Icons.fitness_center,
      'pets': Icons.pets,
      'school': Icons.school,
      'computer': Icons.computer,
      'devices': Icons.devices,
      'phone_android': Icons.phone_android,
      'store': Icons.store,
      'shopping_cart': Icons.shopping_cart,
      'shopping_bag': Icons.shopping_bag,
      'local_grocery_store': Icons.local_grocery_store,
      'agriculture': Icons.agriculture,
      'grass': Icons.grass,
      'palette': Icons.palette,
      'build': Icons.build,
      'handyman': Icons.handyman,
      'settings': Icons.settings,
      'home': Icons.home,
      'business': Icons.business,
      'business_center': Icons.business_center,
      'account_balance': Icons.account_balance,
      'attach_money': Icons.attach_money,
      'sports_soccer': Icons.sports_soccer,
      'celebration': Icons.celebration,
      'local_laundry_service': Icons.local_laundry_service,
      'content_cut': Icons.content_cut,
      'cleaning_services': Icons.cleaning_services,
      'construction': Icons.construction,
    };

    return map[name] ?? Icons.category_outlined;
  }

  Widget _buildTimePickerTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    final formattedTime = time.format(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedTime,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.schedule, color: AppColors.yellow, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
