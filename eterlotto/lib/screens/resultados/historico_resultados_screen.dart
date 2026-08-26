import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/screens/loteria_screen.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/widgets/custom_app_bar.dart';
import 'package:eterlotto/widgets/footer.dart';

import 'package:eterlotto/services/cache_service.dart';

class HistoricoResultadosScreen extends StatefulWidget {
  final LoteriaConfig config;
  final List<String> sorteosDisponibles;
  final String? initialSorteo;
  final List<Map<String, dynamic>>? initialResultados;

  const HistoricoResultadosScreen({
    super.key,
    required this.config,
    this.sorteosDisponibles = const [],
    this.initialSorteo,
    this.initialResultados,
  });

  @override
  State<HistoricoResultadosScreen> createState() => _HistoricoResultadosScreenState();
}

class _HistoricoResultadosScreenState extends State<HistoricoResultadosScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _todosResultados = [];
  late String _selectedSorteo;

  List<String> get sorteosActivos {
    final encontrados = _todosResultados
        .map((r) => r["sorteo"]?.toString().trim())
        .where((s) => s != null && s.isNotEmpty)
        .toSet()
        .cast<String>()
        .toList();
    if (encontrados.isNotEmpty) return encontrados;
    return widget.sorteosDisponibles;
  }

  @override
  void initState() {
    super.initState();
    _selectedSorteo = widget.initialSorteo ??
        (widget.sorteosDisponibles.isNotEmpty ? widget.sorteosDisponibles.first : widget.config.nombre);

    // ⚡ Optimización Cache-First: Usar datos iniciales si vienen pre-cargados
    if (widget.initialResultados != null && widget.initialResultados!.isNotEmpty) {
      _todosResultados = widget.initialResultados!;
      _isLoading = false;
    }

    _cargarHistorico();
  }

  Future<void> _cargarHistorico() async {
    final cacheKey = '${widget.config.route}_historico_completo';

    // 1. Si no teníamos datos iniciales, leer de la caché local primero (0ms)
    if (_todosResultados.isEmpty) {
      final cached = await CacheService.getJson(cacheKey);
      if (cached != null && cached["resultados"] != null && mounted) {
        final listCached = List<Map<String, dynamic>>.from(cached["resultados"]);
        if (listCached.isNotEmpty) {
          final encontrados = listCached
              .map((r) => r["sorteo"]?.toString().trim())
              .where((s) => s != null && s.isNotEmpty)
              .toSet()
              .cast<String>()
              .toList();

          setState(() {
            _todosResultados = listCached;
            _isLoading = false;
            if (encontrados.isNotEmpty &&
                !encontrados.any((s) => s.toLowerCase() == _selectedSorteo.toLowerCase())) {
              _selectedSorteo = encontrados.first;
            }
          });
        }
      }
    }

    if (_todosResultados.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    // 2. Revalidar en segundo plano con el servidor
    try {
      final list = await ApiService.getHistoricoCompleto(widget.config.route);
      if (mounted && list.isNotEmpty) {
        final encontrados = list
            .map((r) => r["sorteo"]?.toString().trim())
            .where((s) => s != null && s.isNotEmpty)
            .toSet()
            .cast<String>()
            .toList();

        setState(() {
          _todosResultados = list;
          _isLoading = false;
          if (encontrados.isNotEmpty &&
              !encontrados.any((s) => s.toLowerCase() == _selectedSorteo.toLowerCase())) {
            _selectedSorteo = encontrados.first;
          }
        });

        // Guardar en caché local
        CacheService.setJson(cacheKey, {"resultados": list});
      }
    } catch (e) {
      if (mounted && _todosResultados.isEmpty) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _obtenerResultadosFiltrados() {
    final disponibles = sorteosActivos;
    List<Map<String, dynamic>> baseList = _todosResultados;

    if (disponibles.length > 1) {
      final filtrados = _todosResultados
          .where((r) =>
              (r["sorteo"]?.toString().trim().toLowerCase() ?? "") ==
              _selectedSorteo.trim().toLowerCase())
          .toList();
      if (filtrados.isNotEmpty) {
        baseList = filtrados;
      }
    }

    // Filtrar filas de predicción futura / placeholders donde todas las balotas son 0
    return baseList.where((r) {
      final rawNums = (r["numeros"] as List<dynamic>? ?? []);
      if (rawNums.isEmpty) return false;
      final parsed = rawNums.map((e) => int.tryParse(e.toString()) ?? 0).toList();
      return parsed.any((n) => n > 0);
    }).take(50).toList();
  }

  Widget _build3DBall(
    int? numero, {
    Color baseColor = const Color(0xFFF33A21),
    double size = 32,
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
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            offset: Offset(1.2, 1.2),
            blurRadius: 2.5,
          ),
        ],
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "–",
          style: GoogleFonts.montserrat(
            fontSize: size * 0.40,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Colors.black87,
                offset: Offset(0.6, 0.6),
                blurRadius: 1.5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final listToShow = _obtenerResultadosFiltrados();

    final int maxBallsInResults = listToShow.isNotEmpty
        ? listToShow
            .map((r) => (r["numeros"] as List<dynamic>? ?? [])
                .map((e) => int.tryParse(e.toString()) ?? -1)
                .where((n) => n >= 0)
                .length)
            .fold(0, (max, len) => len > max ? len : max)
        : widget.config.totalBalotasSorteo;

    final double ballSpacing = maxBallsInResults <= 5
        ? 4.5
        : (maxBallsInResults == 6 ? 3.0 : (maxBallsInResults == 7 ? 2.0 : 1.2));
    final double defaultBallSize = maxBallsInResults <= 5
        ? 34.0
        : (maxBallsInResults == 6 ? 31.0 : (maxBallsInResults == 7 ? 28.0 : 25.0));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.blackfondo,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.blackfondo,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            CustomSliverAppBar(
              title: widget.config.nombre,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título y Subtítulo
                    Text(
                      l10n?.historicoResultadosTitulo ?? "Historial de Resultados",
                      style: AppTextStyles.h2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.ultimos50Resultados(widget.config.nombre) ??
                          "Últimos 50 sorteos de ${widget.config.nombre}",
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Selector de Sub-Sorteos (ej. Melate / Revancha / Revanchita / Baloto / Revancha / 5 de Oro / Revancha)
                    if (sorteosActivos.length > 1) ...[
                      Row(
                        children: sorteosActivos.map((sorteo) {
                          final isSelected =
                              _selectedSorteo.toLowerCase() == sorteo.toLowerCase();
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedSorteo = sorteo),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.yellow : const Color(0xFF2A2A2A),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.yellow.withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    sorteo,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.montserrat(
                                      color: isSelected ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Estado de carga / error / lista de resultados
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(color: AppColors.yellow),
                        ),
                      )
                    else if (_errorMessage != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                              const SizedBox(height: 10),
                              Text(
                                "No se pudieron cargar los resultados.",
                                style: AppTextStyles.mensajeSecundario,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _cargarHistorico,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.yellow,
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text("Reintentar"),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (listToShow.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 50),
                          child: Text(
                            l10n?.sinNumeros ?? "No hay resultados registrados",
                            style: AppTextStyles.mensajeSecundario,
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12, width: 0.8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // Encabezado de la tabla
                            Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    "#",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Colors.white38,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 82,
                                  child: Text(
                                    l10n?.fechaLabel ?? "Fecha",
                                    textAlign: TextAlign.left,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Colors.white38,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      l10n?.resultados ?? "Resultados",
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: Colors.white38,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 16),

                            // Filas de sorteos
                            ...List.generate(listToShow.length, (rowIndex) {
                              final resultado = listToShow[rowIndex];
                              final fecha = resultado["fecha"]?.toString() ?? "S/F";
                              final rawNumeros = resultado["numeros"] as List<dynamic>? ?? [];
                              final int limiteBalotas = widget.config.totalBalotasSorteo > 0
                                  ? widget.config.totalBalotasSorteo
                                  : 20;
                              final bool isReintegro = widget.config.tieneReintegro;
                              final numeros = rawNumeros
                                  .map((e) => int.tryParse(e.toString()) ?? -1)
                                  .whereIndexed((index, n) {
                                    if (n < 0) return false;
                                    if (n == 0 && index >= widget.config.maxSeleccion && !isReintegro) {
                                      return false;
                                    }
                                    return true;
                                  })
                                  .take(limiteBalotas)
                                  .toList();

                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 6.5),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: rowIndex == listToShow.length - 1
                                          ? Colors.transparent
                                          : Colors.white10,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Índice
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        "${rowIndex + 1}",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          color: Colors.white38,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Fecha
                                    SizedBox(
                                      width: 82,
                                      child: Text(
                                        fecha,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Balotas
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final totalBalls = numeros.length;
                                          final double calculatedSize = totalBalls > 0
                                              ? ((constraints.maxWidth -
                                                      (totalBalls * ballSpacing * 2)) /
                                                  totalBalls)
                                              : defaultBallSize;
                                          final double ballSize =
                                              calculatedSize.clamp(15.0, defaultBallSize);

                                          return Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.center,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: List.generate(numeros.length, (index) {
                                                  final n = numeros[index];
                                                  final bool isLastBall =
                                                      index == numeros.length - 1;
                                                  final bool isComp =
                                                      widget.config.tieneComplementario &&
                                                          numeros.length >
                                                              widget.config.maxSeleccion &&
                                                          index == widget.config.maxSeleccion;
                                                  final bool isSpecial =
                                                      widget.config.tieneBalotaRoja &&
                                                          numeros.length >
                                                              widget.config.maxSeleccion &&
                                                          (index >=
                                                                  widget.config.maxSeleccion +
                                                                      (widget.config
                                                                              .tieneComplementario
                                                                          ? 1
                                                                          : 0) ||
                                                              isLastBall);
                                                  final Color ballColor = isSpecial
                                                      ? const Color(0xFFB91C1C)
                                                      : (isComp
                                                          ? const Color(0xFF0D9488)
                                                          : Colors.amber);

                                                  return Padding(
                                                    padding: EdgeInsets.symmetric(
                                                        horizontal: ballSpacing),
                                                    child: _build3DBall(
                                                      n,
                                                      baseColor: ballColor,
                                                      size: ballSize,
                                                    ),
                                                  );
                                                }),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Footer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
