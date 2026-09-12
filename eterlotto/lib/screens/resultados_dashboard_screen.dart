import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'resultados/widgets/ultimo_sorteo_card.dart';
import 'resultados/widgets/mejor_jugada_card.dart';
import 'resultados/widgets/rendimiento_grafica_card.dart';
import 'resultados/widgets/resumen_rendimiento_card.dart';
import 'resultados/widgets/cobertura_gauge_card.dart';
import 'resultados/widgets/insight_ia_card.dart';
import 'resultados/widgets/mis_jugadas_card.dart';
import 'resultados/widgets/estadisticas_cards.dart';
import 'resultados/widgets/resultados_tab_selector.dart';
import 'resultados/widgets/ultimos_sorteos_table.dart';
import 'resultados/widgets/header_card.dart';
import 'resultados/widgets/resultados_shared.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/utils/screen_security_helper.dart';
import 'package:shimmer/shimmer.dart';
import 'package:eterlotto/services/data_refresh_manager.dart';
import 'package:provider/provider.dart';
import 'package:eterlotto/services/ad_service.dart';
import 'package:eterlotto/providers/subscription_provider.dart';
import 'package:eterlotto/screens/resultados/historico_resultados_screen.dart';
import 'package:eterlotto/models/loteria_config.dart';

class ResultadosDashboardScreen extends StatefulWidget {
  final String loteriaNombreInicial;
  final String? loteriaRoute;
  final Map<String, dynamic>? loteriaData;
  /// Fecha de un sorteo concreto, por ejemplo al abrir Resultados desde una
  /// jugada guardada. Si es nula, se conserva el comportamiento normal: se
  /// muestra el último sorteo oficial disponible.
  final String? targetDrawDate;

  const ResultadosDashboardScreen({
    super.key,
    this.loteriaNombreInicial = "Lotería",
    this.loteriaRoute,
    this.loteriaData,
    this.targetDrawDate,
  });

  @override
  State<ResultadosDashboardScreen> createState() =>
      _ResultadosDashboardScreenState();
}

class _ResultadosDashboardScreenState extends State<ResultadosDashboardScreen> {
  late String _selectedLoteria;
  bool _isLoading = true;
  bool _dataRequestFailed = false;
  bool _showingStaleData = false;

  // Estado de Datos Reales de API
  List<Map<String, dynamic>> _ultimosSorteos = [];
  List<int> _top20List = [];
  List<int> _predictionNumeros = [];
  List<int> _predictionBalotaroja = [];
  List<SubSorteoData> _subSorteos = [];
  List<String> _sorteosNombres = [];
  String _fechaSorteo = "";
  String _jackpot = "";
  int _probablesCount = 20;
  int _totalWinningCount = 5;
  // Una serie por cada sub-sorteo. La llave conserva el nombre recibido por
  // la API para que la leyenda sea útil sin configuraciones por lotería.
  Map<String, List<double>> _historialCoberturasPorSorteo = {};
  int _rachaActualCount = 0;
  int _mejorRachaCount = 0;
  List<Map<String, dynamic>> _misJugadas = [];
  List<int> _distribucionAciertos = [0, 0, 0, 0, 0, 0];
  int _selectedResultadosTab = 0; // Índice de tab seleccionado
  Map<String, List<int>> _prediccionesPorFecha = {};

  List<int>? _obtenerPrediccionParaFecha(String rawDate) {
    final isoDate = _normalizarFechaISO(rawDate);
    if (isoDate.isEmpty) return null;
    if (_prediccionesPorFecha.containsKey(isoDate)) {
      final fullList = _prediccionesPorFecha[isoDate]!;
      final limit = _getTopLimitForLoteria(_selectedLoteria, fullList.length);
      return fullList.take(limit).toList();
    }
    return null;
  }

  String _nombreSorteo(Map<String, dynamic> sorteo) {
    final nombre = sorteo['sorteo']?.toString().trim() ?? '';
    return nombre.isNotEmpty ? nombre : _selectedLoteria;
  }

  String _claveSorteo(String nombre) =>
      nombre.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  bool _esMismoSorteo(Map<String, dynamic> sorteo, String nombre) =>
      _claveSorteo(_nombreSorteo(sorteo)) == _claveSorteo(nombre);

  List<int> get _winningNums =>
      _subSorteos.isNotEmpty ? _subSorteos.first.winningNums : [];
  List<int> get _winningSpecials =>
      _subSorteos.isNotEmpty ? _subSorteos.first.winningSpecials : const [];
  double get _coberturaPorcentaje =>
      _subSorteos.isNotEmpty ? _subSorteos.first.coberturaPorcentaje : 0.0;
  int get _topHitsCount =>
      _subSorteos.isNotEmpty ? _subSorteos.first.topHitsCount : 0;

  LoteriaConfig get _numberConfig {
    final data = widget.loteriaData;
    return data == null
        ? LoteriaConfig.fromNombre(
            _selectedLoteria,
            routeOverride: widget.loteriaRoute,
          )
        : LoteriaConfig.fromJson(
            data,
            fallbackNombre: _selectedLoteria,
          );
  }

  /// Lee roles exclusivamente por posición. Los campos antiguos de una sola
  /// especial se usan sólo si el arreglo aún no contiene especiales.
  (List<int> main, List<int> specials, int? complementary) _splitByRole(
    Map<String, dynamic> item,
  ) {
    final config = _numberConfig;
    final groups = config.numberLayout.split(_extraerNumerosDeMap(item));
    final specials = List<int>.from(groups.specials);
    if (specials.isEmpty && config.cantidadEspeciales > 0) {
      final rawLegacy =
          item['balotaroja2'] ??
          item['reintegro'] ??
          item['balotaroja'] ??
          item['balota_roja'] ??
          item['superbalota'] ??
          item['balota'] ??
          item['red'];
      final legacy = int.tryParse(rawLegacy?.toString() ?? '');
      if (legacy != null) specials.add(legacy);
    }
    return (
      groups.main,
      specials,
      groups.complementary.isEmpty ? null : groups.complementary.first,
    );
  }

  @override
  void initState() {
    super.initState();
    ScreenSecurityHelper.enableSecureScreen();
    _selectedLoteria = widget.loteriaNombreInicial;
    DataRefreshManager.instance.refreshNotifier.addListener(
      _onDataRefreshNotification,
    );
    _cargarDatosReales();
  }

