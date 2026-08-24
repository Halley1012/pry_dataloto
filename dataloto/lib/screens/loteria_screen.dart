import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';
import 'package:dataloto/screens/estadisticas_dashboard_screen.dart';
import 'package:dataloto/screens/jugadas/mis_jugadas_screen.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/services/cache_service.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/utils/pais_helper.dart';
import 'package:dataloto/widgets/contenedor3.dart';
import 'package:dataloto/widgets/lottery_avatar_3d.dart';

/// Configuración de reglas y límites de cada lotería
/// Configuración de reglas y límites de cada lotería
class LoteriaConfig {
  final String nombre;
  final String route;
  final int maxSeleccion;
  final int maxBalotasBlancas;
  final int maxBalotasRojas;
  final String superbalotaNombre;
  final bool hasRevancha;
  final int totalBalotasSorteo;
  final bool tieneComplementario;

  const LoteriaConfig({
    required this.nombre,
    required this.route,
    this.maxSeleccion = 5,
    this.maxBalotasBlancas = 45,
    this.maxBalotasRojas = 0,
    this.superbalotaNombre = "Superbalota",
    this.hasRevancha = false,
    this.totalBalotasSorteo = 5,
    this.tieneComplementario = false,
  });

  bool get tieneBalotaRoja => maxBalotasRojas > 0;

  LoteriaConfig copyWith({
    String? nombre,
    String? route,
    int? maxSeleccion,
    int? maxBalotasBlancas,
    int? maxBalotasRojas,
    String? superbalotaNombre,
    bool? hasRevancha,
    int? totalBalotasSorteo,
    bool? tieneComplementario,
  }) {
    return LoteriaConfig(
      nombre: nombre ?? this.nombre,
      route: route ?? this.route,
      maxSeleccion: maxSeleccion ?? this.maxSeleccion,
      maxBalotasBlancas: maxBalotasBlancas ?? this.maxBalotasBlancas,
      maxBalotasRojas: maxBalotasRojas ?? this.maxBalotasRojas,
      superbalotaNombre: superbalotaNombre ?? this.superbalotaNombre,
      hasRevancha: hasRevancha ?? this.hasRevancha,
      totalBalotasSorteo: totalBalotasSorteo ?? this.totalBalotasSorteo,
      tieneComplementario: tieneComplementario ?? this.tieneComplementario,
    );
  }

  /// Construye la configuración dinámicamente desde el mapa devuelto por el API / Base de Datos
  static LoteriaConfig fromJson(Map<String, dynamic> json, {String? fallbackNombre}) {
    final rawNombre = json["nombre"]?.toString() ?? fallbackNombre ?? "Lotería";
    final rawRoute = (json["route"] != null && json["route"].toString().isNotEmpty)
        ? json["route"].toString().trim().toLowerCase()
        : _inferRouteFromName(rawNombre);

    final maxSel = json["max_seleccion"] != null
        ? int.tryParse(json["max_seleccion"].toString())
        : (json["maxSeleccion"] != null ? int.tryParse(json["maxSeleccion"].toString()) : null);

    final maxBlancas = json["max_balotas_blancas"] != null
        ? int.tryParse(json["max_balotas_blancas"].toString())
        : (json["max_balotas"] != null
            ? int.tryParse(json["max_balotas"].toString())
            : (json["maxBalotasBlancas"] != null
                ? int.tryParse(json["maxBalotasBlancas"].toString())
                : null));

    final maxRojas = json["max_balotas_rojas"] != null
        ? int.tryParse(json["max_balotas_rojas"].toString())
        : (json["maxBalotasRojas"] != null
            ? int.tryParse(json["maxBalotasRojas"].toString())
            : null);

    final superNombre =
        json["superbalota_nombre"]?.toString() ?? json["superbalotaNombre"]?.toString();

    final revancha = json["has_revancha"] == true || json["hasRevancha"] == true;

    final tieneComp = json["tiene_complementario"] == true ||
        json["tieneComplementario"] == true;

    final int totalSorteoFallback = (maxSel ?? 5) + ((maxRojas ?? 0) > 0 ? 1 : 0) + (tieneComp ? 1 : 0);
    final totalSorteo = json["total_balotas_sorteo"] != null
        ? int.tryParse(json["total_balotas_sorteo"].toString())
        : (json["totalBalotasSorteo"] != null
            ? int.tryParse(json["totalBalotasSorteo"].toString())
            : null);

    return LoteriaConfig(
      nombre: rawNombre,
      route: rawRoute,
      maxSeleccion: maxSel ?? 5,
      maxBalotasBlancas: maxBlancas ?? 45,
      maxBalotasRojas: maxRojas ?? 0,
      superbalotaNombre: superNombre ?? "Superbalota",
      hasRevancha: revancha,
      totalBalotasSorteo: totalSorteo ?? totalSorteoFallback,
      tieneComplementario: tieneComp,
    );
  }

  /// Constructor fallback cuando solo se conoce el nombre o la ruta
  static LoteriaConfig fromNombre(String? nombreInput, {String? routeOverride}) {
    final t = (nombreInput ?? "Lotería").trim();
    final cleanRoute = (routeOverride != null && routeOverride.isNotEmpty)
        ? routeOverride.trim().toLowerCase()
        : _inferRouteFromName(t);

    final formattedName = t.isNotEmpty
        ? t[0].toUpperCase() + t.substring(1)
        : "Lotería";

    final tieneComp = cleanRoute.contains("bonoloto") || cleanRoute.contains("primitiva");
    final int maxSel = (cleanRoute.contains("bonoloto") || cleanRoute.contains("primitiva") || cleanRoute.contains("cloto") || cleanRoute.contains("eurodreams") || cleanRoute.contains("megasena")) ? 6 : 5;
    final int maxRojas = (cleanRoute.contains("mloto") || cleanRoute.contains("cloto") || cleanRoute.contains("megasena")) ? 0 : 10;
    final int maxBlancas = cleanRoute.contains("megasena") ? 60 : 45;
    final int totalSorteo = maxSel + (maxRojas > 0 ? 1 : 0) + (tieneComp ? 1 : 0);

    return LoteriaConfig(
      nombre: formattedName,
      route: cleanRoute,
      maxSeleccion: maxSel,
      maxBalotasBlancas: maxBlancas,
      maxBalotasRojas: maxRojas,
      superbalotaNombre: "Superbalota",
      hasRevancha: false,
      totalBalotasSorteo: totalSorteo,
      tieneComplementario: tieneComp,
    );
  }

