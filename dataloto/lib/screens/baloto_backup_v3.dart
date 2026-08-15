import 'package:dataloto/screens/jugadas/mis_jugadas_screen.dart';
import 'package:dataloto/screens/directorioLocal.dart';
import 'package:dataloto/services/api_service.dart';
import '../services/cache_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/widgets/jugadas_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import '../widgets/contenedor.dart';
import '../widgets/contenedor2.dart';
import '../widgets/contenedor3.dart';
import '../widgets/custom_app_bar.dart';
import 'dart:math';
import 'package:dataloto/widgets/carrusel.dart';

class BalotoScreen extends StatefulWidget {
  const BalotoScreen({super.key});

  @override
  State<BalotoScreen> createState() => _BalotoScreenState();
}

class _BalotoScreenState extends State<BalotoScreen>
    with TickerProviderStateMixin {
  static const String loteria = 'Baloto/Revancha';
  final storage = const FlutterSecureStorage();

  final int maxSeleccion = 5;
  int? balotaRojaSeleccionada;
  List<int> seleccionados = [];
  List<int> listaProbables = [];
  List<int> listaBalotaRoja = [];
  List<Map<String, dynamic>> ultimosResultados = [];
  List<Map<String, dynamic>> ultimosResultadosBaloto = [];
  List<Map<String, dynamic>> ultimosResultadosRevancha = [];
  List<Map<String, dynamic>> _jugadasList = [];
  bool cargando = false;
  static const String backendUrl = "https://pry-dataloto.onrender.com/bloto";
  String? fechaPrediccion;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _shineController;
  late AnimationController _jugadasController;

  final GlobalKey<JugadasListWidgetState> _jugadasListKey = GlobalKey<JugadasListWidgetState>();
  String? userId;
  bool isSaving = false;
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> anuncios = [];
  bool mostrarResultados = false;
  bool mostrarResultadosRevancha = false;

  @override
  void initState() {
    super.initState();
    _cargarBalotoOptimizado();

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

  Future<void> _cargarBalotoOptimizado() async {
    if (!mounted) return;

    final cached = await CacheService.getJson('bloto_prediccion');
    if (cached != null && cached["numeros"] != null && mounted) {
      final List<dynamic>? numeros = cached["numeros"];
      final List<dynamic>? balotaroja = cached["balotaroja"];
      final String? fecha = cached["fecha"];
      if (numeros != null && fecha != null && balotaroja != null) {
        setState(() {
          listaProbables = numeros.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
          listaBalotaRoja = balotaroja.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
          fechaPrediccion = fecha;
          cargando = false;
        });
      }
    }

    if (listaProbables.isEmpty && mounted) {
      setState(() => cargando = true);
    }

    try {
      final keys = await Future.wait([
        storage.read(key: 'user_id'),
        _storage.read(key: 'pais_id'),
      ]);

      final uId = keys[0];
      final pIdStr = keys[1];
      final pIdInt = pIdStr != null ? int.tryParse(pIdStr) : null;

      if (mounted) setState(() => userId = uId);

      await Future.wait([
        fetchNumeros(),
        _fetchUltimosResultados(),
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
      debugPrint("❌ Error al cargar Baloto en paralelo: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _fetchUltimosResultados() async {
    final cached = await CacheService.getJson('bloto_ultimos5');
    if (cached != null && cached["resultados"] != null && mounted) {
      final list = List<Map<String, dynamic>>.from(cached["resultados"]);
      final balotoList = list.where((r) {
        final s = r["sorteo"]?.toString().toLowerCase() ?? "";
        return s == "baloto" || s.isEmpty;
      }).take(5).toList();
      final revanchaList = list.where((r) {
        final s = r["sorteo"]?.toString().toLowerCase() ?? "";
        return s == "revancha";
      }).take(5).toList();

      setState(() {
        ultimosResultados = list;
        ultimosResultadosBaloto = balotoList.isNotEmpty ? balotoList : list.take(5).toList();
        ultimosResultadosRevancha = revanchaList;
      });
    }

    try {
      final response = await http.get(
        Uri.parse("https://pry-dataloto.onrender.com/bloto/ultimos5"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["resultados"] != null && mounted) {
          final list = List<Map<String, dynamic>>.from(data["resultados"]);

          final balotoList = list.where((r) {
            final s = r["sorteo"]?.toString().toLowerCase() ?? "";
            return s == "baloto" || s.isEmpty;
          }).take(5).toList();

          final revanchaList = list.where((r) {
            final s = r["sorteo"]?.toString().toLowerCase() ?? "";
            return s == "revancha";
          }).take(5).toList();

          setState(() {
            ultimosResultados = list;
            ultimosResultadosBaloto =
                balotoList.isNotEmpty ? balotoList : list.take(5).toList();
            ultimosResultadosRevancha = revanchaList;
          });
          
          CacheService.setJson('bloto_ultimos5', data);
        }
      }
    } catch (e) {
      debugPrint("Excepción al consultar últimos resultados: $e");
    }
  }

  Future<void> fetchNumeros() async {
    final cached = await CacheService.getJson('bloto_prediccion');
    if (cached != null && cached["numeros"] != null && mounted) {
      final List<dynamic>? numeros = cached["numeros"];
      final List<dynamic>? balotaroja = cached["balotaroja"];
      final String? fecha = cached["fecha"];
      if (numeros != null && fecha != null && balotaroja != null) {
        setState(() {
          listaProbables = numeros.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
          listaBalotaRoja = balotaroja.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
          fechaPrediccion = fecha;
          cargando = false;
        });
      }
    }

    if (!mounted) return;
    if (listaProbables.isEmpty) setState(() => cargando = true);

    try {
      final response = await http.get(Uri.parse(backendUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic>? numeros = data["numeros"];
        final List<dynamic>? balotaroja = data["balotaroja"];
        final String? fecha = data["fecha"];

        if (numeros != null && fecha != null && balotaroja != null && mounted) {
          setState(() {
            listaProbables = numeros
                .map((e) => int.tryParse(e.toString()) ?? 0)
                .where((e) => e != 0)
                .toList();
            listaBalotaRoja = balotaroja
                .map((e) => int.tryParse(e.toString()) ?? 0)
                .where((e) => e != 0)
                .toList();
            fechaPrediccion = fecha;
            cargando = false;
          });
          
          CacheService.setJson('bloto_prediccion', data);
        }
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
    });
  }

  String _formatearFecha(String fecha) {
    try {
      String soloFecha = fecha.substring(0, 10);
      DateTime parsed = DateTime.parse(soloFecha);
      const meses = [
        "Ene", "Feb", "Mar", "Abr", "May", "Jun",
        "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
      ];
      String mes = meses[parsed.month - 1];
      return "${parsed.day.toString().padLeft(2, '0')} $mes ${parsed.year}";
    } catch (_) {
      return fecha;
    }
  }

  void _generarAleatorios() {
    if (listaProbables.isEmpty || listaBalotaRoja.isEmpty) return;

    if (!mounted) return;
    setState(() {
      final Random random = Random();
      seleccionados = [];

      while (seleccionados.length < maxSeleccion && listaProbables.isNotEmpty) {
        int nuevoNumero =
            listaProbables[random.nextInt(listaProbables.length)];
        if (!seleccionados.contains(nuevoNumero)) {
          seleccionados.add(nuevoNumero);
        }
      }

      balotaRojaSeleccionada =
          listaBalotaRoja[random.nextInt(listaBalotaRoja.length)];

      _bounceController.reset();
      _bounceController.forward();
      if (!_shineController.isAnimating) _shineController.repeat();
    });
  }

  Future<void> _loadJugadas() async {
    final cached = await CacheService.getJson('user_jugadas_bloto_${userId ?? "anon"}');
    if (cached != null && mounted) {
      setState(() {
        _jugadasList = List<Map<String, dynamic>>.from(cached);
      });
    }

    try {
      final response = await ApiService.listarJugadasBloto();
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
        response,
      );

      if (mounted) {
        setState(() {
          _jugadasList = data;
        });
        CacheService.setJson('user_jugadas_bloto_${userId ?? "anon"}', data);
      }
    } catch (e) {
      debugPrint("Error al cargar jugadas: $e");
    }
  }

  Future<void> _guardarJugada() async {
    if (!mounted) return;

    if (userId == null || userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se encontró el usuario. Inicia sesión.")),
      );
      return;
    }

    if (seleccionados.isEmpty || balotaRojaSeleccionada == null) return;

    if (seleccionados.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes seleccionar exactamente 5 balotas y 1 roja"),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final whites = List<int>.from(seleccionados)..sort();
      final nuevaJugada = [...whites, balotaRojaSeleccionada!];

      await _loadJugadas();

      final yaExiste = _jugadasList.any((jugada) {
        final nums = (jugada["numeros"] as List<dynamic>?)?.cast<int>() ?? [];
        if (nums.length != 6) return false;

        final storedWhites = nums.sublist(0, 5)..sort();
        final storedRed = nums[5];

        return const ListEquality().equals(storedWhites, whites) &&
            storedRed == balotaRojaSeleccionada;
      });

      if (yaExiste) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Esa jugada ya existe")),
        );
        return;
      }

      await _jugadasListKey.currentState!.addJugada(
        nuevaJugada,
        userId!,
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error: $e")),
      );
    }

    if (mounted) setState(() => isSaving = false);
  }

  // 📊 CÁLCULO EN TIEMPO REAL DE VALORES REALES DE LAS ESTADÍSTICAS
  Map<String, String> _calcularEstadisticasReales() {
    if (ultimosResultados.isEmpty) {
      return {
        "masCalienteNum": "38",
        "masCalienteVeces": "9 veces",
        "masFrioNum": "42",
        "masFrioVeces": "2 veces",
        "paresImpares": "21 - 18",
        "analizados": "50",
      };
    }

    final Map<int, int> frecs = {};
    for (int i = 1; i <= 43; i++) {
      frecs[i] = 0;
    }

    for (var r in ultimosResultados) {
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(5)) {
        if (n >= 1 && n <= 43) {
          frecs[n] = (frecs[n] ?? 0) + 1;
        }
      }
    }

    int maxBall = 38;
    int maxVal = 0;
    int minBall = 42;
    int minVal = 999;

    frecs.forEach((ball, count) {
      if (count > maxVal) {
        maxVal = count;
        maxBall = ball;
      }
      if (count < minVal) {
        minVal = count;
        minBall = ball;
      }
    });

    int pares = 0;
    int impares = 0;
    if (ultimosResultados.isNotEmpty) {
      final ultNums = List<int>.from(ultimosResultados.first["numeros"] ?? []);
      for (var n in ultNums.take(5)) {
        if (n % 2 == 0) {
          pares++;
        } else {
          impares++;
        }
      }
    }

    return {
      "masCalienteNum": "$maxBall",
      "masCalienteVeces": "$maxVal veces",
      "masFrioNum": "$minBall",
      "masFrioVeces": minVal == 999 ? "0 veces" : "$minVal veces",
      "paresImpares": "$pares - $impares",
      "analizados": "${ultimosResultados.length}",
    };
  }

  List<int> _getMasCalientesTop5() {
    if (ultimosResultados.isEmpty) {
      return [38, 12, 8, 40, 16];
    }
    final Map<int, int> frecs = {};
    for (int i = 1; i <= 43; i++) {
      frecs[i] = 0;
    }
    for (var r in ultimosResultados) {
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(5)) {
        if (n >= 1 && n <= 43) {
          frecs[n] = (frecs[n] ?? 0) + 1;
        }
      }
    }
    final sorted = frecs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
  }

  Widget _build3DBall(
    int? numero, {
    Color baseColor = const Color(0xFFF33A21),
    double size = 45,
    bool isLoading = false,
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
        child: isLoading
            ? SizedBox(
                width: size * 0.38,
                height: size * 0.38,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.yellow,
                ),
              )
            : Text(
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

  Widget _buildStatCard(String label, String value, String subValue, {IconData? icon, Color? iconColor}) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          if (icon != null) Icon(icon, color: iconColor ?? AppColors.yellow, size: 22),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(subValue, style: const TextStyle(color: Colors.white38, fontSize: 9), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ⭐ RESUMEN RÁPIDO (Ubicado INMEDIATAMENTE después del título principal)
  Widget _buildQuickSummarySection() {
    final stats = _calcularEstadisticasReales();
    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart, color: AppColors.yellow, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "Resumen rápido",
                    style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/estadisticas_bloto'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    "Ver estadísticas completas ›",
                    style: AppTextStyles.mensajeSecundario.copyWith(
                      color: AppColors.yellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatCard("Más caliente", stats["masCalienteNum"]!, stats["masCalienteVeces"]!, icon: Icons.local_fire_department, iconColor: Colors.orangeAccent),
                const SizedBox(width: 10),
                _buildStatCard("Más frío", stats["masFrioNum"]!, stats["masFrioVeces"]!, icon: Icons.ac_unit, iconColor: Colors.blueAccent),
                const SizedBox(width: 10),
                _buildStatCard("Pares - Impares", stats["paresImpares"]!, "Último sorteo", icon: Icons.balance, iconColor: Colors.amberAccent),
                const SizedBox(width: 10),
                _buildStatCard("Score IA", "82%", "Afinidad histórica", icon: Icons.gps_fixed, iconColor: AppColors.yellow),
                const SizedBox(width: 10),
                _buildStatCard("Analizados", stats["analizados"]!, "Sorteos", icon: Icons.analytics_outlined, iconColor: Colors.cyanAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🤖 TARJETA PREDICCIÓN IA ESTILO BOCETO 4 + BALOTAS ANIMADAS CLÁSICAS
  Widget _buildAIPredictionCardBoceto() {
    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Predicción IA para hoy",
                      style: AppTextStyles.tituloPrincipal.copyWith(
                        color: Colors.amberAccent,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Basada en análisis de ${ultimosResultados.isEmpty ? 663 : ultimosResultados.length} sorteos",
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const Text(
                      "Índice de afinidad histórica",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.yellow, width: 3),
                ),
                child: const Center(
                  child: Text(
                    "82%",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // BALOTAS CON ANIMACIÓN DE ROTACIÓN DE BRILLO Y REBOTE CLÁSICA
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isSmall = screenWidth < 360;
              final ballSize = isSmall ? 36.0 : 45.0;
              final fontSize = isSmall ? 12.0 : 16.0;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ...List.generate(maxSeleccion, (index) {
                    if (index < seleccionados.length) {
                      return ScaleTransition(
                        scale: _bounceAnimation,
                        child: SizedBox(
                          width: ballSize,
                          height: ballSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              RotationTransition(
                                turns: Tween(begin: 0.0, end: 1.0).animate(_shineController),
                                child: ShaderMask(
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.25),
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.25),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      stops: const [0.2, 0.5, 0.8],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.srcATop,
                                  child: Image.asset(
                                    "assets/images/yellow-ball.png",
                                    width: ballSize,
                                    height: ballSize,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _build3DBall(
                                      seleccionados[index],
                                      baseColor: const Color(0xFF1A4594),
                                      size: ballSize,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                "${seleccionados[index]}",
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      final fallbackVal = listaProbables.length > index ? listaProbables[index] : null;
                      return SizedBox(
                        width: ballSize,
                        height: ballSize,
                        child: _build3DBall(fallbackVal, baseColor: const Color(0xFF1A4594), size: ballSize),
                      );
                    }
                  }),
                  ScaleTransition(
                    scale: _bounceAnimation,
                    child: SizedBox(
                      width: ballSize,
                      height: ballSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (balotaRojaSeleccionada != null) ...[
                            RotationTransition(
                              turns: Tween(begin: 0.0, end: 1.0).animate(_shineController),
                              child: ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.25),
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.25),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    stops: const [0.2, 0.5, 0.8],
                                  ).createShader(bounds);
                                },
                                blendMode: BlendMode.srcATop,
                                child: Image.asset(
                                  "assets/images/red-ball.png",
                                  width: ballSize,
                                  height: ballSize,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => _build3DBall(
                                    balotaRojaSeleccionada,
                                    baseColor: const Color(0xFFD32F2F),
                                    size: ballSize,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              "$balotaRojaSeleccionada",
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1)),
                                ],
                              ),
                            ),
                          ] else ...[
                            _build3DBall(
                              listaBalotaRoja.isNotEmpty ? listaBalotaRoja[0] : null,
                              baseColor: const Color(0xFFD32F2F),
                              size: ballSize,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 15),
          ShimmerBorderContainer(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Text(
                "💡 Nota: son solo tendencias estadísticas, no garantías absolutas. Juega con responsabilidad.",
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎛️ GRILLA DE 4 ACCIONES RÁPIDAS (BOCETO 4) + BOTÓN COMPARTIR
  Widget _buildActionGridBoceto() {
    return AppContainer3(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.casino_outlined,
                  label: "Generar\nJugada",
                  onTap: _generarAleatorios,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionTile(
                  icon: isSaving ? Icons.hourglass_top : Icons.bookmark_border,
                  label: isSaving ? "Guardando..." : "Guardar\nJugada",
                  onTap: isSaving ? null : _guardarJugada,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.bar_chart,
                  label: "Mis\nJugadas",
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MisJugadasScreen(loteriaNombre: "Baloto", loteriaRoute: "bloto"),
                      ),
                    );
                    await _jugadasListKey.currentState?.reload();
                    if (mounted) {
                      _jugadasController.reset();
                      _jugadasController.forward();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.emoji_events_outlined,
                  label: "Estadísticas",
                  onTap: () {
                    Navigator.pushNamed(context, '/estadisticas_bloto');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({required IconData icon, required String label, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.yellow, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
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
    );
  }

  // 🏆 TARJETA DE ÚLTIMO SORTEO (BOCETO 4)
  Widget _buildUltimoSorteoCardBoceto() {
    final Map<String, dynamic>? ultimo = ultimosResultadosBaloto.isNotEmpty
        ? ultimosResultadosBaloto.first
        : ultimosResultados.isNotEmpty ? ultimosResultados.first : null;

    final fechaStr = ultimo != null ? _formatearFecha(ultimo["fecha"]?.toString() ?? "") : "29 Jul 2026";
    final nums = ultimo != null ? List<int>.from(ultimo["numeros"] ?? []) : [6, 16, 22, 28, 37, 5];

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Último sorteo",
                style: AppTextStyles.h2.copyWith(fontSize: 16),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
            ],
          ),
          const SizedBox(height: 2),
          Text(fechaStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: nums.asMap().entries.map((e) {
              final isLast = e.key == nums.length - 1;
              return _build3DBall(
                e.value,
                baseColor: isLast ? const Color(0xFFD32F2F) : const Color(0xFF1A4594),
                size: 38,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 🔥 TARJETA DE NÚMEROS MÁS CALIENTES (BOCETO 4 + DATOS REALES)
  Widget _buildMasCalientesCardBoceto() {
    final top5 = _getMasCalientesTop5();

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Números más calientes",
                style: AppTextStyles.h2.copyWith(fontSize: 16),
              ),
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/estadisticas_bloto'),
                child: const Text(
                  "Ver más ›",
                  style: TextStyle(color: AppColors.yellow, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: top5.map((nVal) {
              return _build3DBall(nVal, baseColor: Colors.amber, size: 38);
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        color: Colors.amber,
        backgroundColor: const Color(0xFF1E293B),
        onRefresh: () async {
          await _cargarBalotoOptimizado();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const CustomSliverAppBar(
              title: "$loteria",
              pinned: true,
              floating: true,
              snap: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TÍTULO PRINCIPAL DE LA PANTALLA
                    AppContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Predicciones Inteligentes para $loteria",
                            style: AppTextStyles.tituloPrincipal.copyWith(
                              color: Colors.amberAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Números con mayor probabilidad según la IA "
                            "para el sorteo del ${fechaPrediccion != null ? _formatearFecha(fechaPrediccion!) : '...'}",
                            style: AppTextStyles.mensajeSecundario,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. ⭐ RESUMEN RÁPIDO (Ubicación requerida: Inmediatamente después del título)
                    _buildQuickSummarySection(),
                    const SizedBox(height: 18),

                    // 3. PREDICCIÓN IA PARA HOY (BOCETO 4 + BALOTAS ANIMADAS CLÁSICAS)
                    _buildAIPredictionCardBoceto(),
                    const SizedBox(height: 18),

                    // 4. GRILLA DE ACCIONES RÁPIDAS (BOCETO 4: Generar, Guardar, Mis Jugadas, Estadísticas)
                    _buildActionGridBoceto(),
                    const SizedBox(height: 18),

                    // 5. TARJETA ÚLTIMO SORTEO (BOCETO 4)
                    _buildUltimoSorteoCardBoceto(),
                    const SizedBox(height: 18),

                    // 6. TARJETA NÚMEROS MÁS CALIENTES (BOCETO 4 + DATOS REALES)
                    _buildMasCalientesCardBoceto(),
                    const SizedBox(height: 18),

                    // 7. SELECCIONA TUS NÚMEROS (1-43) - GRILLA Y ESTILOS CLÁSICOS DE BALOTO
                    AppContainer3(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Selecciona tus números", style: AppTextStyles.h2),
                          const SizedBox(height: 8),
                          Text(
                            "Números ordenados de mayor a menor probabilidad,\nColor rojo mayor probabilidad.",
                            style: AppTextStyles.mensajeSecundario.copyWith(
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          listaProbables.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.yellow,
                                    ),
                                  ),
                                )
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
                                        Color baseColor = index < 21
                                            ? Colors.redAccent
                                            : const Color(0xFF607D8B);

                                        return GestureDetector(
                                          onTap: () => toggleNumero(numero),
                                          child: SizedBox(
                                            width: ballSize,
                                            height: ballSize,
                                            child: _build3DBall(
                                              numero,
                                              baseColor: isSelected
                                                  ? Colors.amber
                                                  : baseColor,
                                              size: ballSize,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 8. BALOTAS ROJAS (1-16) - GRILLA Y ESTILOS CLÁSICOS DE BALOTO
                    AppContainer3(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Balotas Rojas",
                            style: AppTextStyles.h2.copyWith(fontSize: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Números ordenados de mayor a menor probabilidad.",
                            style: AppTextStyles.mensajeSecundario.copyWith(
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          listaBalotaRoja.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.yellow,
                                    ),
                                  ),
                                )
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
                                          child: SizedBox(
                                            width: ballSize,
                                            height: ballSize,
                                            child: _build3DBall(
                                              numero,
                                              baseColor: isSelected
                                                  ? Colors.amber
                                                  : Colors.redAccent,
                                              size: ballSize,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 9. JUGADAS GUARDADAS EN DB DE USUARIO (`JugadasListBloto`)
                    AppContainer(
                      child: JugadasListWidget(
                        key: _jugadasListKey,
                        jugadasController: _jugadasController,
                        loteriaRoute: "bloto",
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 10. ÚLTIMOS 5 RESULTADOS BALOTO (ACORDEÓN COLAPSABLE ORIGINAL)
                    AppContainer3(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                mostrarResultados = !mostrarResultados;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 0.1),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Últimos 5 resultados Baloto",
                                    style: AppTextStyles.h2,
                                  ),
                                  Icon(
                                    mostrarResultados
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: AppColors.yellow,
                                    size: 26,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: _buildResultadosContent(
                              "Baloto",
                              listaResultados: ultimosResultadosBaloto.isNotEmpty
                                  ? ultimosResultadosBaloto
                                  : ultimosResultados,
                            ),
                            secondChild: const SizedBox.shrink(),
                            crossFadeState: mostrarResultados
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 500),
                            alignment: Alignment.topCenter,
                            firstCurve: Curves.easeOut,
                            secondCurve: Curves.easeIn,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 11. ÚLTIMOS 5 RESULTADOS REVANCHA (ACORDEÓN COLAPSABLE ORIGINAL)
                    AppContainer3(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                mostrarResultadosRevancha = !mostrarResultadosRevancha;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 0.1),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Últimos 5 resultados Revancha",
                                    style: AppTextStyles.h2,
                                  ),
                                  Icon(
                                    mostrarResultadosRevancha
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: AppColors.yellow,
                                    size: 26,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: _buildResultadosContent(
                              "Baloto Revancha",
                              listaResultados: ultimosResultadosRevancha,
                            ),
                            secondChild: const SizedBox.shrink(),
                            crossFadeState: mostrarResultadosRevancha
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 500),
                            alignment: Alignment.topCenter,
                            firstCurve: Curves.easeOut,
                            secondCurve: Curves.easeIn,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 12. ANUNCIOS DESTACADOS
                    if (cargando)
                      const Center(child: CircularProgressIndicator(color: AppColors.amber))
                    else if (anuncios.isEmpty)
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          Center(
                            child: Text(
                              "No hay anuncios disponibles.",
                              style: AppTextStyles.mensajeSecundario.copyWith(
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Anuncios destacados",
                                  style: AppTextStyles.h2.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DirectorioLocalScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Ver más ›",
                                    style: AppTextStyles.mensajeSecundario.copyWith(
                                      color: AppColors.yellow,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          InfiniteAdsCarousel(
                            key: ValueKey(anuncios.length),
                            anuncios: anuncios,
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultadosContent(String loteria, {List<Map<String, dynamic>>? listaResultados}) {
    final resultadosUsar = listaResultados ?? ultimosResultados;
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          "Historial más reciente del $loteria",
          style: AppTextStyles.mensajeSecundario,
        ),
        const SizedBox(height: 20),

        if (resultadosUsar.isEmpty)
          const Center(child: CircularProgressIndicator(color: AppColors.amber))
        else
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      "Fecha",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.fechasResultado,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "Resultados",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.fechasResultado,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...resultadosUsar.map((resultado) {
                final fecha = resultado["fecha"]?.toString() ?? "Fecha desconocida";
                final numeros = List<int>.from(resultado["numeros"] ?? []);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final isSmall = screenWidth < 360;
                      final ballSize = isSmall ? 25.0 : 33.0;

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
                                        "Sin números",
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
                                          baseColor: isLast
                                              ? Colors.redAccent
                                              : Colors.amber,
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
}