  @override
  void dispose() {
    ScreenSecurityHelper.disableSecureScreen();
    DataRefreshManager.instance.refreshNotifier.removeListener(
      _onDataRefreshNotification,
    );
    super.dispose();
  }

  void _onDataRefreshNotification() {
    final module = DataRefreshManager.instance.refreshNotifier.value;
    if (module == RefreshModules.resultados ||
        module == RefreshModules.jugadas ||
        module == 'all') {
      if (mounted) {
        _cargarDatosReales(forceRefresh: false);
      }
    }
  }


  int? get _loteriaId => int.tryParse(
        (widget.loteriaData?['loteria_id'] ?? widget.loteriaData?['id'])
                ?.toString() ??
            '',
      );

  String _getRouteForLoteria(String name) {
    if (widget.loteriaRoute != null && widget.loteriaRoute!.isNotEmpty) {
      return widget.loteriaRoute!.trim().toLowerCase();
    }
    if (widget.loteriaData != null && widget.loteriaData!['route'] != null) {
      return widget.loteriaData!['route'].toString().trim().toLowerCase();
    }

    String clean = name.trim().toLowerCase();
    clean = clean
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n');

    return clean
        .replaceAll(RegExp(r'[^a-z0-9\s_]'), '')
        .trim()
        .replaceAll(RegExp(r'[\s_]+'), '_');
  }

  int _getTopLimitForLoteria(String name, [int? totalPoolSize]) {
    // 1. Dinámico por configuración de la lotería en BD
    if (widget.loteriaData != null) {
      final m = int.tryParse(
        widget.loteriaData!['max_balotas_blancas']?.toString() ??
            widget.loteriaData!['maxBalotasBlancas']?.toString() ??
            widget.loteriaData!['total_balotas']?.toString() ??
            widget.loteriaData!['totalBalotas']?.toString() ??
            '',
      );
      if (m != null && m > 0) {
        return (m ~/ 2);
      }
    }
    // 2. Dinámico por el tamaño del conjunto de números recibido de la IA
    if (totalPoolSize != null && totalPoolSize > 0) {
      return (totalPoolSize ~/ 2);
    }

    // 3. Fallback auxiliar
    final lower = name.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
    if (lower.contains("megamillions") || lower.contains("megamillion"))
      return 35;
    if (lower.contains("powerball") || lower.contains("doubleplay")) return 34;
    if (lower.contains("millionaire") || lower.contains("millionairelife"))
      return 29;
    if (lower.contains("lottoamerica")) return 26;
    if (lower.contains("5deoro") || lower.contains("cincodeoro")) return 24;
    if (lower.contains("baloto") || lower.contains("bloto")) return 21;
    if (lower.contains("miloto") || lower.contains("mloto")) return 20;
    if (lower.contains("colorloto") || lower.contains("cloto")) return 10;
    return 21;
  }

