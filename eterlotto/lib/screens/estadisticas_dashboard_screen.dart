import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/widgets/contenedor3.dart';
import 'package:eterlotto/widgets/fullscreen_chart_viewer.dart';
import 'package:eterlotto/screens/estadisticas/widgets/metric_stat.dart';
import 'package:eterlotto/screens/estadisticas/widgets/ball_badge.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';

class EstadisticasDashboardScreen extends StatefulWidget {
  final String loteriaNombreInicial;
  final String? loteriaRoute;
  final Map<String, dynamic>? loteriaData;
  final Map<String, dynamic>? jugadaComparacion;

  const EstadisticasDashboardScreen({
    super.key,
    required this.loteriaNombreInicial,
    this.loteriaRoute,
    this.loteriaData,
    this.jugadaComparacion,
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
  List<String> listaSorteosDisponibles = [];

  // Comparación de Jugada Flotante (Draggable)
  List<int> _balotasComparacion = [];
  int? _superbalotaComparacion;
  List<int> _balotasOriginales = [];
  int? _superbalotaOriginal;
  int? _jugadaId;
  String? _fechaSorteoOriginal;
  bool _isSavingJugada = false;
  String _tituloComparacion = "";
  Color _colorComparacion = const Color(0xFF0070F3);
  bool _mostrarComparacion = true;
  final ValueNotifier<Offset?> _comparacionCardPositionNotifier = ValueNotifier<Offset?>(null);
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _comparacionCardPositionNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _irAEditarJugada() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    }
  }

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

    if (widget.jugadaComparacion != null) {
      _jugadaId = widget.jugadaComparacion!["id"] as int?;
      _fechaSorteoOriginal = widget.jugadaComparacion!["fecha"]?.toString();
      final rawNums = widget.jugadaComparacion!["numeros"];
      if (rawNums is List) {
        _balotasComparacion = rawNums
            .map((e) => int.tryParse(e.toString()) ?? -1)
            .where((n) => n > 0)
            .toList();
      }
      final rawRoja = widget.jugadaComparacion!["balota_roja"] ?? widget.jugadaComparacion!["superbalota"];
      if (rawRoja != null) {
        _superbalotaComparacion = int.tryParse(rawRoja.toString());
      }
      final rawTitulo = widget.jugadaComparacion!["titulo"]?.toString() ?? "Jugada #1";
      _tituloComparacion = rawTitulo.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      if (widget.jugadaComparacion!["color"] != null) {
        _colorComparacion = Color(int.parse(widget.jugadaComparacion!["color"].toString()));
      }
      _balotasOriginales = List<int>.from(_balotasComparacion);
      _superbalotaOriginal = _superbalotaComparacion;
    }

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

    // 4. Detección automática de sorteos múltiples (ej: Baloto y Revancha, Powerball y Double Play, Melate/Revancha/Revanchita)
    final Set<String> sorteosUnicos = {};
    for (var r in todosResultados) {
      final s = r["sorteo"]?.toString().trim();
      if (s != null && s.isNotEmpty) {
        sorteosUnicos.add(s);
      }
    }

