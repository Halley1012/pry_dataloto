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

class MillionaireLifeScreen extends StatefulWidget {
  const MillionaireLifeScreen({super.key});

  @override
  State<MillionaireLifeScreen> createState() => _MillionaireLifeScreenState();
}

class _MillionaireLifeScreenState extends State<MillionaireLifeScreen> with TickerProviderStateMixin {
  static const String loteria = 'Millionaire for Life';
  static const String backendRoute = 'millionaire_life';
  static const String backendUrl = "https://pry-dataloto.onrender.com/millionaire_life";

  final storage = const FlutterSecureStorage();
  final int maxSeleccion = 5;
  int? balotaRojaSeleccionada;
  List<int> seleccionados = [];
  List<int> listaProbables = [];
  List<int> listaBalotaRoja = [];
  List<Map<String, dynamic>> ultimosResultados = [];
  List<Map<String, dynamic>> _jugadasList = [];
  bool cargando = false;
  String? fechaPrediccion;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _shineController;
  late AnimationController _jugadasController;

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
        _loadJugadas(),
        ApiService.getPublicidades(paisId: pIdInt).then((ads) {
          if (mounted) setState(() => anuncios = ads);
        }),
      ]);

      if (mounted) {
        _jugadasController.reset();
        _jugadasController.forward();
      }
    } catch (e) {
      debugPrint("❌ Error al cargar $loteria: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _fetchUltimosResultados() async {
    final cached = await CacheService.getJson('${backendRoute}_ultimos5');
    if (cached != null && cached["resultados"] != null && mounted) {
      setState(() {
        ultimosResultados = List<Map<String, dynamic>>.from(cached["resultados"]);
      });
    }

    try {
      final response = await http.get(Uri.parse("$backendUrl/ultimos5"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["resultados"] != null && mounted) {
          setState(() {
            ultimosResultados = List<Map<String, dynamic>>.from(data["resultados"]);
          });
          CacheService.setJson('${backendRoute}_ultimos5', data);
        }
      }
    } catch (e) {
      debugPrint("Excepción al consultar últimos resultados: $e");
    }
  }

  Future<void> fetchNumeros() async {
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
            cargando = false;
          });
          CacheService.setJson('${backendRoute}_prediccion', data);
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
      const meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
      String mes = meses[parsed.month - 1];
      return "${parsed.day} de $mes, ${parsed.year}";
    } catch (_) {
      return fecha;
    }
  }

  void _generarAleatorios() {
    if (listaProbables.isEmpty || listaBalotaRoja.isEmpty) return;
    setState(() {
      final Random random = Random();
      seleccionados = [];
      while (seleccionados.length < maxSeleccion && listaProbables.isNotEmpty) {
        int nuevoNumero = listaProbables[random.nextInt(listaProbables.length)];
        if (!seleccionados.contains(nuevoNumero)) seleccionados.add(nuevoNumero);
      }
      balotaRojaSeleccionada = listaBalotaRoja[random.nextInt(listaBalotaRoja.length)];
      _bounceController.reset();
      _bounceController.forward();
      if (!_shineController.isAnimating) _shineController.repeat();
    });
  }

  Future<void> _loadJugadas() async {
    try {
      final response = await ApiService.listarJugadasGenerica(backendRoute);
      if (mounted) {
        setState(() {
          _jugadasList = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint("Error al cargar jugadas: $e");
    }
  }

  Future<void> _guardarJugada() async {
    if (userId == null || userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se encontró el usuario. Inicia sesión.")));
      return;
    }
    if (seleccionados.length != 5 || balotaRojaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debes seleccionar exactamente 5 balotas y 1 roja")));
      return;
    }

    setState(() => isSaving = true);
    try {
      final whites = List<int>.from(seleccionados)..sort();
      final nuevaJugada = [...whites, balotaRojaSeleccionada!];
      await ApiService.crearJugadaGenerica(backendRoute, nuevaJugada, userId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ ¡Jugada de Millionaire for Life guardada exitosamente!")));
      _loadJugadas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⚠️ Error: $e")));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _borrarJugada(int jugadaId) async {
    if (userId == null) return;
    try {
      await ApiService.borrarJugadaGenerica(backendRoute, jugadaId, userId!);
      _loadJugadas();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        color: Colors.amber,
        backgroundColor: const Color(0xFF1E293B),
        onRefresh: _cargarOptimizado,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const CustomSliverAppBar(
              title: loteria,
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
                    AppContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Predicciones Inteligentes para $loteria",
                            style: AppTextStyles.tituloPrincipal.copyWith(color: Colors.amberAccent),
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
                    AppContainer3(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Tus números de la suerte",
                            style: AppTextStyles.tituloPrincipal.copyWith(color: Colors.amberAccent, fontSize: 22),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "✨ Seleccionados especialmente para ti",
                            style: TextStyle(color: Colors.grey[400], fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = MediaQuery.of(context).size.width;
                              final isSmall = screenWidth < 360;
                              final ballSize = isSmall ? 35.0 : 45.0;
                              final spacing = isSmall ? 4.0 : 6.0;
                              final fontSize = isSmall ? 12.0 : 16.0;

                              return Wrap(
                                spacing: spacing,
                                runSpacing: isSmall ? 6.0 : 8.0,
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
                                                  shaderCallback: (bounds) => LinearGradient(
                                                    colors: [Colors.white.withOpacity(0.25), Colors.transparent, Colors.white.withOpacity(0.25)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ).createShader(bounds),
                                                  blendMode: BlendMode.srcATop,
                                                  child: Image.asset(
                                                    "assets/images/yellow-ball.png",
                                                    width: ballSize,
                                                    height: ballSize,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => _build3DBall(
                                                      seleccionados[index],
                                                      baseColor: Colors.lightGreen,
                                                      size: ballSize,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                "${seleccionados[index]}",
                                                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    } else {
                                      return SizedBox(
                                        width: ballSize,
                                        height: ballSize,
                                        child: _build3DBall(null, baseColor: Colors.grey.shade300, size: ballSize),
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
                                                shaderCallback: (bounds) => LinearGradient(
                                                  colors: [Colors.white.withOpacity(0.25), Colors.transparent, Colors.white.withOpacity(0.25)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ).createShader(bounds),
                                                blendMode: BlendMode.srcATop,
                                                child: Image.asset(
                                                  "assets/images/red-ball.png",
                                                  width: ballSize,
                                                  height: ballSize,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) => _build3DBall(
                                                    balotaRojaSeleccionada,
                                                    baseColor: Colors.redAccent,
                                                    size: ballSize,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "$balotaRojaSeleccionada",
                                              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ] else ...[
                                            _build3DBall(null, baseColor: Colors.grey.shade300, size: ballSize),
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
                                  icon: const Icon(Icons.shuffle, color: Colors.black, size: 18),
                                  label: Text("Generar", textAlign: TextAlign.center, style: AppTextStyles.button.copyWith(fontSize: 14)),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 40),
                                    backgroundColor: AppColors.yellow,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isSaving ? null : _guardarJugada,
                                  icon: isSaving
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E1E1E)))
                                      : const Icon(Icons.list, color: Color(0xFF1E1E1E), size: 18),
                                  label: Text(isSaving ? "Guardando..." : "Guardar", style: AppTextStyles.button.copyWith(fontSize: 14)),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 40),
                                    backgroundColor: AppColors.yellow,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
                            style: AppTextStyles.mensajeSecundario.copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          listaProbables.isEmpty
                              ? const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Center(child: CircularProgressIndicator(color: AppColors.yellow)))
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isSmall = MediaQuery.of(context).size.width < 360;
                                    final crossAxisCount = isSmall ? 6 : 8;
                                    final ballSize = isSmall ? 32.0 : 40.0;

                                    return GridView.count(
                                      crossAxisCount: crossAxisCount,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: isSmall ? 4.0 : 8.0,
                                      mainAxisSpacing: isSmall ? 4.0 : 8.0,
                                      children: listaProbables.asMap().entries.map((entry) {
                                        int index = entry.key;
                                        int numero = entry.value;
                                        bool isSelected = seleccionados.contains(numero);
                                        Color baseColor = index < 21 ? Colors.redAccent : const Color(0xFF607D8B);

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
                          const SizedBox(height: 10),
                          Text("Cash Ball (Roja)", style: AppTextStyles.h2.copyWith(fontSize: 20)),
                          const SizedBox(height: 10),
                          listaBalotaRoja.isEmpty
                              ? const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Center(child: CircularProgressIndicator(color: AppColors.yellow)))
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isSmall = MediaQuery.of(context).size.width < 360;
                                    final crossAxisCount = isSmall ? 6 : 8;
                                    final ballSize = isSmall ? 32.0 : 40.0;

                                    return GridView.count(
                                      crossAxisCount: crossAxisCount,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: isSmall ? 4.0 : 8.0,
                                      mainAxisSpacing: isSmall ? 4.0 : 8.0,
                                      children: listaBalotaRoja.map((numero) {
                                        bool isSelected = balotaRojaSeleccionada == numero;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              balotaRojaSeleccionada = isSelected ? null : numero;
                                              _bounceController.reset();
                                              _bounceController.forward();
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
                            onTap: () => setState(() => mostrarResultados = !mostrarResultados),
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Últimos 5 resultados Millionaire for Life", style: AppTextStyles.h2),
                                Icon(mostrarResultados ? Icons.expand_less : Icons.expand_more, color: AppColors.yellow, size: 26),
                              ],
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: _buildResultadosContent(loteria, listaResultados: ultimosResultados),
                            secondChild: const SizedBox.shrink(),
                            crossFadeState: mostrarResultados ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppContainer3(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("📝 Mis Jugadas Guardadas", style: AppTextStyles.h2),
                          const SizedBox(height: 12),
                          _jugadasList.isEmpty
                              ? Text("No tienes jugadas guardadas para esta lotería.", style: AppTextStyles.mensajeSecundario)
                              : Column(
                                  children: _jugadasList.map((j) {
                                    final jId = j["id"];
                                    final nums = (j["numeros"] as List? ?? []).map((e) => int.tryParse(e.toString()) ?? 0).toList();
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: const Color(0xFF282E3B), borderRadius: BorderRadius.circular(10)),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(nums.join(" - "), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                            onPressed: () => jId != null ? _borrarJugada(jId) : null,
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (anuncios.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Anuncios destacados", style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                            TextButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DirectorioLocalScreen())),
                              child: Text("Ver más ›", style: AppTextStyles.mensajeSecundario.copyWith(color: AppColors.yellow)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      InfiniteAdsCarousel(anuncios: anuncios),
                      const SizedBox(height: 50),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DBall(int? numero, {Color baseColor = const Color(0xFFF33A21), double size = 45}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [baseColor.withOpacity(0.95), baseColor.withOpacity(0.8), baseColor.withOpacity(0.6)],
          center: Alignment.topLeft,
          radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), offset: const Offset(3, 3), blurRadius: 6),
          BoxShadow(color: baseColor.withOpacity(0.4), offset: const Offset(-2, -2), blurRadius: 4),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.2),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "–",
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: numero != null ? Colors.white : Colors.white54,
            shadows: numero != null ? [Shadow(color: Colors.black.withOpacity(0.6), offset: const Offset(1, 1), blurRadius: 2)] : null,
          ),
        ),
      ),
    );
  }

  Widget _buildResultadosContent(String loteriaNombre, {required List<Map<String, dynamic>> listaResultados}) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text("Historial más reciente de $loteriaNombre", style: AppTextStyles.mensajeSecundario),
        const SizedBox(height: 20),
        if (listaResultados.isEmpty)
          const Center(child: CircularProgressIndicator(color: AppColors.amber))
        else
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(flex: 1, child: Text("Fecha", textAlign: TextAlign.center, style: AppTextStyles.fechasResultado)),
                  Expanded(flex: 2, child: Text("Resultados", textAlign: TextAlign.center, style: AppTextStyles.fechasResultado)),
                ],
              ),
              const SizedBox(height: 8),
              ...listaResultados.map((resultado) {
                final fecha = resultado["fecha"]?.toString() ?? "";
                final numeros = List<int>.from(resultado["numeros"] ?? []);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmall = MediaQuery.of(context).size.width < 360;
                      final ballSize = isSmall ? 25.0 : 33.0;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 1, child: Text(fecha, textAlign: TextAlign.center, style: AppTextStyles.mensajeImportante)),
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(numeros.length, (index) {
                                final n = numeros[index];
                                final isLast = index == numeros.length - 1;
                                return SizedBox(
                                  width: ballSize,
                                  height: ballSize,
                                  child: _build3DBall(n, baseColor: isLast ? Colors.redAccent : Colors.amber, size: ballSize),
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

