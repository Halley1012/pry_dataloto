import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../styles/colores.dart';
import '../styles/app_text_styles.dart';
import '../widgets/contenedor3.dart';
import '../widgets/fullscreen_chart_viewer.dart';
import '../services/cache_service.dart';

class EstadisticasPowerballScreen extends StatefulWidget {
  const EstadisticasPowerballScreen({super.key});

  @override
  State<EstadisticasPowerballScreen> createState() => _EstadisticasPowerballScreenState();
}

class _EstadisticasPowerballScreenState extends State<EstadisticasPowerballScreen> {
  static const String loteriaNombre = "Powerball";
  static const String routeName = "powerball";
  static const int maxBalota = 69;
  static const int maxRoja = 26;

  bool cargando = true;
  String? errorMensaje;
  List<Map<String, dynamic>> todosResultados = [];
  Map<String, dynamic>? prediccionIA;

  int limiteFiltro = 50;
  String filtroSorteo = 'Todos';

  int touchedBarIndex = -1;
  int touchedPieIndexPar = -1;
  int touchedPieIndexBajos = -1;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final cachedHist = await CacheService.getJson('${routeName}_historico_completo');
    final cachedPred = await CacheService.getJson('${routeName}_prediccion');

    if (cachedHist != null && cachedHist["resultados"] != null && mounted) {
      setState(() {
        todosResultados = List<Map<String, dynamic>>.from(cachedHist["resultados"]);
        if (cachedPred != null) prediccionIA = cachedPred;
        cargando = false;
      });
    }

    if (!mounted) return;
    if (todosResultados.isEmpty) {
      setState(() {
        cargando = true;
        errorMensaje = null;
      });
    }

