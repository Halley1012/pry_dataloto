import 'dart:convert';
import 'dart:io';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
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


  static const int _maxFotosTotal = 4;
  static const int _maxFotosGaleria = 3;
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _fotoPrincipalLocal;
  final List<XFile> _galeriaLocal = [];
  String? _fotoPrincipalRemota;
  final List<String> _galeriaRemota = [];
  bool _subiendoImagenes = false;

  // --- Controladores ---
  final tituloController = TextEditingController();
  final descripcionController = TextEditingController();
  final aboutUsController = TextEditingController();
  final galeriaController = TextEditingController();
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

  // Los valores guardados en la BD siguen en español para compatibilidad;
  // únicamente traducimos las etiquetas que se muestran al usuario.
  String _etiquetaDiaAtencion(String valor, AppLocalizations l10n) {
    switch (valor) {
      case 'Todos los días':
        return l10n.horarioTodosLosDias;
      case 'Lunes a Sábado':
        return l10n.horarioLunesASabado;
      case 'Lunes a Viernes':
        return l10n.horarioLunesAViernes;
      case 'Fines de semana':
        return l10n.horarioFinesDeSemana;
      default:
        return valor;
    }
  }

  // Estilo único para los selectores de prefijo de Teléfono y WhatsApp.
  PickerDialogStyle _estiloSelectorTelefonico(AppLocalizations l10n) {
    return PickerDialogStyle(
      backgroundColor: const Color(0xFF17171C),
      width: 460,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      searchFieldPadding: const EdgeInsets.only(bottom: 4),
      listTilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      countryNameStyle: AppTextStyles.mensajeSecundario.copyWith(
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      countryCodeStyle: AppTextStyles.mensajeSecundario.copyWith(
        color: AppColors.yellow,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      listTileDivider: Divider(
        color: Colors.white.withValues(alpha: 0.08),
        height: 1,
        thickness: 0.6,
        indent: 12,
        endIndent: 12,
      ),
      searchFieldCursorColor: AppColors.yellow,
      searchFieldInputDecoration: InputDecoration(
        hintText: l10n.buscarPaisTelefono,
        hintStyle: AppTextStyles.mensajeSecundario.copyWith(
          color: Colors.white54,
          fontSize: 13,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.yellow,
          size: 22,
        ),
        filled: true,
        fillColor: const Color(0xFF25252D),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColors.yellow,
            width: 1.5,
          ),
        ),
      ),
    );
  }

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
  String? _categoryLanguageCode;

  String _selectedCountryCode = '';
  String _selectedWhatsAppCode = '';
  String? _initialCountryCode;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode =
        Localizations.localeOf(context).languageCode.toLowerCase();

    if (_categoryLanguageCode != null &&
        _categoryLanguageCode != languageCode) {
      _categoryLanguageCode = languageCode;
      _reloadCategoriesForLocale(languageCode);
    }
  }

  Future<void> _reloadCategoriesForLocale(String languageCode) async {
    try {
      final categorias = await ApiService.getCategorias(
        languageCode: languageCode,
      );
      if (!mounted || _categoryLanguageCode != languageCode) return;

      setState(() {
        _categorias = categorias;
        if (categoriaSeleccionada != null &&
            !_categorias.any(
              (item) => _toInt(item['id']) == categoriaSeleccionada,
            )) {
          categoriaSeleccionada = null;
        }
      });
    } catch (_) {
      // Si falla el refresco por idioma conservamos el último catálogo visible.
    }
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
    aboutUsController.dispose();
    galeriaController.dispose();
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
      final languageCode =
          Localizations.localeOf(context).languageCode.toLowerCase();
      _categoryLanguageCode = languageCode;

      final results = await Future.wait([
        ApiService.getPaises(),
        ApiService.getCategorias(languageCode: languageCode),
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

      if (dptoIdDefault != null) {
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
    aboutUsController.text = pub["about_us"]?.toString() ?? "";
    final galleryRaw = pub["galeria_urls"];
    if (galleryRaw is List) {
      galeriaController.text = galleryRaw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .join("\n");
    } else {
      galeriaController.text = galleryRaw?.toString() ?? "";
    }
    direccionController.text = pub["direccion"]?.toString() ?? "";
    imagenUrlController.text = pub["imagen_url"]?.toString() ?? "";

    _fotoPrincipalRemota = imagenUrlController.text.trim().isEmpty
        ? null
        : imagenUrlController.text.trim();
    _galeriaRemota
      ..clear()
      ..addAll(_parseGalleryUrls(galeriaController.text).take(_maxFotosGaleria));

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


  List<String> _parseGalleryUrls(String value) {
    return value
        .split(RegExp(r'[\n,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }


  int get _cantidadFotos =>
      ((_fotoPrincipalLocal != null ||
                  (_fotoPrincipalRemota?.trim().isNotEmpty ?? false))
              ? 1
              : 0) +
      _galeriaRemota.length +
      _galeriaLocal.length;

  Future<void> _seleccionarPrincipal(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null || !mounted) return;
      setState(() => _fotoPrincipalLocal = image);
    } catch (_) {
      _mostrarMensaje(
        AppLocalizations.of(context)!.noSeleccionarImagen,
      );
    }
  }

  Future<void> _seleccionarGaleria() async {
    final disponibles = _maxFotosGaleria -
        _galeriaRemota.length -
        _galeriaLocal.length;
    if (disponibles <= 0) {
      _mostrarMensaje(
        AppLocalizations.of(context)!.maxCuatroFotosAnuncio,
      );
      return;
    }

    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (images.isEmpty || !mounted) return;
      final selected = images.take(disponibles).toList();
      setState(() => _galeriaLocal.addAll(selected));
      if (images.length > disponibles) {
        _mostrarMensaje(
          AppLocalizations.of(context)!.fotosAgregadasLimite(disponibles),
        );
      }
    } catch (_) {
      _mostrarMensaje(
        AppLocalizations.of(context)!.noAbrirGaleria,
      );
    }
  }

  void _mostrarMensaje(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: AppTextStyles.mensajeSecundario),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<Map<String, dynamic>> _subirFotosPendientes() async {
    String principal = _fotoPrincipalRemota?.trim() ?? '';
    final galeria = List<String>.from(_galeriaRemota);

    if (_fotoPrincipalLocal != null) {
      principal = await ApiService.uploadPublicidadImage(
        _fotoPrincipalLocal!.path,
        tipo: 'principal',
      );
    }

    for (final image in _galeriaLocal) {
      if (galeria.length >= _maxFotosGaleria) break;
      final url = await ApiService.uploadPublicidadImage(
        image.path,
        tipo: 'galeria',
      );
      galeria.add(url);
    }

    return {
      'principal': principal,
      'galeria': galeria.take(_maxFotosGaleria).toList(),
    };
  }

  ButtonStyle _photoActionButtonStyle({bool destructive = false}) {
    final activeColor = destructive ? Colors.redAccent : AppColors.yellow;

    return OutlinedButton.styleFrom(
      foregroundColor: activeColor,
      disabledForegroundColor: Colors.white38,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      side: BorderSide(
        color: activeColor.withValues(alpha: 0.70),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      textStyle: AppTextStyles.caption2.copyWith(
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _fotosCompactasSection() {
    final local = _fotoPrincipalLocal;
    final remote = _fotoPrincipalRemota?.trim() ?? '';
    final hasImage = local != null || remote.isNotEmpty;
    final galleryCount = _galeriaRemota.length + _galeriaLocal.length;

    Widget mainPreview;
    if (local != null) {
      mainPreview = Image.file(
        File(local.path),
        fit: BoxFit.cover,
        width: 104,
        height: 104,
      );
    } else if (remote.isNotEmpty) {
      mainPreview = Image.network(
        remote,
        fit: BoxFit.cover,
        width: 104,
        height: 104,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.white38,
          size: 32,
        ),
      );
    } else {
      mainPreview = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_photo_alternate_outlined,
            color: AppColors.yellow,
            size: 32,
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.principalLabel,
            style: AppTextStyles.caption2.copyWith(color: Colors.white70),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.fotosAnuncio,
              style: AppTextStyles.mensajeImportante,
            ),
            Text(
              '${_cantidadFotos.clamp(0, _maxFotosTotal)} / $_maxFotosTotal',
              style: AppTextStyles.caption2.copyWith(color: AppColors.yellow),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _subiendoImagenes
                      ? null
                      : () => _seleccionarPrincipal(ImageSource.gallery),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasImage
                            ? Colors.white12
                            : AppColors.yellow.withValues(alpha: 0.55),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: mainPreview,
                  ),
                ),
                if (hasImage)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: _removePhotoButton(
                      () => setState(() {
                        _fotoPrincipalLocal = null;
                        _fotoPrincipalRemota = null;
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 104,
                child: galleryCount == 0
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: (_subiendoImagenes ||
                                _cantidadFotos >= _maxFotosTotal)
                            ? null
                            : _seleccionarGaleria,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.025),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.photo_library_outlined,
                                color: Colors.white54,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                AppLocalizations.of(context)!.agregarGaleria,
                                style: AppTextStyles.caption2.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (int i = 0; i < _galeriaRemota.length; i++)
                            _miniaturaRemotaCompacta(i),
                          for (int i = 0; i < _galeriaLocal.length; i++)
                            _miniaturaLocalCompacta(i),
                          if (_cantidadFotos < _maxFotosTotal)
                            _agregarFotoCompacta(),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 8),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context)!.ayudaFotosAnuncio,
          style: AppTextStyles.caption.copyWith(color: Colors.white54),
        ),
      ],
    );
  }

  Widget _miniaturaRemotaCompacta(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              _galeriaRemota[index],
              width: 88,
              height: 104,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: _removePhotoButton(
              () => setState(() => _galeriaRemota.removeAt(index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniaturaLocalCompacta(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(_galeriaLocal[index].path),
              width: 88,
              height: 104,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: _removePhotoButton(
              () => setState(() => _galeriaLocal.removeAt(index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _agregarFotoCompacta() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _subiendoImagenes ? null : _seleccionarGaleria,
      child: Container(
        width: 76,
        height: 104,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: const Icon(
          Icons.add_photo_alternate_outlined,
          color: AppColors.yellow,
          size: 28,
        ),
      ),
    );
  }

  Widget _fotoPrincipalPicker() {
    final local = _fotoPrincipalLocal;
    final remote = _fotoPrincipalRemota?.trim() ?? '';
    final hasImage = local != null || remote.isNotEmpty;

    Widget preview;
    if (local != null) {
      preview = Image.file(
        File(local.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 190,
      );
    } else if (remote.isNotEmpty) {
      preview = Image.network(
        remote,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 190,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white38),
        ),
      );
    } else {
      preview = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.yellow, size: 42),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.seleccionaFotoPrincipal,
              style: AppTextStyles.mensajeSecundario,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.fotoPrincipal,
          style: AppTextStyles.mensajeImportante,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 190,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.04),
            child: preview,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: _photoActionButtonStyle(),
                onPressed: _subiendoImagenes
                    ? null
                    : () => _seleccionarPrincipal(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  AppLocalizations.of(context)!.galeriaLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption2.copyWith(
                    color: AppColors.yellow,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: _photoActionButtonStyle(),
                onPressed: _subiendoImagenes
                    ? null
                    : () => _seleccionarPrincipal(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(
                  AppLocalizations.of(context)!.camaraLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption2.copyWith(
                    color: AppColors.yellow,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: _photoActionButtonStyle(destructive: true),
                onPressed: (_subiendoImagenes || !hasImage)
                    ? null
                    : () => setState(() {
                          _fotoPrincipalLocal = null;
                          _fotoPrincipalRemota = null;
                        }),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(
                  AppLocalizations.of(context)!.quitarLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption2.copyWith(
                    color: hasImage ? Colors.redAccent : Colors.white38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _galeriaPicker() {
    final total = _galeriaRemota.length + _galeriaLocal.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.galeriaAnuncio,
              style: AppTextStyles.mensajeImportante,
            ),
            Text(
              '${_cantidadFotos.clamp(0, _maxFotosTotal)} / $_maxFotosTotal',
              style: AppTextStyles.caption2.copyWith(color: AppColors.yellow),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (total > 0)
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (int i = 0; i < _galeriaRemota.length; i++)
                  _miniaturaRemota(i),
                for (int i = 0; i < _galeriaLocal.length; i++)
                  _miniaturaLocal(i),
              ],
            ),
          ),
        if (total > 0) const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: _photoActionButtonStyle(),
            onPressed: (_subiendoImagenes || total >= _maxFotosGaleria)
                ? null
                : _seleccionarGaleria,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(
              AppLocalizations.of(context)!.agregarFotos,
              style: AppTextStyles.caption2.copyWith(
                color: AppColors.yellow,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context)!.limiteFotosDetalle,
          style: AppTextStyles.caption.copyWith(color: Colors.white54),
        ),
      ],
    );
  }

  Widget _miniaturaRemota(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _galeriaRemota[index],
              width: 92,
              height: 92,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: _removePhotoButton(
              () => setState(() => _galeriaRemota.removeAt(index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniaturaLocal(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_galeriaLocal[index].path),
              width: 92,
              height: 92,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: _removePhotoButton(
              () => setState(() => _galeriaLocal.removeAt(index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _removePhotoButton(VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.66),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _subiendoImagenes ? null : onTap,
        child: const Padding(
          padding: EdgeInsets.all(5),
          child: Icon(Icons.close, color: Colors.white, size: 16),
        ),
      ),
    );
  }

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

    final hasPrincipal = _fotoPrincipalLocal != null ||
        (_fotoPrincipalRemota?.trim().isNotEmpty ?? false);
    if (!hasPrincipal) {
      _mostrarMensaje(
        AppLocalizations.of(context)!.seleccionaFotoPrincipalPunto,
      );
      return;
    }

    setState(() {
      isSubmitting = true;
      _subiendoImagenes = true;
    });

    try {
      final fotos = await _subirFotosPendientes();
      final imagenPrincipalFinal = fotos['principal']?.toString() ?? '';
      final galeriaFinal = List<String>.from(fotos['galeria'] as List);
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
        "imagen_url": imagenPrincipalFinal,
        "telefono": telefonoCompleto,
        "facebook_url": facebookController.text.trim(),
        "instagram_url": instagramController.text.trim(),
        "whatsapp_url": whatsappFinal,
        "tiktok_url": tiktokController.text.trim(),
        "pagina_url": paginaController.text.trim(),
        "direccion": direccionController.text.trim(),
        "about_us": aboutUsController.text.trim(),
        "galeria_urls": galeriaFinal,
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
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(response["message"] ?? l10n.errorGuardar);
      }
    } catch (e) {
      // Silencioso
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
          _subiendoImagenes = false;
        });
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    tituloController.clear();
    descripcionController.clear();
    aboutUsController.clear();
    galeriaController.clear();
    telefonoController.clear();
    direccionController.clear();
    imagenUrlController.clear();
    facebookController.clear();
    instagramController.clear();
    whatsappController.clear();
    tiktokController.clear();
    paginaController.clear();

    _fotoPrincipalLocal = null;
    _fotoPrincipalRemota = null;
    _galeriaLocal.clear();
    _galeriaRemota.clear();

    setState(() {
      paisSeleccionado = null;
      departamentoSeleccionado = null;
      ciudadSeleccionada = null;
      categoriaSeleccionada = null;
      _departamentos = [];
      _ciudades = [];
      _selectedCountryCode = '';
      _selectedWhatsAppCode = '';
      _initialCountryCode = null;
      descripcionLength = 0;
      _esAtencion24Horas = true;
      _horaApertura = const TimeOfDay(hour: 8, minute: 0);
      _horaCierre = const TimeOfDay(hour: 20, minute: 0);
      _diasAtencion = "Lunes a Sábado";
    });
  }

  bool _mostrarCampoCiudad() {
    // La disponibilidad de ciudades viene del catálogo, no del nombre del país.
    return paisSeleccionado != null && _ciudades.isNotEmpty;
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
                              child: Text(l10n.reintentar),
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
                    _buildTextField(
                      tituloController,
                      l10n.titulo,
                      true,
                      l10n,
                      maxLength: 300,
                    ),
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
                    _buildTextField(
                      aboutUsController,
                      AppLocalizations.of(context)!.sobreNosotros,
                      false,
                      l10n,
                      maxLines: 5,
                      maxLength: 500,
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
                        languageCode: Localizations.localeOf(context).languageCode,
                        pickerDialogStyle: _estiloSelectorTelefonico(l10n),
                        dropdownTextStyle: AppTextStyles.mensajeSecundario,
                        dropdownIcon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.yellow,
                          size: 20,
                        ),
                        cursorColor: AppColors.yellow,
                        disableLengthCheck: true,
                        onCountryChanged: (country) {
                          _selectedCountryCode = '+${country.dialCode}';
                        },
                        onChanged: (phone) {
                          _selectedCountryCode = phone.countryCode;
                          field.didChange(phone.number);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(direccionController, l10n.direccion, true, l10n),
                    const SizedBox(height: 16),
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
                              orElse: () => {"nombre": ""},
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
                    Text(l10n.horarioAtencion, style: AppTextStyles.caption),
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
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time_filled,
                                  color: _esAtencion24Horas
                                      ? const Color(0xFF00E676)
                                      : Colors.white54,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.horarioAtencion24h,
                                    style: AppTextStyles.mensajeSecundario.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                              label: l10n.horarioAperturaLabel,
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
                              label: l10n.horarioCierreLabel,
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
                        decoration: _inputStyle(l10n.horarioDiasAtencionLabel),
                        dropdownColor: AppColors.blackfondo,
                        style: AppTextStyles.mensajeSecundario,
                        items: _opcionesDias
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(
                                    _etiquetaDiaAtencion(d, l10n),
                                    style: AppTextStyles.mensajeSecundario,
                                  ),
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
                        languageCode: Localizations.localeOf(context).languageCode,
                        pickerDialogStyle: _estiloSelectorTelefonico(l10n),
                        dropdownTextStyle: AppTextStyles.mensajeSecundario,
                        dropdownIcon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.yellow,
                          size: 20,
                        ),
                        cursorColor: AppColors.yellow,
                        disableLengthCheck: true,
                        onCountryChanged: (country) {
                          _selectedWhatsAppCode = '+${country.dialCode}';
                        },
                        onChanged: (phone) {
                          _selectedWhatsAppCode = phone.countryCode;
                          field.didChange(phone.number);
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    _fotosCompactasSection(),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : () => _enviarFormulario(l10n),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: const Color(0xFF1E1E1E),
                        disabledBackgroundColor: AppColors.yellow.withValues(alpha: 0.45),
                        minimumSize: const Size(double.infinity, 50),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
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
    int? maxLength,
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
      maxLength: maxLength,
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
    final selectedId = categoriaSeleccionada != null &&
            _categorias.any(
              (e) => _toInt(e['id']) == categoriaSeleccionada,
            )
        ? categoriaSeleccionada
        : null;

    Widget buildCategoryItem(Map<String, dynamic> category) {
      final rawIcon =
          category['icon']?.toString() ??
          category['icono']?.toString();

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _categoryIcon(rawIcon),
            color: AppColors.yellow,
            size: 20,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              category['nombre']?.toString() ?? '',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppTextStyles.mensajeSecundario,
            ),
          ),
        ],
      );
    }

    final validCategories = _categorias
        .where((category) => _toInt(category['id']) != null)
        .toList();

    return DropdownButtonFormField<int>(
      isExpanded: true,
      dropdownColor: AppColors.blackfondo,
      decoration: _inputStyle(l10n.categoria),
      style: AppTextStyles.mensajeSecundario,
      value: selectedId,
      items: validCategories
          .map(
            (category) => DropdownMenuItem<int>(
              value: _toInt(category['id'])!,
              child: buildCategoryItem(category),
            ),
          )
          .toList(),

      // El menú y el campo cerrado no usan exactamente el mismo layout.
      // Esto evita que la opción quede visualmente en blanco al seleccionarla.
      selectedItemBuilder: (context) {
        return validCategories
            .map(
              (category) => Align(
                alignment: Alignment.centerLeft,
                child: buildCategoryItem(category),
              ),
            )
            .toList();
      },

      onChanged: (value) {
        if (!mounted) return;
        setState(() {
          categoriaSeleccionada = value;
        });
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
              style: AppTextStyles.caption.copyWith(
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
                  style: AppTextStyles.mensajeSecundario.copyWith(
                    color: Colors.white,
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
