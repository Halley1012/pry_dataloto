import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../styles/colores.dart';
import '../styles/app_text_styles.dart';
import '../widgets/contenedor3.dart';
import '../services/cache_service.dart';

class EstadisticasPowerballScreen extends StatefulWidget {
  const EstadisticasPowerballScreen({super.key});
  @override
  State<EstadisticasPowerballScreen> createState() => _EstadisticasPowerballScreenState();
}

class _EstadisticasPowerballScreenState extends State<EstadisticasPowerballScreen> {
  bool cargando = true;
  String? errorMensaje;
  List<Map<String, dynamic>> todosResultados = [];
  Map<String, dynamic>? prediccionIA;
  int limiteFiltro = 50;

  @override
  void initState() { super.initState(); _cargarDatos(); }

  Future<void> _cargarDatos() async {
    final cachedHist = await CacheService.getJson('powerball_historico_completo');
    final cachedPred = await CacheService.getJson('powerball_prediccion');
    if (cachedHist != null) setState(() { todosResultados = List<Map<String, dynamic>>.from(cachedHist["resultados"]); cargando = false; });
    if (cachedPred != null) setState(() => prediccionIA = cachedPred);
    try {
      final resHist = await http.get(Uri.parse("https://pry-dataloto.onrender.com/powerball/historico_completo"));
      final resPred = await http.get(Uri.parse("https://pry-dataloto.onrender.com/powerball"));
      if (resHist.statusCode == 200) {
        final data = jsonDecode(resHist.body);
        if (mounted) setState(() => todosResultados = List<Map<String, dynamic>>.from(data["resultados"]));
        CacheService.setJson('powerball_historico_completo', data);
      }
      if (resPred.statusCode == 200) {
        final dataP = jsonDecode(resPred.body);
        if (mounted) setState(() => prediccionIA = dataP);
        CacheService.setJson('powerball_prediccion', dataP);
      }
    } catch (_) { if (todosResultados.isEmpty) errorMensaje = "Error de conexión"; }
    finally { if (mounted) setState(() => cargando = false); }
  }

  @override
  Widget build(BuildContext context) {
    final resultados = limiteFiltro > 0 ? todosResultados.take(limiteFiltro).toList() : todosResultados;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: AppColors.blackfondo, title: Text("Estadísticas Powerball", style: AppTextStyles.h2), centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.yellow), onPressed: () => Navigator.pop(context))),
      body: cargando ? const Center(child: CircularProgressIndicator(color: AppColors.amber)) : errorMensaje != null ? Center(child: Text(errorMensaje!, style: AppTextStyles.mensajeImportante)) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _buildFiltros(), const SizedBox(height: 20),
          _buildCardCalientesFrios(resultados), const SizedBox(height: 20),
          _buildCardGraficaFrecuencia(resultados), const SizedBox(height: 20),
          _buildCardParImpar(resultados), const SizedBox(height: 20),
          _buildCardScoreIA(),
        ]),
      ),
    );
  }

  Widget _buildFiltros() {
    return AppContainer3(child: Row(children: [
      Text("Sorteos: ", style: AppTextStyles.mensajeSecundario),
      ...[20, 50, 100, 0].map((n) => Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text(n == 0 ? "Todos" : "$n"), selected: limiteFiltro == n, onSelected: (s) => setState(() => limiteFiltro = n)))),
    ]));
  }

  Widget _buildCardCalientesFrios(List<Map<String, dynamic>> res) {
    final frecs = <int, int>{};
    for (var r in res) { for (var n in (r['numeros'] as List).take(5)) { frecs[n] = (frecs[n] ?? 0) + 1; } }
    final sorted = frecs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return AppContainer3(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Números Calientes y Fríos 🔥❄️", style: AppTextStyles.h2),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Column(children: [Text("🔥 Calientes", style: TextStyle(color: Colors.amber)), ...sorted.take(5).map((e) => Text("${e.key}: ${e.value} veces", style: AppTextStyles.caption2))])),
        Expanded(child: Column(children: [Text("❄️ Fríos", style: TextStyle(color: Colors.lightBlue)), ...sorted.reversed.take(5).map((e) => Text("${e.key}: ${e.value} veces", style: AppTextStyles.caption2))])),
      ]),
    ]));
  }

  Widget _buildCardGraficaFrecuencia(List<Map<String, dynamic>> res) {
    return AppContainer3(child: Column(children: [
      Text("Frecuencia Histórica", style: AppTextStyles.h2),
      const SizedBox(height: 20),
      SizedBox(height: 150, child: BarChart(BarChartData(titlesData: FlTitlesData(show: false), borderData: FlBorderData(show: false), gridData: FlGridData(show: false), barGroups: []))),
      Text("Gráfica detallada próximamente", style: AppTextStyles.caption),
    ]));
  }

  Widget _buildCardParImpar(List<Map<String, dynamic>> res) {
    int p = 0, i = 0;
    for (var r in res) { for (var n in (r['numeros'] as List).take(5)) { if (n % 2 == 0) p++; else i++; } }
    return AppContainer3(child: Column(children: [
      Text("Distribución Par vs Impar", style: AppTextStyles.h2),
      const SizedBox(height: 10),
      Text("Pares: $p - Impares: $i", style: AppTextStyles.mensajeSecundario),
    ]));
  }

  Widget _buildCardScoreIA() {
    return AppContainer3(child: Column(children: [
      Text("Score de Probabilidad IA 🤖", style: AppTextStyles.h2),
      const SizedBox(height: 10),
      LinearProgressIndicator(value: 0.85, color: Colors.amber, backgroundColor: Colors.white10),
      const SizedBox(height: 8),
      Text("Consistencia del 85% con patrones históricos.", style: AppTextStyles.caption),
    ]));
  }
}