  Future<List<Map<String, dynamic>>> _obtenerJugadasUsuario(
    String loteriaName, {
    String? fecha,
  }) async {
    try {
      final route = _getRouteForLoteria(loteriaName);
      // Petición 100% genérica para cualquier lotería actual o futura
      final raw = await ApiService.listarJugadasGenerica(
        route,
        fecha: fecha,
        loteriaId: _loteriaId,
      );
      return List<Map<String, dynamic>>.from(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> _cargarDatosReales({bool forceRefresh = false}) async {
    final route = _getRouteForLoteria(_selectedLoteria);
    final requestedDrawDate = _normalizarFechaISO(
      widget.targetDrawDate?.toString() ?? '',
    );
    // Este payload incluye las jugadas del usuario, por eso nunca puede
    // compartirse entre sesiones aunque los resultados sean públicos.
    final userId = (await ApiService.getUserId())?.toString() ?? 'anon';
    // Una consulta dirigida a un sorteo histórico no puede reutilizar el
    // resultado de la última fecha (ni viceversa).
    final lotteryIdentity = _loteriaId != null
        ? 'id_${_loteriaId}_$route'
        : 'route_$route';
    final cacheKey =
        'resultados_dashboard_cache_v11_${lotteryIdentity}_${requestedDrawDate.isEmpty ? 'latest' : requestedDrawDate}_$userId';

    // 1. SWR: el payload es privado por usuario, pero sigue siendo válido
    // para esa misma sesión aunque haya vencido mientras llega la red.
    {
      final cached = await CacheService.getStaleJson(cacheKey);
      if (cached != null && mounted) {
        setState(() {
          _procesarDatosCargados(cached);
          if (_winningNums.isNotEmpty) {
            _isLoading = false;
          }
        });
      }
    }

    if (_winningNums.isEmpty) {
      setState(() {
        _isLoading = true;
        _dataRequestFailed = false;
      });
    }

    try {
      // Phase 1: Fetch ultimos5 to determine target draw date
      final rawSorteosList = await ApiService.getUltimosResultados(route);

      final now = DateTime.now();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      bool esSorteoValido(Map<String, dynamic> s) {
        final nums = _extraerNumerosDeMap(s);
        if (nums.isEmpty || !nums.any((n) => n > 0)) return false;
        final fIso = _normalizarFechaISO(s["fecha"]?.toString() ?? "");
        final dt = DateTime.tryParse(fIso);
        if (dt != null && dt.isAfter(todayEnd)) return false;
        return true;
      }

      String makeKey(Map<String, dynamic> s) {
        return "${_normalizarFechaISO(s['fecha']?.toString() ?? '')}_${s['sorteo']?.toString().trim().toLowerCase()}";
      }

      final seenSorteos = <String>{};
      List<Map<String, dynamic>> sorteosList = [];
      for (var s in rawSorteosList) {
        if (esSorteoValido(s) && seenSorteos.add(makeKey(s))) {
          sorteosList.add(s);
        }
      }

      // Una lotería puede tener varios sub-sorteos. Para que cada serie del
      // historial tenga hasta 10 puntos, completar con el histórico cuando
      // alguno todavía no llega a 10 resultados.
      final conteoPorSorteo = <String, int>{};
      for (final sorteo in sorteosList) {
        final nombre = sorteo['sorteo']?.toString().trim();
        final clave = (nombre == null || nombre.isEmpty)
            ? _selectedLoteria.toLowerCase()
            : nombre.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        conteoPorSorteo[clave] = (conteoPorSorteo[clave] ?? 0) + 1;
      }
      final necesitaHistorico =
          sorteosList.length < 10 ||
          conteoPorSorteo.values.any((conteo) => conteo < 10);
      // Una jugada puede pertenecer a un sorteo que ya no está entre los
      // últimos cinco. En ese caso se consulta el histórico para localizar
      // exactamente su fecha, sin nombres ni reglas particulares por lotería.
      if (necesitaHistorico || requestedDrawDate.isNotEmpty) {
        try {
          final extraSorteos = await ApiService.getHistorico50(route);
          if (extraSorteos.isNotEmpty) {
            for (var s in extraSorteos) {
              if (esSorteoValido(s) && seenSorteos.add(makeKey(s))) {
                sorteosList.add(s);
              }
            }
          }
        } catch (_) {}
      }

      List<Map<String, dynamic>> sorteosHastaFecha =
          List<Map<String, dynamic>>.from(sorteosList);
      if (requestedDrawDate.isNotEmpty) {
        // Contexto histórico para gráficas y tabla: sólo resultados de la
        // fecha elegida hacia atrás. Así nunca se mezclan datos futuros con
        // una jugada histórica.
        sorteosHastaFecha = sorteosList
            .where(
              (s) =>
                  _normalizarFechaISO(s['fecha']?.toString() ?? '')
                      .compareTo(requestedDrawDate) <=
                  0,
            )
            .toList();
        sorteosList = sorteosList
            .where(
              (s) =>
                  _normalizarFechaISO(s['fecha']?.toString() ?? '') ==
                  requestedDrawDate,
            )
            .toList();

        // Conservamos ambos conjuntos: `sorteos` para la cabecera y la
        // comparación exacta; `sorteosHastaFecha` para el rendimiento y los
        // últimos resultados disponibles a la fecha seleccionada.
      }

      // Determinar la fecha exacta del sorteo evaluado
      String targetDrawDate = requestedDrawDate;
      if (sorteosList.isNotEmpty) {
        final isBalotoSession = _selectedLoteria.toLowerCase().contains(
          "baloto",
        );
        Map<String, dynamic>? firstSort = isBalotoSession
            ? (sorteosList.firstWhere(
                (s) =>
                    (s["sorteo"]?.toString().toLowerCase() ?? "").contains(
                      "baloto",
                    ) ||
                    (s["sorteo"]?.toString() ?? "").trim().isEmpty,
                orElse: () => sorteosList.first,
              ))
            : sorteosList.first;
        targetDrawDate = _normalizarFechaISO(
          firstSort["fecha"]?.toString() ?? "",
        );
      }

      // Phase 2: Fetch user plays, cached prediction, and historical predictions
      final responses = await Future.wait([
        _obtenerJugadasUsuario(_selectedLoteria, fecha: targetDrawDate),
        CacheService.getStaleJson('${route}_prediccion'),
        ApiService.getPrediccionesHistorico(route),
      ]);

      final userJugadas = responses[0] as List<Map<String, dynamic>>;
      final cachedPred = responses[1];
      final prediccionesHistoricas = responses[2] as List<Map<String, dynamic>>;

      List<int> top20 = [];
      List<int> predictionNumeros = [];
      List<int> predictionBalotaroja = [];
      String? jackpotVal;

      if (cachedPred != null && cachedPred["jackpot"] != null) {
        jackpotVal = cachedPred["jackpot"].toString();
      }

      // 1. Intentar usar la predicción guardada específicamente para la fecha de ese sorteo (ej. 10 Ago 2026)
      if (cachedPred != null && cachedPred["numeros"] != null) {
        final String predFecha = _normalizarFechaISO(
          cachedPred["fecha"]?.toString() ?? "",
        );
        if (targetDrawDate.isNotEmpty && predFecha == targetDrawDate) {
          final rawNums = cachedPred["numeros"];
          final rawRoja = cachedPred["balotaroja"] ?? cachedPred["balota_roja"];
          if (rawNums is List) {
            predictionNumeros = rawNums
                .map((e) => int.tryParse(e.toString()) ?? -1)
                .where((n) => n >= 0)
                .toList();
            final limit = _getTopLimitForLoteria(
              _selectedLoteria,
              predictionNumeros.length,
            );
            top20 = predictionNumeros.take(limit).toList();
          }
          if (rawRoja is List) {
            predictionBalotaroja = rawRoja
                .map((e) => int.tryParse(e.toString()))
                .where((n) => n != null && n >= 0)
                .cast<int>()
                .toList();
          }
        }
      }

      // 2. Si no coincide la fecha de la caché previa, consultar al backend pasando la fecha exacta del sorteo (?fecha=$targetDrawDate)
      if (top20.isEmpty) {
        final String endpoint = targetDrawDate.isNotEmpty
            ? "/$route?fecha=$targetDrawDate"
            : "/$route";

        final resPrediccion = await ApiService.get(
          endpoint,
          withAuth: false,
        ).catchError((_) => http.Response('{}', 500));
        if (resPrediccion.statusCode == 200) {
          final body = jsonDecode(resPrediccion.body);
          if (body["jackpot"] != null) {
            jackpotVal = body["jackpot"].toString();
          }
          final rawNums =
              body["numeros"] ??
              body["probables"] ??
              body["top20"] ??
              body["lista_probables"];
          final rawRoja =
              body["balotaroja"] ??
              body["balota_roja"] ??
              body["balotas_rojas"];

          // Verificar si el backend nos devolvió la predicción del sorteo que pedimos
          final String resFecha = _normalizarFechaISO(
            body["fecha"]?.toString() ?? "",
          );
          if (resFecha.isNotEmpty &&
              targetDrawDate.isNotEmpty &&
              resFecha != targetDrawDate) {
            // El API ignoró la fecha y devolvió la predicción de un sorteo futuro.
            // No tenemos la predicción histórica para este sorteo.
            top20 = [];
            predictionNumeros = [];
            predictionBalotaroja = [];
          } else {
            if (rawNums is List) {
              predictionNumeros = rawNums
                  .map((e) => int.tryParse(e.toString()) ?? -1)
                  .where((n) => n >= 0)
                  .toList();
              final limit = _getTopLimitForLoteria(
                _selectedLoteria,
                predictionNumeros.length,
              );
              top20 = predictionNumeros.take(limit).toList();
            }
            if (rawRoja is List) {
              predictionBalotaroja = rawRoja
                  .map((e) => int.tryParse(e.toString()))
                  .where((n) => n != null && n >= 0)
                  .cast<int>()
                  .toList();
            }
          }
        }
      }

      final payload = {
        "sorteos": sorteosList,
        "sorteosHastaFecha": sorteosHastaFecha,
        "top20": top20,
        "predictionNumeros": predictionNumeros,
        "predictionBalotaroja": predictionBalotaroja,
        "jugadas": userJugadas,
        "jackpot": jackpotVal,
        "prediccionesHistoricas": prediccionesHistoricas,
      };

      CacheService.setJson(cacheKey, payload);
      DataRefreshManager.instance.markUpdated(RefreshModules.resultados);

      if (mounted) {
        _procesarDatosCargados(payload);
        setState(() {
          _isLoading = false;
          _showingStaleData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _dataRequestFailed = _subSorteos.isEmpty;
          _showingStaleData = _subSorteos.isNotEmpty;
        });
      }
    }
  }

  void _procesarDatosCargados(Map<String, dynamic> data) {
    // Se requiere context para l10n, pero esta función se llama desde initState y peticiones async.
    // Usaremos un flag para recalcular strings dependientes de l10n en el build.
    final sorteosRaw = List<Map<String, dynamic>>.from(data["sorteos"] ?? []);
    // Para una consulta por jugada, esta lista contiene los sorteos desde la
    // fecha seleccionada hacia atrás. La cabecera sigue usando `sorteosRaw`,
    // que representa únicamente el sorteo que el usuario eligió.
    final sorteosHastaFechaRaw = List<Map<String, dynamic>>.from(
      data["sorteosHastaFecha"] ?? sorteosRaw,
    );
    final rawTop20 = data["top20"] ?? data["numeros"] ?? data["probables"];

    final rawPredNums = data["predictionNumeros"];
    final rawPredRoja = data["predictionBalotaroja"];
    if (rawPredNums is List) {
      _predictionNumeros = rawPredNums
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .toList();
    } else {
      _predictionNumeros = [];
    }
    if (rawPredRoja is List) {
      _predictionBalotaroja = rawPredRoja
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .toList();
    } else {
      _predictionBalotaroja = [];
    }

    final poolSize = _predictionNumeros.isNotEmpty
        ? _predictionNumeros.length
        : null;
    final limit = _getTopLimitForLoteria(_selectedLoteria, poolSize);

    List<int> top20 = [];
    if (_predictionNumeros.isNotEmpty) {
      top20 = _predictionNumeros.take(limit).toList();
    } else if (rawTop20 is List) {
      final allNums = rawTop20
          .map((e) => int.tryParse(e.toString()) ?? -1)
          .where((n) => n >= 0)
          .toList();
      top20 = allNums.take(limit).toList();
    }
    _top20List = top20;

    final rawPredList = List<Map<String, dynamic>>.from(
      data["prediccionesHistoricas"] ?? [],
    );
    Map<String, List<int>> predMap = {};
    for (var p in rawPredList) {
      final f = _normalizarFechaISO(p["fecha"]?.toString() ?? "");
      final rawN = p["numeros"];
      if (f.isNotEmpty && rawN is List) {
        final nums = rawN
            .map((e) => int.tryParse(e.toString()) ?? -1)
            .where((n) => n >= 0)
            .toList();
        if (nums.isNotEmpty) {
          predMap[f] = nums;
        }
      }
    }
    _prediccionesPorFecha = predMap;

    final jugadasRaw = List<Map<String, dynamic>>.from(data["jugadas"] ?? []);

    final int maxSel =
        int.tryParse(widget.loteriaData?['max_seleccion']?.toString() ?? '') ??
        int.tryParse(widget.loteriaData?['maxSeleccion']?.toString() ?? '') ??
        (_selectedLoteria.toLowerCase().contains("colorloto") ? 6 : 5);
    String drawDateISO = "";
    List<SubSorteoData> subSorteosParsed = [];

    // 1. Extraer todos los sub-sorteos dinámicamente
    if (sorteosRaw.isNotEmpty) {
      final nombresPorClave = <String, String>{};
      for (var s in sorteosRaw) {
        final name = s["sorteo"]?.toString().trim();
        if (name != null && name.isNotEmpty) {
          nombresPorClave.putIfAbsent(_claveSorteo(name), () => name);
        }
      }

      // Ordenar nombres: el principal (que coincide con _selectedLoteria) va de PRIMERO
      List<String> sortedNames = nombresPorClave.values.toList();
      if (sortedNames.length > 1) {
        final cleanLoteria = _selectedLoteria.toLowerCase().replaceAll(
          RegExp(r'[\s_]+'),
          '',
        );
        sortedNames.sort((a, b) {
          final cleanA = a.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
          final cleanB = b.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
          final aIsMain =
              cleanLoteria.contains(cleanA) || cleanA.contains(cleanLoteria);
          final bIsMain =
              cleanLoteria.contains(cleanB) || cleanB.contains(cleanLoteria);
          if (aIsMain && !bIsMain) return -1;
          if (!aIsMain && bIsMain) return 1;
          return 0;
        });
      } else if (sortedNames.isEmpty) {
        sortedNames = [_selectedLoteria];
      }
      _sorteosNombres = sortedNames;

      final palette = [
        Colors.amber,
        const Color(0xFFC084FC),
        const Color(0xFF2DD4BF),
        const Color(0xFFFB923C),
        Colors.blueAccent,
      ];

      for (int i = 0; i < sortedNames.length; i++) {
        final sName = sortedNames[i];
        final matches = sorteosRaw
            .where((s) => _esMismoSorteo(s, sName))
            .toList();
        final Map<String, dynamic> record = matches.isNotEmpty
            ? matches.first
            : sorteosRaw.first;

        if (i == 0) {
          _fechaSorteo = _formatearFecha(record["fecha"]?.toString() ?? "");
          drawDateISO = _normalizarFechaISO(record["fecha"]?.toString() ?? "");
          _jackpot = "";
          if (record["jackpot"] != null &&
              record["jackpot"].toString().isNotEmpty) {
            _jackpot = record["jackpot"].toString();
          } else if (data["jackpot"] != null &&
              data["jackpot"].toString().isNotEmpty) {
            _jackpot = data["jackpot"].toString();
          }
        }

        final (main, specials, complementary) = _splitByRole(record);
        final mainBalls = main;

        final hitsInTop = top20.isNotEmpty
            ? mainBalls.where((n) => top20.contains(n)).toList()
            : <int>[];
        final double cobertura = maxSel > 0
            ? (hitsInTop.length / maxSel.toDouble()).clamp(0.0, 1.0)
            : 0.0;

        subSorteosParsed.add(
          SubSorteoData(
            nombre: sName,
            winningNums: mainBalls,
            winningSpecials: specials,
            compBall: complementary,
            coberturaPorcentaje: cobertura,
            topHitsCount: hitsInTop.length,
            hitsInTop: hitsInTop,
            color: palette[i % palette.length],
          ),
        );
      }
    }

    _subSorteos = subSorteosParsed;
    if (_selectedResultadosTab >= _sorteosNombres.length) {
      _selectedResultadosTab = 0;
    }

    // 2. Cobertura IA real (sobre las balotas principales)
    if (top20.isNotEmpty) {
      _probablesCount = top20.length;
    }
    _totalWinningCount = maxSel;

    // 3. Procesar jugadas del usuario (Filtrando estrictamente por la fecha del sorteo)
    if (jugadasRaw.isNotEmpty) {
      List<Map<String, dynamic>> jugadasFiltradas = [];

      if (drawDateISO.isNotEmpty) {
        final exactMatches = jugadasRaw.where((j) {
          final String playDateISO = _extraerFechaDeJugada(j);
          return playDateISO == drawDateISO;
        }).toList();

        if (exactMatches.isNotEmpty) {
          jugadasFiltradas = exactMatches;
        } else {
          final pastOrEqualMatches = jugadasRaw.where((j) {
            final String playDateISO = _extraerFechaDeJugada(j);
            return playDateISO.isNotEmpty &&
                playDateISO.compareTo(drawDateISO) <= 0;
          }).toList();

          if (pastOrEqualMatches.isNotEmpty) {
            final String maxDateInPast = pastOrEqualMatches
                .map((j) => _extraerFechaDeJugada(j))
                .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

            jugadasFiltradas = pastOrEqualMatches.where((j) {
              return _extraerFechaDeJugada(j) == maxDateInPast;
            }).toList();
          }
        }
      } else {
        jugadasFiltradas = jugadasRaw;
      }

      _misJugadas = jugadasFiltradas.map((j) {
        final int originalIdx = jugadasRaw.indexOf(j) + 1;
        final (main, specials, complementary) = _splitByRole(j);

        final String? titulo = j["nombre"] ?? j["titulo"];

        return {
          "id": j["id"],
          "titulo": titulo,
          "index": originalIdx,
          "nums": main,
          "specials": specials,
          "complementaria": complementary,
        };
      }).toList();
    }

    // 4. Calcular distribución de aciertos
    List<int> dist = [0, 0, 0, 0, 0, 0];
    for (var jugada in _misJugadas) {
      final nums = (jugada["nums"] as List)
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .toList();
      final specials = List<int>.from(jugada["specials"] as List? ?? const []);

      int maxHits = 0;
      if (_subSorteos.isNotEmpty) {
        for (final sub in _subSorteos) {
          final int hits = nums
              .where((n) => sub.winningNums.contains(n))
              .length;
          final specialHits = specials
              .where(sub.winningSpecials.contains)
              .length;
          final int total = hits + specialHits;
          if (total > maxHits) maxHits = total;
        }
      } else {
        maxHits = nums.where((n) => _winningNums.contains(n)).length;
        maxHits += specials.where(_winningSpecials.contains).length;
      }

      int bucket = maxHits.clamp(0, 5);
      dist[bucket]++;
    }
    _distribucionAciertos = dist;

    // 5. Historial de coberturas para gráficas. Cada sub-sorteo conserva su
    // propia serie, sin importar si la lotería tiene 1, 2, 3 o más variantes.
    _ultimosSorteos = sorteosHastaFechaRaw;
    final historiales = <String, List<double>>{};
    final nombresPorClave = <String, String>{};
    final sorteosPorClave = <String, List<Map<String, dynamic>>>{};
    for (final sorteo in sorteosHastaFechaRaw) {
      final nombre = _nombreSorteo(sorteo);
      final clave = _claveSorteo(nombre);
      nombresPorClave.putIfAbsent(clave, () => nombre);
      sorteosPorClave.putIfAbsent(clave, () => []).add(sorteo);
    }
    for (final entry in sorteosPorClave.entries) {
      final historial = <double>[];

      // 100% DINÁMICO: Si existen predicciones históricas en base de datos,
      // evaluar únicamente sorteos con predicción real para que la gráfica
      // coincida exactamente con la lista de resultados históricos.
      List<Map<String, dynamic>> sorteosCandidatos = entry.value;
      if (_prediccionesPorFecha.isNotEmpty) {
        final evaluados = sorteosCandidatos
            .where(
              (s) =>
                  _obtenerPrediccionParaFecha(s["fecha"]?.toString() ?? "") !=
                  null,
            )
            .toList();
        if (evaluados.isNotEmpty) {
          sorteosCandidatos = evaluados;
        }
      }

      sorteosCandidatos.sort(
        (a, b) => _normalizarFechaISO(
          b['fecha']?.toString() ?? '',
        ).compareTo(_normalizarFechaISO(a['fecha']?.toString() ?? '')),
      );

      for (final sorteo in sorteosCandidatos.take(10)) {
        final sortDate = sorteo["fecha"]?.toString() ?? "";
        final predForDate = _prediccionesPorFecha.isNotEmpty
            ? _obtenerPrediccionParaFecha(sortDate)
            : (_obtenerPrediccionParaFecha(sortDate) ?? top20);
        if (predForDate == null || predForDate.isEmpty) continue;

        final mainDrawNums = _splitByRole(sorteo).$1;

        if (mainDrawNums.isNotEmpty) {
          final hits = mainDrawNums.where(predForDate.contains).length;
          historial.add((hits / mainDrawNums.length).clamp(0.0, 1.0));
        }
      }
      if (historial.isNotEmpty) {
        historiales[nombresPorClave[entry.key]!] = historial.reversed.toList();
      }
    }
    _historialCoberturasPorSorteo = historiales;

    // 6. Racha actual y mejor racha de aciertos
    int currentStreak = 0;
    int maxStreak = 0;
    for (var jugada in _misJugadas) {
      final nums = (jugada["nums"] as List)
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .toList();
      final specials = List<int>.from(jugada["specials"] as List? ?? const []);

      int maxHits = 0;
      if (_subSorteos.isNotEmpty) {
        for (final sub in _subSorteos) {
          final int hits = nums
              .where((n) => sub.winningNums.contains(n))
              .length;
          final specialHits = specials
              .where(sub.winningSpecials.contains)
              .length;
          final int total = hits + specialHits;
          if (total > maxHits) maxHits = total;
        }
      } else {
        maxHits = nums.where((n) => _winningNums.contains(n)).length;
        maxHits += specials.where(_winningSpecials.contains).length;
      }

      if (maxHits >= 1) {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        currentStreak = 0;
      }
    }
    _rachaActualCount = currentStreak;
    _mejorRachaCount = math.max(maxStreak, currentStreak);
  }

  List<int> _extraerNumerosDeMap(Map<String, dynamic> item) {
    if (item["numeros"] is List) {
      return (item["numeros"] as List)
          .map((e) => int.tryParse(e.toString()) ?? -1)
          .where((n) => n >= 0)
          .toList();
    } else if (item["numeros"] != null) {
      final numsStr = item["numeros"].toString().replaceAll(
        RegExp(r'[\[\]]'),
        '',
      );
      return numsStr
          .split(RegExp(r'[,\-\s]+'))
          .map((e) => int.tryParse(e.trim()) ?? -1)
          .where((n) => n >= 0)
          .toList();
    } else if (item["n1"] != null) {
      final List<int> result = [];
      for (int i = 1; i <= 10; i++) {
        if (item["n$i"] != null) {
          final val = int.tryParse(item["n$i"].toString()) ?? -1;
          if (val >= 0) result.add(val);
        }
      }
      return result;
    } else if (item["balota1"] != null) {
      final List<int> result = [];
      for (int i = 1; i <= 10; i++) {
        if (item["balota$i"] != null) {
          final val = int.tryParse(item["balota$i"].toString()) ?? -1;
          if (val >= 0) result.add(val);
        }
      }
      return result;
    }
    return [];
  }

  String _extraerFechaDeJugada(Map<String, dynamic> j) {
    final raw =
        j["fecha_sorteo"]?.toString() ??
        j["fecha_guardado"]?.toString() ??
        j["fecha"]?.toString() ??
        j["created_at"]?.toString() ??
        j["fecha_creacion"]?.toString() ??
        j["createdAt"]?.toString() ??
        "";
    return _normalizarFechaISO(raw);
  }

  String _normalizarFechaISO(String raw) {
    if (raw.isEmpty) return "";
    final clean = raw.trim().split("T").first;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(clean)) {
      return clean;
    }
    final parts = clean.split(RegExp(r'[/.\-]'));
    if (parts.length == 3) {
      if (parts[2].length == 4) {
        final day = parts[0].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[2];
        return "$year-$month-$day";
      } else if (parts[0].length == 4) {
        final year = parts[0];
        final month = parts[1].padLeft(2, '0');
        final day = parts[2].padLeft(2, '0');
        return "$year-$month-$day";
      }
    }
    final parsed = DateTime.tryParse(clean);
    if (parsed != null) {
      return "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
    }
    return clean;
  }

  String _formatearFecha(String rawDate) {
    if (rawDate.isEmpty) return "--";
    try {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        final langCode = mounted
            ? Localizations.localeOf(context).languageCode
            : 'es';
        final dias = langCode == 'en'
            ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            : (langCode == 'pt'
                  ? ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
                  : ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]);
        final meses = langCode == 'en'
            ? [
                "Jan",
                "Feb",
                "Mar",
                "Apr",
                "May",
                "Jun",
                "Jul",
                "Aug",
                "Sep",
                "Oct",
                "Nov",
                "Dec",
              ]
            : (langCode == 'pt'
                  ? [
                      "Jan",
                      "Fev",
                      "Mar",
                      "Abr",
                      "Mai",
                      "Jun",
                      "Jul",
                      "Ago",
                      "Set",
                      "Out",
                      "Nov",
                      "Dez",
                    ]
                  : [
                      "Ene",
                      "Feb",
                      "Mar",
                      "Abr",
                      "May",
                      "Jun",
                      "Jul",
                      "Ago",
                      "Sep",
                      "Oct",
                      "Nov",
                      "Dic",
                    ]);
        final diaSemana = dias[parsed.weekday - 1];
        return "$diaSemana, ${parsed.day} ${meses[parsed.month - 1]} ${parsed.year}";
      }
    } catch (_) {}
    return rawDate;
  }

