import 'package:dataloto/services/api_service.dart';
import '../services/cache_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/widgets/contenedor2.dart';
import 'package:dataloto/widgets/contenedor3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import '../widgets/contenedor.dart';
import '../widgets/custom_app_bar.dart';
import 'dart:math';
import 'package:dataloto/widgets/carrusel.dart';
import 'package:dataloto/screens/directorioLocal.dart';
import 'package:dataloto/screens/estadisticas_megamillions.dart';
import 'package:dataloto/screens/loterias_mis_jugadas_generica.dart';
import 'package:dataloto/widgets/jugadas_list_generico.dart';

class MegaMillionsScreen extends StatefulWidget {
  const MegaMillionsScreen({super.key});

  @override
  State<MegaMillionsScreen> createState() => _MegaMillionsScreenState();
}

class _MegaMillionsScreenState extends State<MegaMillionsScreen>
    with TickerProviderStateMixin {
  static const String loteria = 'Mega Millions';
  static const String backendRoute = 'megamillions';
  static const String backendUrl = "https://pry-dataloto.onrender.com/megamillions";

  final storage = const FlutterSecureStorage();
  final int maxSeleccion = 5;
  int? balotaRojaSeleccionada;
  List<int> seleccionados = [];
  List<int> listaProbables = [];
  List<int> listaBalotaRoja = [];
  List<Map<String, dynamic>> ultimosResultados = [];
  bool cargando = false;
  String? fechaPrediccion;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _shineController;
  late AnimationController _jugadasController;

  final GlobalKey<JugadasListGenericoState> _jugadasListKey =
      GlobalKey<JugadasListGenericoState>();
  String? userId;
  bool isSaving = false;
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> anuncios = [];
  bool mostrarResultados = false;

  @override
  void initState() {
    super.initState();
    _cargarOptimizado();

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

  Future<void> _cargarOptimizado() async {
    if (!mounted) return;

    final cached = await CacheService.getJson('${backendRoute}_prediccion');
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
      debugPrint("❌ Error al cargar Mega Millions en paralelo: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _fetchUltimosResultados() async {
    final cached = await CacheService.getJson('${backendRoute}_ultimos5');
    if (cached != null && cached["resultados"] != null && mounted) {
      final list = List<Map<String, dynamic>>.from(cached["resultados"]);
      setState(() {
        ultimosResultados = list;
      });
    }

    try {
      final response = await http.get(Uri.parse("$backendUrl/ultimos5"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["resultados"] != null && mounted) {
          final list = List<Map<String, dynamic>>.from(data["resultados"]);
          setState(() {
            ultimosResultados = list;
          });
          CacheService.setJson('${backendRoute}_ultimos5', data);
        }
      }
    } catch (e) {
      debugPrint("Excepción al consultar últimos resultados Mega Millions: $e");
    }
  }

  Future<void> fetchNumeros() async {
    final cached = await CacheService.getJson('${backendRoute}_prediccion');
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

    try {
      final response = await http.get(Uri.parse(backendUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic>? numeros = data["numeros"];
        final List<dynamic>? balotaroja = data["balotaroja"];
        final String? fecha = data["fecha"];

        if (numeros != null && fecha != null && balotaroja != null && mounted) {
          setState(() {
            listaProbables = numeros.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
            listaBalotaRoja = balotaroja.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
            fechaPrediccion = fecha;
          });
          CacheService.setJson('${backendRoute}_prediccion', data);
        }
      }
    } catch (e) {
      debugPrint("Error al consultar predicciones Mega Millions: $e");
    }
  }

  void toggleNumero(int numero) {
    setState(() {
      if (seleccionados.contains(numero)) {
        seleccionados.remove(numero);
      } else {
        if (seleccionados.length < maxSeleccion) {
          seleccionados.add(numero);
          _bounceController.reset();
          _bounceController.forward();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("¡Ya has seleccionado 5 números!")),
          );
        }
      }
    });
  }

  void _generarAleatorios() {
    if (listaProbables.isEmpty) return;
    setState(() {
      final random = Random();
      final poolCopy = List<int>.from(listaProbables);
      poolCopy.shuffle(random);
      seleccionados = poolCopy.take(maxSeleccion).toList()..sort();

      if (listaBalotaRoja.isNotEmpty) {
        balotaRojaSeleccionada = listaBalotaRoja[random.nextInt(listaBalotaRoja.length)];
      }

      _bounceController.reset();
      _bounceController.forward();
    });
  }

  Future<void> _guardarJugada() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes iniciar sesión para guardar tu jugada")),
      );
      return;
    }

    if (seleccionados.length != maxSeleccion || balotaRojaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes seleccionar 5 números y 1 Mega Ball")),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final whites = List<int>.from(seleccionados)..sort();
      final jugadaCompleta = [...whites, balotaRojaSeleccionada!];

      // 🔍 Validación de duplicados (igual a baloto.dart)
      final jugadasActuales = _jugadasListKey.currentState?.jugadas ?? [];
      final yaExiste = jugadasActuales.any((jugada) {
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

      await _jugadasListKey.currentState?.addJugada(jugadaCompleta, userId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al guardar la jugada: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  String _formatearFecha(String fechaRaw) {
    try {
      DateTime parsed = DateTime.parse(fechaRaw.substring(0, 10));
      const meses = [
        "enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
      ];
      return "${parsed.day} de ${meses[parsed.month - 1]}, ${parsed.year}";
    } catch (_) {
      return fechaRaw;
    }
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
            baseColor.withValues(alpha: 0.75),
            baseColor.withValues(alpha: 0.5),
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
            color: baseColor.withValues(alpha: 0.3),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        color: Colors.amber,
        onRefresh: _cargarOptimizado,
        child: CustomScrollView(
          slivers: [
            CustomSliverAppBar(
              title: loteria,
              pinned: true,
              floating: true,
              snap: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
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
                            "Números con mayor probabilidad según la IA para el sorteo del ${fechaPrediccion != null ? _formatearFecha(fechaPrediccion!) : '...'}",
                            style: AppTextStyles.mensajeSecundario,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppContainer(
                      child: JugadasListGenerico(
                        key: _jugadasListKey,
                        jugadasController: _jugadasController,
                        loteriaRoute: backendRoute,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppContainer3(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Tus números de la suerte",
                            style: AppTextStyles.h2.copyWith(
                              fontSize: 22,
                              color: AppColors.yellow,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: AppColors.yellow,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Seleccionados especialmente para ti",
                                style: AppTextStyles.caption.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = MediaQuery.of(context).size.width;
                              final isSmall = screenWidth < 360;
                              final ballSize = isSmall ? 36.0 : 45.0;
                              final fontSize = isSmall ? 14.0 : 16.0;

                              return Wrap(
                                alignment: WrapAlignment.center,
                                spacing: isSmall ? 4 : 6,
                                runSpacing: 8,
                                children: [
                                  ...List.generate(maxSeleccion, (index) {
                                    final tieneNumero = index < seleccionados.length;
                                    final numero = tieneNumero ? seleccionados[index] : null;

                                    return SizedBox(
                                      width: ballSize,
                                      height: ballSize,
                                      child: ScaleTransition(
                                        scale: tieneNumero ? _bounceAnimation : const AlwaysStoppedAnimation(1.0),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            if (tieneNumero) ...[
                                              RotationTransition(
                                                turns: Tween(begin: 0.0, end: 1.0).animate(_shineController),
                                                child: ShaderMask(
                                                  shaderCallback: (bounds) {
                                                    return LinearGradient(
                                                      colors: [
                                                        Colors.white.withOpacity(0.3),
                                                        Colors.transparent,
                                                        Colors.white.withOpacity(0.3),
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ).createShader(bounds);
                                                  },
                                                  blendMode: BlendMode.srcATop,
                                                  child: Image.asset(
                                                    "assets/images/yellow-ball.png",
                                                    width: ballSize,
                                                    height: ballSize,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (context, error, stackTrace) => _build3DBall(
                                                      numero,
                                                      baseColor: Colors.amber,
                                                      size: ballSize,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                "$numero",
                                                style: TextStyle(
                                                  fontSize: fontSize,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  shadows: const [
                                                    Shadow(
                                                      blurRadius: 4,
                                                      color: Colors.black,
                                                      offset: Offset(1, 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ] else ...[
                                              _build3DBall(
                                                null,
                                                baseColor: Colors.grey.shade400,
                                                size: ballSize,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }),

                                  SizedBox(
                                    width: ballSize,
                                    height: ballSize,
                                    child: ScaleTransition(
                                      scale: balotaRojaSeleccionada != null ? _bounceAnimation : const AlwaysStoppedAnimation(1.0),
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
                                                      Colors.white.withOpacity(0.25),
                                                      Colors.transparent,
                                                      Colors.white.withOpacity(0.25),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ).createShader(bounds);
                                                },
                                                blendMode: BlendMode.srcATop,
                                                child: Image.asset(
                                                  "assets/images/red-ball.png",
                                                  width: ballSize,
                                                  height: ballSize,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error, stackTrace) => _build3DBall(
                                                    balotaRojaSeleccionada,
                                                    baseColor: Colors.redAccent,
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
                                                  Shadow(
                                                    blurRadius: 4,
                                                    color: Colors.black,
                                                    offset: Offset(1, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else ...[
                                            _build3DBall(
                                              null,
                                              baseColor: Colors.grey.shade400,
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
                    ),
                    const SizedBox(height: 20),
                    AppContainer3(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _generarAleatorios,
                                  icon: const Icon(
                                    Icons.shuffle,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                  label: Text(
                                    "Generar",
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.button.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 40),
                                    backgroundColor: AppColors.yellow,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isSaving ? null : _guardarJugada,
                                  icon: isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Color(0xFF1E1E1E),
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.list,
                                          color: Color(0xFF1E1E1E),
                                          size: 18,
                                        ),
                                  label: Text(
                                    isSaving ? "Guardando..." : "Guardar",
                                    style: AppTextStyles.button.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 40),
                                    backgroundColor: AppColors.yellow,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
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
                                    if (mounted) {
                                      _jugadasController.reset();
                                      _jugadasController.forward();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 40),
                                    backgroundColor: AppColors.yellow,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: Text(
                                    "Mis jugadas",
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.button.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/estadisticas_megamillions');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 40),
                                    backgroundColor: AppColors.yellow,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: Text(
                                    "Estadísticas",
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.button.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text("Selecciona tus números", style: AppTextStyles.h2),
                          const SizedBox(height: 15),
                          Text(
                            "Números ordenados de mayor a menor probabilidad,\nColor rojo mayor probabilidad.",
                            style: AppTextStyles.mensajeSecundario.copyWith(
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
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
                                        Color baseColor = index < 35
                                            ? Colors.redAccent
                                            : const Color(0xFF607D8B);

                                        return GestureDetector(
                                          onTap: () => toggleNumero(numero),
                                          child: SizedBox(
                                            width: ballSize,
                                            height: ballSize,
                                            child: _build3DBall(
                                              numero,
                                              baseColor: isSelected ? Colors.amber : baseColor,
                                              size: ballSize,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                          const SizedBox(height: 15),
                          Text(
                            "Mega Ball",
                            style: AppTextStyles.h2.copyWith(fontSize: 20),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Números ordenados de mayor a menor probabilidad.",
                            style: AppTextStyles.mensajeSecundario.copyWith(
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
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
                                              baseColor: isSelected ? Colors.amber : Colors.redAccent,
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
                    const SizedBox(height: 20),
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
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Últimos 5 resultados Mega Millions",
                                        style: AppTextStyles.h2.copyWith(fontSize: 16),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Historial más reciente de Mega Millions",
                                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    mostrarResultados ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: AppColors.yellow,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (mostrarResultados) ...[
                            const SizedBox(height: 10),
                            _buildResultadosContent(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (anuncios.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Anuncios destacados", style: AppTextStyles.h2.copyWith(fontSize: 18)),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => DirectorioLocalScreen()),
                              ),
                              child: Text("Ver más ›", style: TextStyle(color: AppColors.yellow)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      InfiniteAdsCarousel(anuncios: anuncios),
                    ],
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultadosContent() {
    if (ultimosResultados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "Cargando resultados...",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return Column(
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
        ...ultimosResultados.map((resultado) {
          final fecha = resultado["fecha"]?.toString() ?? "";
          final numeros = (resultado["numeros"] as List<dynamic>?)?.cast<int>() ?? [];

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
                                        ? const Color(0xFFF33A21)
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
    );
  }
}
