import 'package:dataloto/widgets/lottery_avatar_3d.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/services/cache_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/widgets/contenedor3.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dataloto/utils/pais_helper.dart';
import 'package:dataloto/widgets/carrusel.dart';
import 'package:dataloto/screens/directorioLocal.dart';
import 'package:dataloto/screens/loterias_mis_jugadas_generica.dart';
import 'package:dataloto/widgets/jugadas_list_generico.dart';
import 'package:dataloto/screens/estadisticas_powerball.dart';
import 'dart:math';
import 'package:dataloto/l10n/generated/app_localizations.dart';

class PowerballScreen extends StatefulWidget {
  const PowerballScreen({super.key});

  @override
  State<PowerballScreen> createState() => _PowerballScreenState();
}

class _PowerballScreenState extends State<PowerballScreen> with TickerProviderStateMixin {
  static const String loteria = 'Powerball';
  static const String backendRoute = 'powerball';
  static const String backendUrl = "https://pry-dataloto.onrender.com/powerball";

  final int maxSeleccion = 5;
  int? balotaRojaSeleccionada;
  List<int> seleccionados = [];
  List<int> listaProbables = [];
  List<int> listaBalotaRoja = [];
  List<Map<String, dynamic>> ultimosResultados = [];
  List<Map<String, dynamic>> todosResultadosHistorico = [];
  List<Map<String, dynamic>> _jugadasList = [];
  bool cargando = false;
  String? fechaPrediccion;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _shineController;
  late AnimationController _jugadasController;

  final GlobalKey<JugadasListGenericoState> _jugadasListKey = GlobalKey<JugadasListGenericoState>();
  String? userId;
  bool isSaving = false;
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> anuncios = [];
  String? _jackpot;

  @override
  void initState() {
    super.initState();
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
    );
    _shineController.repeat();

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

    final cached = await CacheService.getJson('powerball_prediccion');
    if (cached != null && cached["numeros"] != null && mounted) {
      final List<dynamic>? numeros = cached["numeros"];
      final List<dynamic>? roja = cached["balotaroja"];
      final String? fecha = cached["fecha"];
      if (numeros != null && fecha != null) {
        setState(() {
          listaProbables = numeros.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
          listaBalotaRoja = roja != null ? roja.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList() : [];
          fechaPrediccion = fecha;
          cargando = false;
        });
      }
    }

    if (listaProbables.isEmpty && mounted) {
      setState(() => cargando = true);
    }