  String _formatearFechaCorta(String rawDate) {
    if (rawDate.isEmpty) return "18-08-26";
    try {
      final clean = rawDate.trim();
      if (clean.length >= 10 && clean[4] == '-' && clean[7] == '-') {
        final year = clean.substring(2, 4);
        final month = clean.substring(5, 7);
        final day = clean.substring(8, 10);
        return "$day-$month-$year";
      }
      final parsed = DateTime.tryParse(clean);
      if (parsed != null) {
        final day = parsed.day.toString().padLeft(2, '0');
        final month = parsed.month.toString().padLeft(2, '0');
        final year = (parsed.year % 100).toString().padLeft(2, '0');
        return "$day-$month-$year";
      }
    } catch (_) {}
    return rawDate;
  }

  String _buildInsightIAText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_subSorteos.isEmpty) return "";

    if (_top20List.isEmpty) {
      return l10n.prediccionesNoDisponibles;
    }

    if (_subSorteos.length == 1) {
      final s = _subSorteos.first;
      if (s.hitsInTop.isNotEmpty) {
        final numsStr = s.hitsInTop.join(', ');
        return l10n.insightIACayeron(
          _probablesCount,
          _selectedLoteria,
          "${l10n.nNumeros(s.hitsInTop.length)} ($numsStr)",
        );
      } else {
        return l10n.insightIANoCoincidencias(_probablesCount, _selectedLoteria);
      }
    }

    final langCode = Localizations.localeOf(context).languageCode;
    final enPrep = langCode == 'en' ? "in" : (langCode == 'pt' ? "em" : "en");
    final yConj = langCode == 'en' ? "and" : (langCode == 'pt' ? "e" : "y");

    List<String> parts = [];
    for (var s in _subSorteos) {
      if (s.hitsInTop.isNotEmpty) {
        parts.add(
          "${s.hitsInTop.length} $enPrep ${s.nombre} (${s.hitsInTop.join(', ')})",
        );
      } else {
        parts.add("0 $enPrep ${s.nombre}");
      }
    }

    String joined;
    if (parts.length == 2) {
      joined = "${parts[0]} $yConj ${parts[1]}";
    } else {
      joined =
          "${parts.sublist(0, parts.length - 1).join(', ')} $yConj ${parts.last}";
    }

    return l10n.insightIACayeron(_probablesCount, _selectedLoteria, joined);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canPop = Navigator.canPop(context);
    int dynamicMaxSel =
        int.tryParse(widget.loteriaData?['max_seleccion']?.toString() ?? '') ??
        (_winningNums.length > 5 ? 6 : 5);

    // Preparar listToRender para la tabla
    List<Map<String, dynamic>> rawSource = _ultimosSorteos;

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Filtrar sorteos válidos (no futuros y con balotas > 0)
    rawSource = rawSource.where((s) {
      final nums = _extraerNumerosDeMap(s);
      if (nums.isEmpty || !nums.any((n) => n > 0)) return false;
      final fIso = _normalizarFechaISO(s["fecha"]?.toString() ?? "");
      final dt = DateTime.tryParse(fIso);
      if (dt != null && dt.isAfter(todayEnd)) return false;
      return true;
    }).toList();

    // Deduplicar por fecha y subsorteo
    final seen = <String>{};
    rawSource = rawSource.where((s) {
      final key =
          "${_normalizarFechaISO(s['fecha']?.toString() ?? '')}_${s['sorteo']?.toString().trim().toLowerCase()}";
      return seen.add(key);
    }).toList();

    // El contexto ya está limitado a la fecha de la jugada; ordenar garantiza
    // que la tabla muestre los cinco sorteos más recientes dentro de ese
    // límite, sin depender del orden recibido por cada API.
    rawSource.sort(
      (a, b) => _normalizarFechaISO(
        b['fecha']?.toString() ?? '',
      ).compareTo(_normalizarFechaISO(a['fecha']?.toString() ?? '')),
    );

    if (_sorteosNombres.length > 1 &&
        _selectedResultadosTab < _sorteosNombres.length) {
      final targetSorteo = _sorteosNombres[_selectedResultadosTab];
      final matches = rawSource
          .where((s) => _esMismoSorteo(s, targetSorteo))
          .toList();
      if (matches.isNotEmpty) {
        rawSource = matches;
      }
    }

    // Filtrar para evaluar únicamente los sorteos que tienen predicción real en la base de datos
    if (_prediccionesPorFecha.isNotEmpty) {
      final evaluados = rawSource
          .where(
            (s) =>
                _obtenerPrediccionParaFecha(s["fecha"]?.toString() ?? "") !=
                null,
          )
          .toList();
      if (evaluados.isNotEmpty) {
        rawSource = evaluados;
      }
    }

    final SubSorteoData? currentSub =
        _selectedResultadosTab < _subSorteos.length
        ? _subSorteos[_selectedResultadosTab]
        : (_subSorteos.isNotEmpty ? _subSorteos.first : null);

    final List<Map<String, dynamic>> listToRender = rawSource.isNotEmpty
        ? rawSource.take(5).map((item) {
            final rawDate = item["fecha"]?.toString() ?? "";
            final dateDisplay = _formatearFechaCorta(rawDate);

            final (main, specials, complementary) = _splitByRole(item);
            final mainNums = main;

            // Evaluar contra la predicción específica de esa fecha
            final predParaFecha = _obtenerPrediccionParaFecha(rawDate);
            final bool tienePred =
                predParaFecha != null && predParaFecha.isNotEmpty;
            final hits = tienePred
                ? mainNums.where((n) => predParaFecha.contains(n)).length
                : 0;
            final covPercent = (mainNums.isNotEmpty && tienePred)
                ? ((hits / mainNums.length) * 100).round()
                : 0;

            return {
              "fecha": dateDisplay,
              "nums": mainNums,
              "specials": specials,
              "complementaria": complementary,
              "cobertura": tienePred ? "$covPercent%" : "--",
              "aciertos": tienePred ? "$hits / ${mainNums.length}" : "--",
              "color": tienePred
                  ? (covPercent >= 60 ? Colors.greenAccent : Colors.amber)
                  : Colors.white38,
            };
          }).toList()
        : [
            {
              "fecha": _formatearFechaCorta(
                _fechaSorteo.isNotEmpty ? _fechaSorteo : "",
              ),
              "nums": currentSub?.winningNums ?? _winningNums,
              "specials": currentSub?.winningSpecials ?? _winningSpecials,
              "complementaria": currentSub?.compBall,
              "cobertura":
                  "${((currentSub?.coberturaPorcentaje ?? _coberturaPorcentaje) * 100).round()}%",
              "aciertos":
                  "${currentSub?.topHitsCount ?? _topHitsCount} / $dynamicMaxSel",
              "color": Colors.greenAccent,
            },
          ];

    final String subTitulo = l10n.ultimosResultados;

    final insightText = _buildInsightIAText(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.yellow,
          backgroundColor: const Color(0xFF1E1E1E),
          displacement: 25.0,
          onRefresh: () => _cargarDatosReales(forceRefresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading && _subSorteos.isEmpty)
                  _buildSkeletonDashboard()
                else if (_subSorteos.isEmpty)
                  _buildDataUnavailableState(l10n)
                else ...[
                  // 0. Encabezado Estilizado
                  HeaderCard(
                    selectedLoteria: _selectedLoteria,
                    fechaSorteo: _fechaSorteo,
                    jackpot: _jackpot,
                    canPop: canPop,
                  ),

                  if (_showingStaleData) ...[
                    const SizedBox(height: 10),
                    _buildStaleDataNotice(),
                  ],

                  const SizedBox(height: 14),

                  // 1. Números Ganadores del Último Sorteo
                  UltimoSorteoCard(
                    selectedLoteria: _selectedLoteria,
                    fechaSorteo: _fechaSorteo,
                    subSorteos: _subSorteos,
                    maxSeleccion: dynamicMaxSel,
                    tieneComplementario:
                        widget.loteriaData?['tiene_complementario'] == true ||
                        widget.loteriaData?['tieneComplementario'] == true ||
                        (_winningNums.length > dynamicMaxSel),
                    totalBalotasSorteo:
                        int.tryParse(
                          widget.loteriaData?['total_balotas_sorteo']
                                  ?.toString() ??
                              '',
                        ) ??
                        int.tryParse(
                          widget.loteriaData?['totalBalotasSorteo']
                                  ?.toString() ??
                              '',
                        ),
                  ),
                  const SizedBox(height: 14),
                  // 2. 🏆 Mejor Jugada del Sorteo
                  MejorJugadaCard(
                    misJugadas: _misJugadas.map((j) {
                      final String displayTitle =
                          j["titulo"] ?? l10n.jugadaShare(j["index"]);
                      return {...j, "titulo": displayTitle};
                    }).toList(),
                    subSorteos: _subSorteos,
                    maxSeleccion: dynamicMaxSel,
                  ),

                  // 3. Comparación Mis Jugadas vs Resultado
                  MisJugadasCard(
                    selectedLoteria: _selectedLoteria,
                    misJugadas: _misJugadas.map((j) {
                      final String displayTitle =
                          j["titulo"] ?? l10n.jugadaShare(j["index"]);
                      return {...j, "titulo": displayTitle};
                    }).toList(),
                    subSorteos: _subSorteos,
                  ),
                  const SizedBox(height: 14),

                  // 4. Cobertura del Resultado
                  CoberturaGaugeCard(
                    subSorteos: _subSorteos,
                    probablesCount: _probablesCount,
                    totalWinningCount: _totalWinningCount,
                  ),
                  const SizedBox(height: 14),

                  // 5. Insights IA
                  InsightIaCard(
                    insightIAText: insightText,
                    selectedLoteria: _selectedLoteria,
                    probablesCount: _probablesCount,
                    coberturaPorcentaje: _coberturaPorcentaje,
                    subSorteos: _subSorteos,
                    fechaSorteo: _fechaSorteo,
                    predictionNumeros: _predictionNumeros.isNotEmpty
                        ? _predictionNumeros
                        : _top20List,
                    predictionBalotaroja: _predictionBalotaroja,
                  ),
                  const SizedBox(height: 14),

                  // 6. 📈 Rendimiento últimos 10 sorteos (Gráfica Comparativa)
                  if (_historialCoberturasPorSorteo.isNotEmpty) ...[
                    RendimientoGraficaCard(
                      historialCoberturasPorSorteo:
                          _historialCoberturasPorSorteo,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 7. 📊 Resumen del rendimiento (Tarjeta compacta)
                  if (_historialCoberturasPorSorteo.isNotEmpty) ...[
                    ResumenRendimientoCard(
                      historialCoberturasPorSorteo:
                          _historialCoberturasPorSorteo,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 8. Gráficas (Distribución de aciertos y rachas del usuario)
                  EstadisticasCards(
                    misJugadas: _misJugadas,
                    distribucionAciertos: _distribucionAciertos,
                    rachaActualCount: _rachaActualCount,
                    mejorRachaCount: _mejorRachaCount,
                  ),
                  const SizedBox(height: 16),

                  // 6. Tabla de Últimos Sorteos
                  UltimosSorteosTable(
                    subTitulo: subTitulo,
                    listToRender: listToRender,
                    maxSeleccion: dynamicMaxSel,
                    tieneComplementario:
                        widget.loteriaData?['tiene_complementario'] == true ||
                        widget.loteriaData?['tieneComplementario'] == true ||
                        (_winningNums.length > dynamicMaxSel),
                    tabSelector: ResultadosTabSelector(
                      sorteos: _sorteosNombres,
                      selectedIndex: _selectedResultadosTab,
                      onTabChanged: (val) {
                        setState(() {
                          _selectedResultadosTab = val;
                        });
                      },
                    ),
                    onVerMas: _abrirHistoricoResultados,
                  ),
                  const SizedBox(height: 30),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataUnavailableState(AppLocalizations l10n) {
    final isConnectionIssue = _dataRequestFailed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(
              isConnectionIssue
                  ? Icons.cloud_off_outlined
                  : Icons.receipt_long_outlined,
              color: isConnectionIssue ? Colors.redAccent : AppColors.yellow,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              isConnectionIssue
                  ? l10n.errorConexion
                  : (l10n.informacionNoDisponible),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isConnectionIssue
                  ? l10n.datosLoteriaSinConexion
                  : l10n.datosLoteriaNoDisponibles,
              style: const TextStyle(color: Colors.white70, height: 1.35),
              textAlign: TextAlign.center,
            ),
            if (isConnectionIssue) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _cargarDatosReales(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.reintentar),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.yellow,
                  side: const BorderSide(color: AppColors.yellow),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaleDataNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.28)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: AppColors.yellow, size: 17),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión · mostrando los últimos datos disponibles',
              style: TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirHistoricoResultados() {
    final route = _getRouteForLoteria(_selectedLoteria);
    final configData = Map<String, dynamic>.from(widget.loteriaData ?? {});
    configData['route'] = route;
    configData.putIfAbsent('nombre', () => _selectedLoteria);
    var config = LoteriaConfig.fromJson(
      configData,
      fallbackNombre: _selectedLoteria,
    );

    // Si el API no entregó el total, el resultado visible es la única fuente
    // de respaldo. No se infiere por el nombre de una lotería concreta.
    if (!configData.containsKey('total_balotas_sorteo') &&
        !configData.containsKey('totalBalotasSorteo') &&
        _winningNums.length > config.totalBalotasSorteo) {
      config = config.copyWith(
        totalBalotasSorteo: _winningNums.length,
        tieneComplementario: _winningNums.length > config.maxSeleccion,
      );
    }

    final isPremium = context.read<SubscriptionProvider>().isSubscribed;
    final l10n = AppLocalizations.of(context);

    AdService.instance.showRewardedFeatureGate(
      context: context,
      isPremium: isPremium,
      featureKey: "historico_resultados",
      featureTitle:
          l10n?.historicoResultadosTitulo ?? "Histórico de Resultados",
      featureActionDescription:
          l10n?.descripcionVideoHistorico ??
          "Mira un breve video publicitario para acceder y consultar el historial completo de resultados.",
      onRewardGranted: () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HistoricoResultadosScreen(
              config: config,
              sorteosDisponibles: _sorteosNombres,
              initialSorteo:
                  _sorteosNombres.isNotEmpty &&
                      _selectedResultadosTab < _sorteosNombres.length
                  ? _sorteosNombres[_selectedResultadosTab]
                  : null,
              initialResultados: _ultimosSorteos,
              top20: _top20List,
              prediccionesPorFecha: _prediccionesPorFecha,
              modoResultadosIA: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonDashboard() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2C2C2C),
      period: const Duration(milliseconds: 1400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card Skeleton
          Container(
            width: double.infinity,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          // Winning Numbers Card Skeleton
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          // Cobertura Card Skeleton
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          // Insight IA Card Skeleton
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          // Table Skeleton
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