    if (sorteosUnicos.length > 1) {
      hasRevancha = true;
      final List<String> listaSorteos = sorteosUnicos.toList();
      final cleanLoteria = widget.loteriaNombreInicial.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
      listaSorteos.sort((a, b) {
        final cleanA = a.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
        final cleanB = b.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
        final aIsMain = cleanLoteria.contains(cleanA) || cleanA.contains(cleanLoteria);
        final bIsMain = cleanLoteria.contains(cleanB) || cleanB.contains(cleanLoteria);
        if (aIsMain && !bIsMain) return -1;
        if (!aIsMain && bIsMain) return 1;
        return 0;
      });
      listaSorteosDisponibles = listaSorteos;
      nombreSorteoPrincipal = listaSorteos[0];
      nombreSorteoSecundario = listaSorteos[1];
      if (filtroSorteo == 'Todos' || !listaSorteosDisponibles.contains(filtroSorteo)) {
        filtroSorteo = listaSorteosDisponibles.first;
      }
    } else {
      listaSorteosDisponibles = [];
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

    if (hasRevancha && listaSorteosDisponibles.isNotEmpty) {
      final target = filtroSorteo.toLowerCase();
      lista = lista.where((r) {
        final s = r["sorteo"]?.toString().toLowerCase() ?? "";
        return s == target;
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
    final bool isInitialLoading = cargando && todosResultados.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${l10n?.estadisticas ?? 'Estadísticas'} - ${widget.loteriaNombreInicial}",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isInitialLoading
          ? _buildSkeletonEstadisticas()
          : errorMensaje != null
              ? Center(
                  child: Text(
                    errorMensaje!,
                    style: AppTextStyles.mensajeImportante,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: RefreshIndicator(
                            color: AppColors.yellow,
                            backgroundColor: const Color(0xFF1E1E1E),
                            displacement: 25.0,
                            onRefresh: () async {
                              await _cargarDatos();
                            },
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
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
                                  const SizedBox(height: 20),
                                  if (_mostrarComparacion && _balotasComparacion.isNotEmpty) ...[
                                    _buildManualSelectorSection(l10n),
                                    const SizedBox(height: 20),
                                    if (maxRoja > 0) ...[
                                      _buildRedBallsSection(l10n),
                                      const SizedBox(height: 20),
                                    ],
                                    _buildGuardarJugadaSection(l10n),
                                    const SizedBox(height: 30),
                                  ],
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_mostrarComparacion && _balotasComparacion.isNotEmpty)
                          _buildDraggableJugadaComparacionCard(constraints),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildDraggableJugadaComparacionCard(BoxConstraints constraints) {
    if (!_mostrarComparacion || _balotasComparacion.isEmpty) {
      return const SizedBox.shrink();
    }

    final double maxW = constraints.maxWidth > 0 ? constraints.maxWidth : MediaQuery.of(context).size.width;
    final double maxH = constraints.maxHeight > 0 ? constraints.maxHeight : MediaQuery.of(context).size.height;

    final int totalBalls = _balotasComparacion.length + (_superbalotaComparacion != null ? 1 : 0);
    final double estimatedWidth = (totalBalls * 42.0 + 64.0).clamp(220.0, maxW - 20.0);
    const double estimatedHeight = 94.0;

    const double defaultX = 14.0;
    const double defaultY = 14.0;

    return ValueListenableBuilder<Offset?>(
      valueListenable: _comparacionCardPositionNotifier,
      builder: (context, pos, child) {
        final currentX = (pos?.dx ?? defaultX).clamp(4.0, (maxW - estimatedWidth - 4.0).clamp(4.0, double.infinity));
        final currentY = (pos?.dy ?? defaultY).clamp(4.0, (maxH - estimatedHeight - 4.0).clamp(4.0, double.infinity));

        return Positioned(
          left: currentX,
          top: currentY,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              final cur = _comparacionCardPositionNotifier.value ?? const Offset(defaultX, defaultY);
              double newX = cur.dx + details.delta.dx;
              double newY = cur.dy + details.delta.dy;

              newX = newX.clamp(4.0, (maxW - estimatedWidth - 4.0).clamp(4.0, double.infinity));
              newY = newY.clamp(4.0, (maxH - estimatedHeight - 4.0).clamp(4.0, double.infinity));

              _comparacionCardPositionNotifier.value = Offset(newX, newY);
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141921).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.85),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(12.0, 8.0, 10.0, 10.0),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabecera: Título "Comparando Jugada #..." + Botón Editar + Botón Cerrar (X)
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.drag_indicator, color: Colors.white38, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              _tituloComparacion.startsWith("Comparando")
                                  ? _tituloComparacion
                                  : "Comparando ${_tituloComparacion.isNotEmpty ? _tituloComparacion : "Jugada"}",
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _irAEditarJugada,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                ),
                                child: const Icon(Icons.edit_outlined, color: Color(0xFF00E5FF), size: 15),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _mostrarComparacion = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                child: const Icon(Icons.close, color: Colors.white70, size: 15),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Balotas (su ancho define naturalmente el ancho de la tarjeta)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._balotasComparacion.map((n) {
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _colorComparacion.withValues(alpha: 0.95),
                                  _colorComparacion.withValues(alpha: 0.75),
                                  _colorComparacion.withValues(alpha: 0.5),
                                ],
                                center: Alignment.topLeft,
                                radius: 0.9,
                              ),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  offset: const Offset(2, 2),
                                  blurRadius: 4,
                                ),
                                BoxShadow(
                                  color: _colorComparacion.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                "$n",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }),
                        if (_superbalotaComparacion != null) ...[
                          Container(
                            margin: const EdgeInsets.only(left: 2, right: 2),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFB91C1C).withValues(alpha: 0.95),
                                  const Color(0xFFB91C1C).withValues(alpha: 0.75),
                                  const Color(0xFFB91C1C).withValues(alpha: 0.5),
                                ],
                                center: Alignment.topLeft,
                                radius: 0.9,
                              ),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  offset: const Offset(2, 2),
                                  blurRadius: 4,
                                ),
                                BoxShadow(
                                  color: const Color(0xFFFF1744).withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                "$_superbalotaComparacion",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _irAEditarJugada,
                          child: Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.edit, color: Color(0xFF00E5FF), size: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _build3DBall(
    int? numero, {
    Color baseColor = const Color(0xFFF33A21),
    double size = 38,
    bool isSelected = false,
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
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.7),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Colors.black45,
                  offset: Offset(1.5, 1.5),
                  blurRadius: 3,
                ),
              ]
            : const [
                BoxShadow(
                  color: Colors.black38,
                  offset: Offset(1.5, 1.5),
                  blurRadius: 3,
                ),
              ],
        border: Border.all(
          color: isSelected ? Colors.white : Colors.white24,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "–",
          style: GoogleFonts.montserrat(
            fontSize: size * 0.40,
            fontWeight: FontWeight.w700,
            color: numero != null ? Colors.white : Colors.white54,
            shadows: numero != null
                ? const [
                    Shadow(
                      color: Colors.black87,
                      offset: Offset(0.8, 0.8),
                      blurRadius: 2.0,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  List<int> _obtenerListaProbables() {
    final List<int> result = [];
    final Set<int> added = {};

    // 1. Extraer del modelo IA
    if (prediccionIA != null && prediccionIA!["numeros"] is List) {
      for (var n in prediccionIA!["numeros"]) {
        final val = int.tryParse(n.toString());
        if (val != null && val >= 1 && val <= maxBalota && !added.contains(val)) {
          result.add(val);
          added.add(val);
        }
      }
    }

    // 2. Completar según frecuencia histórica descendente
    final frecs = _calcularFrecuencias(todosResultados);
    final sortedByFrec = frecs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (var entry in sortedByFrec) {
      if (entry.key >= 1 && entry.key <= maxBalota && !added.contains(entry.key)) {
        result.add(entry.key);
        added.add(entry.key);
      }
    }

    // 3. Cualquier balota restante
    for (int i = 1; i <= maxBalota; i++) {
      if (!added.contains(i)) {
        result.add(i);
        added.add(i);
      }
    }

    return result;
  }

  List<int> _obtenerListaBalotaRoja() {
    if (maxRoja <= 0) return [];
    final List<int> result = [];
    final Set<int> added = {};

    final rawRojas = prediccionIA?["balotaroja"] ??
        prediccionIA?["balota_roja"] ??
        prediccionIA?["balotas_rojas"] ??
        prediccionIA?["superbalota"];
    if (rawRojas is List) {
      for (var r in rawRojas) {
        final val = int.tryParse(r.toString());
        if (val != null && val >= 1 && val <= maxRoja && !added.contains(val)) {
          result.add(val);
          added.add(val);
        }
      }
    }

    for (int i = 1; i <= maxRoja; i++) {
      if (!added.contains(i)) {
        result.add(i);
        added.add(i);
      }
    }

    return result;
  }

  Future<void> _guardarJugadaEditada() async {
    if (_isSavingJugada) return;

    if (_balotasComparacion.length != maxSeleccion) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Debes seleccionar exactamente $maxSeleccion balotas."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (maxRoja > 0 && _superbalotaComparacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes seleccionar la balota roja / superbalota."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final uidInt = await ApiService.getUserId();
    final String userId = uidInt?.toString() ?? "";
    if (userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Inicia sesión para guardar tu jugada."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() => _isSavingJugada = true);

    try {
      final sortedWhites = List<int>.from(_balotasComparacion)..sort();
      bool success = false;

      if (_jugadaId != null && _jugadaId! > 0) {
        // Actualizar jugada existente en backend
        success = await ApiService.actualizarJugadaGenerica(
          routeName,
          _jugadaId!,
          sortedWhites,
          userId,
          balotaRoja: _superbalotaComparacion,
          fechaSorteo: _fechaSorteoOriginal,
        );
      } else {
        // Crear jugada si no existía ID
        final res = await ApiService.crearJugadaGenerica(
          routeName,
          sortedWhites,
          userId,
          balotaRoja: _superbalotaComparacion,
          fechaSorteo: _fechaSorteoOriginal,
        );
        success = res.isNotEmpty;
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Jugada guardada y actualizada con éxito!"),
            backgroundColor: Color(0xFF00E5FF),
          ),
        );
        // Regresa a la pantalla de jugadas
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo actualizar la jugada. Intenta de nuevo."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingJugada = false);
      }
    }
  }

  Widget _buildManualSelectorSection(AppLocalizations? l10n) {
    final probables = _obtenerListaProbables();
    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.seleccionaNumeros ?? "Selecciona tus números",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              InkWell(
                onTap: () => setState(() {
                  _balotasComparacion.clear();
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
          Text(
            "${l10n?.numerosOrdenadosProbabilidad ?? "Números ordenados de mayor a menor probabilidad."}\n${l10n?.tocaNumeroSeleccionar ?? "Toca un número para seleccionarlo"}",
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
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
                children: probables.asMap().entries.map((entry) {
                  final int index = entry.key;
                  final int numero = entry.value;
                  final bool isSelected = _balotasComparacion.contains(numero);
                  final Color baseColor = isSelected
                      ? Colors.amber
                      : (index < (maxBalota / 2).ceil()
                          ? const Color(0xFFF33A21)
                          : const Color(0xFF607D8B));

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_balotasComparacion.contains(numero)) {
                          _balotasComparacion.remove(numero);
                        } else if (_balotasComparacion.length < maxSeleccion) {
                          _balotasComparacion.add(numero);
                          _balotasComparacion.sort();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Ya has seleccionado $maxSeleccion balotas. Toca una para quitarla."),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      });
                    },
                    child: _build3DBall(
                      numero,
                      baseColor: baseColor,
                      size: 38,
                      isSelected: isSelected,
                    ),
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
    if (maxRoja <= 0) return const SizedBox.shrink();
    final rojas = _obtenerListaBalotaRoja();

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.balotasRojas ?? "Balotas Rojas",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_superbalotaComparacion != null)
                InkWell(
                  onTap: () => setState(() => _superbalotaComparacion = null),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n?.numerosOrdenadosProbabilidad ?? "Números ordenados de mayor a menor probabilidad.",
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
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
                children: rojas.map((numero) {
                  final bool isSelected = _superbalotaComparacion == numero;
                  final Color baseColor = isSelected ? Colors.amber : const Color(0xFFC62828);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _superbalotaComparacion = isSelected ? null : numero;
                      });
                    },
                    child: _build3DBall(
                      numero,
                      baseColor: baseColor,
                      size: 38,
                      isSelected: isSelected,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGuardarJugadaSection(AppLocalizations? l10n) {
    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Selección (${_balotasComparacion.length}/$maxSeleccion${maxRoja > 0 ? " + ${_superbalotaComparacion != null ? "1" : "0"}/1" : ""})",
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (_balotasOriginales.isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () {
                    setState(() {
                      _balotasComparacion = List<int>.from(_balotasOriginales);
                      _superbalotaComparacion = _superbalotaOriginal;
                    });
                  },
                  icon: const Icon(Icons.restart_alt, size: 15, color: Color(0xFF00E5FF)),
                  label: const Text(
                    "Restablecer",
                    style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                ..._balotasComparacion.map((n) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _build3DBall(
                        n,
                        baseColor: _colorComparacion,
                        size: 36,
                        isSelected: true,
                      ),
                    )),
                if (_superbalotaComparacion != null) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _build3DBall(
                      _superbalotaComparacion,
                      baseColor: const Color(0xFFB91C1C),
                      size: 36,
                      isSelected: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              icon: _isSavingJugada
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.save_outlined, size: 20, color: Colors.black),
              label: Text(
                _isSavingJugada
                    ? "Guardando..."
                    : (_jugadaId != null ? "Guardar y Actualizar Jugada" : "Guardar Jugada"),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              onPressed: _isSavingJugada ? null : _guardarJugadaEditada,
            ),
          ),
        ],
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("${l10n?.sorteos ?? "Sorteos"}: ", style: AppTextStyles.mensajeSecundario),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
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
                        fontSize: 12,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        setState(() => limiteFiltro = cant);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (hasRevancha && listaSorteosDisponibles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("${l10n?.tipo ?? "Tipo"}: ", style: AppTextStyles.mensajeSecundario),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: listaSorteosDisponibles.map((tipo) {
                      final isSel = filtroSorteo == tipo;
                      return ChoiceChip(
                        label: Text(tipo),
                        selected: isSel,
                        selectedColor: AppColors.yellow,
                        backgroundColor: AppColors.darkGray,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() => filtroSorteo = tipo);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardResumenGeneral(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
    final String label3 = l10n?.numerosLabel ?? "Números";
    final String value3;

    if (routeName == "colorloto" || routeName == "cloto") {
      value3 = "6 + Color";
    } else {
      int totalBallsInResults = 0;
      if (resultados.isNotEmpty) {
        final firstNums = resultados.first["numeros"];
        if (firstNums is List && firstNums.isNotEmpty) {
          totalBallsInResults = firstNums.length;
        }
      }

      final int extraCount = totalBallsInResults > maxSeleccion
          ? (totalBallsInResults - maxSeleccion)
          : (maxRoja > 0 ? 1 : 0);

      if (extraCount > 0) {
        value3 = "$maxSeleccion + $extraCount";
      } else {
        value3 = "$maxSeleccion";
      }
    }

    return AppContainer3(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: MetricStat(label: l10n?.sorteosEvaluados ?? "Sorteos Evaluados", value: "${resultados.length}")),
          const SizedBox(width: 8),
          Expanded(child: MetricStat(label: l10n?.rangoBalotas ?? "Rango Balotas", value: "1 - $maxBalota")),
          const SizedBox(width: 8),
          Expanded(child: MetricStat(label: label3, value: value3)),
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
                    ...calientes.map((e) => BallBadge(
                          num: e.key,
                          sub: "${e.value} ${l10n?.veces ?? "veces"}",
                          color: Colors.amber,
                          isHighlighted: _mostrarComparacion && _balotasComparacion.contains(e.key),
                          highlightColor: _colorComparacion,
                        )),
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
                    ...frios.map((e) => BallBadge(
                          num: e.key,
                          sub: "${e.value} ${l10n?.veces ?? "veces"}",
                          color: Colors.lightBlueAccent,
                          isHighlighted: _mostrarComparacion && _balotasComparacion.contains(e.key),
                          highlightColor: _colorComparacion,
                        )),
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
              final isComparacion = _mostrarComparacion && _balotasComparacion.contains(ball);
              return BarChartGroupData(
                x: ball,
                barRods: [
                  BarChartRodData(
                    toY: count,
                    gradient: isComparacion
                        ? LinearGradient(
                            colors: [_colorComparacion, _colorComparacion.withValues(alpha: 0.7), Colors.white],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          )
                        : const LinearGradient(
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
                    width: isFullScreen ? (isComparacion ? 12 : 10) : (isComparacion ? 7 : 5),
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

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Column(
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          labelText,
                          style: AppTextStyles.caption2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
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
    final finalMaxY = (maxY * 1.25).toDouble();

    Widget buildLineChart({bool isFullScreen = false}) {
      return SizedBox(
        height: isFullScreen ? double.infinity : 180,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 12.0, bottom: 8.0, left: 8.0),
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      return LineTooltipItem(
                        touchedSpot.y.toInt().toString(),
                        const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                      );
                    }).toList();
                  },
                ),
              ),
              minY: minY,
              maxY: finalMaxY,
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

  int _calcularScoreProbabilidadIA(List<Map<String, dynamic>> resultados, [List<int>? customNums]) {
    if (resultados.isEmpty) return 85;

    final List<int> predNums;
    if (customNums != null && customNums.isNotEmpty) {
      predNums = customNums.take(maxSeleccion).toList();
    } else {
      final rawPredNums = prediccionIA?["numeros"];
      predNums = (rawPredNums is List && rawPredNums.isNotEmpty)
          ? rawPredNums
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((n) => n > 0)
              .take(maxSeleccion)
              .toList()
          : [];
    }

    if (predNums.isEmpty) return 85;

    double scoreTotal = 0.0;

    // 1. Afinidad con Números Frecuentes Históricos (40 pts máx)
    final frecs = _calcularFrecuencias(resultados);
    int totalPuntosFrec = 0;
    int maxPosibleFrec = 0;
    final sortedFrecs = frecs.values.toList()..sort();
    final maxFrec = sortedFrecs.isNotEmpty && sortedFrecs.last > 0 ? sortedFrecs.last : 1;

    for (var n in predNums) {
      final f = frecs[n] ?? 0;
      totalPuntosFrec += f;
      maxPosibleFrec += maxFrec;
    }
    double frecScore = maxPosibleFrec > 0 ? (totalPuntosFrec / maxPosibleFrec) * 40.0 : 30.0;
    scoreTotal += frecScore.clamp(18.0, 40.0);

    // 2. Consistencia Par/Impar (25 pts máx)
    int pares = predNums.where((n) => n % 2 == 0).length;
    int impares = predNums.length - pares;
    double balanceParImpar = (pares - impares).abs() <= 1 ? 25.0 : ((pares - impares).abs() <= 2 ? 18.0 : 12.0);
    scoreTotal += balanceParImpar;

    // 3. Dispersión y Suma Histórica (20 pts máx)
    int sumaPred = predNums.fold(0, (acc, n) => acc + n);
    List<int> sumasHist = [];
    for (var r in resultados) {
      final nums = List<int>.from(r["numeros"] ?? []).take(maxSeleccion);
      if (nums.isNotEmpty) {
        sumasHist.add(nums.fold(0, (acc, n) => acc + n));
      }
    }
    if (sumasHist.isNotEmpty) {
      double mediaSuma = sumasHist.reduce((a, b) => a + b) / sumasHist.length;
      double diffSuma = (sumaPred - mediaSuma).abs();
      double maxDiff = mediaSuma * 0.5;
      double sumaScore = (1.0 - (diffSuma / (maxDiff > 0 ? maxDiff : 1.0))).clamp(0.0, 1.0) * 20.0;
      scoreTotal += sumaScore;
    } else {
      scoreTotal += 15.0;
    }

    // 4. Distribución Bajos vs Altos (15 pts máx)
    int mitad = maxBalota ~/ 2;
    int bajos = predNums.where((n) => n <= mitad).length;
    int altos = predNums.length - bajos;
    double balanceBajosAltos = (bajos - altos).abs() <= 1 ? 15.0 : ((bajos - altos).abs() <= 2 ? 10.0 : 6.0);
    scoreTotal += balanceBajosAltos;

    return scoreTotal.round().clamp(60, 97);
  }

  Widget _buildCardScoreIA(List<Map<String, dynamic>> resultados, AppLocalizations? l10n) {
    final score = _calcularScoreProbabilidadIA(resultados);
    final scoreComparacion = (_mostrarComparacion && _balotasComparacion.isNotEmpty)
        ? _calcularScoreProbabilidadIA(resultados, _balotasComparacion)
        : null;

    final String mensajeConsistencia;
    if (score >= 88) {
      mensajeConsistencia = l10n?.altaConsistenciaIA ?? "✅ Alta consistencia con patrones históricos par/impar y dispersión de suma.";
    } else if (score >= 76) {
      mensajeConsistencia = l10n?.moderadaConsistenciaIA ?? "⚡ Moderada-alta afinidad con frecuencias históricas y dispersión balanceada.";
    } else {
      mensajeConsistencia = l10n?.variabilidadConsistenciaIA ?? "📊 Comportamiento de alta variabilidad estadística respecto a tendencias previas.";
    }

    return AppContainer3(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("8. ${l10n?.scoreProbabilidadIA ?? "Score de Probabilidad IA"} 🤖", style: AppTextStyles.h2),
          if (scoreComparacion != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF141921),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _colorComparacion.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Tu ${_tituloComparacion.isNotEmpty ? _tituloComparacion : "Jugada Actual"}",
                        style: TextStyle(
                          color: _colorComparacion,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        "$scoreComparacion%",
                        style: GoogleFonts.montserrat(
                          color: scoreComparacion >= 80 ? Colors.greenAccent : (scoreComparacion >= 70 ? const Color(0xFF00E5FF) : Colors.redAccent),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: scoreComparacion / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.darkGray,
                    color: scoreComparacion >= 80 ? Colors.greenAccent : (scoreComparacion >= 70 ? const Color(0xFF00E5FF) : Colors.redAccent),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(l10n?.indiceAfinidadHistorica ?? "Índice de afinidad estadística global:", style: AppTextStyles.caption),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: score / 100,
                  minHeight: 12,
                  backgroundColor: AppColors.darkGray,
                  color: score >= 80 ? Colors.amber : (score >= 70 ? Colors.orangeAccent : Colors.redAccent),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "$score%",
                style: AppTextStyles.tituloPrincipal.copyWith(
                  color: score >= 80 ? Colors.amber : (score >= 70 ? Colors.orangeAccent : Colors.redAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mensajeConsistencia,
            style: AppTextStyles.caption,
          ),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: top3Hist
                .map((n) => Chip(
                      label: Text("$n"),
                      backgroundColor: Colors.amber,
                      labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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

  Widget _buildSkeletonEstadisticas() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2C2C2C),
      period: const Duration(milliseconds: 1400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter bar skeleton
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            // Resumen card skeleton
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 20),
            // Hot/Cold card skeleton
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 20),
            // Frequency Chart skeleton
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 20),
            // Pairs/Odds card skeleton
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