    try {
      final uId = await _storage.read(key: 'user_id');
      final pIdStr = await _storage.read(key: 'pais_id');
      final pIdInt = pIdStr != null ? int.tryParse(pIdStr) : null;

      if (mounted) setState(() => userId = uId);

      await Future.wait([
        fetchNumeros(),
        _fetchUltimosResultados(),
        _fetchHistoricoCompleto(),
        _loadJugadas(),
        _jugadasListKey.currentState?.reload() ?? Future.value(),
        ApiService.getPublicidades(paisId: pIdInt).then((ads) {
          if (mounted) setState(() => anuncios = ads);
        }),
      ]);

      if (mounted) {
        _jugadasController.reset();
        _jugadasController.forward();
      }
    } catch (e) {
      debugPrint("❌ Error al cargar Powerball: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _fetchUltimosResultados() async {
    try {
      final response = await http.get(Uri.parse("https://pry-dataloto.onrender.com/powerball/ultimos5"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["resultados"] != null && mounted) {
          setState(() {
            ultimosResultados = List<Map<String, dynamic>>.from(data["resultados"]);
          });
          CacheService.setJson('powerball_ultimos5', data);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchHistoricoCompleto() async {
    final cached = await CacheService.getJson('powerball_historico_completo');
    if (cached != null && cached["resultados"] != null && mounted) {
      setState(() {
        todosResultadosHistorico = List<Map<String, dynamic>>.from(cached["resultados"]);
      });
    }

    try {
      final response = await http.get(Uri.parse("https://pry-dataloto.onrender.com/powerball/historico_completo"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["resultados"] != null && mounted) {
          setState(() {
            todosResultadosHistorico = List<Map<String, dynamic>>.from(data["resultados"]);
          });
          CacheService.setJson('powerball_historico_completo', data);
        }
      }
    } catch (_) {}
  }

  Future<void> fetchNumeros() async {
    try {
      final response = await http.get(Uri.parse(backendUrl));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final List<dynamic> nums = data["numeros"] ?? [];
        final List<dynamic> roja = data["balotaroja"] ?? [];
        final String fecha = data["fecha"] ?? "";
        setState(() {
          listaProbables = nums.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
          listaBalotaRoja = roja.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
          fechaPrediccion = fecha;
          if (data["jackpot"] != null) _jackpot = data["jackpot"].toString();
        });
        CacheService.setJson('powerball_prediccion', data);
      }
    } catch (e) {
      debugPrint("Error en fetchNumeros: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  void toggleNumero(int numero) {
    if (!mounted) return;
    setState(() {
      if (seleccionados.contains(numero)) {
        seleccionados.remove(numero);
      } else if (seleccionados.length < maxSeleccion) {
        seleccionados.add(numero);
      }
      _bounceController.reset();
      _bounceController.forward();
      if (!_shineController.isAnimating) {
        _shineController.repeat();
      }
    });
  }

  String _formatearFechaSimple(String fecha) {
    try {
      String soloFecha = fecha.substring(0, 10);
      DateTime parsed = DateTime.parse(soloFecha);
      const meses = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
      return "${parsed.day} ${meses[parsed.month - 1]} ${parsed.year}";
    } catch (_) {
      return fecha;
    }
  }

  String _getFechaProximoSorteo() {
    if (fechaPrediccion != null && fechaPrediccion!.isNotEmpty) {
      return _formatearFechaSimple(fechaPrediccion!);
    }
    if (ultimosResultados.isNotEmpty) {
      final String raw = ultimosResultados.first["fecha"]?.toString() ?? "";
      if (raw.isNotEmpty) return _formatearFechaSimple(raw);
    }
    return "05 ago 2026";
  }

  void _generarAleatorios() {
    if (!mounted || listaProbables.isEmpty) return;
    setState(() {
      final random = Random();
      seleccionados = [];
      while (seleccionados.length < maxSeleccion) {
        int nuevoNumero = listaProbables[random.nextInt(listaProbables.length)];
        if (!seleccionados.contains(nuevoNumero)) {
          seleccionados.add(nuevoNumero);
        }
      }
      if (listaBalotaRoja.isNotEmpty) {
        balotaRojaSeleccionada = listaBalotaRoja[random.nextInt(listaBalotaRoja.length)];
      }
      _bounceController.reset();
      _bounceController.forward();
      if (!_shineController.isAnimating) {
        _shineController.repeat();
      }
    });
  }

  Future<void> _loadJugadas() async {
    final cached = await CacheService.getJson('user_jugadas_${backendRoute}_${userId ?? "anon"}');
    if (cached != null && mounted) {
      setState(() {
        _jugadasList = List<Map<String, dynamic>>.from(cached);
      });
    }

    try {
      final response = await ApiService.listarJugadasGenerica(backendRoute);
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);
      if (mounted) {
        setState(() {
          _jugadasList = data;
        });
        CacheService.setJson('user_jugadas_${backendRoute}_${userId ?? "anon"}', data);
      }
    } catch (_) {}
  }

  Future<void> _guardarJugada(AppLocalizations? l10n) async {
    if (!mounted) return;

    if (userId == null || userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.iniciaSesionParaContinuar ?? "No se encontró el usuario. Inicia sesión.")),
      );
      return;
    }

    final bool isCustomMode = seleccionados.isNotEmpty || balotaRojaSeleccionada != null;
    List<int> numerosToSave;
    int redToSave;

    if (!isCustomMode) {
      final aiWhites = (listaProbables.length >= 5)
          ? listaProbables.take(5).toList()
          : [12, 28, 35, 42, 59];
      final aiRed = listaBalotaRoja.isNotEmpty ? listaBalotaRoja.first : 18;
      numerosToSave = aiWhites;
      redToSave = aiRed;
    } else {
      if (seleccionados.length != 5 || balotaRojaSeleccionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.debesSeleccionarBalotas ?? "Debes seleccionar 5 balotas principales y 1 Powerball roja")),
        );
        return;
      }
      numerosToSave = List<int>.from(seleccionados);
      redToSave = balotaRojaSeleccionada!;
    }

