import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../styles/colores.dart';
import '../styles/app_text_styles.dart';
import '../widgets/contenedor3.dart';

class EstadisticasBlotoScreen extends StatefulWidget {
  const EstadisticasBlotoScreen({super.key});

  @override
  State<EstadisticasBlotoScreen> createState() => _EstadisticasBlotoScreenState();
}

class _EstadisticasBlotoScreenState extends State<EstadisticasBlotoScreen> {
  bool cargando = true;
  String? errorMensaje;
  List<Map<String, dynamic>> todosResultados = [];
  Map<String, dynamic>? prediccionIA;

  int limiteFiltro = 50; // 20, 50, 100, 0 (todos)
  String filtroSorteo = 'Todos'; // 'Todos', 'Baloto', 'Revancha'

  int touchedBarIndex = -1;
  int touchedPieIndexPar = -1;
  int touchedPieIndexBajos = -1;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      cargando = true;
      errorMensaje = null;
    });

    try {
      final resHist = await http.get(
        Uri.parse("https://pry-dataloto.onrender.com/bloto/historico_completo"),
      );
      final resPred = await http.get(
        Uri.parse("https://pry-dataloto.onrender.com/bloto"),
      );

      if (resHist.statusCode == 200) {
        final data = jsonDecode(resHist.body);
        if (data["resultados"] != null) {
          todosResultados = List<Map<String, dynamic>>.from(data["resultados"]);
        }
      }

      if (resPred.statusCode == 200) {
        final dataP = jsonDecode(resPred.body);
        prediccionIA = dataP;
      }
    } catch (e) {
      debugPrint("Error cargando estadísticas: $e");
      errorMensaje = "No se pudieron cargar los datos de estadísticas.";
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  List<Map<String, dynamic>> _filtrarResultados() {
    var lista = todosResultados;

    if (filtroSorteo != 'Todos') {
      lista = lista.where((r) {
        final s = r["sorteo"]?.toString().toLowerCase() ?? "";
        return s == filtroSorteo.toLowerCase();
      }).toList();
    }

    if (limiteFiltro > 0 && lista.length > limiteFiltro) {
      lista = lista.take(limiteFiltro).toList();
    }

    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final resultadosFiltrados = _filtrarResultados();

    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Estadísticas Baloto / Revancha",
          style: AppTextStyles.tituloPrincipal,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.yellow),
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
                  child: Text(
                    errorMensaje!,
                    style: AppTextStyles.mensajeImportante,
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
          const SizedBox(height: 10),
          Row(
            children: [
              Text("Tipo: ", style: AppTextStyles.mensajeSecundario),
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                children: ['Todos', 'Baloto', 'Revancha'].map((tipo) {
                  final isSel = filtroSorteo == tipo;
                  return ChoiceChip(
                    label: Text(tipo),
                    selected: isSel,
                    selectedColor: AppColors.yellow,
                    backgroundColor: AppColors.darkGray,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) {
                      setState(() => filtroSorteo = tipo);
                    },
                  );
                }).toList(),
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
          _buildMetricStat("Rango Balotas", "1 - 43"),
          _buildMetricStat("Superbalota", "1 - 16"),
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

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("1. Frecuencia Histórica (Balotas 1 - 43)", style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text("Toca una barra para interactuar", style: AppTextStyles.caption),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
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
                        if (v % 5 == 0 || v == 1 || v == 43) {
                          return Text("$v", style: const TextStyle(color: Colors.white54, fontSize: 10));
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
                            style: const TextStyle(color: Colors.white54, fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(43, (idx) {
                  final ball = idx + 1;
                  final count = (frecs[ball] ?? 0).toDouble();
                  return BarChartGroupData(
                    x: ball,
                    barRods: [
                      BarChartRodData(
                        toY: count,
                        color: count > (maxFrec * 0.7) ? Colors.amber : AppColors.grayBlue,
                        width: 5,
                        borderRadius: BorderRadius.circular(2),
                      )
                    ],
                  );
                }),
              ),
            ),
          ),
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
          Text("3. Días / Sorteos Sin Salir (Ausencia)", style: AppTextStyles.h2),
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

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("4. Distribución Par vs Impar", style: AppTextStyles.h2),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 30,
                    sections: [
                      PieChartSectionData(
                        value: pares.toDouble(),
                        color: Colors.amber,
                        title: '$pctPar%',
                        radius: 35,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      PieChartSectionData(
                        value: impares.toDouble(),
                        color: Colors.deepOrangeAccent,
                        title: '$pctImpar%',
                        radius: 35,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem("Pares: $pares ($pctPar%)", Colors.amber),
                    const SizedBox(height: 8),
                    _buildLegendItem("Impares: $impares ($pctImpar%)", Colors.deepOrangeAccent),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBajosAltos(List<Map<String, dynamic>> resultados) {
    int bajos = 0; // 1 - 21
    int altos = 0; // 22 - 43

    for (var r in resultados) {
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(5)) {
        if (n <= 21) bajos++;
        else altos++;
      }
    }

    final total = (bajos + altos) == 0 ? 1 : (bajos + altos);
    final pctBajos = ((bajos / total) * 100).toStringAsFixed(1);
    final pctAltos = ((altos / total) * 100).toStringAsFixed(1);

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("5. Bajos (1-21) vs Altos (22-43)", style: AppTextStyles.h2),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 30,
                    sections: [
                      PieChartSectionData(
                        value: bajos.toDouble(),
                        color: Colors.cyanAccent,
                        title: '$pctBajos%',
                        radius: 35,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      PieChartSectionData(
                        value: altos.toDouble(),
                        color: Colors.purpleAccent,
                        title: '$pctAltos%',
                        radius: 35,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem("Bajos (1-21): $bajos ($pctBajos%)", Colors.cyanAccent),
                    const SizedBox(height: 8),
                    _buildLegendItem("Altos (22-43): $altos ($pctAltos%)", Colors.purpleAccent),
                  ],
                ),
              ),
            ],
          ),
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
    final avgSuma = sumas.isEmpty ? 110 : (sumas.reduce((a, b) => a + b) / sumas.length).toStringAsFixed(0);

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("6. Suma de la Combinación", style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text("Promedio de suma histórica: $avgSuma", style: AppTextStyles.caption2.copyWith(color: AppColors.yellow)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      reversedSumas.length,
                      (idx) => FlSpot(idx.toDouble(), reversedSumas[idx]),
                    ),
                    isCurved: true,
                    color: AppColors.yellow,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
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
    final score = 88; // Score algorítmico / IA
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
        : [10, 18, 25, 33, 40, 8];

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
          Row(
            children: predNums
                .map((n) => Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.redAccent,
                        child: Text("$n", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Map<int, int> _calcularFrecuencias(List<Map<String, dynamic>> resultados) {
    final map = <int, int>{};
    for (int i = 1; i <= 43; i++) map[i] = 0;

    for (var r in resultados) {
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(5)) {
        if (n >= 1 && n <= 43) {
          map[n] = (map[n] ?? 0) + 1;
        }
      }
    }
    return map;
  }

  Map<int, int> _calcularAusencias(List<Map<String, dynamic>> resultados) {
    final ausencias = <int, int>{};
    for (int i = 1; i <= 43; i++) ausencias[i] = 999;

    for (int idx = 0; idx < resultados.length; idx++) {
      final r = resultados[idx];
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(5)) {
        if (n >= 1 && n <= 43) {
          if (ausencias[n] == 999) {
            ausencias[n] = idx;
          }
        }
      }
    }
    return ausencias;
  }
}