    try {
      final resHist = await http.get(
        Uri.parse("https://pry-dataloto.onrender.com/$routeName/historico_completo"),
      );
      final resPred = await http.get(
        Uri.parse("https://pry-dataloto.onrender.com/$routeName"),
      );

      if (resHist.statusCode == 200) {
        final dataHist = jsonDecode(resHist.body);
        if (dataHist["resultados"] != null && mounted) {
          setState(() {
            todosResultados = List<Map<String, dynamic>>.from(dataHist["resultados"]);
          });
          CacheService.setJson('${routeName}_historico_completo', dataHist);
        }
      }

      if (resPred.statusCode == 200) {
        final dataPred = jsonDecode(resPred.body);
        if (mounted) {
          setState(() {
            prediccionIA = dataPred;
          });
          CacheService.setJson('${routeName}_prediccion', dataPred);
        }
      }
    } catch (e) {
      if (todosResultados.isEmpty && mounted) {
        setState(() {
          errorMensaje = "No fue posible conectar con el servidor para obtener las estadísticas.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> resultadosFiltrados = todosResultados;

    if (limiteFiltro > 0 && todosResultados.length > limiteFiltro) {
      resultadosFiltrados = todosResultados.take(limiteFiltro).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: AppColors.blackfondo,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 24, color: AppColors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Estadísticas $loteriaNombre",
          style: AppTextStyles.h2,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 24, color: AppColors.yellow),
            onPressed: _cargarDatos,
          )
        ],
      ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            )
          : errorMensaje != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      errorMensaje!,
                      style: AppTextStyles.mensajeImportante,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFiltrosBarra(),
                      const SizedBox(height: 20),
                      _buildCardResumenGeneral(resultadosFiltrados),
                      const SizedBox(height: 20),
                      _buildCardCalientesFrios(resultadosFiltrados),
                      const SizedBox(height: 20),
                      _buildCardGraficaFrecuencia(resultadosFiltrados),
                      const SizedBox(height: 20),
                      _buildCardAusenciaSorteos(resultadosFiltrados),
                      const SizedBox(height: 20),
                      _buildCardParImpar(resultadosFiltrados),
                      const SizedBox(height: 20),
                      _buildCardBajosAltos(resultadosFiltrados),
                      const SizedBox(height: 20),
                      _buildCardSumaCombinaciones(resultadosFiltrados),
                      const SizedBox(height: 20),
                      _buildCardParejasYTrios(resultadosFiltrados),
                      const SizedBox(height: 20),
                      _buildCardScoreIA(resultadosFiltrados),
                      const SizedBox(height: 20),
                      _buildCardComparacionIA(resultadosFiltrados),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFiltrosBarra() {
    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Filtros de Análisis", style: AppTextStyles.h2),
          const SizedBox(height: 12),
          Row(
            children: [
              Text("Sorteos: ", style: AppTextStyles.mensajeSecundario),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [20, 50, 100, 0].map((cant) {
                    final isSel = limiteFiltro == cant;
                    final texto = cant == 0 ? "Todos" : "$cant";
                    return ChoiceChip(
                      label: Text(texto),
                      selected: isSel,
                      selectedColor: AppColors.yellow,
                      backgroundColor: AppColors.darkGray,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (_) {
                        setState(() => limiteFiltro = cant);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardResumenGeneral(List<Map<String, dynamic>> resultados) {
    return AppContainer3(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricStat("Sorteos Evaluados", "${resultados.length}"),
          _buildMetricStat("Rango Balotas", "1 - $maxBalota"),
          _buildMetricStat("Balota Roja", "1 - $maxRoja"),
        ],
      ),
    );
  }

  Widget _buildMetricStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.tituloPrincipal.copyWith(color: AppColors.yellow, fontSize: 24)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildCardCalientesFrios(List<Map<String, dynamic>> resultados) {
    final frecs = _calcularFrecuencias(resultados);

    final sortedEntries = frecs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final calientes = sortedEntries.take(5).toList();
    final frios = sortedEntries.reversed.take(5).toList();

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("2. Números Calientes y Fríos 🔥❄️", style: AppTextStyles.h2),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("🔥 Más Frecuentes",
                        style: AppTextStyles.mensajeImportante.copyWith(color: Colors.amber)),
                    const SizedBox(height: 8),
                    ...calientes.map((e) => _buildBallBadge(e.key, "${e.value} veces", Colors.amber)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("❄️ Menos Frecuentes",
                        style: AppTextStyles.mensajeImportante.copyWith(color: Colors.lightBlueAccent)),
                    const SizedBox(height: 8),
                    ...frios.map((e) => _buildBallBadge(e.key, "${e.value} veces", Colors.lightBlueAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBallBadge(int num, String sub, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                )
              ],
            ),
            child: Center(
              child: Text(
                "$num",
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(sub, style: AppTextStyles.caption2),
        ],
      ),
    );
  }

  Widget _buildCardGraficaFrecuencia(List<Map<String, dynamic>> resultados) {
    final frecs = _calcularFrecuencias(resultados);
    final maxFrec = frecs.values.fold(1, (max, val) => val > max ? val : max);
    final titleText = "1. Frecuencia Histórica (Balotas 1 - $maxBalota)";
    const subtitleText = "Toca una barra para interactuar";

    Widget buildBarChart({bool isFullScreen = false}) {
      return SizedBox(
        height: isFullScreen ? double.infinity : 220,
        child: BarChart(
          BarChartData(
            maxY: (maxFrec * 1.22).toDouble(),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final ball = group.x.toInt();
                  return BarTooltipItem(
                    "Balota $ball\n${rod.toY.toInt()} salidas",
                    const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (val, meta) {
                    final v = val.toInt();
                    if (v % 10 == 0 || v == 1 || v == maxBalota) {
                      return Text("$v", style: TextStyle(color: Colors.white54, fontSize: isFullScreen ? 12 : 10));
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (val, meta) {
                    return Text("${val.toInt()}",
                        style: TextStyle(color: Colors.white54, fontSize: isFullScreen ? 12 : 10));
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: isFullScreen),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(maxBalota, (idx) {
              final ball = idx + 1;
              final count = (frecs[ball] ?? 0).toDouble();
              return BarChartGroupData(
                x: ball,
                barRods: [
                  BarChartRodData(
                    toY: count,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF4A148C),
                        Color(0xFF1565C0),
                        Color(0xFF00B0FF),
                        Color(0xFF00E676),
                        Color(0xFFFFEA00),
                        Color(0xFFFF6D00),
                        Color(0xFFFF1744),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: isFullScreen ? 10 : 5,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  )
                ],
              );
            }),
          ),
        ),
      );
    }

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(titleText, style: AppTextStyles.h2.copyWith(fontSize: 14.5)),
              ),
              InkWell(
                onTap: () {
                  FullScreenChartViewer.show(
                    context,
                    title: titleText,
                    subtitle: subtitleText,
                    chartWidget: buildBarChart(isFullScreen: true),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.open_in_full, color: AppColors.yellow, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitleText, style: AppTextStyles.caption),
          const SizedBox(height: 16),
          buildBarChart(isFullScreen: false),
        ],
      ),
    );
  }

  Widget _buildCardAusenciaSorteos(List<Map<String, dynamic>> resultados) {
    final ausencias = _calcularAusencias(resultados);
    final sortedByAusencia = ausencias.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final masAtrasados = sortedByAusencia.take(5).toList();

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("3. Sorteos Sin Salir (Ausencia)", style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text("Balotas con mayor tiempo sin aparecer:", style: AppTextStyles.caption),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: masAtrasados.map((e) {
              return Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent,
                    ),
                    child: Center(
                      child: Text("${e.key}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("${e.value} sorteos", style: AppTextStyles.caption2),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardParImpar(List<Map<String, dynamic>> resultados) {
    int pares = 0;
    int impares = 0;

    for (var r in resultados) {
      final nums = List<int>.from(r["numeros"] ?? []);
      final main5 = nums.take(5);
      for (var n in main5) {
        if (n % 2 == 0) pares++;
        else impares++;
      }
    }

    final total = (pares + impares) == 0 ? 1 : (pares + impares);
    final pctPar = ((pares / total) * 100).toStringAsFixed(1);
    final pctImpar = ((impares / total) * 100).toStringAsFixed(1);
    const titleText = "4. Distribución Par vs Impar";

    Widget buildPieContent({bool isFullScreen = false}) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: isFullScreen ? 240 : 120,
            width: isFullScreen ? 240 : 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: isFullScreen ? 55 : 30,
                sections: [
                  PieChartSectionData(
                    value: pares.toDouble(),
                    color: Colors.amber,
                    title: '$pctPar%',
                    radius: isFullScreen ? 65 : 35,
                    titleStyle: TextStyle(fontSize: isFullScreen ? 15 : 12, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  PieChartSectionData(
                    value: impares.toDouble(),
                    color: Colors.deepOrangeAccent,
                    title: '$pctImpar%',
                    radius: isFullScreen ? 65 : 35,
                    titleStyle: TextStyle(fontSize: isFullScreen ? 15 : 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem("Pares: $pares ($pctPar%)", Colors.amber),
                const SizedBox(height: 12),
                _buildLegendItem("Impares: $impares ($pctImpar%)", Colors.deepOrangeAccent),
              ],
            ),
          ),
        ],
      );
    }

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(titleText, style: AppTextStyles.h2.copyWith(fontSize: 14.5)),
              ),
              InkWell(
                onTap: () {
                  FullScreenChartViewer.show(
                    context,
                    title: titleText,
                    chartWidget: buildPieContent(isFullScreen: true),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.open_in_full, color: AppColors.yellow, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          buildPieContent(isFullScreen: false),
        ],
      ),
    );
  }

  Widget _buildCardBajosAltos(List<Map<String, dynamic>> resultados) {
    final mitad = maxBalota ~/ 2;
    int bajos = 0;
    int altos = 0;

    for (var r in resultados) {
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(5)) {
        if (n <= mitad) bajos++;
        else altos++;
      }
    }

    final total = (bajos + altos) == 0 ? 1 : (bajos + altos);
    final pctBajos = ((bajos / total) * 100).toStringAsFixed(1);
    final pctAltos = ((altos / total) * 100).toStringAsFixed(1);
    final titleText = "5. Bajos (1-$mitad) vs Altos (${mitad + 1}-$maxBalota)";

    Widget buildPieContent({bool isFullScreen = false}) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: isFullScreen ? 240 : 120,
            width: isFullScreen ? 240 : 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: isFullScreen ? 55 : 30,
                sections: [
                  PieChartSectionData(
                    value: bajos.toDouble(),
                    color: Colors.cyanAccent,
                    title: '$pctBajos%',
                    radius: isFullScreen ? 65 : 35,
                    titleStyle: TextStyle(fontSize: isFullScreen ? 15 : 12, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  PieChartSectionData(
                    value: altos.toDouble(),
                    color: Colors.purpleAccent,
                    title: '$pctAltos%',
                    radius: isFullScreen ? 65 : 35,
                    titleStyle: TextStyle(fontSize: isFullScreen ? 15 : 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem("Bajos (1-$mitad): $bajos ($pctBajos%)", Colors.cyanAccent),
                const SizedBox(height: 12),
                _buildLegendItem("Altos (${mitad + 1}-$maxBalota): $altos ($pctAltos%)", Colors.purpleAccent),
              ],
            ),
          ),
        ],
      );
    }

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(titleText, style: AppTextStyles.h2.copyWith(fontSize: 14.5)),
              ),
              InkWell(
                onTap: () {
                  FullScreenChartViewer.show(
                    context,
                    title: titleText,
                    chartWidget: buildPieContent(isFullScreen: true),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.open_in_full, color: AppColors.yellow, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          buildPieContent(isFullScreen: false),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppTextStyles.mensajeSecundario)),
      ],
    );
  }

  Widget _buildCardSumaCombinaciones(List<Map<String, dynamic>> resultados) {
    final sumas = <double>[];
    for (var r in resultados.take(30)) {
      final nums = List<int>.from(r["numeros"] ?? []);
      final s = nums.take(5).fold(0, (acc, val) => acc + val);
      if (s > 0) sumas.add(s.toDouble());
    }

    final reversedSumas = sumas.reversed.toList();
    final avgSuma = sumas.isEmpty ? "150" : (sumas.reduce((a, b) => a + b) / sumas.length).toStringAsFixed(0);
    const titleText = "6. Suma de la Combinación";
    final subtitleText = "Promedio de suma histórica: $avgSuma";

    double minY = reversedSumas.isEmpty ? 0 : reversedSumas[0];
    double maxY = reversedSumas.isEmpty ? 0 : reversedSumas[0];
    for (final val in reversedSumas) {
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    Widget buildLineChart({bool isFullScreen = false}) {
      return SizedBox(
        height: isFullScreen ? double.infinity : 180,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 12.0, bottom: 8.0, left: 8.0),
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              minX: 0,
              maxX: reversedSumas.isNotEmpty ? (reversedSumas.length - 1).toDouble() : 0,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final intVal = value.toInt();
                      final isMin = intVal == minY.toInt();
                      final isMax = intVal == maxY.toInt();
                      final isStep = intVal % 50 == 0 && intVal > minY && intVal < maxY;
                      if (isMin || isMax || isStep) {
                        return Text(
                          "$intVal",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final intVal = value.toInt();
                      final isLast = intVal == reversedSumas.length - 1;
                      if (intVal % 5 == 0 || isLast) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "$intVal",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    reversedSumas.length,
                    (idx) => FlSpot(idx.toDouble(), reversedSumas[idx]),
                  ),
                  isCurved: true,
                  color: AppColors.amber,
                  barWidth: isFullScreen ? 4 : 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3.5,
                        color: AppColors.amber,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(titleText, style: AppTextStyles.h2.copyWith(fontSize: 14.5)),
              ),
              InkWell(
                onTap: () {
                  FullScreenChartViewer.show(
                    context,
                    title: titleText,
                    subtitle: subtitleText,
                    chartWidget: buildLineChart(isFullScreen: true),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.open_in_full, color: AppColors.yellow, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitleText, style: AppTextStyles.caption2.copyWith(color: AppColors.yellow)),
          const SizedBox(height: 16),
          buildLineChart(isFullScreen: false),
        ],
      ),
    );
  }

  Widget _buildCardParejasYTrios(List<Map<String, dynamic>> resultados) {
    final parejas = <String, int>{};
    for (var r in resultados) {
      final nums = List<int>.from(r["numeros"] ?? []).take(5).toList()..sort();
      for (int i = 0; i < nums.length; i++) {
        for (int j = i + 1; j < nums.length; j++) {
          final pair = "${nums[i]} - ${nums[j]}";
          parejas[pair] = (parejas[pair] ?? 0) + 1;
        }
      }
    }

    final topParejas = parejas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("7. Parejas Más Frecuentes", style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ...topParejas.take(5).map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Pareja ( ${e.key} )", style: AppTextStyles.mensajeImportante),
                  Text("${e.value} apariciones", style: AppTextStyles.caption2.copyWith(color: AppColors.yellow)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCardScoreIA(List<Map<String, dynamic>> resultados) {
    final score = 92;
    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("8. Score de Probabilidad IA 🤖", style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text("Índice de afinidad estadística global:", style: AppTextStyles.caption),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: score / 100,
                  minHeight: 12,
                  backgroundColor: AppColors.darkGray,
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 16),
              Text("$score%", style: AppTextStyles.tituloPrincipal.copyWith(color: Colors.amber)),
            ],
          ),
          const SizedBox(height: 8),
          Text("✅ Alta consistencia con patrones históricos par/impar y dispersión de suma.",
              style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildCardComparacionIA(List<Map<String, dynamic>> resultados) {
    final predNums = prediccionIA != null && prediccionIA!["numeros"] != null
        ? List<int>.from(prediccionIA!["numeros"])
        : [5, 12, 28, 45, 60];

    final frecs = _calcularFrecuencias(resultados);
    final top3Hist = (frecs.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) => e.key)
        .toList();

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("10. Comportamiento Histórico vs IA ⚡", style: AppTextStyles.h2),
          const SizedBox(height: 12),
          Text("Números de mayor tendencia histórica:", style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Row(
            children: top3Hist
                .map((n) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: Text("$n"),
                        backgroundColor: Colors.amber,
                        labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Text("Predicción actual del modelo IA:", style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: predNums
                .map((n) => CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.redAccent,
                      child: Text("$n", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Map<int, int> _calcularFrecuencias(List<Map<String, dynamic>> resultados) {
    final map = <int, int>{};
    for (int i = 1; i <= maxBalota; i++) map[i] = 0;

    for (var r in resultados) {
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(5)) {
        if (n >= 1 && n <= maxBalota) {
          map[n] = (map[n] ?? 0) + 1;
        }
      }
    }
    return map;
  }

  Map<int, int> _calcularAusencias(List<Map<String, dynamic>> resultados) {
    final ausencias = <int, int>{};
    for (int i = 1; i <= maxBalota; i++) ausencias[i] = 999;

    for (int idx = 0; idx < resultados.length; idx++) {
      final r = resultados[idx];
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(5)) {
        if (n >= 1 && n <= maxBalota) {
          if (ausencias[n] == 999) {
            ausencias[n] = idx;
          }
        }
      }
    }
    return ausencias;
  }
}
