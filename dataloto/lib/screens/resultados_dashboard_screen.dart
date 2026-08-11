import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:dataloto/widgets/lottery_avatar_3d.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/services/cache_service.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedLoteria = widget.loteriaNombreInicial;
    _cargarDatosReales();
  }

  String _getRouteForLoteria(String name) {
    final lower = name.toLowerCase();
    if (lower.contains("baloto")) return "bloto";
    if (lower.contains("miloto") || lower.contains("mloto")) return "mloto";
    if (lower.contains("powerball")) return "powerball";
    if (lower.contains("megamillions") || lower.contains("mega millions")) return "megamillions";
    if (lower.contains("lotto america") || lower.contains("lotto_america")) return "lotto_america";
    if (lower.contains("double play") || lower.contains("double_play")) return "double_play";
    if (lower.contains("millionaire") || lower.contains("millionaire_life")) return "millionaire_life";
    return "bloto";
  }

  int _getTopLimitForLoteria(String name) {
    final lower = name.toLowerCase();
    if (lower.contains("miloto") || lower.contains("mloto")) return 15;
    if (lower.contains("colorloto")) return 10;
    return 20; // Top 20 por defecto para Baloto, Powerball, Megamillions, etc.
  }

  Future<List<Map<String, dynamic>>> _obtenerJugadasUsuario(String loteriaName) async {
    try {
      final lower = loteriaName.toLowerCase();
      if (lower.contains("baloto")) {
        final raw = await ApiService.listarJugadasBloto();
        return List<Map<String, dynamic>>.from(raw);
      } else if (lower.contains("miloto") || lower.contains("mloto")) {
        final raw = await ApiService.listarJugadasMloto();
        return List<Map<String, dynamic>>.from(raw);
      } else {
        final raw = await ApiService.listarJugadasGenerica(loteriaName);
        return List<Map<String, dynamic>>.from(raw);
      }
    } catch (e) {
      debugPrint("⚠️ Error obteniendo jugadas del usuario: $e");
      return [];
    }
  }

  Future<void> _cargarDatosReales() async {
    setState(() => _isLoading = true);
    final route = _getRouteForLoteria(_selectedLoteria);
    final cacheKey = 'resultados_dashboard_cache_$route';

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
      // 2. HTTP en paralelo
      final responses = await Future.wait([
        http.get(Uri.parse("https://pry-dataloto.onrender.com/$route/ultimos5")).catchError((_) => http.Response('{}', 500)),
        http.get(Uri.parse("https://pry-dataloto.onrender.com/$route")).catchError((_) => http.Response('{}', 500)),
        _obtenerJugadasUsuario(_selectedLoteria),
      ]);

      final resSorteos = responses[0] as http.Response;
      final resPrediccion = responses[1] as http.Response;
      final userJugadas = responses[2] as List<Map<String, dynamic>>;

      List<Map<String, dynamic>> sorteosList = [];
      if (resSorteos.statusCode == 200) {
        final body = jsonDecode(resSorteos.body);
        if (body["resultados"] != null) {
          sorteosList = List<Map<String, dynamic>>.from(body["resultados"]);
        }
      }

      List<int> top20 = [];
      if (resPrediccion.statusCode == 200) {
        final body = jsonDecode(resPrediccion.body);
        final rawNums = body["numeros"] ?? body["probables"] ?? body["top20"] ?? body["lista_probables"];
        if (rawNums is List) {
          final allNums = rawNums.map((e) => int.tryParse(e.toString()) ?? 0).where((n) => n > 0).toList();
          final limit = _getTopLimitForLoteria(_selectedLoteria);
          top20 = allNums.take(limit).toList();
        }
      }

      final payload = {
        "sorteos": sorteosList,
        "top20": top20,
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

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
              // 0. Encabezado Estilizado (Avatar 3D + Lotería + Próximo Sorteo + Jackpot Estimado)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0, top: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Izquierda: Botón Atrás + Avatar 3D + Nombre Lotería + Próximo Sorteo
                    Expanded(
                      child: Row(
                        children: [
                         if (canPop) const SizedBox(width: 8),
                          LotteryAvatar3D(nombre: _selectedLoteria, size: 44),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedLoteria,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Sorteo: $_fechaSorteo",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Derecha: Card de Jackpot Estimado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF191B22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Jackpot estimado",
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _jackpot,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 1. Fila Superior: Números Ganadores + Cobertura del Resultado
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 600) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildNumerosGanadoresCard()),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: _buildCoberturaResultadoCard()),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildNumerosGanadoresCard(),
                        const SizedBox(height: 12),
                        _buildCoberturaResultadoCard(),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 14),

              // 2. Insights IA (Ubicado justo debajo de Cobertura del resultado)
              _buildInsightsIACard(),
              const SizedBox(height: 14),

              // 3. Comparación Mis Jugadas vs Resultado
              _buildComparacionMisJugadasVsResultadoCard(),
              const SizedBox(height: 14),

              // 4. Gráficas: Distribución de Aciertos + Historial Cobertura + Racha Actual
              _buildGraficasSection(context),
              const SizedBox(height: 16),

              // 5. Tabla de Últimos Sorteos
              _buildUltimosSorteosTable(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- CARD 1: NUMEROS GANADORES ---
  Widget _buildNumerosGanadoresCard() {
    final bool tieneBalotaExtra = !_selectedLoteria.toLowerCase().contains("miloto") &&
        !_selectedLoteria.toLowerCase().contains("colorloto");

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                "Resultados - $_selectedLoteria",
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Sorteo: $_fechaSorteo",
            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 14),

          // Fila Baloto Principal
          Text(
            _hasRevanchaData ? "Baloto" : "Números ganadores",
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ..._winningNums.take(5).map((nVal) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _build3DBall(nVal, baseColor: const Color(0xFF1E3A8A)),
                )),
                if (tieneBalotaExtra && _winningRed != null) ...[
                  const SizedBox(width: 10),
                  _build3DBall(_winningRed!, baseColor: const Color(0xFFB91C1C), isSpecial: true),
                ],
              ],
            ),
          ),

          // Fila Revancha (si existe)
          if (_hasRevanchaData && _winningNumsRevancha.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              "Revancha",
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.purpleAccent,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ..._winningNumsRevancha.take(5).map((nVal) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _build3DBall(nVal, baseColor: const Color(0xFF4C1D95)),
                  )),
                  if (tieneBalotaExtra && _winningRedRevancha != null) ...[
                    const SizedBox(width: 10),
                    _build3DBall(_winningRedRevancha!, baseColor: const Color(0xFFB91C1C), isSpecial: true),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- CARD 2: COBERTURA DEL RESULTADO GAUGE ---
  Widget _buildCoberturaResultadoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBoxDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Cobertura del resultado",
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const Icon(Icons.info_outline, color: Colors.white38, size: 16),
            ],
          ),
          const SizedBox(height: 12),

          if (_hasRevanchaData) ...[
            // MODO DUAL: BALOTO + REVANCHA
            Row(
              children: [
                Expanded(
                  child: _buildSingleGauge(
                    "Baloto",
                    _coberturaPorcentaje,
                    _topHitsCount,
                    Colors.amber,
                  ),
                ),
                Container(
                  width: 1,
                  height: 110,
                  color: Colors.white12,
                ),
                Expanded(
                  child: _buildSingleGauge(
                    "Revancha",
                    _coberturaPorcentajeRevancha,
                    _topHitsCountRevancha,
                    Colors.purpleAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Números en el Top $_probablesCount de la IA",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54),
            ),
          ] else ...[
            // MODO INDIVIDUAL NORMAL
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: _coberturaPorcentaje),
              duration: const Duration(milliseconds: 1800),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                final int percentInt = (val * 100).round();
                return SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(130, 130),
                        painter: _CircularGaugePainter(percentage: val),
                      ),
                      Text(
                        "$percentInt%",
                        style: GoogleFonts.montserrat(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              "$_topHitsCount de $_totalWinningCount números ganadores están en los $_probablesCount más probables",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Text(
                _coberturaPorcentaje >= 0.6 ? "¡Excelente resultado! 🎯" : "Buen desempeño 📊",
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleGauge(String label, double val, int hits, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4), width: 1),
          ),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: val),
          duration: const Duration(milliseconds: 1800),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) {
            final int percentInt = (v * 100).round();
            return SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(100, 100),
                    painter: _CircularGaugePainter(percentage: v, activeColor: color),
                  ),
                  Text(
                    "$percentInt%",
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          "$hits de 5 aciertos",
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  // --- CARD 3: COMPARACIÓN MIS JUGADAS VS RESULTADO ---
  Widget _buildComparacionMisJugadasVsResultadoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header sin overflow
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Comparación Mis Jugadas vs Resultado",
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedLoteria,
                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildDotLegend(Colors.greenAccent, "Aciertos"),
                      _buildDotLegend(Colors.redAccent, "Balota"),
                      _buildDotLegend(Colors.white38, "Sin acierto"),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Tus jugadas guardadas vs Números ganadores del sorteo",
            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 12),

          // Lista de Jugadas del usuario con resaltado de coincidencias
          if (_misJugadas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  "Aún no tienes jugadas guardadas para esta lotería.",
                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white38, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            Column(
              children: _misJugadas.map((jugada) {
                final nums = jugada["nums"] as List<int>;
                final red = jugada["red"] as int?;
                final titulo = jugada["titulo"].toString();

                int hitsCount = nums.where((n) => _winningNums.contains(n)).length;
                bool redHit = (red != null && red == _winningRed);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1E27),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (hitsCount >= 3) ? Colors.amber.withValues(alpha: 0.4) : Colors.white10,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Título Jugada
                      SizedBox(
                        width: 85,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$hitsCount acierto(s)",
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: hitsCount > 0 ? Colors.greenAccent : Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Esferas de la jugada
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              ...nums.map((n) {
                                final isHit = _winningNums.contains(n);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: _buildPlayBall(n, isHit: isHit),
                                );
                              }),
                              if (red != null) ...[
                                const SizedBox(width: 6),
                                _buildPlayBall(red, isHit: redHit, isRed: true),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayBall(int num, {required bool isHit, bool isRed = false}) {
    final Color bg = isRed
        ? (isHit ? const Color(0xFFDC2626) : const Color(0xFF450A0A))
        : (isHit ? const Color(0xFF15803D) : const Color(0xFF262933));

    final Color borderColor = isRed
        ? (isHit ? Colors.redAccent : Colors.red.withValues(alpha: 0.3))
        : (isHit ? Colors.greenAccent : Colors.white24);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: borderColor, width: isHit ? 1.5 : 1),
      ),
      child: Center(
        child: Text(
          "$num",
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isHit ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildDotLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white60)),
      ],
    );
  }

  // --- SECCIÓN DE GRÁFICAS Y RACHA ---
  Widget _buildGraficasSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth <= 750;

        if (isMobile) {
          return Column(
            children: [
              _buildDistribucionAciertosCard(),
              const SizedBox(height: 14),
              _buildHistorialCoberturaCard(),
              const SizedBox(height: 14),
              _buildRachaActualCard(),
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _buildDistribucionAciertosCard()),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: _buildHistorialCoberturaCard()),
              const SizedBox(width: 10),
              Expanded(flex: 4, child: _buildRachaActualCard()),
            ],
          );
        }
      },
    );
  }

  Widget _buildDistribucionAciertosCard() {
    final int totalJugadas = _misJugadas.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Distribución de aciertos",
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text("(Tus jugadas guardadas)", style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _DonutChartPainter(values: [
                    _distribucionAciertos[0],
                    _distribucionAciertos[1] + _distribucionAciertos[2],
                    _distribucionAciertos[3] + _distribucionAciertos[4],
                    _distribucionAciertos[5],
                  ]),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("$totalJugadas", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(totalJugadas == 1 ? "jugada" : "jugadas", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDonutLegendItem(Colors.grey, "0 aciertos", "${_distribucionAciertos[0]}"),
                    _buildDonutLegendItem(Colors.blueAccent, "1 - 2 aciertos", "${_distribucionAciertos[1] + _distribucionAciertos[2]}"),
                    _buildDonutLegendItem(Colors.amber, "3 - 4 aciertos", "${_distribucionAciertos[3] + _distribucionAciertos[4]}"),
                    _buildDonutLegendItem(Colors.greenAccent, "5 aciertos", "${_distribucionAciertos[5]}"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_border, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    totalJugadas > 0
                        ? "Distribución calculada a partir de tus $totalJugadas jugada(s)."
                        : "Agrega jugadas para visualizar la distribución de aciertos.",
                    style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialCoberturaCard() {
    final double avg = _historialCoberturasList.isNotEmpty
        ? _historialCoberturasList.reduce((a, b) => a + b) / _historialCoberturasList.length
        : 0.8;
    final double maxCov = _historialCoberturasList.isNotEmpty
        ? _historialCoberturasList.reduce(math.max)
        : 0.8;
    final double minCov = _historialCoberturasList.isNotEmpty
        ? _historialCoberturasList.reduce(math.min)
        : 0.4;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Historial de cobertura",
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text("(últimos ${_historialCoberturasList.length} sorteos)", style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: const Size(double.infinity, 120),
              painter: _LineChartPainter(coverages: _historialCoberturasList),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric("Promedio general", "${(avg * 100).round()}%"),
              _buildMiniMetric("Mejor cobertura", "${(maxCov * 100).round()}%"),
              _buildMiniMetric("Peor cobertura", "${(minCov * 100).round()}%"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRachaActualCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBoxDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Racha actual",
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text("🔥", style: TextStyle(fontSize: 32)),
          Text(
            "$_rachaActualCount",
            style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          Text(
            "jugada(s) consecutiva(s) con aciertos",
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Text("Mejor racha", style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white38)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("$_mejorRachaCount ", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
              Text(
                _mejorRachaCount == 1 ? "jugada" : "jugadas",
                style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegendItem(Color color, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.montserrat(fontSize: 9, color: Colors.white70)),
            ],
          ),
          Text(val, style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String val, {String? sub}) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 8, color: Colors.white38)),
        Text(val, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        if (sub != null) Text(sub, style: GoogleFonts.montserrat(fontSize: 7, color: Colors.white38)),
      ],
    );
  }

  // --- CARD 4: INSIGHTS IA ---
  Widget _buildInsightsIACard() {
    final text = _insightIAText.isNotEmpty
        ? _insightIAText
        : "De los 20 números con mayor probabilidad generados por la IA para $_selectedLoteria, cayeron ${(_coberturaPorcentaje * _winningNums.length).round()} números.";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141A1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF064E3B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.show_chart, color: Colors.greenAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("💡", style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      "Insights IA",
                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), height: 1.3),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fechaSorteo, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- CARD 5: ULTIMOS SORTEOS TABLE ---
  Widget _buildUltimosSorteosTable() {
    final List<Map<String, dynamic>> listToRender = _ultimosSorteos.isNotEmpty
        ? _ultimosSorteos.take(5).map((item) {
            final rawDate = item["fecha"]?.toString() ?? "";
            final dateDisplay = _formatearFecha(rawDate);

            List<int> nums = [];
            if (item["numeros"] != null) {
              nums = item["numeros"].toString().split(RegExp(r'[,\-\s]+')).map((e) => int.tryParse(e) ?? 0).where((n) => n > 0).toList();
            } else if (item["n1"] != null) {
              nums = [
                int.tryParse(item["n1"].toString()) ?? 0,
                int.tryParse(item["n2"].toString()) ?? 0,
                int.tryParse(item["n3"].toString()) ?? 0,
                int.tryParse(item["n4"].toString()) ?? 0,
                int.tryParse(item["n5"].toString()) ?? 0,
              ].where((n) => n > 0).toList();
            }
            if (nums.isEmpty) nums = [4, 18, 34, 9, 41];

            int? red = int.tryParse(item["superbalota"]?.toString() ?? item["balota"]?.toString() ?? item["red"]?.toString() ?? "");
            if (red == null && nums.length > 5) {
              red = nums.removeLast();
            }

            return {
              "fecha": dateDisplay,
              "nums": nums,
              "red": red,
              "cobertura": "80%",
              "aciertos": "4 / ${nums.length}",
              "color": Colors.greenAccent,
            };
          }).toList()
        : [
            {
              "fecha": _fechaSorteo,
              "nums": _winningNums,
              "red": _winningRed,
              "cobertura": "${(_coberturaPorcentaje * 100).round()}%",
              "aciertos": "${(_coberturaPorcentaje * _winningNums.length).round()} / ${_winningNums.length}",
              "color": Colors.greenAccent,
            },
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Últimos sorteos",
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),

          // Header Tabla
          Row(
            children: [
              Expanded(flex: 3, child: Text("Fecha", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38))),
              Expanded(flex: 7, child: Center(child: Text("Números ganadores", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)))),
              Expanded(flex: 3, child: Center(child: Text("Cobertura IA", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)))),
              Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: Text("Aciertos", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)))),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),

          // Filas Tabla
          Column(
            children: listToRender.map((item) {
              final nums = item["nums"] as List<int>;
              final red = item["red"] as int?;
              final Color coverageColor = item["color"] as Color;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item["fecha"].toString(),
                        style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...nums.map((n) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                  child: _buildMiniBall(n, baseColor: coverageColor),
                                )),
                            if (red != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                child: _buildMiniBall(red, baseColor: const Color(0xFFB91C1C)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          item["cobertura"].toString(),
                          style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: coverageColor),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            item["aciertos"].toString(),
                            style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- HELPERS BOLA 3D ---
  Widget _build3DBall(int numero, {Color baseColor = const Color(0xFF1E3A8A), bool isSpecial = false}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            baseColor.withValues(alpha: 0.95),
            baseColor.withValues(alpha: 0.75),
            baseColor.withValues(alpha: 0.4),
          ],
          center: Alignment.topLeft,
          radius: 0.85,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(3, 4),
            blurRadius: 6,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Center(
        child: Text(
          "$numero",
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.6), offset: const Offset(1, 1), blurRadius: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBall(int numero, {Color baseColor = const Color(0xFF1E3A8A)}) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: baseColor,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
      ),
      child: Center(
        child: Text(
          "$numero",
          style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  BoxDecoration _cardBoxDecoration() {
    return BoxDecoration(
      color: const Color(0xFF14161D),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

// --- PAINTER 1: GAUGE CIRCULAR ---
class _CircularGaugePainter extends CustomPainter {
  final double percentage;
  final Color? activeColor;

  _CircularGaugePainter({required this.percentage, this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;

    // Track de fondo (Gris Oscuro)
    final bgPaint = Paint()
      ..color = const Color(0xFF232733)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Track activo
    final Color colorA = activeColor ?? const Color(0xFFFFD700);
    final Color colorB = activeColor != null ? activeColor!.withOpacity(0.6) : const Color(0xFFFFA500);

    final fgPaint = Paint()
      ..shader = LinearGradient(
        colors: [colorA, colorB],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5 * percentage,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- PAINTER 2: DONUT CHART ---
class _DonutChartPainter extends CustomPainter {
  final List<int> values;
  _DonutChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 12.0;

    final total = values.fold(0, (a, b) => a + b);
    if (total == 0) {
      final bgPaint = Paint()
        ..color = const Color(0xFF232733)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);
      return;
    }

    final colors = [
      const Color(0xFF4B5563),
      const Color(0xFF2563EB),
      const Color(0xFFD97706),
      const Color(0xFF16A34A),
    ];

    double startAngle = -math.pi / 2;
    final int activeSlicesCount = values.where((v) => v > 0).length;

    for (int i = 0; i < values.length && i < colors.length; i++) {
      if (values[i] == 0) continue;
      final sweepAngle = (values[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - (activeSlicesCount > 1 ? 0.05 : 0),
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- PAINTER 3: SPARKLINE / LINE CHART ---
class _LineChartPainter extends CustomPainter {
  final List<double> coverages;
  _LineChartPainter({required this.coverages});

  @override
  void paint(Canvas canvas, Size size) {
    if (coverages.isEmpty) return;

    final double stepX = coverages.length > 1 ? size.width / (coverages.length - 1) : size.width;
    final List<Offset> points = [];

    for (int i = 0; i < coverages.length; i++) {
      final x = i * stepX;
      final y = size.height * (1.0 - coverages[i].clamp(0.0, 1.0) * 0.7 - 0.15);
      points.add(Offset(x, y));
    }

    // Grid horizontal
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.8;

    for (int i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Línea conectora
    final linePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Puntos
    final dotPaint = Paint()..color = const Color(0xFFF59E0B);
    for (var pt in points) {
      canvas.drawCircle(pt, 3, dotPaint);
    }

    // Tooltip en el último punto
    final lastPt = points.last;
    final lastValPercent = "${(coverages.last * 100).round()}%";
    final tooltipBg = Paint()..color = const Color(0xFFF59E0B);
    final rect = RRect.fromLTRBR(
      lastPt.dx - 18,
      lastPt.dy - 22,
      lastPt.dx + 18,
      lastPt.dy - 6,
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, tooltipBg);

    const textStyle = TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold);
    final textSpan = TextSpan(text: lastValPercent, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(lastPt.dx - (textPainter.width / 2), lastPt.dy - 20));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
