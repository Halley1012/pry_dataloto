import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/services/cache_service.dart';
import 'resultados/widgets/ultimo_sorteo_card.dart';
import 'resultados/widgets/cobertura_gauge_card.dart';
import 'resultados/widgets/insight_ia_card.dart';
import 'resultados/widgets/mis_jugadas_card.dart';
import 'resultados/widgets/estadisticas_cards.dart';
import 'resultados/widgets/resultados_tab_selector.dart';
import 'resultados/widgets/ultimos_sorteos_table.dart';
import 'resultados/widgets/header_card.dart';

class ResultadosDashboardScreen extends StatefulWidget {
  final String loteriaNombreInicial;

  const ResultadosDashboardScreen({
    super.key,
    this.loteriaNombreInicial = "Miloto",
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
  List<int> _winningNums = [];
  int? _winningRed;
  bool _hasRevanchaData = false;
  List<int> _winningNumsRevancha = [];
  int? _winningRedRevancha;
  double _coberturaPorcentajeRevancha = 0.0;
  int _topHitsCountRevancha = 0;
  String _fechaSorteo = "";
  String _jackpot = "";
  double _coberturaPorcentaje = 0.0;
  int _probablesCount = 20;
  int _totalWinningCount = 5;
  int _topHitsCount = 0;
  List<double> _historialCoberturasList = [];
  int _rachaActualCount = 0;
  int _mejorRachaCount = 0;
  List<Map<String, dynamic>> _misJugadas = [];
  List<int> _distribucionAciertos = [0, 0, 0, 0, 0, 0];
  String _insightIAText = "";
  int _selectedResultadosTab = 0; // 0 = Sorteo Principal, 1 = Sorteo Secundario

  String get _nombreSorteoPrincipal {
    final parts = _selectedLoteria.split('/').map((s) => s.trim()).toList();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0];
    }
    return _selectedLoteria;
  }

