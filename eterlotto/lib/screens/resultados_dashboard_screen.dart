import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'resultados/widgets/ultimo_sorteo_card.dart';
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

class ResultadosDashboardScreen extends StatefulWidget {
  final String loteriaNombreInicial;
  final String? loteriaRoute;
  final Map<String, dynamic>? loteriaData;

  const ResultadosDashboardScreen({
    super.key,
    this.loteriaNombreInicial = "Lotería",
    this.loteriaRoute,
    this.loteriaData,
  });

  @override
  State<ResultadosDashboardScreen> createState() => _ResultadosDashboardScreenState();
}

class _ResultadosDashboardScreenState extends State<ResultadosDashboardScreen> {
  late String _selectedLoteria;
  bool _isLoading = true;

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
  List<double> _historialCoberturasList = [];
  int _rachaActualCount = 0;
  int _mejorRachaCount = 0;
  List<Map<String, dynamic>> _misJugadas = [];
  List<int> _distribucionAciertos = [0, 0, 0, 0, 0, 0];
  int _selectedResultadosTab = 0; // Índice de tab seleccionado

  List<int> get _winningNums => _subSorteos.isNotEmpty ? _subSorteos.first.winningNums : [];
  int? get _winningRed => _subSorteos.isNotEmpty ? _subSorteos.first.winningRed : null;
  double get _coberturaPorcentaje => _subSorteos.isNotEmpty ? _subSorteos.first.coberturaPorcentaje : 0.0;
  int get _topHitsCount => _subSorteos.isNotEmpty ? _subSorteos.first.topHitsCount : 0;

  @override
  void initState() {
    super.initState();
    ScreenSecurityHelper.enableSecureScreen();
    _selectedLoteria = widget.loteriaNombreInicial;
    _cargarDatosReales();
  }

  @override
  void dispose() {
    ScreenSecurityHelper.disableSecureScreen();
    super.dispose();
  }

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
    final lower = name.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
    if (lower.contains("megamillions") || lower.contains("megamillion")) return 35;
    if (lower.contains("powerball")) return 34;
    if (lower.contains("doubleplay")) return 34;
    if (lower.contains("millionaire") || lower.contains("millionairelife")) return 29;
    if (lower.contains("lottoamerica")) return 26;
    if (lower.contains("miloto") || lower.contains("mloto")) return 20;
    if (lower.contains("colorloto") || lower.contains("cloto")) return 10;
    if (lower.contains("baloto") || lower.contains("bloto")) return 21;