  static String _inferRouteFromName(String t) {
    return t.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }
}

class LoteriaScreen extends StatefulWidget {
  final String loteriaNombre;
  final String? loteriaRoute;
  final Map<String, dynamic>? loteriaData;

  const LoteriaScreen({
    super.key,
    required this.loteriaNombre,
    this.loteriaRoute,
    this.loteriaData,
  });

  @override
  State<LoteriaScreen> createState() => _LoteriaScreenState();
}

class _LoteriaScreenState extends State<LoteriaScreen> with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  late LoteriaConfig config;

  int? balotaRojaSeleccionada;
  List<int> seleccionados = [];
  List<int> listaProbables = [];
  List<int> listaBalotaRoja = [];
  List<Map<String, dynamic>> ultimosResultados = [];
  List<Map<String, dynamic>> todosResultadosHistorico = [];
  List<Map<String, dynamic>> _jugadasList = [];
  List<Map<String, dynamic>> anuncios = [];
  List<String> _sorteosDisponibles = [];

  bool cargando = false;
  bool isSaving = false;
  String? fechaPrediccion;
  String? userId;
  String? _jackpot;
  String _selectedResultadosTab = "";

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _shineController;
  late AnimationController _jugadasController;

  @override
  void initState() {
    super.initState();
    if (widget.loteriaData != null) {
      config = LoteriaConfig.fromJson(widget.loteriaData!, fallbackNombre: widget.loteriaNombre);
      if (widget.loteriaData!['jackpot'] != null && widget.loteriaData!['jackpot'].toString().isNotEmpty) {
        _jackpot = widget.loteriaData!['jackpot'].toString();
      }
    } else {
      config = LoteriaConfig.fromNombre(widget.loteriaNombre, routeOverride: widget.loteriaRoute);
    }
    _cargarDataOptimizado();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceAnimation = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    );
    _bounceController.forward();

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _jugadasController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _shineController.dispose();
    _jugadasController.dispose();
    super.dispose();
  }

  Future<void> _cargarDataOptimizado() async {
    if (!mounted) return;

    final cacheKeyPred = '${config.route}_prediccion';
    final cached = await CacheService.getJson(cacheKeyPred);
    if (cached != null && cached["numeros"] != null) {
      final nums = (cached["numeros"] as List)
          .map((e) => int.tryParse(e.toString()) ?? -1)
          .where((e) => e >= 0)
          .toList();
      final redNums = cached["balotaroja"] != null
          ? (cached["balotaroja"] as List)
              .map((e) => int.tryParse(e.toString()))
              .where((e) => e != null && e >= 0)
              .cast<int>()
              .toList()
          : <int>[];

      setState(() {
        listaProbables = nums;
        listaBalotaRoja = redNums;
        fechaPrediccion = cached["fecha"]?.toString();
        if (cached["jackpot"] != null) {
          _jackpot = cached["jackpot"].toString();
        }
      });
    }

    final cacheKeyUltimos = '${config.route}_ultimos5';
    final cachedUltimos = await CacheService.getJson(cacheKeyUltimos);
    if (cachedUltimos != null && cachedUltimos["resultados"] is List) {
      final list = List<Map<String, dynamic>>.from(cachedUltimos["resultados"]);
      final sorteosUnicos = list
          .map((r) => r["sorteo"]?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      setState(() {
        ultimosResultados = list;
        _sorteosDisponibles = sorteosUnicos;
        if (_sorteosDisponibles.isNotEmpty &&
            !_sorteosDisponibles.contains(_selectedResultadosTab)) {
          _selectedResultadosTab = _sorteosDisponibles.first;
        }
      });
    }

    if (listaProbables.isEmpty) setState(() => cargando = true);

    try {
      final uId = await _storage.read(key: 'user_id');
      if (mounted) setState(() => userId = uId);

      await Future.wait([
        _fetchNumeros(),
        _fetchUltimosResultados(),
        _fetchHistoricoCompleto(),
        _loadJugadas(),
        _loadAnuncios(),
      ]);

      if (mounted) {
        _jugadasController.reset();
        _jugadasController.forward();
      }
    } catch (e) {
      debugPrint("❌ Error cargando datos de ${config.nombre}: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _fetchNumeros() async {
    try {
      final data = await ApiService.getPrediccionLoteria(config.route);
      if (data["numeros"] != null && mounted) {
        final nums = (data["numeros"] as List)
            .map((e) => int.tryParse(e.toString()) ?? -1)
            .where((e) => e >= 0)
            .toList();

        final redNums = data["balotaroja"] != null
            ? (data["balotaroja"] as List)
                .map((e) => int.tryParse(e.toString()))
                .where((e) => e != null && e >= 0)
                .cast<int>()
                .toList()
            : <int>[];

        int dynamicMaxBlancas = config.maxBalotasBlancas;
        if (nums.isNotEmpty) {
          final maxNum = nums.reduce(max);
          if (maxNum > dynamicMaxBlancas) dynamicMaxBlancas = maxNum;
        }
        int dynamicMaxRojas = config.maxBalotasRojas;
        if (redNums.isNotEmpty) {
          final maxRed = redNums.reduce(max);
          if (maxRed > dynamicMaxRojas) dynamicMaxRojas = maxRed;
        }

        setState(() {
          listaProbables = nums;
          listaBalotaRoja = redNums;
          fechaPrediccion = data["fecha"]?.toString();
          if (data["jackpot"] != null) {
            _jackpot = data["jackpot"].toString();
          }
          config = config.copyWith(
            maxBalotasBlancas: dynamicMaxBlancas,
            maxBalotasRojas: dynamicMaxRojas,
          );
        });
        CacheService.setJson('${config.route}_prediccion', data);
      }
    } catch (e) {
      debugPrint("⚠️ Error obteniendo predicción (${config.route}): $e");
    }
  }

  Future<void> _fetchUltimosResultados() async {
    try {
      final list = await ApiService.getUltimosResultados(config.route);
      if (mounted && list.isNotEmpty) {
        final sorteosUnicos = list
            .map((r) => r["sorteo"]?.toString().trim())
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

        setState(() {
          ultimosResultados = list;
          _sorteosDisponibles = sorteosUnicos;
          if (_sorteosDisponibles.isNotEmpty &&
              !_sorteosDisponibles.contains(_selectedResultadosTab)) {
            _selectedResultadosTab = _sorteosDisponibles.first;
          }
        });
        CacheService.setJson('${config.route}_ultimos5', {"resultados": list});
      }
    } catch (e) {
      debugPrint("⚠️ Error obteniendo últimos resultados (${config.route}): $e");
    }
  }

  Future<void> _fetchHistoricoCompleto() async {
    final cacheKey = '${config.route}_historico_completo';
    final cached = await CacheService.getJson(cacheKey);
    if (cached != null && cached["resultados"] != null && mounted) {
      setState(() {
        todosResultadosHistorico = List<Map<String, dynamic>>.from(cached["resultados"]);
      });
    }

    try {
      final list = await ApiService.getHistoricoCompleto(config.route);
      if (mounted && list.isNotEmpty) {
        setState(() {
          todosResultadosHistorico = list;
        });
        CacheService.setJson(cacheKey, {"resultados": list});
      }
    } catch (e) {
      debugPrint("⚠️ Error obteniendo histórico (${config.route}): $e");
    }
  }

  Future<void> _loadJugadas() async {
    final uId = userId ?? (await ApiService.getUserId())?.toString() ?? "anon";
    final cacheKeyUser = 'user_jugadas_${config.route}_$uId';
    final cacheKeyGeneral = 'mis_jugadas_${config.route}';

    final cached = await CacheService.getJson(cacheKeyUser) ??
        await CacheService.getJson(cacheKeyGeneral);
    if (cached is List && mounted) {
      setState(() => _jugadasList = List<Map<String, dynamic>>.from(cached));
    }

    try {
      final response = await ApiService.listarJugadasGenerica(config.route);
      if (mounted) {
        final list = List<Map<String, dynamic>>.from(response);
        setState(() => _jugadasList = list);
        await CacheService.setJson(cacheKeyUser, list);
        await CacheService.setJson(cacheKeyGeneral, list);
      }
    } catch (_) {}
  }

  Future<void> _loadAnuncios() async {
    try {
      final data = await ApiService.getPublicidades();
      if (mounted) setState(() => anuncios = data);
    } catch (_) {}
  }

  void _generarAleatorios() {
    setState(() {
      final Random random = Random();
      seleccionados = [];

      final pool = listaProbables.isNotEmpty
          ? listaProbables
          : List.generate(config.maxBalotasBlancas, (i) => i + 1);

      while (seleccionados.length < config.maxSeleccion) {
        int n = pool[random.nextInt(pool.length)];
        if (!seleccionados.contains(n)) seleccionados.add(n);
      }

      if (config.tieneBalotaRoja) {
        final bool includesZero = listaBalotaRoja.contains(0) ||
            config.superbalotaNombre.toLowerCase().contains("reintegro") ||
            config.superbalotaNombre.toLowerCase().contains("clave") ||
            config.route.contains("bonoloto") ||
            config.route.contains("primitiva") ||
            config.route.contains("gordo");

        final redPool = listaBalotaRoja.isNotEmpty
            ? listaBalotaRoja
            : (includesZero
                ? List.generate(config.maxBalotasRojas, (i) => i)
                : List.generate(config.maxBalotasRojas, (i) => i + 1));
        balotaRojaSeleccionada = redPool[random.nextInt(redPool.length)];
      }

      _bounceController.reset();
      _bounceController.forward();
    });
  }

  Future<void> _guardarJugada(AppLocalizations? l10n) async {
    if (isSaving) return;

    String? currentUid = userId;
    if (currentUid == null || currentUid.isEmpty) {
      final uidInt = await ApiService.getUserId();
      if (uidInt != null) {
        currentUid = uidInt.toString();
        if (mounted) setState(() => userId = currentUid);
      }
    }

    if (currentUid == null || currentUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.iniciaSesionParaContinuar ?? "Inicia sesión para guardar tu jugada",
            ),
          ),
        );
      }
      return;
    }

    List<int> whitesToSave = [];
    int? redToSave;

    if (seleccionados.isEmpty) {
      if (listaProbables.length < config.maxSeleccion) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Cargando predicción, espera un momento...",
              ),
            ),
          );
        }
        return;
      }
      whitesToSave = listaProbables.take(config.maxSeleccion).toList();
      if (config.tieneBalotaRoja && listaBalotaRoja.isNotEmpty) {
        redToSave = listaBalotaRoja.first;
      }
    } else {
      if (seleccionados.length != config.maxSeleccion ||
          (config.tieneBalotaRoja && balotaRojaSeleccionada == null)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                config.tieneBalotaRoja
                    ? (l10n?.debesSeleccionarBalotas ??
                        "Debes seleccionar ${config.maxSeleccion} balotas y 1 ${config.superbalotaNombre}")
                    : (l10n?.debesSeleccionarBalotas ??
                        "Debes seleccionar ${config.maxSeleccion} números para guardar tu jugada"),
              ),
            ),
          );
        }
        return;
      }
      whitesToSave = List<int>.from(seleccionados);
      redToSave = balotaRojaSeleccionada;
    }

    final whites = List<int>.from(whitesToSave)..sort();
    final jugadaCompleta = redToSave != null ? [...whites, redToSave] : whites;
    final Set<int> whitesSet = whites.toSet();

    if (_jugadasList.isEmpty) {
      final cacheKey = 'mis_jugadas_${config.route}';
      final cached = await CacheService.getJson(cacheKey);
      if (cached is List && cached.isNotEmpty) {
        _jugadasList = List<Map<String, dynamic>>.from(cached);
      } else {
        try {
          final res = await ApiService.listarJugadasGenerica(config.route);
          if (res.isNotEmpty) {
            _jugadasList = List<Map<String, dynamic>>.from(res);
          }
        } catch (_) {}
      }
    }

    final bool isDuplicate = _jugadasList.any((j) {
      final rawNums = (j["numeros"] as List<dynamic>?)
              ?.map((n) => int.tryParse(n.toString()) ?? -1)
              .where((n) => n >= 0)
              .toList() ??
          [];
      if (rawNums.isEmpty) return false;

      final rawRed = j["balota_roja"] ?? j["balotaroja"];
      final int? existingRed = rawRed != null
          ? int.tryParse(rawRed.toString())
          : (config.tieneBalotaRoja && rawNums.length > config.maxSeleccion
              ? rawNums.last
              : null);

      final List<int> existingWhites =
          (config.tieneBalotaRoja && rawNums.length > config.maxSeleccion)
              ? (rawNums.sublist(0, config.maxSeleccion)..sort())
              : (rawNums.take(config.maxSeleccion).toList()..sort());
      final Set<int> existingWhitesSet = existingWhites.toSet();

      final bool whiteMatch = whitesSet.length == existingWhitesSet.length &&
          whitesSet.difference(existingWhitesSet).isEmpty;

      if (whiteMatch) {
        if (config.tieneBalotaRoja) {
          if (redToSave == null || existingRed == null || redToSave == existingRed) {
            return true;
          }
        } else {
          return true;
        }
      }

      if (const ListEquality().equals(rawNums, jugadaCompleta)) {
        return true;
      }

      return false;
    });

    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.jugadaYaExiste ??
                  "Esta jugada ya se encuentra en tus jugadas guardadas",
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => isSaving = true);

    final String targetFechaSorteo = ApiService.getProximoSorteoFecha(
      config.route,
      fechaPrediccion: fechaPrediccion,
      ultimoSorteoFecha: ultimosResultados.isNotEmpty
          ? ultimosResultados.first["fecha"]?.toString()
          : null,
    );

    try {
      await ApiService.crearJugadaGenerica(
        config.route,
        whites,
        currentUid,
        balotaRoja: redToSave,
        fechaSorteo: targetFechaSorteo,
      );

      final nuevaJugada = {
        "numeros": (redToSave != null && whites.length == config.maxSeleccion)
            ? [...whites, redToSave]
            : whites,
        if (redToSave != null) "balota_roja": redToSave,
        if (redToSave != null) "balotaroja": redToSave,
        "fecha_sorteo": targetFechaSorteo,
      };
      _jugadasList.insert(0, nuevaJugada);
      final uIdStr = currentUid;
      await CacheService.setJson('user_jugadas_${config.route}_$uIdStr', _jugadasList);
      await CacheService.setJson('mis_jugadas_${config.route}', _jugadasList);

      await _loadJugadas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.jugadaGuardadaExito ?? "¡Jugada guardada con éxito! 🎉"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error al guardar jugada: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.errorGuardarJugada ?? "Error al guardar la jugada"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Map<String, String> _calcularStats() {
    final listaUsar =
        todosResultadosHistorico.isNotEmpty ? todosResultadosHistorico : ultimosResultados;
    if (listaUsar.isEmpty) {
      return {
        "hot": "--",
        "hotV": "--",
        "cold": "--",
        "coldV": "--",
        "pairs": "--",
        "total": "0",
      };
    }

    final Map<int, int> freq = {};
    for (var r in listaUsar) {
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(config.maxSeleccion)) {
        freq[n] = (freq[n] ?? 0) + 1;
      }
    }

    int hotNum = 1, hotCount = -1;
    int coldNum = 1, coldCount = 999999;

    freq.forEach((k, v) {
      if (v > hotCount) {
        hotCount = v;
        hotNum = k;
      }
      if (v < coldCount) {
        coldCount = v;
        coldNum = k;
      }
    });

    String pairsRatio = "--";
    if (listaUsar.isNotEmpty) {
      final lastNums =
          List<int>.from(listaUsar.first["numeros"] ?? []).take(config.maxSeleccion);
      int evens = lastNums.where((n) => n % 2 == 0).length;
      int odds = lastNums.length - evens;
      pairsRatio = "$evens-$odds";
    }

    return {
      "hot": hotCount > 0 ? hotNum.toString().padLeft(2, '0') : "--",
      "hotV": hotCount > 0 ? "$hotCount veces" : "--",
      "cold": coldCount < 999999 ? coldNum.toString().padLeft(2, '0') : "--",
      "coldV": coldCount < 999999 ? "$coldCount veces" : "--",
      "pairs": pairsRatio,
      "total": "${listaUsar.length}",
    };
  }

  String _formatearFecha(String fecha) {
    try {
      if (fecha.contains('T')) {
        DateTime parsed = DateTime.parse(fecha);
        return DateFormat('dd MMM yyyy', 'es').format(parsed);
      }
      if (fecha.length >= 10 && fecha.contains('-')) {
        DateTime parsed = DateTime.parse(fecha.substring(0, 10));
        return DateFormat('dd MMM yyyy', 'es').format(parsed);
      }
      if (fecha.contains('/')) {
        final parts = fecha.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final parsed = DateTime(year, month, day);
          return DateFormat('dd MMM yyyy', 'es').format(parsed);
        }
      }
      return fecha;
    } catch (_) {
      return fecha;
    }
  }

  String _getFechaProximoSorteo(AppLocalizations? l10n) {
    if (fechaPrediccion != null && fechaPrediccion!.isNotEmpty) {
      return _formatearFecha(fechaPrediccion!);
    }
    if (ultimosResultados.isNotEmpty && ultimosResultados.first["fecha"] != null) {
      return _formatearFecha(ultimosResultados.first["fecha"].toString());
    }
    return l10n?.proximoSorteo ?? "Por definir";
  }

  int _calcularAfinidadScore(List<int> nums, int maxBall) {
    final listaUsar =
        todosResultadosHistorico.isNotEmpty ? todosResultadosHistorico : ultimosResultados;
    if (listaUsar.isEmpty || nums.isEmpty) return 0;

    final Map<int, int> f = {};
    for (int i = 1; i <= maxBall; i++) {
      f[i] = 0;
    }
    for (var r in listaUsar) {
      final nList = List<int>.from(r["numeros"] ?? []);
      for (var n in nList.take(config.maxSeleccion)) {
        if (n >= 1 && n <= maxBall) {
          f[n] = (f[n] ?? 0) + 1;
        }
      }
    }

    final freqs = f.values.toList()..sort();
    final int minSum = freqs.take(config.maxSeleccion).fold(0, (a, b) => a + b);
    final int maxSum = freqs.reversed.take(config.maxSeleccion).fold(0, (a, b) => a + b);

    int sumUser = 0;
    for (var n in nums.take(config.maxSeleccion)) {
      sumUser += f[n] ?? 0;
    }

    if (maxSum == minSum) return 50;
    double ratio = (sumUser - minSum) / (maxSum - minSum);
    ratio = ratio.clamp(0.0, 1.0);
    return (50 + (ratio * 45)).round();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = _calcularStats();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.yellow,
          onRefresh: _cargarDataOptimizado,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 3),
                      _buildHeader(l10n),
                      const SizedBox(height: 18),
                      _buildQuickSummary(s, l10n),
                      const SizedBox(height: 24),
                      _buildIAPrediction(l10n),
                      const SizedBox(height: 16),
                      _buildDisclaimerNote(l10n),
                      const SizedBox(height: 20),
                      _buildActionGrid(l10n),
                      const SizedBox(height: 24),
                      _buildManualSelectorSection(l10n),
                      if (config.tieneBalotaRoja) ...[
                        const SizedBox(height: 24),
                        _buildRedBallsSection(l10n),
                      ],
                      const SizedBox(height: 24),
                      _buildResultadosSection(l10n),
                      const SizedBox(height: 24),
                      _buildNewsSection(l10n),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations? l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LotteryAvatar3D(nombre: config.nombre, size: 32),
                const SizedBox(width: 10),
                Text(
                  config.hasRevancha ? "${config.nombre} / Revancha" : config.nombre,
                  style: AppTextStyles.tituloPrincipal.copyWith(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              "${l10n?.proximoSorteo ?? "Próximo sorteo"}: ${_getFechaProximoSorteo(l10n)}",
              style: AppTextStyles.caption,
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Builder(
            builder: (context) {
              final parts = PaisHelper.getJackpotParts(
                _jackpot,
                fallbackValue: (_jackpot != null && _jackpot!.isNotEmpty) ? _jackpot! : "--",
              );
              final displayVal = parts["value"]!.isNotEmpty ? parts["value"]! : "--";

              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n?.jackpotEstimado ?? "Jackpot estimado",
                    style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 9),
                  ),
                  Text(
                    displayVal,
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.yellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (parts["label"]!.isNotEmpty)
                    Text(
                      parts["label"]!,
                      style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 9),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerNote(AppLocalizations? l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.yellow, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              l10n?.notaTendenciasEstadisticas ??
                  "Nota: son solo tendencias estadísticas, no garantías absolutas.",
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSummary(Map<String, String> stats, AppLocalizations? l10n) {
    final int affinityScore = listaProbables.isNotEmpty
        ? _calcularAfinidadScore(
            listaProbables.take(config.maxSeleccion).toList(), config.maxBalotasBlancas)
        : 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n?.resumenRapido ?? "Resumen rápido",
                  style: AppTextStyles.mensajeImportante,
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EstadisticasDashboardScreen(
                        loteriaNombreInicial: config.nombre,
                        loteriaRoute: config.route,
                      ),
                ),
              ),
              child: Text(
                l10n?.verEstadisticasCompletas ?? "Ver estadísticas completas ›",
                style: AppTextStyles.caption.copyWith(fontSize: 12, color: Colors.amber),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildStatCard(
                l10n?.masCaliente ?? "Más caliente",
                stats["hot"]!,
                stats["hotV"]!,
                l10n,
                icon: Icons.local_fire_department,
                iconColor: Colors.orangeAccent,
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                l10n?.masFrio ?? "Más frío",
                stats["cold"]!,
                stats["coldV"]!,
                l10n,
                icon: Icons.ac_unit,
                iconColor: Colors.blueAccent,
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                l10n?.paresImpares ?? "Pares - Impares",
                stats["pairs"]!,
                l10n?.ultimoSorteo ?? "Último sorteo",
                l10n,
                icon: Icons.balance,
                iconColor: Colors.white54,
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                "Score IA",
                affinityScore > 0 ? "$affinityScore%" : "--",
                l10n?.indiceAfinidadHistorica ?? "Afinidad histórica",
                l10n,
                icon: Icons.insights,
                iconColor: AppColors.yellow,
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                l10n?.analizados ?? "Analizados",
                stats["total"]!,
                l10n?.sorteos ?? "Sorteos",
                l10n,
                icon: Icons.analytics_outlined,
                iconColor: Colors.white54,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String subValue,
    AppLocalizations? l10n, {
    IconData? icon,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EstadisticasDashboardScreen(
                loteriaNombreInicial: config.nombre,
                loteriaRoute: config.route,
              ),
        ),
      ),
      child: Container(
        width: 105,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            if (icon != null) Icon(icon, color: iconColor ?? AppColors.yellow, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center,
            ),
            Text(
              subValue,
              style: const TextStyle(color: Colors.white54, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DBallPrediction(
    int? numero, {
    Color baseColor = const Color(0xFF1A4594),
    double size = 45,
  }) {
    return ScaleTransition(
      scale: _bounceAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: Tween(begin: 0.0, end: 1.0).animate(_shineController),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.25),
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.25),
                ],
                stops: const [0.2, 0.5, 0.8],
              ).createShader(bounds),
              blendMode: BlendMode.srcATop,
              child: Image.asset(
                baseColor == const Color(0xFFD32F2F)
                    ? "assets/images/red-ball.png"
                    : "assets/images/yellow-ball.png",
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _build3DBall(
                  numero,
                  baseColor: baseColor,
                  size: size,
                ),
              ),
            ),
          ),
          Text(
            numero?.toString() ?? "–",
            style: TextStyle(
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [
                Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DBall(
    int? numero, {
    Color baseColor = const Color(0xFFF33A21),
    double size = 45,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            baseColor.withValues(alpha: 0.95),
            baseColor.withValues(alpha: 0.8),
            baseColor.withValues(alpha: 0.6),
          ],
          center: Alignment.topLeft,
          radius: 0.9,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            offset: Offset(1.5, 1.5),
            blurRadius: 3,
          ),
        ],
        border: Border.all(color: Colors.white24, width: 1.0),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "–",
          style: GoogleFonts.montserrat(
            fontSize: size * 0.40,
            fontWeight: FontWeight.w700,
            color: numero != null ? Colors.white : Colors.white54,
            shadows: numero != null
                ? const [
                    Shadow(
                      color: Colors.black87,
                      offset: Offset(0.8, 0.8),
                      blurRadius: 2.0,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildIAPrediction(AppLocalizations? l10n) {
    final bool isCustomSelection =
        seleccionados.isNotEmpty || (config.tieneBalotaRoja && balotaRojaSeleccionada != null);
    final listaUsar =
        todosResultadosHistorico.isNotEmpty ? todosResultadosHistorico : ultimosResultados;
    final int totalSorteosAnalizados = listaUsar.length;

    final numsEvaluados = isCustomSelection
        ? seleccionados
        : (listaProbables.isNotEmpty
            ? listaProbables.take(config.maxSeleccion).toList()
            : <int>[]);

    final int scoreAfinidad = numsEvaluados.isNotEmpty
        ? _calcularAfinidadScore(numsEvaluados, config.maxBalotasBlancas)
        : 0;
    final double progressVal = (scoreAfinidad / 100.0).clamp(0.0, 1.0);

    return AppContainer3(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCustomSelection
                        ? (l10n?.tuJugadaSeleccionada ?? "Tu Jugada Seleccionada")
                        : (l10n?.prediccionIAHoy ?? "Predicción IA para hoy"),
                    style: AppTextStyles.mensajeImportante.copyWith(color: Colors.amber),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isCustomSelection
                        ? (l10n?.balotasPrincipales(seleccionados.length) ??
                            "${seleccionados.length}/${config.maxSeleccion} balotas")
                        : (l10n?.basadaEnAnalisisDe(totalSorteosAnalizados) ??
                            "Basada en análisis de $totalSorteosAnalizados sorteos"),
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                  Text(
                    isCustomSelection
                        ? (l10n?.tocaNumerosModificar ?? "Toca los números abajo para modificar")
                        : (l10n?.indiceAfinidadHistorica ?? "Índice de afinidad histórica"),
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                  ),
                ],
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: progressVal,
                      strokeWidth: 4,
                      color: AppColors.yellow,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  Text(
                    scoreAfinidad > 0 ? "$scoreAfinidad%" : "--",
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ...List.generate(config.maxSeleccion, (index) {
                  int? val;
                  if (isCustomSelection) {
                    val = index < seleccionados.length ? seleccionados[index] : null;
                  } else {
                    val = index < listaProbables.length ? listaProbables[index] : null;
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: _build3DBallPrediction(
                      val,
                      baseColor: const Color(0xFF1A4594),
                      size: config.maxSeleccion > 5 ? 38 : 45,
                    ),
                  );
                }),
                if (config.tieneBalotaRoja)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: _build3DBallPrediction(
                      isCustomSelection
                          ? balotaRojaSeleccionada
                          : (listaBalotaRoja.isNotEmpty ? listaBalotaRoja.first : null),
                      baseColor: const Color(0xFFD32F2F),
                      size: config.maxSeleccion > 5 ? 38 : 45,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_tethering, color: AppColors.yellow, size: 12),
              const SizedBox(width: 4),
              Text(
                isCustomSelection
                    ? (l10n?.jugada ?? "Jugada")
                    : (l10n?.numeroSuerteSugerido ?? "Número de la suerte sugerido por IA"),
                style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(AppLocalizations? l10n) {
    return Row(
      children: [
        _buildActionTile(
          icon: Icons.auto_awesome_outlined,
          label: l10n?.generarJugada.replaceAll(" ", "\n") ?? "Generar\nJugada",
          onTap: _generarAleatorios,
        ),
        const SizedBox(width: 8),
        _buildActionTile(
          icon: Icons.bookmark_add_outlined,
          label: isSaving
              ? (l10n?.guardando ?? "Guardando...")
              : (l10n?.guardarJugada.replaceAll(" ", "\n") ?? "Guardar\nJugada"),
          onTap: isSaving ? null : () => _guardarJugada(l10n),
          isLoading: isSaving,
        ),
        const SizedBox(width: 8),
        _buildActionTile(
          icon: Icons.bookmarks_outlined,
          label: l10n?.misJugadas.replaceAll(" ", "\n") ?? "Mis\nJugadas",
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MisJugadasScreen(
                  loteriaNombre: config.nombre,
                  loteriaRoute: config.route,
                ),
              ),
            );
            if (mounted) {
              await _loadJugadas();
            }
          },
        ),
        const SizedBox(width: 8),
        _buildActionTile(
          icon: Icons.bar_chart,
          label: l10n?.estadisticas ?? "Estadísticas",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EstadisticasDashboardScreen(
                    loteriaNombreInicial: config.nombre,
                    loteriaRoute: config.route,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final bool disabled = onTap == null || isLoading;
    return Expanded(
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: disabled ? 0.5 : 1.0,
          child: Container(
            height: 76,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: disabled ? 0.02 : 0.05),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.yellow,
                    ),
                  )
                else
                  Icon(icon, color: AppColors.yellow, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualSelectorSection(AppLocalizations? l10n) {
    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.seleccionaNumeros ?? "Selecciona tus números",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              InkWell(
                onTap: () => setState(() {
                  seleccionados.clear();
                  balotaRojaSeleccionada = null;
                }),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "${l10n?.numerosOrdenadosProbabilidad ?? "Números ordenados de mayor a menor probabilidad."} \n${l10n?.tocaNumeroSeleccionar ?? "Toca un número para seleccionarlo"}",
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 20),
          listaProbables.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final isSmall = screenWidth < 360;
                    final crossAxisCount = isSmall ? 6 : 8;
                    final spacing = isSmall ? 6.0 : 10.0;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      children: listaProbables.asMap().entries.map((entry) {
                        int index = entry.key;
                        int numero = entry.value;
                        bool isSelected = seleccionados.contains(numero);
                        Color baseColor = isSelected
                            ? Colors.amber
                            : (index < (config.maxBalotasBlancas / 2).ceil()
                                ? Colors.redAccent
                                : const Color(0xFF607D8B));

                        return GestureDetector(
                          onTap: () {
                            if (!mounted) return;
                            setState(() {
                              if (seleccionados.contains(numero)) {
                                seleccionados.remove(numero);
                              } else if (seleccionados.length < config.maxSeleccion) {
                                seleccionados.add(numero);
                                _bounceController.reset();
                                _bounceController.forward();
                              }
                            });
                          },
                          child: _build3DBall(numero, baseColor: baseColor, size: 38),
                        );
                      }).toList(),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildRedBallsSection(AppLocalizations? l10n) {
    if (!config.tieneBalotaRoja) return const SizedBox.shrink();

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                config.superbalotaNombre == "Balota Roja" ||
                        config.superbalotaNombre == "Superbalota"
                    ? (l10n?.balotasRojas ?? "Balotas Rojas")
                    : config.superbalotaNombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (balotaRojaSeleccionada != null)
                InkWell(
                  onTap: () => setState(() => balotaRojaSeleccionada = null),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n?.numerosOrdenadosProbabilidad ??
                "Números ordenados de mayor a menor probabilidad.",
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 20),
          listaBalotaRoja.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final isSmall = screenWidth < 360;
                    final crossAxisCount = isSmall ? 6 : 8;
                    final spacing = isSmall ? 6.0 : 10.0;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      children: listaBalotaRoja.map((numero) {
                        bool isSelected = balotaRojaSeleccionada == numero;
                        return GestureDetector(
                          onTap: () {
                            if (!mounted) return;
                            setState(() {
                              if (balotaRojaSeleccionada == numero) {
                                balotaRojaSeleccionada = null;
                              } else {
                                balotaRojaSeleccionada = numero;
                                _bounceController.reset();
                                _bounceController.forward();
                              }
                            });
                          },
                          child: _build3DBall(
                            numero,
                            baseColor: isSelected ? Colors.amber : Colors.redAccent,
                            size: 38,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildResultadosSection(AppLocalizations? l10n) {
    if (_sorteosDisponibles.length > 1) {
      final listToShow = ultimosResultados
          .where((r) =>
              (r["sorteo"]?.toString().trim().toLowerCase() ?? "") ==
              _selectedResultadosTab.trim().toLowerCase())
          .take(5)
          .toList();

      return AppContainer3(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "${l10n?.ultimosResultados ?? "Últimos 5 resultados"} ${config.nombre}",
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: _sorteosDisponibles.map((sorteo) {
                final isSelected =
                    _selectedResultadosTab.toLowerCase() == sorteo.toLowerCase();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedResultadosTab = sorteo),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.yellow : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          sorteo,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildResultadosContent(
              _selectedResultadosTab,
              l10n,
              listaResultados: listToShow.isNotEmpty ? listToShow : ultimosResultados,
            ),
          ],
        ),
      );
    }

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "${l10n?.ultimosResultados ?? "Últimos 5 resultados"} ${config.nombre}",
              style: AppTextStyles.h2.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildResultadosContent(config.nombre, l10n),
        ],
      ),
    );
  }

  Widget _buildResultadosContent(
    String loteria,
    AppLocalizations? l10n, {
    List<Map<String, dynamic>>? listaResultados,
  }) {
    final resultadosUsar = listaResultados ?? ultimosResultados;
    final int maxBallsInResults = resultadosUsar.isNotEmpty
        ? resultadosUsar
            .map((r) => (r["numeros"] as List<dynamic>? ?? []).length)
            .fold(0, (max, len) => len > max ? len : max)
        : 5;

    // Configuración adaptativa según la cantidad de balotas de la lotería
    final double dateWidth;
    final double dateFontSize;
    final double defaultBallSize;
    final double ballSpacing;
    final double rowPaddingVertical;

    if (maxBallsInResults <= 5) {
      dateWidth = 88.0;
      dateFontSize = 15.0;
      defaultBallSize = 35.0;
      ballSpacing = 5.5;
      rowPaddingVertical = 2.5;
    } else if (maxBallsInResults == 6) {
      dateWidth = 84.0;
      dateFontSize = 14.0;
      defaultBallSize = 34.0;
      ballSpacing = 3.5;
      rowPaddingVertical = 2.5;
    } else if (maxBallsInResults == 7) {
      dateWidth = 88.0;
      dateFontSize = 14.0;
      defaultBallSize = 31.0;
      ballSpacing = 2.0;
      rowPaddingVertical = 2.5;
    } else {
      // 8 o más balotas (La Primitiva, Bonoloto, etc.)
      dateWidth = 85.0;
      dateFontSize = 14.0;
      defaultBallSize = 28.0;
      ballSpacing = 1.8;
      rowPaddingVertical = 2.5;
    }

    return Column(
      children: [
        if (resultadosUsar.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
          )
        else
          Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: dateWidth,
                    child: Text(
                      l10n?.fechaLabel ?? "Fecha",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.fechasResultado.copyWith(fontSize: dateFontSize),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n?.resultados ?? "Resultados",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.fechasResultado.copyWith(fontSize: dateFontSize),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...resultadosUsar.take(5).map((resultado) {
                final fecha = resultado["fecha"] ?? "S/F";
                final rawNumeros = resultado["numeros"] as List<dynamic>? ?? [];
                final numeros = rawNumeros
                    .map((e) => int.tryParse(e.toString()) ?? -1)
                    .where((e) => e >= 0)
                    .toList();

                return Padding(
                  padding: EdgeInsets.symmetric(vertical: rowPaddingVertical),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: dateWidth,
                        child: Text(
                          fecha,
                          textAlign: TextAlign.left,
                          style: AppTextStyles.mensajeImportante.copyWith(
                            fontSize: dateFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final totalBalls = numeros.length;
                            final double calculatedSize = totalBalls > 0
                                ? ((constraints.maxWidth - (totalBalls * ballSpacing * 2)) / totalBalls)
                                : defaultBallSize;
                            final double ballSize = calculatedSize.clamp(18.0, defaultBallSize);

                            return Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: numeros.isEmpty
                                      ? [
                                          Text(
                                            l10n?.sinNumeros ?? "Sin números",
                                            style: AppTextStyles.mensajeSecundario,
                                          ),
                                        ]
                                      : List.generate(numeros.length, (index) {
                                          final n = numeros[index];
                                          final bool isLastBall = index == numeros.length - 1;
                                          final bool isSpecial = config.tieneBalotaRoja && isLastBall && numeros.length > config.maxSeleccion;
                                          final bool isComp = config.tieneComplementario && index == config.maxSeleccion && numeros.length > config.maxSeleccion + 1;
                                          final Color ballColor = isSpecial
                                              ? const Color(0xFFB91C1C)
                                              : (isComp ? const Color(0xFF0D9488) : Colors.amber);

                                          return Padding(
                                            padding: EdgeInsets.symmetric(horizontal: ballSpacing),
                                            child: SizedBox(
                                              width: ballSize,
                                              height: ballSize,
                                              child: _build3DBall(
                                                n,
                                                baseColor: ballColor,
                                                size: ballSize,
                                              ),
                                            ),
                                          );
                                        }),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
      ],
    );
  }

  bool get _esHoySorteo {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (fechaPrediccion != null && fechaPrediccion!.isNotEmpty) {
      if (fechaPrediccion!.startsWith(todayStr)) return true;
    }
    final proxData = widget.loteriaData?['proximo_sorteo']?.toString();
    if (proxData != null && proxData.isNotEmpty) {
      if (proxData.startsWith(todayStr)) return true;
    }
    return false;
  }

  Widget _buildNewsSection(AppLocalizations? l10n) {
    final bool esHoy = _esHoySorteo;
    final String tituloAlerta = esHoy
        ? (l10n?.hoyEsSorteo(config.nombre) ?? "Hoy es el sorteo de ${config.nombre}")
        : "${l10n?.proximoSorteo ?? "Próximo sorteo"}: ${_getFechaProximoSorteo(l10n)}";
    final String subtituloAlerta = esHoy
        ? (l10n?.noOlvidesRevisar ?? "No olvides revisar tus números y mucha suerte.")
        : "Prepara tus jugadas con las predicciones de IA.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n?.noticiasAlertas ?? "Noticias / Alertas",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (esHoy ? AppColors.yellow : Colors.white24).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  esHoy ? Icons.notifications_active_outlined : Icons.calendar_today_outlined,
                  color: esHoy ? AppColors.yellow : Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tituloAlerta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtituloAlerta,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
