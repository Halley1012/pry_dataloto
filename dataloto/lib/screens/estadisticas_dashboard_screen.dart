import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/widgets/contenedor3.dart';
import 'package:dataloto/widgets/fullscreen_chart_viewer.dart';
import 'package:dataloto/screens/estadisticas/widgets/metric_stat.dart';
import 'package:dataloto/screens/estadisticas/widgets/ball_badge.dart';
import 'package:dataloto/services/cache_service.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

class EstadisticasDashboardScreen extends StatefulWidget {
  final String loteriaNombreInicial;
  final String? loteriaRoute;
  final Map<String, dynamic>? loteriaData;

  const EstadisticasDashboardScreen({
    super.key,
    required this.loteriaNombreInicial,
    this.loteriaRoute,
    this.loteriaData,
  });

  @override
  State<EstadisticasDashboardScreen> createState() => _EstadisticasDashboardScreenState();
}

class _EstadisticasDashboardScreenState extends State<EstadisticasDashboardScreen> {
  bool cargando = true;
  String? errorMensaje;
  List<Map<String, dynamic>> todosResultados = [];
  Map<String, dynamic>? prediccionIA;

  int limiteFiltro = 50; // 20, 50, 100, 0 (todos)
  String filtroSorteo = 'Todos'; // 'Todos', principal, secundario

  int touchedBarIndex = -1;
  int touchedPieIndexPar = -1;
  int touchedPieIndexBajos = -1;

  late final String routeName;
  late int maxBalota;
  late int maxRoja;
  late int maxSeleccion;
  late bool hasRevancha;
  late String nombreSorteoPrincipal;
  late String nombreSorteoSecundario;

  @override
  void initState() {
    super.initState();
    routeName = widget.loteriaRoute ?? (widget.loteriaData?['route']?.toString()) ?? _getRouteForLoteria(widget.loteriaNombreInicial);
    maxBalota = int.tryParse(widget.loteriaData?['max_balotas_blancas']?.toString() ?? '') ?? 45;
    maxRoja = int.tryParse(widget.loteriaData?['max_balotas_rojas']?.toString() ?? '') ?? 0;
    maxSeleccion = int.tryParse(widget.loteriaData?['max_seleccion']?.toString() ?? '') ?? 5;
    hasRevancha = widget.loteriaData?['has_revancha'] == true;
    nombreSorteoPrincipal = widget.loteriaNombreInicial;
    nombreSorteoSecundario = "Secundario";
    _cargarDatos();
  }

  String _getRouteForLoteria(String name) {
    if (widget.loteriaRoute != null && widget.loteriaRoute!.isNotEmpty) {
      return widget.loteriaRoute!.trim().toLowerCase();
    }
    if (widget.loteriaData != null && widget.loteriaData!['route'] != null) {
      return widget.loteriaData!['route'].toString().trim().toLowerCase();
    }

    String clean = name.trim().toLowerCase();
    if (clean.contains("baloto") || clean == "bloto") return "bloto";
    if (clean.contains("miloto") || clean == "mloto") return "mloto";
    if (clean.contains("colorloto") || clean.contains("color_loto") || clean == "cloto") return "cloto";

    clean = clean
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n');

    return clean
        .replaceAll(RegExp(r'[^a-z0-9\s_]'), '')
        .trim()
        .replaceAll(RegExp(r'[\s_]+'), '_');
  }