    if (widget.loteriaData != null && widget.loteriaData!['max_balotas_blancas'] != null) {
      final m = int.tryParse(widget.loteriaData!['max_balotas_blancas'].toString());
      if (m != null && m > 0) {
        return (m ~/ 2);
      }
    }
    if (totalPoolSize != null && totalPoolSize > 0) {
      return (totalPoolSize ~/ 2);
    }
    return 21;
  }

  Future<List<Map<String, dynamic>>> _obtenerJugadasUsuario(String loteriaName, {String? fecha}) async {
    try {
      final route = _getRouteForLoteria(loteriaName);
      // Petición 100% genérica para cualquier lotería actual o futura
      final raw = await ApiService.listarJugadasGenerica(route, fecha: fecha);
      return List<Map<String, dynamic>>.from(raw);
    } catch (e) {
      debugPrint("⚠️ Error obteniendo jugadas del usuario para $loteriaName: $e");
      return [];
    }
  }

  Future<void> _cargarDatosReales({bool forceRefresh = false}) async {
    final route = _getRouteForLoteria(_selectedLoteria);
    final cacheKey = 'resultados_dashboard_cache_v6_$route';

    // 1. ⚡ Despliegue instantáneo desde caché local (0 ms)
    if (!forceRefresh) {
      final cached = await CacheService.getJson(cacheKey);
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
      setState(() => _isLoading = true);
    }

    try {
      // Phase 1: Fetch ultimos5 to determine target draw date
      final resSorteos = await http.get(Uri.parse("https://pry-dataloto.onrender.com/$route/ultimos5")).catchError((_) => http.Response('{}', 500));

      List<Map<String, dynamic>> sorteosList = [];
      if (resSorteos.statusCode == 200) {
        final body = jsonDecode(resSorteos.body);
        if (body["resultados"] != null) {
          sorteosList = List<Map<String, dynamic>>.from(body["resultados"]);
        }
      }

      // Determinar la fecha exacta del sorteo evaluado
      String targetDrawDate = "";
      if (sorteosList.isNotEmpty) {
        final isBalotoSession = _selectedLoteria.toLowerCase().contains("baloto");
        Map<String, dynamic>? firstSort = isBalotoSession
            ? (sorteosList.firstWhere(
                (s) => (s["sorteo"]?.toString().toLowerCase() ?? "").contains("baloto") || (s["sorteo"]?.toString() ?? "").trim().isEmpty,
                orElse: () => sorteosList.first,
              ))
            : sorteosList.first;
        targetDrawDate = _normalizarFechaISO(firstSort["fecha"]?.toString() ?? "");
      }

      // Phase 2: Fetch user plays for this specific draw date
      final responses = await Future.wait([
        _obtenerJugadasUsuario(_selectedLoteria, fecha: targetDrawDate),
        CacheService.getJson('${route}_prediccion'),
      ]);

      final userJugadas = responses[0] as List<Map<String, dynamic>>;
      final cachedPred = responses[1];

      List<int> top20 = [];
      List<int> predictionNumeros = [];
      List<int> predictionBalotaroja = [];
      String? jackpotVal;

      if (cachedPred != null && cachedPred["jackpot"] != null) {
        jackpotVal = cachedPred["jackpot"].toString();
      }

      // 1. Intentar usar la predicción guardada específicamente para la fecha de ese sorteo (ej. 10 Ago 2026)
      if (cachedPred != null && cachedPred["numeros"] != null) {
        final String predFecha = _normalizarFechaISO(cachedPred["fecha"]?.toString() ?? "");
        if (targetDrawDate.isNotEmpty && predFecha == targetDrawDate) {
          final rawNums = cachedPred["numeros"];
          final rawRoja = cachedPred["balotaroja"] ?? cachedPred["balota_roja"];
          if (rawNums is List) {
            predictionNumeros = rawNums.map((e) => int.tryParse(e.toString()) ?? -1).where((n) => n >= 0).toList();
            final limit = _getTopLimitForLoteria(_selectedLoteria, predictionNumeros.length);
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
        final String predUrl = targetDrawDate.isNotEmpty
            ? "https://pry-dataloto.onrender.com/$route?fecha=$targetDrawDate"
            : "https://pry-dataloto.onrender.com/$route";

        final resPrediccion = await http.get(Uri.parse(predUrl)).catchError((_) => http.Response('{}', 500));
        if (resPrediccion.statusCode == 200) {
          final body = jsonDecode(resPrediccion.body);
          if (body["jackpot"] != null) {
            jackpotVal = body["jackpot"].toString();
          }
          final rawNums = body["numeros"] ?? body["probables"] ?? body["top20"] ?? body["lista_probables"];
          final rawRoja = body["balotaroja"] ?? body["balota_roja"] ?? body["balotas_rojas"];
          
          // Verificar si el backend nos devolvió la predicción del sorteo que pedimos
          final String resFecha = _normalizarFechaISO(body["fecha"]?.toString() ?? "");
          if (resFecha.isNotEmpty && targetDrawDate.isNotEmpty && resFecha != targetDrawDate) {
            // El API ignoró la fecha y devolvió la predicción de un sorteo futuro.
            // No tenemos la predicción histórica para este sorteo.
            top20 = [];
            predictionNumeros = [];
            predictionBalotaroja = [];
          } else {
            if (rawNums is List) {
              predictionNumeros = rawNums.map((e) => int.tryParse(e.toString()) ?? -1).where((n) => n >= 0).toList();
              final limit = _getTopLimitForLoteria(_selectedLoteria, predictionNumeros.length);
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
        "top20": top20,
        "predictionNumeros": predictionNumeros,
        "predictionBalotaroja": predictionBalotaroja,
        "jugadas": userJugadas,
        "jackpot": jackpotVal,
      };

      CacheService.setJson(cacheKey, payload);

      if (mounted) {
        _procesarDatosCargados(payload);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("⚠️ Error cargando datos reales: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _procesarDatosCargados(Map<String, dynamic> data) {
    // Se requiere context para l10n, pero esta función se llama desde initState y peticiones async.
    // Usaremos un flag para recalcular strings dependientes de l10n en el build.
    final sorteosRaw = List<Map<String, dynamic>>.from(data["sorteos"] ?? []);
    final rawTop20 = data["top20"] ?? data["numeros"] ?? data["probables"];

    final rawPredNums = data["predictionNumeros"];
    final rawPredRoja = data["predictionBalotaroja"];
    if (rawPredNums is List) {
      _predictionNumeros = rawPredNums.map((e) => int.tryParse(e.toString()) ?? 0).toList();
    } else {
      _predictionNumeros = [];
    }
    if (rawPredRoja is List) {
      _predictionBalotaroja = rawPredRoja.map((e) => int.tryParse(e.toString()) ?? 0).toList();
    } else {
      _predictionBalotaroja = [];
    }

    final poolSize = _predictionNumeros.isNotEmpty ? _predictionNumeros.length : null;
    final limit = _getTopLimitForLoteria(_selectedLoteria, poolSize);

    List<int> top20 = [];
    if (_predictionNumeros.isNotEmpty) {
      top20 = _predictionNumeros.take(limit).toList();
    } else if (rawTop20 is List) {
      final allNums = rawTop20.map((e) => int.tryParse(e.toString()) ?? -1).where((n) => n >= 0).toList();
      top20 = allNums.take(limit).toList();
    }
    _top20List = top20;


    final jugadasRaw = List<Map<String, dynamic>>.from(data["jugadas"] ?? []);

    final bool tieneBalotaExtra = _predictionBalotaroja.isNotEmpty ||
        (widget.loteriaData != null && (int.tryParse(widget.loteriaData!['max_balotas_rojas']?.toString() ?? '0') ?? 0) > 0);

    String drawDateISO = "";
    List<SubSorteoData> subSorteosParsed = [];

    // 1. Extraer todos los sub-sorteos dinámicamente
    if (sorteosRaw.isNotEmpty) {
      final Set<String> distinctNames = {};
      for (var s in sorteosRaw) {
        final name = s["sorteo"]?.toString().trim();
        if (name != null && name.isNotEmpty) {
          distinctNames.add(name);
        }
      }

      // Ordenar nombres: el principal (que coincide con _selectedLoteria) va de PRIMERO
      List<String> sortedNames = distinctNames.toList();
      if (sortedNames.length > 1) {
        final cleanLoteria = _selectedLoteria.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
        sortedNames.sort((a, b) {
          final cleanA = a.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
          final cleanB = b.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
          final aIsMain = cleanLoteria.contains(cleanA) || cleanA.contains(cleanLoteria);
          final bIsMain = cleanLoteria.contains(cleanB) || cleanB.contains(cleanLoteria);
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
        final matches = sorteosRaw.where(
          (s) => (s["sorteo"]?.toString().toLowerCase() ?? "").contains(sName.toLowerCase()),
        ).toList();
        final Map<String, dynamic> record = matches.isNotEmpty ? matches.first : sorteosRaw.first;

        if (i == 0) {
          _fechaSorteo = _formatearFecha(record["fecha"]?.toString() ?? "");
          drawDateISO = _normalizarFechaISO(record["fecha"]?.toString() ?? "");
          _jackpot = "";
          if (record["jackpot"] != null && record["jackpot"].toString().isNotEmpty) {
            _jackpot = record["jackpot"].toString();
          } else if (data["jackpot"] != null && data["jackpot"].toString().isNotEmpty) {
            _jackpot = data["jackpot"].toString();
          }
        }

        List<int> extractedNums = _extraerNumerosDeMap(record);
        final redVal = int.tryParse(
          record["balotaroja2"]?.toString() ??
          record["reintegro"]?.toString() ??
          record["balotaroja"]?.toString() ??
          record["balota_roja"]?.toString() ??
          record["superbalota"]?.toString() ??
          record["balota"]?.toString() ??
          record["red"]?.toString() ?? "",
        );

        int maxSel = int.tryParse(widget.loteriaData?['max_seleccion']?.toString() ?? '') ?? (extractedNums.length > 6 ? 6 : 5);

        int? winningRed;
        if (tieneBalotaExtra && redVal == null && extractedNums.length > maxSel) {
          winningRed = extractedNums.removeLast();
        } else {
          winningRed = redVal;
          if (tieneBalotaExtra && winningRed != null && extractedNums.length > maxSel && extractedNums.last == winningRed) {
            extractedNums.removeLast();
          }
        }

        final mainBalls = extractedNums.length > maxSel ? extractedNums.sublist(0, maxSel) : extractedNums;
        final int? compBall = extractedNums.length > maxSel ? extractedNums.last : null;

        final hitsInTop = top20.isNotEmpty ? mainBalls.where((n) => top20.contains(n)).toList() : <int>[];
        final double cobertura = maxSel > 0 ? (hitsInTop.length / maxSel.toDouble()).clamp(0.0, 1.0) : 0.0;

        subSorteosParsed.add(SubSorteoData(
          nombre: sName,
          winningNums: extractedNums,
          winningRed: winningRed,
          compBall: compBall,
          coberturaPorcentaje: cobertura,
          topHitsCount: hitsInTop.length,
          hitsInTop: hitsInTop,
          color: palette[i % palette.length],
        ));
      }
    }

    _subSorteos = subSorteosParsed;
    if (_selectedResultadosTab >= _sorteosNombres.length) {
      _selectedResultadosTab = 0;
    }

    // 2. Cobertura IA real (sobre las balotas principales)
    int maxSel = int.tryParse(widget.loteriaData?['max_seleccion']?.toString() ?? '') ?? (_winningNums.length > 5 ? 6 : 5);
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
            return playDateISO.isNotEmpty && playDateISO.compareTo(drawDateISO) <= 0;
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
        List<int> nums = _extraerNumerosDeMap(j);

        int? red = int.tryParse(j["superbalota"]?.toString() ?? j["balota"]?.toString() ?? j["red"]?.toString() ?? "");
        if (tieneBalotaExtra && red == null && nums.length > 5) {
          red = nums.removeLast();
        }

        final String? titulo = j["nombre"] ?? j["titulo"];

        return {
          "id": j["id"],
          "titulo": titulo,
          "index": originalIdx,
          "nums": nums,
          "red": red,
        };
      }).toList();
    }

    // 4. Calcular distribución de aciertos
    List<int> dist = [0, 0, 0, 0, 0, 0];
    for (var jugada in _misJugadas) {
      final nums = jugada["nums"] as List<int>;
      int aciertos = nums.where((n) => _winningNums.contains(n)).length;
      if (aciertos >= 0 && aciertos < dist.length) {
        dist[aciertos]++;
      }
    }
    _distribucionAciertos = dist;

    // 5. Historial de sorteos & coberturas para gráficas (evaluando 5 balotas principales)
    _ultimosSorteos = sorteosRaw;
    if (sorteosRaw.isNotEmpty && top20.isNotEmpty) {
      List<double> histList = [];
      for (var sort in sorteosRaw.take(10)) {
        List<int> drawNums = _extraerNumerosDeMap(sort);
        if (drawNums.isNotEmpty) {
          final mainDrawNums = drawNums.length > 5 ? drawNums.sublist(0, 5) : drawNums;
          int hCount = mainDrawNums.where((n) => top20.contains(n)).length;
          histList.add((hCount / mainDrawNums.length).clamp(0.0, 1.0));
        }
      }
      if (histList.isNotEmpty) {
        _historialCoberturasList = histList.reversed.toList();
      }
    }

    // 6. Racha actual y mejor racha de aciertos
    int currentStreak = 0;
    int maxStreak = 0;
    for (var jugada in _misJugadas) {
      final nums = jugada["nums"] as List<int>;
      int hits = nums.where((n) => _winningNums.contains(n)).length;
      if (hits >= 2) {
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
      final numsStr = item["numeros"].toString().replaceAll(RegExp(r'[\[\]]'), '');
      return numsStr.split(RegExp(r'[,\-\s]+')).map((e) => int.tryParse(e.trim()) ?? -1).where((n) => n >= 0).toList();
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
    final raw = j["fecha_sorteo"]?.toString() ??
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
        final langCode = mounted ? Localizations.localeOf(context).languageCode : 'es';
        final meses = langCode == 'en'
            ? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            : (langCode == 'pt'
                ? ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]
                : ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]);
        return "${parsed.day} ${meses[parsed.month - 1]} ${parsed.year}";
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
        return l10n.insightIACayeron(_probablesCount, _selectedLoteria, "${l10n.nNumeros(s.hitsInTop.length)} ($numsStr)");
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
        parts.add("${s.hitsInTop.length} $enPrep ${s.nombre} (${s.hitsInTop.join(', ')})");
      } else {
        parts.add("0 $enPrep ${s.nombre}");
      }
    }

    String joined;
    if (parts.length == 2) {
      joined = "${parts[0]} $yConj ${parts[1]}";
    } else {
      joined = "${parts.sublist(0, parts.length - 1).join(', ')} $yConj ${parts.last}";
    }

    return l10n.insightIACayeron(_probablesCount, _selectedLoteria, joined);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canPop = Navigator.canPop(context);
    int dynamicMaxSel = int.tryParse(widget.loteriaData?['max_seleccion']?.toString() ?? '') ?? (_winningNums.length > 5 ? 6 : 5);

    // Preparar listToRender para la tabla
    List<Map<String, dynamic>> rawSource = _ultimosSorteos;

    if (_sorteosNombres.length > 1 && _selectedResultadosTab < _sorteosNombres.length) {
      final targetSorteo = _sorteosNombres[_selectedResultadosTab];
      final matches = _ultimosSorteos
          .where((s) => (s["sorteo"]?.toString().toLowerCase() ?? "").contains(targetSorteo.toLowerCase()))
          .toList();
      if (matches.isNotEmpty) {
        rawSource = matches;
      }
    }

    final SubSorteoData? currentSub = _selectedResultadosTab < _subSorteos.length
        ? _subSorteos[_selectedResultadosTab]
        : (_subSorteos.isNotEmpty ? _subSorteos.first : null);

    final List<Map<String, dynamic>> listToRender = rawSource.isNotEmpty
        ? rawSource.take(5).map((item) {
            final rawDate = item["fecha"]?.toString() ?? "";
            final dateDisplay = _formatearFechaCorta(rawDate);

            List<int> nums = _extraerNumerosDeMap(item);
            int? red = int.tryParse(
              item["balotaroja2"]?.toString() ??
              item["reintegro"]?.toString() ??
              item["balotaroja"]?.toString() ??
              item["balota_roja"]?.toString() ??
              item["superbalota"]?.toString() ??
              item["balota"]?.toString() ??
              item["red"]?.toString() ?? "",
            );
            if (red == null && nums.length > dynamicMaxSel) {
              red = nums.removeLast();
            } else if (red != null && nums.length > dynamicMaxSel && nums.last == red) {
              nums.removeLast();
            }

            final mainNums = nums.length > dynamicMaxSel ? nums.sublist(0, dynamicMaxSel) : nums;
            final hits = mainNums.where((n) => _top20List.contains(n)).length;
            final covPercent = mainNums.isNotEmpty ? ((hits / mainNums.length) * 100).round() : 0;

            return {
              "fecha": dateDisplay,
              "nums": nums,
              "red": red,
              "cobertura": "$covPercent%",
              "aciertos": "$hits / ${mainNums.length}",
              "color": covPercent >= 60 ? Colors.greenAccent : Colors.amber,
            };
          }).toList()
        : [
            {
              "fecha": _formatearFechaCorta(_fechaSorteo.isNotEmpty ? _fechaSorteo : ""),
              "nums": currentSub?.winningNums ?? _winningNums,
              "red": currentSub?.winningRed ?? _winningRed,
              "cobertura": "${((currentSub?.coberturaPorcentaje ?? _coberturaPorcentaje) * 100).round()}%",
              "aciertos": "${currentSub?.topHitsCount ?? _topHitsCount} / $dynamicMaxSel",
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
              else ...[
                // 0. Encabezado Estilizado
                HeaderCard(
                  selectedLoteria: _selectedLoteria,
                  fechaSorteo: _fechaSorteo,
                  jackpot: _jackpot,
                  canPop: canPop,
                ),

              // 1. Fila Superior: Números Ganadores + Cobertura del Resultado
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool tieneComp = widget.loteriaData?['tiene_complementario'] == true ||
                      widget.loteriaData?['tieneComplementario'] == true ||
                      (_winningNums.length > dynamicMaxSel);
                  final int? totalSorteo = int.tryParse(widget.loteriaData?['total_balotas_sorteo']?.toString() ?? '') ??
                      int.tryParse(widget.loteriaData?['totalBalotasSorteo']?.toString() ?? '');

                  final ultimoSorteoWidget = UltimoSorteoCard(
                    selectedLoteria: _selectedLoteria,
                    fechaSorteo: _fechaSorteo,
                    subSorteos: _subSorteos,
                    maxSeleccion: dynamicMaxSel,
                    tieneComplementario: tieneComp,
                    totalBalotasSorteo: totalSorteo,
                  );

                  final coberturaWidget = CoberturaGaugeCard(
                    subSorteos: _subSorteos,
                    probablesCount: _probablesCount,
                    totalWinningCount: _totalWinningCount,
                  );

                  if (constraints.maxWidth > 600) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: ultimoSorteoWidget),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: coberturaWidget),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        ultimoSorteoWidget,
                        const SizedBox(height: 12),
                        coberturaWidget,
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 14),

              // 2. Insights IA
              InsightIaCard(
                insightIAText: insightText,
                selectedLoteria: _selectedLoteria,
                probablesCount: _probablesCount,
                coberturaPorcentaje: _coberturaPorcentaje,
                subSorteos: _subSorteos,
                fechaSorteo: _fechaSorteo,
                predictionNumeros: _predictionNumeros.isNotEmpty ? _predictionNumeros : _top20List,
                predictionBalotaroja: _predictionBalotaroja,
              ),
              const SizedBox(height: 14),

              // 3. Comparación Mis Jugadas vs Resultado
              MisJugadasCard(
                selectedLoteria: _selectedLoteria,
                misJugadas: _misJugadas.map((j) {
                  final String displayTitle = j["titulo"] ?? l10n.jugadaShare(j["index"]);
                  return {
                    ...j,
                    "titulo": displayTitle,
                  };
                }).toList(),
                subSorteos: _subSorteos,
              ),
              const SizedBox(height: 14),

              // 4. Gráficas
              EstadisticasCards(
                misJugadas: _misJugadas,
                distribucionAciertos: _distribucionAciertos,
                historialCoberturasList: _historialCoberturasList,
                rachaActualCount: _rachaActualCount,
                mejorRachaCount: _mejorRachaCount,
              ),
              const SizedBox(height: 16),

              // 5. Tabla de Últimos Sorteos
              UltimosSorteosTable(
                subTitulo: subTitulo,
                listToRender: listToRender,
                maxSeleccion: dynamicMaxSel,
                tieneComplementario: widget.loteriaData?['tiene_complementario'] == true ||
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
