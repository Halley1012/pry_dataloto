import 'package:dataloto/services/api_service.dart';
import '../services/cache_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/widgets/contenedor3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dataloto/styles/app_text_styles.dart';
import '../widgets/contenedor.dart';
import '../widgets/custom_app_bar.dart';
import 'dart:math';
import 'package:dataloto/widgets/carrusel.dart';
import 'package:dataloto/screens/loterias_mis_jugadas.dart';

class LottoAmericaScreen extends StatefulWidget {
  const LottoAmericaScreen({super.key});
  @override
  State<LottoAmericaScreen> createState() => _LottoAmericaScreenState();
}

class _LottoAmericaScreenState extends State<LottoAmericaScreen> with TickerProviderStateMixin {
  static const String loteria = 'Lotto America';
  static const String backendRoute = 'lotto_america';
  static const String backendUrl = "https://pry-dataloto.onrender.com/lotto_america";
  final storage = const FlutterSecureStorage();
  List<int> seleccionados = [];
  List<int> listaProbables = [];
  List<int> listaBalotaRoja = [];
  int? balotaRojaSeleccionada;
  String? fechaPrediccion;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _shineController;
  String? userId;
  bool isSaving = false;
  bool mostrarResultados = false;
  List<Map<String, dynamic>> ultimosResultados = [];
  List<Map<String, dynamic>> anuncios = [];

  @override
  void initState() {
    super.initState();
    _cargarOptimizado();
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _bounceAnimation = CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut);
    _shineController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() { _bounceController.dispose(); _shineController.dispose(); super.dispose(); }

  Future<void> _cargarOptimizado() async {
    if (!mounted) return;
    final cached = await CacheService.getJson('${backendRoute}_prediccion');
    if (cached != null) setState(() { listaProbables = List<int>.from(cached["numeros"]); listaBalotaRoja = List<int>.from(cached["balotaroja"] ?? []); fechaPrediccion = cached["fecha"]; });
    try {
      userId = await storage.read(key: 'user_id');
      final pId = int.tryParse(await storage.read(key: 'pais_id') ?? "1");
      await Future.wait([ fetchNumeros(), _fetchUltimosResultados(), ApiService.getPublicidades(paisId: pId).then((ads) { if (mounted) setState(() => anuncios = ads); }) ]);
    } catch (_) {}
  }

  Future<void> fetchNumeros() async {
    try {
      final res = await http.get(Uri.parse(backendUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() { listaProbables = List<int>.from(data["numeros"]); listaBalotaRoja = List<int>.from(data["balotaroja"] ?? []); fechaPrediccion = data["fecha"]; });
        CacheService.setJson('${backendRoute}_prediccion', data);
      }
    } catch (_) {}
  }

  Future<void> _fetchUltimosResultados() async {
    try {
      final res = await http.get(Uri.parse("$backendUrl/ultimos5"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() => ultimosResultados = List<Map<String, dynamic>>.from(data["resultados"]));
      }
    } catch (_) {}
  }

  void _generarAleatorios() {
    if (listaProbables.isEmpty) return;
    setState(() {
      seleccionados = (List<int>.from(listaProbables)..shuffle()).take(5).toList();
      if (listaBalotaRoja.isNotEmpty) balotaRojaSeleccionada = listaBalotaRoja[Random().nextInt(listaBalotaRoja.length)];
      _bounceController.reset(); _bounceController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        onRefresh: _cargarOptimizado,
        child: CustomScrollView(
          slivers: [
            CustomSliverAppBar(title: loteria, pinned: true, floating: true, snap: true),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: [
                  AppContainer(child: Column(children: [
                    Text("Predicciones $loteria", style: AppTextStyles.tituloPrincipal.copyWith(color: Colors.amberAccent)),
                    Text("Sorteo del ${fechaPrediccion ?? '...'}", style: AppTextStyles.mensajeSecundario),
                  ])),
                  const SizedBox(height: 20),
                  AppContainer3(child: Column(children: [
                    Text("Tus números", style: AppTextStyles.h2.copyWith(color: Colors.amberAccent)),
                    const SizedBox(height: 10),
                    _buildLuckRow(),
                    const SizedBox(height: 15),
                    Row(children: [
                      Expanded(child: ElevatedButton(onPressed: _generarAleatorios, style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("Generar"))),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/estadisticas_lotto_america'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("Estadísticas"))),
                    ]),
                  ])),
                  const SizedBox(height: 20),
                  _buildResultadosSection(),
                  const SizedBox(height: 20),
                  if (anuncios.isNotEmpty) InfiniteAdsCarousel(anuncios: anuncios),
                  const SizedBox(height: 50),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuckRow() {
    return Wrap(spacing: 6, children: [
      ...seleccionados.map((n) => ScaleTransition(scale: _bounceAnimation, child: _buildBallWithShine(n, "yellow-ball.png", 45))),
      if (balotaRojaSeleccionada != null) ScaleTransition(scale: _bounceAnimation, child: _buildBallWithShine(balotaRojaSeleccionada!, "red-ball.png", 45)),
    ]);
  }

  Widget _buildBallWithShine(int n, String asset, double size) {
    return SizedBox(width: size, height: size, child: Stack(alignment: Alignment.center, children: [
      RotationTransition(turns: Tween(begin: 0.0, end: 1.0).animate(_shineController), child: ShaderMask(shaderCallback: (b) => LinearGradient(colors: [Colors.white.withOpacity(0.3), Colors.transparent, Colors.white.withOpacity(0.3)], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(b), blendMode: BlendMode.srcATop, child: Image.asset("assets/images/$asset", width: size, height: size, fit: BoxFit.contain))),
      Text("$n", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 4, offset: Offset(1, 1))])),
    ]));
  }

  Widget _buildResultadosSection() {
    return AppContainer3(child: Column(children: [
      InkWell(onTap: () => setState(() => mostrarResultados = !mostrarResultados), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Últimos Resultados", style: AppTextStyles.h2), Icon(mostrarResultados ? Icons.expand_less : Icons.expand_more, color: AppColors.yellow)])),
      if (mostrarResultados) ...ultimosResultados.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${r['fecha']}", style: AppTextStyles.mensajeImportante), Text("${(r['numeros'] as List).join(' - ')}", style: const TextStyle(color: Colors.white))]))),
    ]));
  }
}