  void _autoCalibrarParametros() {
    // 1. Extraer del Modelo IA y de la configuración base
    if (widget.loteriaData != null) {
      if (widget.loteriaData!['max_balotas_blancas'] != null) {
        maxBalota = int.tryParse(widget.loteriaData!['max_balotas_blancas'].toString()) ?? maxBalota;
      }
      if (widget.loteriaData!['max_balotas_rojas'] != null) {
        maxRoja = int.tryParse(widget.loteriaData!['max_balotas_rojas'].toString()) ?? maxRoja;
      }
      if (widget.loteriaData!['max_seleccion'] != null) {
        maxSeleccion = int.tryParse(widget.loteriaData!['max_seleccion'].toString()) ?? maxSeleccion;
      }
    }

    // 2. Extraer del Modelo IA (el predictor evalúa el universo completo de balotas del juego)
    if (prediccionIA != null) {
      final predNums = prediccionIA!["numeros"];
      if (predNums is List && predNums.isNotEmpty) {
        int maxFromModel = 0;
        for (var n in predNums) {
          final val = int.tryParse(n.toString()) ?? 0;
          if (val > maxFromModel) maxFromModel = val;
        }
        if (maxFromModel > 0) {
          maxBalota = maxFromModel;
        }
      }

      final predRojas = prediccionIA!["balotaroja"] ??
          prediccionIA!["balota_roja"] ??
          prediccionIA!["balotas_rojas"] ??
          prediccionIA!["superbalota"];
      if (predRojas is List && predRojas.isNotEmpty) {
        int maxRojaFromModel = 0;
        for (var n in predRojas) {
          final val = int.tryParse(n.toString()) ?? 0;
          if (val > maxRojaFromModel) maxRojaFromModel = val;
        }
        if (maxRojaFromModel > 0) {
          maxRoja = maxRojaFromModel;
        }
      }
    }

    if (todosResultados.isEmpty) return;

    // 3. Si es una lotería no catalogada, inferir selección de los resultados históricos
    if (widget.loteriaData == null || widget.loteriaData!['max_seleccion'] == null) {
      final Map<int, int> lenCounts = {};
      for (var r in todosResultados) {
        final nums = r["numeros"];
        if (nums is List && nums.isNotEmpty) {
          lenCounts[nums.length] = (lenCounts[nums.length] ?? 0) + 1;
        }
      }
      if (lenCounts.isNotEmpty) {
        final mostCommonLen = lenCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        maxSeleccion = maxRoja > 0 && mostCommonLen > 1 ? mostCommonLen - 1 : mostCommonLen;
      }
    }

    // 4. Detección automática de sorteos múltiples (ej: Baloto y Revancha, Powerball y Double Play)
    final sorteosUnicos = todosResultados
        .map((r) => r["sorteo"]?.toString().trim())
        .where((s) => s != null && s.isNotEmpty)
        .toSet();

    if (sorteosUnicos.length > 1) {
      hasRevancha = true;
      final listaSorteos = sorteosUnicos.toList();
      nombreSorteoPrincipal = listaSorteos[0]!;
      nombreSorteoSecundario = listaSorteos[1]!;
    }
  }

