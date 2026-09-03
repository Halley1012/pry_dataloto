import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/screens/loteria_screen.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/widgets/custom_app_bar.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'package:eterlotto/utils/screen_security_helper.dart';
import 'package:shimmer/shimmer.dart';
import 'widgets/resultados_shared.dart';

class HistoricoResultadosScreen extends StatefulWidget {
  final LoteriaConfig config;
  final List<String> sorteosDisponibles;
  final String? initialSorteo;
  final List<Map<String, dynamic>>? initialResultados;
  final List<int>? top20;
  final bool modoResultadosIA;

  const HistoricoResultadosScreen({
    super.key,
    required this.config,
    this.sorteosDisponibles = const [],
    this.initialSorteo,
    this.initialResultados,
    this.top20,
    this.modoResultadosIA = false,
  });

  @override
  State<HistoricoResultadosScreen> createState() => _HistoricoResultadosScreenState();
}

class _HistoricoResultadosScreenState extends State<HistoricoResultadosScreen> {
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _todosResultados = [];
  late String _selectedSorteo;
  List<int> _top20 = [];

  String _formatearFechaCorta(String rawDate) {
    if (rawDate.isEmpty) return "";
    try {
      final clean = rawDate.trim();
      if (clean.length >= 10 && clean[4] == '-' && clean[7] == '-') {
        final year = clean.substring(2, 4);
        final month = clean.substring(5, 7);
        final day = clean.substring(8, 10);
        return "$day-$month-$year";
      }
      final parsed = DateTime.tryParse(clean);
      if (parsed != null) {
        final day = parsed.day.toString().padLeft(2, '0');
        final month = parsed.month.toString().padLeft(2, '0');
        final year = (parsed.year % 100).toString().padLeft(2, '0');
        return "$day-$month-$year";
      }
    } catch (_) {}
    return rawDate;
  }

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
    ScreenSecurityHelper.enableSecureScreen();
    _selectedSorteo = widget.initialSorteo ??
        (widget.sorteosDisponibles.isNotEmpty ? widget.sorteosDisponibles.first : widget.config.nombre);

    if (widget.top20 != null && widget.top20!.isNotEmpty) {
      _top20 = List<int>.from(widget.top20!);
    }

    // ⚡ Optimización Cache-First: Usar datos iniciales si vienen pre-cargados
    if (widget.initialResultados != null && widget.initialResultados!.isNotEmpty) {
      _todosResultados = widget.initialResultados!.take(50).toList();
      _isLoading = false;
    }

