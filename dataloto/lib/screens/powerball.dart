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
import 'package:dataloto/screens/estadisticas_powerball.dart';
import 'package:dataloto/screens/loterias_mis_jugadas.dart';

class PowerballScreen extends StatefulWidget {
  const PowerballScreen({super.key});
  @override
  State<PowerballScreen> createState() => _PowerballScreenState();
}

class _PowerballScreenState extends State<PowerballScreen> with TickerProviderStateMixin {
  static const String loteria = 'Powerball';
  static const String backendRoute = 'powerball';
  static const String backendUrl = "https://pry-dataloto.onrender.com/powerball";

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
  List<Map<String, dynamic>> anuncios = [];
  bool mostrarResultados = false;

  @override
  void initState() {
    super.initState();
    _cargarOptimizado();
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _bounceAnimation = CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut);
    _bounceController.forward();
    _shineController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _jugadasController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _bounceController.dispose(); _shineController.dispose(); _jugadasController.dispose();
    super.dispose();
  }

  Future<void> _cargarOptimizado() async {
    if (!mounted) return;
    final cached = await CacheService.getJson('${backendRoute}_prediccion');
    if (cached != null && cached["numeros"] != null) {
      setState(() {
        listaProbables = List<int>.from(cached["numeros"]);
        listaBalotaRoja = List<int>.from(cached["balotaroja"] ?? []);
        fechaPrediccion = cached["fecha"];
      });
    }

    try {
      userId = await storage.read(key: 'user_id');
      final pId = int.tryParse(await storage.read(key: 'pais_id') ?? "1");
      await Future.wait([
        fetchNumeros(),
        _fetchUltimosResultados(),
        _loadJugadas(),
        ApiService.getPublicidades(paisId: pId).then((ads) { if (mounted) setState(() => anuncios = ads); }),
      ]);
    } catch (_) {}
  }

  Future<void> fetchNumeros() async {
    try {
      final response = await http.get(Uri.parse(backendUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            listaProbables = List<int>.from(data["numeros"]);
            listaBalotaRoja = List<int>.from(data["balotaroja"] ?? []);
            fechaPrediccion = data["fecha"];
          });
        }
        CacheService.setJson('${backendRoute}_prediccion', data);
      }
    } catch (_) {}
  }

  Future<void> _fetchUltimosResultados() async {
    try {
      final response = await http.get(Uri.parse("$backendUrl/ultimos5"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => ultimosResultados = List<Map<String, dynamic>>.from(data["resultados"]));
      }
    } catch (_) {}
  }

  Future<void> _loadJugadas() async {
    try {
      final res = await ApiService.listarJugadasGenerica(backendRoute);
      if (mounted) setState(() => _jugadasList = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  Future<void> _guardarJugada() async {
    if (userId == null || seleccionados.length != 5 || balotaRojaSeleccionada == null) return;
    setState(() => isSaving = true);
    try {
      final jugada = [...seleccionados..sort(), balotaRojaSeleccionada!];
      await ApiService.crearJugadaGenerica(backendRoute, jugada, userId!);
      await _loadJugadas();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Jugada de Powerball guardada")));
    } finally { if (mounted) setState(() => isSaving = false); }
  }

  void _generarAleatorios() {
    if (listaProbables.isEmpty) return;
    setState(() {
      seleccionados = (List<int>.from(listaProbables)..shuffle()).take(5).toList();
      if (listaBalotaRoja.isNotEmpty) balotaRojaSeleccionada = listaBalotaRoja[Random().nextInt(listaBalotaRoja.length)];
      _bounceController.reset(); _bounceController.forward();
    });
  }

  String _formatearFecha(String f) {
    try {
      DateTime p = DateTime.parse(f.substring(0, 10));
      const m = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
      return "${p.day} de ${m[p.month - 1]}, ${p.year}";
    } catch (_) { return f; }
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
            CustomSliverAppBar(title: loteria, pinned: true, floating: true, snap: true),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    AppContainer(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Predicciones Inteligentes para $loteria", style: AppTextStyles.tituloPrincipal.copyWith(color: Colors.amberAccent)),
                        const SizedBox(height: 8),
                        Text("Números con mayor probabilidad para el sorteo del ${fechaPrediccion != null ? _formatearFecha(fechaPrediccion!) : '...'}", style: AppTextStyles.mensajeSecundario),
                      ],
                    )),
                    const SizedBox(height: 20),
                    AppContainer3(child: Column(
                      children: [
                        Text("Tus números de la suerte", style: AppTextStyles.h2.copyWith(color: Colors.amberAccent)),
                        const SizedBox(height: 10),
                        _buildLuckNumbersRow(),
                        const SizedBox(height: 15),
                        _buildActionButtons(),
                        const SizedBox(height: 12),
                        _buildNavigationButtons(),
                      ],
                    )),
                    const SizedBox(height: 20),
                    _buildSelectionGrid(),
                    const SizedBox(height: 20),
                    _buildBalotaRojaGrid(),
                    const SizedBox(height: 20),
                    _buildResultadosSection(),
                    const SizedBox(height: 20),
                    if (anuncios.isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("Anuncios destacados", style: AppTextStyles.h2.copyWith(fontSize: 18)),
                        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DirectorioLocalScreen())), child: Text("Ver más ›", style: TextStyle(color: AppColors.yellow))),
                      ])),
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

  Widget _buildLuckNumbersRow() {
    return Wrap(
      spacing: 6, runSpacing: 8,
      children: [
        ...List.generate(maxSeleccion, (i) {
          if (i < seleccionados.length) return ScaleTransition(scale: _bounceAnimation, child: _buildBallWithShine(seleccionados[i], "yellow-ball.png", 45));
          return _build3DBall(null, baseColor: Colors.grey.shade300, size: 45);
        }),
        if (balotaRojaSeleccionada != null) ScaleTransition(scale: _bounceAnimation, child: _buildBallWithShine(balotaRojaSeleccionada!, "red-ball.png", 45))
        else _build3DBall(null, baseColor: Colors.grey.shade300, size: 45),
      ],
    );
  }

  Widget _buildBallWithShine(int n, String asset, double size) {
    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: Tween(begin: 0.0, end: 1.0).animate(_shineController),
            child: ShaderMask(
              shaderCallback: (b) => LinearGradient(colors: [Colors.white.withOpacity(0.3), Colors.transparent, Colors.white.withOpacity(0.3)], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(b),
              blendMode: BlendMode.srcATop,
              child: Image.asset("assets/images/$asset", width: size, height: size, fit: BoxFit.contain),
            ),
          ),
          Text("$n", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 4, offset: Offset(1, 1))])),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: ElevatedButton.icon(onPressed: _generarAleatorios, icon: const Icon(Icons.shuffle, size: 18), label: const Text("Generar"), style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))))),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton.icon(onPressed: isSaving ? null : _guardarJugada, icon: isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save, size: 18), label: Text(isSaving ? "..." : "Guardar"), style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))))),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoteriasMisJugadasScreen(loteria: loteria, route: backendRoute))), style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("Mis jugadas"))),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/estadisticas_powerball'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("Estadísticas"))),
      ],
    );
  }

  Widget _buildSelectionGrid() {
    return AppContainer3(child: Column(
      children: [
        Text("Probabilidades según IA", style: AppTextStyles.h2),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemCount: listaProbables.length,
          itemBuilder: (context, i) {
            final n = listaProbables[i];
            final isSel = seleccionados.contains(n);
            return GestureDetector(onTap: () => setState(() => isSel ? seleccionados.remove(n) : (seleccionados.length < 5 ? seleccionados.add(n) : null)), child: _build3DBall(n, baseColor: isSel ? Colors.amber : (i < 20 ? Colors.redAccent : Colors.blueGrey)));
          },
        ),
      ],
    ));
  }

  Widget _buildBalotaRojaGrid() {
    if (listaBalotaRoja.isEmpty) return const SizedBox.shrink();
    return AppContainer3(child: Column(children: [
      Text("Balotas Rojas Powerball", style: AppTextStyles.h2),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
        itemCount: listaBalotaRoja.length,
        itemBuilder: (context, i) {
          final n = listaBalotaRoja[i];
          final isSel = balotaRojaSeleccionada == n;
          return GestureDetector(onTap: () => setState(() => balotaRojaSeleccionada = isSel ? null : n), child: _build3DBall(n, baseColor: isSel ? Colors.amber : Colors.redAccent));
        },
      ),
    ]));
  }

  Widget _buildResultadosSection() {
    return AppContainer3(child: Column(
      children: [
        InkWell(onTap: () => setState(() => mostrarResultados = !mostrarResultados), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Últimos Resultados", style: AppTextStyles.h2), Icon(mostrarResultados ? Icons.expand_less : Icons.expand_more, color: AppColors.yellow)])),
        if (mostrarResultados) ...ultimosResultados.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("${r['fecha']}", style: AppTextStyles.mensajeImportante),
          Row(children: (r['numeros'] as List).map((n) => Padding(padding: const EdgeInsets.only(left: 4), child: _build3DBall(n as int, size: 28))).toList()),
        ]))),
      ],
    ));
  }

  Widget _build3DBall(int? n, {Color baseColor = Colors.redAccent, double size = 40}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [baseColor.withOpacity(0.9), baseColor.withOpacity(0.7), baseColor.withOpacity(0.5)], center: Alignment.topLeft, radius: 0.9), border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)),
      child: Center(child: Text(n?.toString() ?? "-", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.4))),
    );
  }
}