  String get _nombreSorteoSecundario {
    final parts = _selectedLoteria.split('/').map((s) => s.trim()).toList();
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return parts[1];
    }
    return "Revancha";
  }

  @override
  void initState() {
    super.initState();
    _selectedLoteria = widget.loteriaNombreInicial;
    _cargarDatosReales();
  }

  String _getRouteForLoteria(String name) {
    final clean = name.trim().toLowerCase();
    if (clean == "baloto" || clean.contains("revancha")) return "bloto";
    if (clean == "miloto") return "mloto";
    // Generación dinámica de ruta para cualquier lotería nueva:
    return clean.replaceAll(RegExp(r'[^a-z0-9_]'), '_').replaceAll(RegExp(r'_+'), '_');
  }

  int _getTopLimitForLoteria(String name, [int? totalPoolSize]) {
    final lower = name.toLowerCase();
    if (lower.contains("powerball")) return 34;
    if (lower.contains("megamillions") || lower.contains("mega millions")) return 35;
    if (lower.contains("double play") || lower.contains("double_play")) return 34;
    if (lower.contains("lotto america") || lower.contains("lotto_america")) return 26;
    if (lower.contains("millionaire") || lower.contains("millionaire_life")) return 29;
    if (lower.contains("miloto") || lower.contains("mloto")) return 20;
    if (lower.contains("colorloto")) return 10;
    if (lower.contains("baloto")) return 21;
    
    // Para cualquier lotería futura agregada sin configuración previa:
    if (totalPoolSize != null && totalPoolSize > 0) {
      return (totalPoolSize / 2).round();
    }
    return 20;
  }

  Future<List<Map<String, dynamic>>> _obtenerJugadasUsuario(String loteriaName) async {
    try {
      final route = _getRouteForLoteria(loteriaName);
      // Petición 100% genérica para cualquier lotería actual o futura
      final raw = await ApiService.listarJugadasGenerica(route);
      return List<Map<String, dynamic>>.from(raw);
    } catch (e) {
      debugPrint("⚠️ Error obteniendo jugadas del usuario para $loteriaName: $e");
      return [];
    }
  }

  Future<void> _cargarDatosReales() async {
    setState(() => _isLoading = true);
    final route = _getRouteForLoteria(_selectedLoteria);
    final cacheKey = 'resultados_dashboard_cache_v4_$route';

    // 1. Caché inmediato
    final cached = await CacheService.getJson(cacheKey);
    if (cached != null && mounted) {
      final cachedTop = cached["top20"];
      if (cachedTop is List && cachedTop.isNotEmpty) {
        _procesarDatosCargados(cached);
        setState(() => _isLoading = false);
      }
    }

    try {
      // 2. HTTP en dos fases para consultar la predicción por la fecha exacta del sorteo
      final responses = await Future.wait([
        http.get(Uri.parse("https://pry-dataloto.onrender.com/$route/ultimos5")).catchError((_) => http.Response('{}', 500)),
        _obtenerJugadasUsuario(_selectedLoteria),
      ]);

      final resSorteos = responses[0] as http.Response;
      final userJugadas = responses[1] as List<Map<String, dynamic>>;

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

      List<int> top20 = [];
      List<int> predictionNumeros = [];
      List<int> predictionBalotaroja = [];

      // 1. Intentar usar la predicción guardada específicamente para la fecha de ese sorteo (ej. 10 Ago 2026)
      final cachedPred = await CacheService.getJson('${route}_prediccion');
      if (cachedPred != null && cachedPred["numeros"] != null) {
        final String predFecha = _normalizarFechaISO(cachedPred["fecha"]?.toString() ?? "");
        if (targetDrawDate.isNotEmpty && predFecha == targetDrawDate) {
          final rawNums = cachedPred["numeros"];
          final rawRoja = cachedPred["balotaroja"] ?? cachedPred["balota_roja"];
          if (rawNums is List) {
            predictionNumeros = rawNums.map((e) => int.tryParse(e.toString()) ?? 0).where((n) => n > 0).toList();
            final limit = _getTopLimitForLoteria(_selectedLoteria);
            top20 = predictionNumeros.take(limit).toList();
          }
          if (rawRoja is List) {
            predictionBalotaroja = rawRoja.map((e) => int.tryParse(e.toString()) ?? 0).where((n) => n > 0).toList();
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
              predictionNumeros = rawNums.map((e) => int.tryParse(e.toString()) ?? 0).where((n) => n > 0).toList();
              final limit = _getTopLimitForLoteria(_selectedLoteria);
              top20 = predictionNumeros.take(limit).toList();
            }
            if (rawRoja is List) {
              predictionBalotaroja = rawRoja.map((e) => int.tryParse(e.toString()) ?? 0).where((n) => n > 0).toList();
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
    final sorteosRaw = List<Map<String, dynamic>>.from(data["sorteos"] ?? []);
    final rawTop20 = data["top20"] ?? data["numeros"] ?? data["probables"];
    List<int> top20 = [];
    if (rawTop20 is List) {
      final allNums = rawTop20.map((e) => int.tryParse(e.toString()) ?? 0).where((n) => n > 0).toList();
      final limit = _getTopLimitForLoteria(_selectedLoteria);
      top20 = allNums.take(limit).toList();
    }
    _top20List = top20;

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

    final jugadasRaw = List<Map<String, dynamic>>.from(data["jugadas"] ?? []);

    final bool tieneBalotaExtra = !_selectedLoteria.toLowerCase().contains("miloto") &&
        !_selectedLoteria.toLowerCase().contains("colorloto");

    _hasRevanchaData = false;
    _winningNumsRevancha = [];
    _winningRedRevancha = null;
    _coberturaPorcentajeRevancha = 0.0;
    _topHitsCountRevancha = 0;

    String drawDateISO = "";

    // 1. Extraer último sorteo real (Baloto y Revancha)
    if (sorteosRaw.isNotEmpty) {
      final isBalotoSession = _selectedLoteria.toLowerCase().contains("baloto");

      Map<String, dynamic>? ultimoBaloto;
      Map<String, dynamic>? ultimoRevancha;

      if (isBalotoSession) {
        final balotoMatches = sorteosRaw.where(
          (s) => (s["sorteo"]?.toString().toLowerCase() ?? "").contains("baloto") ||
                 (s["sorteo"]?.toString() ?? "").trim().isEmpty,
        ).toList();

        if (balotoMatches.isNotEmpty) {
          ultimoBaloto = balotoMatches.first;
        } else {
          ultimoBaloto = sorteosRaw.first;
        }

        final revanchaMatches = sorteosRaw.where(
          (s) => (s["sorteo"]?.toString().toLowerCase() ?? "").contains("revancha"),
        ).toList();

        if (revanchaMatches.isNotEmpty) {
          ultimoRevancha = revanchaMatches.first;
        }
      } else {
        ultimoBaloto = sorteosRaw.first;
      }

      // Procesar Sorteo Principal / Baloto
      _fechaSorteo = _formatearFecha(ultimoBaloto["fecha"]?.toString() ?? "");
      drawDateISO = _normalizarFechaISO(ultimoBaloto["fecha"]?.toString() ?? "");

      List<int> extractedNums = _extraerNumerosDeMap(ultimoBaloto);
      final redVal = int.tryParse(ultimoBaloto["superbalota"]?.toString() ?? ultimoBaloto["balota"]?.toString() ?? ultimoBaloto["red"]?.toString() ?? "");

      if (tieneBalotaExtra && redVal == null && extractedNums.length > 5) {
        _winningRed = extractedNums.removeLast();
      } else {
        _winningRed = redVal;
      }

      if (extractedNums.isNotEmpty) {
        _winningNums = extractedNums;
      }

      if (ultimoBaloto["jackpot"] != null && ultimoBaloto["jackpot"].toString().isNotEmpty) {
        _jackpot = ultimoBaloto["jackpot"].toString();
      }

      // Procesar Revancha (si existe)
      if (ultimoRevancha != null) {
        List<int> extractedRevancha = _extraerNumerosDeMap(ultimoRevancha);
        final redValRev = int.tryParse(ultimoRevancha["superbalota"]?.toString() ?? ultimoRevancha["balota"]?.toString() ?? ultimoRevancha["red"]?.toString() ?? "");

        if (tieneBalotaExtra && redValRev == null && extractedRevancha.length > 5) {
          _winningRedRevancha = extractedRevancha.removeLast();
        } else {
          _winningRedRevancha = redValRev;
        }

        if (extractedRevancha.isNotEmpty) {
          _winningNumsRevancha = extractedRevancha;
          _hasRevanchaData = true;
        }
      }
    }

    // 2. Cobertura IA real (exclusivamente sobre las 5 balotas principales)
    if (top20.isNotEmpty) {
      _probablesCount = top20.length;
    }

    _totalWinningCount = 5;

    if (_winningNums.isNotEmpty && top20.isNotEmpty) {
      final mainBaloto = _winningNums.length > 5 ? _winningNums.sublist(0, 5) : _winningNums;
      _topHitsCount = mainBaloto.where((n) => top20.contains(n)).length;
      _coberturaPorcentaje = (_topHitsCount / 5.0).clamp(0.0, 1.0);
    }

    if (_hasRevanchaData && _winningNumsRevancha.isNotEmpty && top20.isNotEmpty) {
      final mainRevancha = _winningNumsRevancha.length > 5 ? _winningNumsRevancha.sublist(0, 5) : _winningNumsRevancha;
      _topHitsCountRevancha = mainRevancha.where((n) => top20.contains(n)).length;
      _coberturaPorcentajeRevancha = (_topHitsCountRevancha / 5.0).clamp(0.0, 1.0);
    }

    // 3. Procesar jugadas del usuario (Filtrando estrictamente por la fecha del sorteo)
    if (jugadasRaw.isNotEmpty) {
      List<Map<String, dynamic>> jugadasFiltradas = jugadasRaw;

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
      }

      _misJugadas = jugadasFiltradas.map((j) {
        final int originalIdx = jugadasRaw.indexOf(j) + 1;
        List<int> nums = _extraerNumerosDeMap(j);

        int? red = int.tryParse(j["superbalota"]?.toString() ?? j["balota"]?.toString() ?? j["red"]?.toString() ?? "");
        if (tieneBalotaExtra && red == null && nums.length > 5) {
          red = nums.removeLast();
        }

        final String titulo = j["nombre"] ?? j["titulo"] ?? "Jugada #$originalIdx";

        return {
          "id": j["id"],
          "titulo": titulo,
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

    // 7. Insight IA dinámico con lista de números acertados (Baloto y Revancha)
    if (_winningNums.isNotEmpty) {
      if (top20.isEmpty) {
         _insightIAText = "Las predicciones de la IA para este sorteo pasado no están disponibles en el historial.";
      } else {
        final mainBaloto = _winningNums.length > 5 ? _winningNums.sublist(0, 5) : _winningNums;
        final balotoHits = mainBaloto.where((n) => top20.contains(n)).toList();

        if (_hasRevanchaData && _winningNumsRevancha.isNotEmpty) {
          final mainRevancha = _winningNumsRevancha.length > 5 ? _winningNumsRevancha.sublist(0, 5) : _winningNumsRevancha;
          final revanchaHits = mainRevancha.where((n) => top20.contains(n)).toList();

          final String bText = balotoHits.isNotEmpty ? "${balotoHits.length} en Baloto (${balotoHits.join(', ')})" : "0 en Baloto";
          final String rText = revanchaHits.isNotEmpty ? "${revanchaHits.length} en Revancha (${revanchaHits.join(', ')})" : "0 en Revancha";

          _insightIAText = "De los $_probablesCount números con mayor probabilidad generados por la IA para $_selectedLoteria, cayeron $bText y $rText.";
        } else {
          if (balotoHits.isNotEmpty) {
            final numsStr = balotoHits.join(', ');
            _insightIAText = "De los $_probablesCount números con mayor probabilidad generados por la IA para $_selectedLoteria, cayeron ${balotoHits.length} números ($numsStr).";
          } else {
            _insightIAText = "De los $_probablesCount números con mayor probabilidad generados por la IA para $_selectedLoteria, no hubo coincidencias en este sorteo.";
          }
        }
      }
    }
  }

  List<int> _extraerNumerosDeMap(Map<String, dynamic> item) {
    if (item["numeros"] is List) {
      return (item["numeros"] as List)
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((n) => n > 0)
          .toList();
    } else if (item["numeros"] != null) {
      final numsStr = item["numeros"].toString().replaceAll(RegExp(r'[\[\]]'), '');
      return numsStr.split(RegExp(r'[,\-\s]+')).map((e) => int.tryParse(e.trim()) ?? 0).where((n) => n > 0).toList();
    } else if (item["n1"] != null) {
      return [
        int.tryParse(item["n1"].toString()) ?? 0,
        int.tryParse(item["n2"].toString()) ?? 0,
        int.tryParse(item["n3"].toString()) ?? 0,
        int.tryParse(item["n4"].toString()) ?? 0,
        int.tryParse(item["n5"].toString()) ?? 0,
      ].where((n) => n > 0).toList();
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
    if (rawDate.isEmpty) return "10 Ago 2026";
    try {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        final meses = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
        return "${parsed.day} ${meses[parsed.month - 1]} ${parsed.year}";
      }
    } catch (_) {}
    return rawDate;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    // Preparar listToRender para la tabla
    List<Map<String, dynamic>> rawSource = _ultimosSorteos;

    if (_hasRevanchaData) {
      if (_selectedResultadosTab == 1) {
        final revMatches = _ultimosSorteos.where((s) => (s["sorteo"]?.toString().toLowerCase() ?? "").contains("revancha")).toList();
        if (revMatches.isNotEmpty) {
          rawSource = revMatches;
        }
      } else {
        final balMatches = _ultimosSorteos.where((s) => (s["sorteo"]?.toString().toLowerCase() ?? "").contains("baloto") || (s["sorteo"]?.toString() ?? "").trim().isEmpty).toList();
        if (balMatches.isNotEmpty) {
          rawSource = balMatches;
        }
      }
    }

    final List<Map<String, dynamic>> listToRender = rawSource.isNotEmpty
        ? rawSource.take(5).map((item) {
            final rawDate = item["fecha"]?.toString() ?? "";
            final dateDisplay = _formatearFecha(rawDate);

            List<int> nums = _extraerNumerosDeMap(item);
            int? red = int.tryParse(item["superbalota"]?.toString() ?? item["balota"]?.toString() ?? item["red"]?.toString() ?? "");
            if (red == null && nums.length > 5) {
              red = nums.removeLast();
            }

            final main5 = nums.length > 5 ? nums.sublist(0, 5) : nums;
            final hits = main5.where((n) => _top20List.contains(n)).length;
            final covPercent = main5.isNotEmpty ? ((hits / main5.length) * 100).round() : 0;

            return {
              "fecha": dateDisplay,
              "nums": nums,
              "red": red,
              "cobertura": "$covPercent%",
              "aciertos": "$hits / ${main5.length}",
              "color": covPercent >= 60 ? Colors.greenAccent : Colors.amber,
            };
          }).toList()
        : [
            {
              "fecha": _fechaSorteo.isNotEmpty ? _fechaSorteo : "Reciente",
              "nums": _selectedResultadosTab == 1 && _winningNumsRevancha.isNotEmpty ? _winningNumsRevancha : _winningNums,
              "red": _selectedResultadosTab == 1 && _winningRedRevancha != null ? _winningRedRevancha : _winningRed,
              "cobertura": _selectedResultadosTab == 1 ? "${(_coberturaPorcentajeRevancha * 100).round()}%" : "${(_coberturaPorcentaje * 100).round()}%",
              "aciertos": _selectedResultadosTab == 1 ? "$_topHitsCountRevancha / 5" : "$_topHitsCount / ${_winningNums.length > 5 ? 5 : _winningNums.length}",
              "color": Colors.greenAccent,
            },
          ];

    final String subTitulo = _hasRevanchaData
        ? (_selectedResultadosTab == 1 ? "Últimos 5 resultados $_nombreSorteoSecundario" : "Últimos 5 resultados $_nombreSorteoPrincipal")
        : "Últimos sorteos";

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.amber,
          onRefresh: _cargarDatosReales,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: LinearProgressIndicator(
                    backgroundColor: Color(0xFF1E2029),
                    color: Colors.amber,
                    minHeight: 2,
                  ),
                ),
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
                  final ultimoSorteoWidget = UltimoSorteoCard(
                    selectedLoteria: _selectedLoteria,
                    fechaSorteo: _fechaSorteo,
                    hasRevanchaData: _hasRevanchaData,
                    nombreSorteoPrincipal: _nombreSorteoPrincipal,
                    nombreSorteoSecundario: _nombreSorteoSecundario,
                    winningNums: _winningNums,
                    winningRed: _winningRed,
                    winningNumsRevancha: _winningNumsRevancha,
                    winningRedRevancha: _winningRedRevancha,
                  );

                  final coberturaWidget = CoberturaGaugeCard(
                    hasRevanchaData: _hasRevanchaData,
                    nombreSorteoPrincipal: _nombreSorteoPrincipal,
                    nombreSorteoSecundario: _nombreSorteoSecundario,
                    coberturaPorcentaje: _coberturaPorcentaje,
                    coberturaPorcentajeRevancha: _coberturaPorcentajeRevancha,
                    topHitsCount: _topHitsCount,
                    topHitsCountRevancha: _topHitsCountRevancha,
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
                insightIAText: _insightIAText,
                selectedLoteria: _selectedLoteria,
                probablesCount: _probablesCount,
                coberturaPorcentaje: _coberturaPorcentaje,
                winningNums: _selectedResultadosTab == 1 && _winningNumsRevancha.isNotEmpty ? _winningNumsRevancha : _winningNums,
                winningRed: _selectedResultadosTab == 1 && _winningRedRevancha != null ? _winningRedRevancha : _winningRed,
                fechaSorteo: _fechaSorteo,
                predictionNumeros: _predictionNumeros.isNotEmpty ? _predictionNumeros : _top20List,
                predictionBalotaroja: _predictionBalotaroja,
              ),
              const SizedBox(height: 14),

              // 3. Comparación Mis Jugadas vs Resultado
              MisJugadasCard(
                selectedLoteria: _selectedLoteria,
                misJugadas: _misJugadas,
                winningNums: _winningNums,
                winningRed: _winningRed,
                hasRevanchaData: _hasRevanchaData,
                winningNumsRevancha: _winningNumsRevancha,
                winningRedRevancha: _winningRedRevancha,
                nombreSorteoPrincipal: _nombreSorteoPrincipal,
                nombreSorteoSecundario: _nombreSorteoSecundario,
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
                tabSelector: ResultadosTabSelector(
                  hasRevanchaData: _hasRevanchaData,
                  selectedResultadosTab: _selectedResultadosTab,
                  nombreSorteoPrincipal: _nombreSorteoPrincipal,
                  nombreSorteoSecundario: _nombreSorteoSecundario,
                  onTabChanged: (val) {
                    setState(() {
                      _selectedResultadosTab = val;
                    });
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