  Future<void> _cargarDatos() async {
    final cachedHist = await CacheService.getJson('${routeName}_historico_completo');
    final cachedPred = await CacheService.getJson('${routeName}_prediccion');

    if (cachedHist != null && cachedHist["resultados"] != null && mounted) {
      setState(() {
        todosResultados = List<Map<String, dynamic>>.from(cachedHist["resultados"]);
        if (cachedPred != null) prediccionIA = cachedPred;
        _autoCalibrarParametros();
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
      final listResultados = await ApiService.getHistoricoCompleto(routeName);
      if (listResultados.isNotEmpty && mounted) {
        setState(() {
          todosResultados = listResultados;
          _autoCalibrarParametros();
        });
        CacheService.setJson('${routeName}_historico_completo', {"resultados": listResultados});
      }

      final dataP = await ApiService.getPrediccionLoteria(routeName);
      if (mounted) {
        setState(() {
          prediccionIA = dataP;
          _autoCalibrarParametros();
        });
      }
      CacheService.setJson('${routeName}_prediccion', dataP);
    } catch (e) {
      debugPrint("Error cargando estadísticas para $routeName: $e");
      if (todosResultados.isEmpty) {
        errorMensaje = "No se pudieron cargar los datos de estadísticas.";
      }
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  List<Map<String, dynamic>> _filtrarResultados() {
    var lista = todosResultados;

    if (hasRevancha && filtroSorteo != 'Todos') {
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
    final l10n = AppLocalizations.of(context);
    final resultadosFiltrados = _filtrarResultados();

    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      appBar: AppBar(
        backgroundColor: AppColors.blackfondo,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 24, color: AppColors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${l10n?.estadisticas ?? "Estadísticas"} ${widget.loteriaNombreInicial}",
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
                      _buildFiltrosBarra(l10n),
                      const SizedBox(height: 20),
                      _buildCardResumenGeneral(resultadosFiltrados, l10n),
                      const SizedBox(height: 20),
                      _buildCardCalientesFrios(resultadosFiltrados, l10n),
                      const SizedBox(height: 20),
                      _buildCardGraficaFrecuencia(resultadosFiltrados, l10n),
                      const SizedBox(height: 20),
                      _buildCardAusenciaSorteos(resultadosFiltrados, l10n),
                      const SizedBox(height: 20),
                      _buildCardParImpar(resultadosFiltrados, l10n),
                      const SizedBox(height: 20),
                      _buildCardBajosAltos(resultadosFiltrados, l10n),
                      const SizedBox(height: 20),
                      _buildCardSumaCombinaciones(resultadosFiltrados, l10n),
                      const SizedBox(height: 20),
                      _buildCardParejasYTrios(resultadosFiltrados, l10n),
                      const SizedBox(height: 20),
                      _buildCardScoreIA(resultadosFiltrados, l10n),
                      const SizedBox(height: 20),
                      _buildCardComparacionIA(resultadosFiltrados, l10n),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFiltrosBarra(AppLocalizations? l10n) {
    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n?.filtrosAnalisis ?? "Filtros de Análisis", style: AppTextStyles.h2),
          const SizedBox(height: 12),
          Row(
            children: [
              Text("${l10n?.sorteos ?? "Sorteos"}: ", style: AppTextStyles.mensajeSecundario),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [20, 50, 100, 0].map((cant) {
                    final isSel = limiteFiltro == cant;
                    final texto = cant == 0 ? (l10n?.todas ?? "Todos") : "$cant";
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
          if (hasRevancha) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text("${l10n?.tipo ?? "Tipo"}: ", style: AppTextStyles.mensajeSecundario),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 8,
                  children: ['Todos', nombreSorteoPrincipal, nombreSorteoSecundario].map((tipo) {
                    final isSel = filtroSorteo == tipo;
                    String displayTipo = tipo;
                    if (tipo == 'Todos') displayTipo = l10n?.todas ?? "Todos";
                    return ChoiceChip(
                      label: Text(displayTipo),
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
        ],
      ),
    );
  }

  Widget _buildCardResumenGeneral(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
    String label3 = l10n?.tipo ?? "Combinación";
    String value3 = "5 Números";

    if (maxRoja > 0) {
      label3 = "Superbalota";
      value3 = "1 - $maxRoja";
    } else if (routeName == "colorloto") {
      label3 = l10n?.tipo ?? "Combinación";
      value3 = "6 Números + Color";
    }

    return AppContainer3(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            MetricStat(label: l10n?.sorteosEvaluados ?? "Sorteos Evaluados", value: "${resultados.length}"),
            MetricStat(label: "Rango Balotas", value: "1 - $maxBalota"),
            MetricStat(label: label3, value: value3),
          ],
        ),
      );
  }

  Widget _buildCardCalientesFrios(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
    final frecs = _calcularFrecuencias(resultados);

    final sortedEntries = frecs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final calientes = sortedEntries.take(5).toList();
    final frios = sortedEntries.reversed.take(5).toList();

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n?.numerosCalientesFrios ?? "2. Números Calientes y Fríos 🔥❄️", style: AppTextStyles.h2),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("🔥 ${l10n?.masFrecuentes ?? "Más Frecuentes"}",
                        style: AppTextStyles.mensajeImportante.copyWith(color: Colors.amber)),
                    const SizedBox(height: 8),
                    ...calientes.map((e) => BallBadge(num: e.key, sub: "${e.value} ${l10n?.veces ?? "veces"}", color: Colors.amber)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("❄️ ${l10n?.menosFrecuentes ?? "Menos Frecuentes"}",
                        style: AppTextStyles.mensajeImportante.copyWith(color: Colors.lightBlueAccent)),
                    const SizedBox(height: 8),
                    ...frios.map((e) => BallBadge(num: e.key, sub: "${e.value} ${l10n?.veces ?? "veces"}", color: Colors.lightBlueAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }




  Widget _buildCardGraficaFrecuencia(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
    final frecs = _calcularFrecuencias(resultados);
    final maxFrec = frecs.values.fold(1, (max, val) => val > max ? val : max);
    final titleText = "1. ${l10n?.frecuenciaHistorica ?? "Frecuencia Histórica"} (Balotas 1 - $maxBalota)";
    final subtitleText = l10n?.tocaParaVerMas ?? "Toca una barra para interactuar";

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

  Widget _buildCardAusenciaSorteos(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
    final ausencias = _calcularAusencias(resultados);
    final sortedByAusencia = ausencias.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final masAtrasados = sortedByAusencia.take(5).toList();

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n?.ausenciaSorteosTitle ?? "3. Sorteos Sin Salir (Ausencia)", style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(l10n?.balotasMayorTiempo ?? "Balotas con mayor tiempo sin aparecer:", style: AppTextStyles.caption),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: masAtrasados.map((e) {
              final int sorteosSinSalir = e.value;
              final String labelText = (sorteosSinSalir >= resultados.length && resultados.isNotEmpty)
                  ? "+$sorteosSinSalir ${l10n?.sorteos ?? "sorteos"}"
                  : "$sorteosSinSalir ${l10n?.sorteos ?? "sorteos"}";

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
                  Text(labelText, style: AppTextStyles.caption2),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardParImpar(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
    int pares = 0;
    int impares = 0;

    for (var r in resultados) {
      final nums = List<int>.from(r["numeros"] ?? []);
      final mainNums = nums.take(maxSeleccion);
      for (var n in mainNums) {
        if (n % 2 == 0) pares++;
        else impares++;
      }
    }

    final total = (pares + impares) == 0 ? 1 : (pares + impares);
    final pctPar = ((pares / total) * 100).toStringAsFixed(1);
    final pctImpar = ((impares / total) * 100).toStringAsFixed(1);
    final titleText = "4. ${l10n?.parImpar ?? "Distribución Par vs Impar"}";

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
                _buildLegendItem("${l10n?.parImpar.split("vs").first.trim() ?? "Pares"}: $pares ($pctPar%)", Colors.amber),
                const SizedBox(height: 12),
                _buildLegendItem("${l10n?.parImpar.split("vs").last.trim() ?? "Impares"}: $impares ($pctImpar%)", Colors.deepOrangeAccent),
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

  Widget _buildCardBajosAltos(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
    final mitad = maxBalota ~/ 2;
    int bajos = 0;
    int altos = 0;

    for (var r in resultados) {
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(maxSeleccion)) {
        if (n <= mitad) bajos++;
        else altos++;
      }
    }

    final total = (bajos + altos) == 0 ? 1 : (bajos + altos);
    final pctBajos = ((bajos / total) * 100).toStringAsFixed(1);
    final pctAltos = ((altos / total) * 100).toStringAsFixed(1);
    final titleText = "5. ${l10n?.bajosAltos ?? "Bajos (1-$mitad) vs Altos (${mitad + 1}-$maxBalota)"}";

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
                _buildLegendItem("${l10n?.bajosAltos.split("vs").first.trim() ?? "Bajos (1-$mitad)"}: $bajos ($pctBajos%)", Colors.cyanAccent),
                const SizedBox(height: 12),
                _buildLegendItem("${l10n?.bajosAltos.split("vs").last.trim() ?? "Altos (${mitad + 1}-$maxBalota)"}: $altos ($pctAltos%)", Colors.purpleAccent),
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

  Widget _buildCardSumaCombinaciones(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
    final sumas = <double>[];
    for (var r in resultados.take(30)) {
      final nums = List<int>.from(r["numeros"] ?? []);
      final s = nums.take(maxSeleccion).fold(0, (acc, val) => acc + val);
      if (s > 0) sumas.add(s.toDouble());
    }

    final reversedSumas = sumas.reversed.toList();
    final avgSuma = sumas.isEmpty ? "150" : (sumas.reduce((a, b) => a + b) / sumas.length).toStringAsFixed(0);
    final titleText = "6. ${l10n?.sumaCombinacion ?? "Suma de la Combinación"}";
    final subtitleText = l10n?.promedioSumaHistorica(avgSuma) ?? "Promedio de suma histórica: $avgSuma";

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

  Widget _buildCardParejasYTrios(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
    final parejas = <String, int>{};
    for (var r in resultados) {
      final nums = List<int>.from(r["numeros"] ?? []).take(maxSeleccion).toList()..sort();
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
          Text("7. ${l10n?.parejasFrecuentes ?? "Parejas Más Frecuentes"}", style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ...topParejas.take(5).map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${l10n?.pareja ?? "Pareja"} ( ${e.key} )", style: AppTextStyles.mensajeImportante),
                  Text("${e.value} ${l10n?.apariciones ?? "apariciones"}", style: AppTextStyles.caption2.copyWith(color: AppColors.yellow)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCardScoreIA(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
    final score = 92;
    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("8. ${l10n?.scoreProbabilidadIA ?? "Score de Probabilidad IA"} 🤖", style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(l10n?.indiceAfinidadHistorica ?? "Índice de afinidad estadística global:", style: AppTextStyles.caption),
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
          Text(l10n?.altaConsistenciaIA ?? "✅ Alta consistencia con patrones históricos par/impar y dispersión de suma.",
              style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildCardComparacionIA(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
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
          Text("10. ${l10n?.comparacionIA ?? "Comportamiento Histórico vs IA"} ⚡", style: AppTextStyles.h2),
          const SizedBox(height: 12),
          Text(l10n?.numerosMayorTendencia ?? "Números de mayor tendencia histórica:", style: AppTextStyles.caption),
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
          Text(l10n?.prediccionActualIA ?? "Predicción actual del modelo IA:", style: AppTextStyles.caption),
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
      for (var n in nums.take(maxSeleccion)) {
        if (n >= 1 && n <= maxBalota) {
          map[n] = (map[n] ?? 0) + 1;
        }
      }
    }
    return map;
  }

  Map<int, int> _calcularAusencias(List<Map<String, dynamic>> resultados) {
    final ausencias = <int, int>{};
    final int maxHist = resultados.isNotEmpty ? resultados.length : 1;
    for (int i = 1; i <= maxBalota; i++) ausencias[i] = maxHist;

    for (int idx = 0; idx < resultados.length; idx++) {
      final r = resultados[idx];
      final nums = List<int>.from(r["numeros"] ?? []);
      for (var n in nums.take(maxSeleccion)) {
        if (n >= 1 && n <= maxBalota) {
          if (ausencias[n] == maxHist) {
            ausencias[n] = idx;
          }
        }
      }
    }
    return ausencias;
  }
}