    final whites = List<int>.from(numerosToSave)..sort();
    final jugadaCompleta = [...whites, redToSave];

    // Verificar si esta jugada exacta ya fue guardada para evitar duplicados
    final bool yaExiste = _jugadasList.any((jugada) {
      final nums = (jugada["numeros"] as List<dynamic>?)?.cast<int>() ?? [];
      final bRoja = jugada["balota_roja"] ?? jugada["balotaroja"];
      final storedCompleta = nums.length >= 6
          ? nums.sublist(0, 6)
          : [...nums, if (bRoja != null) int.tryParse(bRoja.toString()) ?? 0];
      return const ListEquality().equals(storedCompleta, jugadaCompleta);
    });

    if (yaExiste) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.jugadaYaExiste ?? "Esta jugada ya se encuentra en tus jugadas guardadas"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => isSaving = true);

    final String targetFechaSorteo = ApiService.getProximoSorteoFecha(
      backendRoute,
      fechaPrediccion: fechaPrediccion,
      ultimoSorteoFecha: ultimosResultados.isNotEmpty ? ultimosResultados.first["fecha"]?.toString() : null,
    );

    try {
      await ApiService.crearJugadaGenerica(
        backendRoute,
        jugadaCompleta,
        userId!,
        balotaRoja: redToSave,
        fechaSorteo: targetFechaSorteo,
      );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${l10n?.errorGuardarJugada ?? "⚠️ Error al guardar"}: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Map<String, String> _calcularStats() {
    final listaUsar = todosResultadosHistorico.isNotEmpty ? todosResultadosHistorico : ultimosResultados;
    if (listaUsar.isEmpty) {
      return {
        "hot": "24",
        "hotV": "18 veces",
        "cold": "61",
        "coldV": "1 veces",
        "pairs": "3 - 2",
        "total": "50"
      };
    }

    final Map<int, int> f = {};
    for (int i = 1; i <= 69; i++) f[i] = 0;

    for (var r in listaUsar) {
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(5)) {
        if (n >= 1 && n <= 69) {
          f[n] = (f[n] ?? 0) + 1;
        }
      }
    }

    int maxB = 1, maxV = -1;
    int minB = 1, minV = 999999;

    f.forEach((b, count) {
      if (count > maxV) {
        maxV = count;
        maxB = b;
      }
      if (count < minV) {
        minV = count;
        minB = b;
      }
    });

    int p = 0, im = 0;
    if (listaUsar.isNotEmpty) {
      final ult = List<int>.from(listaUsar.first["numeros"] ?? []);
      for (var n in ult.take(5)) {
        if (n % 2 == 0) p++; else im++;
      }
    }

    return {
      "hot": "$maxB",
      "hotV": "$maxV veces",
      "cold": "$minB",
      "coldV": minV == 999999 ? "0 veces" : "$minV veces",
      "pairs": "$p - $im",
      "total": "${listaUsar.length}"
    };
  }

  Widget _build3DBall(int? numero, {Color baseColor = const Color(0xFFF33A21), double size = 45}) {
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(3, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: 0.4),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "–",
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: numero != null ? Colors.white : Colors.white54,
            shadows: numero != null
                ? [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _build3DBallPrediction(int? numero, {Color baseColor = const Color(0xFF1A4594), double size = 45}) {
    return ScaleTransition(
      scale: _bounceAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: Tween(begin: 0.0, end: 1.0).animate(_shineController),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(colors: [Colors.white.withValues(alpha: 0.25), Colors.transparent, Colors.white.withValues(alpha: 0.25)], stops: const [0.2, 0.5, 0.8]).createShader(bounds),
              blendMode: BlendMode.srcATop,
              child: Image.asset(baseColor == const Color(0xFFD32F2F) || baseColor == Colors.redAccent ? 'assets/images/red-ball.png' : 'assets/images/yellow-ball.png', width: size, height: size, fit: BoxFit.contain, errorBuilder: (_,__,___) => _build3DBall(numero, baseColor: baseColor, size: size)),
            ),
          ),
          Text(numero?.toString() ?? '–', style: TextStyle(fontSize: size * 0.35, fontWeight: FontWeight.bold, color: Colors.white, shadows: const [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1))])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = _calcularStats();
    return Scaffold(
      backgroundColor: AppColors.blackfondo,
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
                      const SizedBox(height: 24),
                      _buildRedBallsSection(l10n),
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
                LotteryAvatar3D(nombre: "Powerball", size: 32),
                const SizedBox(width: 10),
                Text("Powerball", style: AppTextStyles.tituloPrincipal.copyWith(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              "${l10n?.proximoSorteo ?? "Próximo sorteo"}: ${_getFechaProximoSorteo()}",
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
          child: Builder(builder: (context) {
            final parts = PaisHelper.getJackpotParts(_jackpot, fallbackValue: "\$180 millones USD");
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(l10n?.jackpotEstimado ?? "Jackpot estimado", style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 9)),
                Text(parts["value"]!, style: AppTextStyles.h2.copyWith(color: AppColors.yellow, fontWeight: FontWeight.bold, fontSize: 15)),
                if (parts["label"]!.isNotEmpty)
                  Text(parts["label"]!, style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 9)),
              ],
            );
          }),
        ),
      ],
    );
  }

  int _calcularAfinidadScore(List<int> nums, int maxBall) {
    final listaUsar = todosResultadosHistorico.isNotEmpty ? todosResultadosHistorico : ultimosResultados;
    if (listaUsar.isEmpty || nums.isEmpty) return 82;

    final Map<int, int> f = {};
    for (int i = 1; i <= maxBall; i++) f[i] = 0;
    for (var r in listaUsar) {
      final nList = List<int>.from(r["numeros"] ?? []);
      for (var n in nList.take(5)) {
        if (n >= 1 && n <= maxBall) f[n] = (f[n] ?? 0) + 1;
      }
    }

    final freqs = f.values.toList()..sort();
    final int minSum = freqs.take(5).fold(0, (a, b) => a + b);
    final int maxSum = freqs.reversed.take(5).fold(0, (a, b) => a + b);

    int sumUser = 0;
    for (var n in nums.take(5)) {
      sumUser += f[n] ?? 0;
    }

    if (maxSum == minSum) return 82;
    double ratio = (sumUser - minSum) / (maxSum - minSum);
    ratio = ratio.clamp(0.0, 1.0);
    return (52 + (ratio * 43)).round();
  }

  Widget _buildIAPrediction(AppLocalizations? l10n) {
    final bool isCustomSelection = seleccionados.isNotEmpty || balotaRojaSeleccionada != null;
    final listaUsar = todosResultadosHistorico.isNotEmpty ? todosResultadosHistorico : ultimosResultados;
    final int totalSorteosAnalizados = listaUsar.isNotEmpty ? listaUsar.length : 663;

    final numsEvaluados = isCustomSelection
        ? seleccionados
        : ((listaProbables.length >= 5) ? listaProbables.take(5).toList() : [12, 28, 35, 42, 59]);

    final int scoreAfinidad = _calcularAfinidadScore(numsEvaluados, 69);
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
                    isCustomSelection ? (l10n?.tuJugadaSeleccionada ?? "Tu Jugada Seleccionada") : (l10n?.prediccionIAHoy ?? "Predicción IA para hoy"),
                    style: AppTextStyles.mensajeImportante.copyWith(color: Colors.amber),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isCustomSelection ? (l10n?.balotasPrincipales(seleccionados.length) ?? "${seleccionados.length}/5 balotas") : (l10n?.basadaEnAnalisisDe(totalSorteosAnalizados) ?? "Basada en análisis de $totalSorteosAnalizados sorteos"),
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                  Text(
                    isCustomSelection ? (l10n?.tocaNumerosModificar ?? "Toca los números abajo para modificar") : (l10n?.indiceAfinidadHistorica ?? "Índice de afinidad histórica"),
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
                  Text("$scoreAfinidad%", style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...List.generate(5, (index) {
                int? val;
                if (isCustomSelection) {
                  val = index < seleccionados.length ? seleccionados[index] : null;
                } else {
                  val = (listaProbables.length >= 5) ? listaProbables[index] : [12, 28, 35, 42, 59][index];
                }
                return _build3DBallPrediction(val, baseColor: const Color(0xFF1A4594), size: 45);
              }),
              _build3DBallPrediction(
                isCustomSelection
                    ? balotaRojaSeleccionada
                    : (listaBalotaRoja.isNotEmpty ? listaBalotaRoja.first : 18),
                baseColor: Colors.redAccent,
                size: 45,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_tethering, color: AppColors.yellow, size: 12),
              const SizedBox(width: 4),
              Text(
                isCustomSelection ? (l10n?.jugada ?? "Jugada") : (l10n?.numeroSuerteSugerido ?? "Número de la suerte sugerido por IA"),
                style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
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
              l10n?.notaTendenciasEstadisticas ?? "Nota: son solo tendencias estadísticas, no garantías absolutas.",
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
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
          label: isSaving ? (l10n?.guardando ?? "Guardando...") : (l10n?.guardarJugada.replaceAll(" ", "\n") ?? "Guardar\nJugada"),
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
                builder: (_) => const LoteriasMisJugadasGenericaScreen(
                  loteriaNombre: loteria,
                  loteriaRoute: backendRoute,
                ),
              ),
            );
            await _jugadasListKey.currentState?.reload();
          },
        ),
        const SizedBox(width: 8),
        _buildActionTile(
          icon: Icons.bar_chart,
          label: (l10n?.verTodas ?? "Ver").replaceAll(" ", "\n") + "\n" + (l10n?.estadisticas ?? "Estadísticas"),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EstadisticasPowerballScreen()),
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
              border: Border.all(color: Colors.white.withValues(alpha: disabled ? 0.02 : 0.05)),
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
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.1),
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
              Text(l10n?.seleccionaNumeros ?? "Selecciona tus números", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
          Text("${l10n?.numerosOrdenadosProbabilidad ?? "Números ordenados de mayor a menor probabilidad."} \n${l10n?.tocaNumeroSeleccionar ?? "Toca un número para seleccionarlo"}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 20),
          listaProbables.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.yellow)))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final isSmall = screenWidth < 360;
                    final crossAxisCount = isSmall ? 6 : 8;
                    final ballSize = isSmall ? 32.0 : 40.0;
                    final spacing = isSmall ? 4.0 : 8.0;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: 1.0,
                      children: listaProbables.asMap().entries.map((entry) {
                        int index = entry.key;
                        int numero = entry.value;
                        bool isSelected = seleccionados.contains(numero);
                        Color baseColor = isSelected
                            ? Colors.amber
                            : (index < 34 ? Colors.redAccent : const Color(0xFF607D8B));
                        return GestureDetector(
                          onTap: () => toggleNumero(numero),
                          child: _build3DBall(numero, baseColor: baseColor, size: ballSize),
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
    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n?.balotasRojas ?? "Powerball Roja", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n?.numerosOrdenadosProbabilidad ?? "Números ordenados de mayor a menor probabilidad.", style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 20),
          listaBalotaRoja.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.yellow)))
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
                          child: _build3DBall(numero, baseColor: isSelected ? Colors.amber : Colors.redAccent, size: 38),
                        );
                      }).toList(),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildQuickSummary(Map<String, String> stats, AppLocalizations? l10n) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [const Icon(Icons.bar_chart, color: Colors.amber, size: 20), const SizedBox(width: 8), Text(l10n?.resumenRapido ?? "Resumen rápido", style: AppTextStyles.mensajeImportante)]),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EstadisticasPowerballScreen()),
              ),
              child: Text(l10n?.verEstadisticasCompletas ?? "Ver estadísticas completas ›", style: AppTextStyles.caption.copyWith(fontSize: 12, color: Colors.amber)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildStatCard(l10n?.masCaliente ?? "Más caliente", stats["hot"]!, stats["hotV"]!, l10n, icon: Icons.local_fire_department, iconColor: Colors.orangeAccent),
              const SizedBox(width: 10),
              _buildStatCard(l10n?.masFrio ?? "Más frío", stats["cold"]!, stats["coldV"]!, l10n, icon: Icons.ac_unit, iconColor: Colors.blueAccent),
              const SizedBox(width: 10),
              _buildStatCard(l10n?.paresImpares ?? "Pares - Impares", stats["pairs"]!, l10n?.ultimoSorteo ?? "Último sorteo", l10n, icon: Icons.balance, iconColor: Colors.white54),
              const SizedBox(width: 10),
              _buildStatCard("Score IA", "82%", l10n?.indiceAfinidadHistorica ?? "Afinidad histórica", l10n, icon: Icons.insights, iconColor: AppColors.yellow),
              const SizedBox(width: 10),
              _buildStatCard(l10n?.analizados ?? "Analizados", stats["total"]!, l10n?.sorteos ?? "Sorteos", l10n, icon: Icons.analytics_outlined, iconColor: Colors.white54),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String val, String sub, AppLocalizations? l10n, {required IconData icon, required Color iconColor}) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EstadisticasPowerballScreen()),
      ),
      child: Container(
        width: 125,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(val, style: AppTextStyles.h2.copyWith(fontSize: 18, color: Colors.white)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultadosSection(AppLocalizations? l10n) {
    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n?.resultados ?? "Resultados",
              style: AppTextStyles.h2,
            ),
          ),
          const SizedBox(height: 16),
          _buildResultadosContent(l10n),
        ],
      ),
    );
  }

  Widget _buildResultadosContent(AppLocalizations? l10n) {
    return Column(
      children: [
        if (ultimosResultados.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.amber)))
        else
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      l10n?.pais ?? "Fecha",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.fechasResultado,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      l10n?.resultados ?? "Resultados",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.fechasResultado,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...ultimosResultados.take(5).map((resultado) {
                final fechaRaw = resultado["fecha"]?.toString() ?? "Fecha desconocida";
                final fecha = fechaRaw.length >= 10 ? fechaRaw.substring(0, 10) : fechaRaw;
                final numeros = List<int>.from(resultado["numeros"] ?? []);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final isSmall = screenWidth < 360;
                      final ballSize = isSmall ? 25.0 : 31.0;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              fecha,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.mensajeImportante,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: numeros.isEmpty
                                  ? [
                                      Text(
                                        l10n?.sinNumeros ?? "Sin números",
                                        style: AppTextStyles.mensajeSecundario,
                                      ),
                                    ]
                                  : List.generate(numeros.length, (index) {
                                      final n = numeros[index];
                                      final isLast = index == numeros.length - 1;
                                      return SizedBox(
                                        width: ballSize,
                                        height: ballSize,
                                        child: _build3DBall(
                                          n,
                                          baseColor: isLast ? Colors.redAccent : Colors.amber,
                                          size: ballSize,
                                        ),
                                      );
                                    }),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }).toList(),
            ],
          ),
      ],
    );
  }

  Widget _buildNewsSection(AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n?.anunciosDestacados ?? "Anuncios destacados", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectorioLocalScreen()));
              },
              child: Text(l10n?.verTodas ?? "Ver más ›", style: const TextStyle(color: AppColors.yellow, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (cargando)
          const Center(child: CircularProgressIndicator(color: AppColors.amber))
        else if (anuncios.isEmpty)
          const Center(child: Text("No hay anuncios disponibles.", style: TextStyle(color: Colors.white38, fontSize: 12)))
        else
          InfiniteAdsCarousel(anuncios: anuncios),
      ],
    );
  }
}