    _cargarHistorico();
  }

  @override
  void dispose() {
    ScreenSecurityHelper.disableSecureScreen();
    super.dispose();
  }

  Future<void> _cargarHistorico({bool force = false}) async {
    final cacheKey = '${widget.config.route}_ultimos50_historico';

    // 1. Si no teníamos datos iniciales, leer de la caché local primero (0ms)
    if (_todosResultados.isEmpty && !force) {
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
            _todosResultados = listCached.take(50).toList();
            _isLoading = false;
            if (encontrados.isNotEmpty &&
                !encontrados.any((s) => s.toLowerCase() == _selectedSorteo.toLowerCase())) {
              _selectedSorteo = encontrados.first;
            }
          });
        }
      }
    }

    if (_todosResultados.isEmpty || force) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    // 2. Traer los 50 sorteos más recientes desde el servidor
    try {
      final list = await ApiService.getHistorico50(widget.config.route);
      if (mounted && list.isNotEmpty) {
        final encontrados = list
            .map((r) => r["sorteo"]?.toString().trim())
            .where((s) => s != null && s.isNotEmpty)
            .toSet()
            .cast<String>()
            .toList();

        final final50 = list.take(50).toList();

        setState(() {
          _todosResultados = final50;
          if (encontrados.isNotEmpty &&
              !encontrados.any((s) => s.toLowerCase() == _selectedSorteo.toLowerCase())) {
            _selectedSorteo = encontrados.first;
          }
        });

        // Guardar en caché local
        CacheService.setJson(cacheKey, {"resultados": final50});
      }
    } catch (e) {
      if (mounted && _todosResultados.isEmpty) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (_top20.isEmpty) {
        try {
          final pred = await ApiService.getPrediccionLoteria(widget.config.route);
          if (pred["numeros"] is List) {
            final pNums = (pred["numeros"] as List)
                .map((e) => int.tryParse(e.toString()) ?? -1)
                .where((n) => n >= 0)
                .toList();
            if (pNums.isNotEmpty && mounted) {
              setState(() {
                _top20 = pNums.take(20).toList();
              });
            }
          }
        } catch (_) {}
      }
      if (mounted) setState(() => _isLoading = false);
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

  Widget _buildActionButton({
    required dynamic icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isEnabled = true,
    bool isLoading = false,
    double size = 42,
  }) {
    return InkWell(
      onTap: isEnabled && !isLoading ? onPressed : null,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isEnabled
                ? [color.withValues(alpha: 0.35), Colors.black]
                : [Colors.white10, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            if (isEnabled) ...[
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 7,
                offset: const Offset(-1.5, -1.5),
                spreadRadius: 0.5,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 8,
                offset: const Offset(3, 3),
                spreadRadius: 1,
              ),
            ] else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 4,
                offset: const Offset(1, 1),
              ),
          ],
          border: Border.all(
            color: isEnabled ? color.withValues(alpha: 0.5) : Colors.white10,
            width: 1.2,
          ),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: size * 0.42,
                  height: size * 0.42,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : (icon is IconData
                  ? Icon(
                      icon,
                      color: isEnabled ? color : Colors.white24,
                      size: size * 0.42,
                    )
                  : FaIcon(
                      icon,
                      color: isEnabled ? color : Colors.white24,
                      size: size * 0.42,
                    )),
        ),
      ),
    );
  }

  /// 📊 Mostrar diálogo de confirmación antes de descargar
  Future<void> _exportarExcel() async {
    if (_isExporting) return;
    final l10n = AppLocalizations.of(context);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12, width: 0.8),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(FontAwesomeIcons.fileExcel, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n?.tituloDescargaExcel ?? "Descargar Histórico",
                style: AppTextStyles.h2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n?.mensajeDescargaExcel ??
              "¿Deseas descargar el archivo Excel con el 100% de los sorteos registrados en la base de datos para realizar tus propios análisis?",
          style: AppTextStyles.mensajeSecundario.copyWith(
            color: Colors.white70,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n?.cancelar ?? "Cancelar",
              style: AppTextStyles.button.copyWith(
                color: AppColors.yellow,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 2,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const FaIcon(FontAwesomeIcons.fileArrowDown, size: 14, color: Colors.white),
            label: Text(
              l10n?.descargar ?? "Descargar",
              style: AppTextStyles.button.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      _ejecutarDescargaExcel();
    }
  }

  /// 📊 Exportar a Excel (CSV) con el 100% de los registros históricos de la base de datos
  Future<void> _ejecutarDescargaExcel() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    final l10n = AppLocalizations.of(context);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.descargandoHistorico ?? "Descargando histórico completo de la base de datos..."),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }

      // Descargar el histórico 100% completo del servidor
      final listCompleta = await ApiService.getHistoricoCompleto(widget.config.route);
      List<Map<String, dynamic>> listToExport = listCompleta.isNotEmpty ? listCompleta : _todosResultados;

      if (sorteosActivos.length > 1) {
        final filtrados = listToExport
            .where((r) =>
                (r["sorteo"]?.toString().trim().toLowerCase() ?? "") ==
                _selectedSorteo.trim().toLowerCase())
            .toList();
        if (filtrados.isNotEmpty) {
          listToExport = filtrados;
        }
      }

      // Filtrar filas vacías o con ceros
      listToExport = listToExport.where((r) {
        final rawNums = (r["numeros"] as List<dynamic>? ?? []);
        if (rawNums.isEmpty) return false;
        final parsed = rawNums.map((e) => int.tryParse(e.toString()) ?? 0).toList();
        return parsed.any((n) => n > 0);
      }).toList();

      if (listToExport.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No hay resultados para exportar")),
          );
        }
        return;
      }

      final buffer = StringBuffer();
      // UTF-8 BOM para que Excel abra acentos y símbolos correctamente
      buffer.write('\uFEFF');
      if (widget.modoResultadosIA) {
        buffer.writeln("#,Fecha,Sorteo,Numeros_Ganadores,Especial_Superbalota,Cobertura_IA,Aciertos");
      } else {
        buffer.writeln("#,Fecha,Sorteo,Numeros_Ganadores,Especial_Superbalota");
      }

      for (int i = 0; i < listToExport.length; i++) {
        final r = listToExport[i];
        final rawNums = (r["numeros"] as List<dynamic>? ?? []);
        List<int> nums = rawNums.map((e) => int.tryParse(e.toString()) ?? -1).where((n) => n >= 0).toList();
        int? red = int.tryParse(
          r["balotaroja2"]?.toString() ??
          r["reintegro"]?.toString() ??
          r["balotaroja"]?.toString() ??
          r["balota_roja"]?.toString() ??
          r["superbalota"]?.toString() ??
          r["red"]?.toString() ?? "",
        );
        if (red == null && (widget.config.tieneBalotaRoja || widget.config.maxBalotasRojas > 0) && nums.length > widget.config.maxSeleccion) {
          red = nums.removeLast();
        } else if (red != null && nums.length > widget.config.maxSeleccion && nums.last == red) {
          nums.removeLast();
        }

        final mainBalls = nums.length > widget.config.maxSeleccion ? nums.sublist(0, widget.config.maxSeleccion) : nums;
        final numbersStr = mainBalls.join(' - ');
        final specialStr = red?.toString() ?? "";

        if (widget.modoResultadosIA) {
          final hits = mainBalls.where((n) => _top20.contains(n)).length;
          final covPercent = mainBalls.isNotEmpty ? ((hits / mainBalls.length) * 100).round() : 0;
          buffer.writeln('${i + 1},"${r["fecha"]}","${r["sorteo"] ?? _selectedSorteo}","$numbersStr","$specialStr","$covPercent%","$hits / ${mainBalls.length}"');
        } else {
          buffer.writeln('${i + 1},"${r["fecha"]}","${r["sorteo"] ?? _selectedSorteo}","$numbersStr","$specialStr"');
        }
      }

      final bytes = utf8.encode(buffer.toString());
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType: 'text/csv',
            name: 'Historial_Completo_${widget.config.nombre}_$_selectedSorteo.csv',
          ),
        ],
        subject: 'Historial Completo de Resultados ${widget.config.nombre} ($_selectedSorteo)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al exportar histórico: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final listToShow = _obtenerResultadosFiltrados();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.blackfondo,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.blackfondo,
        body: RefreshIndicator(
          color: AppColors.yellow,
          backgroundColor: const Color(0xFF1E1E1E),
          displacement: 25.0,
          onRefresh: () => _cargarHistorico(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                    // Título, Subtítulo y Botón de Exportar Excel
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n?.historicoResultadosTitulo ?? "Historial de Resultados",
                                style: AppTextStyles.h2.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                listToShow.isNotEmpty
                                    ? (l10n?.ultimosNSorteosRegistrados(listToShow.length) ?? "Últimos ${listToShow.length} sorteos registrados")
                                    : (l10n?.ultimos50Resultados(widget.config.nombre) ?? "Historial de ${widget.config.nombre}"),
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: FontAwesomeIcons.fileExcel,
                          color: const Color(0xFF10B981), // Verde Esmeralda Excel
                          isLoading: _isExporting,
                          onPressed: _exportarExcel,
                        ),
                      ],
                    ),
                    if (listToShow.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1C23),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppColors.yellow),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n?.descripcionHistoricoResultados ?? "Consulta los 50 sorteos más recientes o pulsa el botón Excel para descargar el histórico completo de la base de datos.",
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                                onTap: () => setState(() {
                                  _selectedSorteo = sorteo;
                                }),
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
                      _buildSkeletonHistorico()
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
                            // Encabezado dinámico según el modo
                            if (widget.modoResultadosIA)
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Center(
                                      child: Text(
                                        l10n?.sorteoLabel ?? "Sorteo",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          color: Colors.white38,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 12,
                                    child: Center(
                                      child: Text(
                                        l10n?.numerosGanadores ?? "Números ganadores",
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          color: Colors.white38,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Center(
                                      child: Text(
                                        l10n?.coberturaIA ?? "Cobertura IA",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          color: Colors.white38,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Center(
                                      child: Text(
                                        l10n?.aciertosSimple ?? "Aciertos",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          color: Colors.white38,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
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
                                    width: 84,
                                    child: Text(
                                      l10n?.sorteoLabel ?? "Sorteo",
                                      textAlign: TextAlign.center,
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

                            // Filas de sorteos visibles (hasta 50)
                            ...List.generate(listToShow.length, (rowIndex) {
                              final resultado = listToShow[rowIndex];
                              final rawDate = resultado["fecha"]?.toString() ?? "";
                              final dateDisplay = _formatearFechaCorta(rawDate);

                              final rawNumeros = (resultado["numeros"] as List<dynamic>? ?? []);
                              List<int> nums = rawNumeros
                                  .map((e) => int.tryParse(e.toString()) ?? -1)
                                  .where((n) => n >= 0)
                                  .toList();

                              int? red = int.tryParse(
                                resultado["balotaroja2"]?.toString() ??
                                resultado["reintegro"]?.toString() ??
                                resultado["balotaroja"]?.toString() ??
                                resultado["balota_roja"]?.toString() ??
                                resultado["superbalota"]?.toString() ??
                                resultado["red"]?.toString() ?? "",
                              );
                              if (red == null && (widget.config.tieneBalotaRoja || widget.config.maxBalotasRojas > 0) && nums.length > widget.config.maxSeleccion) {
                                red = nums.removeLast();
                              } else if (red != null && nums.length > widget.config.maxSeleccion && nums.last == red) {
                                nums.removeLast();
                              }

                              final bool tieneComp = widget.config.tieneComplementario || (nums.length > widget.config.maxSeleccion);
                              final List<int> mainBalls = nums.length > widget.config.maxSeleccion
                                  ? nums.sublist(0, widget.config.maxSeleccion)
                                  : nums;
                              final int? compBall = (tieneComp && nums.length > widget.config.maxSeleccion)
                                  ? nums.last
                                  : null;

                              final int hits = mainBalls.where((n) => _top20.contains(n)).length;
                              final int covPercent = mainBalls.isNotEmpty ? ((hits / mainBalls.length) * 100).round() : 0;
                              final Color coverageColor = covPercent >= 60 ? Colors.greenAccent : Colors.amber;

                              final int totalBalls = mainBalls.length +
                                  (compBall != null ? 1 : 0) +
                                  (red != null ? 1 : 0);

                              final double ballSize = totalBalls <= 5
                                  ? 27.0
                                  : (totalBalls == 6 ? 25.0 : (totalBalls == 7 ? 22.0 : 20.0));
                              final double ballPadding = totalBalls <= 5
                                  ? 2.0
                                  : (totalBalls == 6 ? 1.8 : (totalBalls == 7 ? 1.4 : 1.0));

                              if (widget.modoResultadosIA) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 7.0),
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
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: Text(
                                            dateDisplay,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 12,
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                ...mainBalls.map((n) => Padding(
                                                      padding: EdgeInsets.symmetric(horizontal: ballPadding),
                                                      child: buildMiniBall(n, baseColor: coverageColor, size: ballSize),
                                                    )),
                                                if (compBall != null) ...[
                                                  SizedBox(width: ballPadding),
                                                  Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: ballPadding),
                                                    child: buildMiniBall(compBall, baseColor: const Color(0xFF0D9488), size: ballSize),
                                                  ),
                                                ],
                                                if (red != null) ...[
                                                  SizedBox(width: ballPadding),
                                                  Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: ballPadding),
                                                    child: buildMiniBall(red, baseColor: const Color(0xFFB91C1C), size: ballSize),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: Text(
                                            "$covPercent%",
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: coverageColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: Text(
                                            "$hits / ${mainBalls.length}",
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Modo Tabla Principal (Lotería): #, Sorteo, Resultados (balotas doradas + roja)
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
                                  children: [
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
                                    SizedBox(
                                      width: 84,
                                      child: Text(
                                        rawDate,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.center,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              ...mainBalls.map((n) => Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: ballPadding),
                                                    child: buildMiniBall(n, baseColor: Colors.amber, size: ballSize),
                                                  )),
                                              if (compBall != null) ...[
                                                SizedBox(width: ballPadding),
                                                Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: ballPadding),
                                                  child: buildMiniBall(compBall, baseColor: const Color(0xFF0D9488), size: ballSize),
                                                ),
                                              ],
                                              if (red != null) ...[
                                                SizedBox(width: ballPadding),
                                                Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: ballPadding),
                                                  child: buildMiniBall(red, baseColor: const Color(0xFFB91C1C), size: ballSize),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildSkeletonHistorico() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2C2C2C),
      period: const Duration(milliseconds: 1400),
      child: Column(
        children: List.generate(
          8,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
