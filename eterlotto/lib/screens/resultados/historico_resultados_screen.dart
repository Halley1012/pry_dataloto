import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/screens/loteria_screen.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/widgets/custom_app_bar.dart';
import 'package:eterlotto/widgets/footer.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'package:eterlotto/utils/screen_security_helper.dart';
import 'package:shimmer/shimmer.dart';

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
    ScreenSecurityHelper.enableSecureScreen();
    _selectedSorteo = widget.initialSorteo ??
        (widget.sorteosDisponibles.isNotEmpty ? widget.sorteosDisponibles.first : widget.config.nombre);

    // ⚡ Optimización Cache-First: Usar datos iniciales si vienen pre-cargados
    if (widget.initialResultados != null && widget.initialResultados!.isNotEmpty) {
      _todosResultados = widget.initialResultados!;
      _isLoading = false;
    }

    _cargarHistorico();
  }

  @override
  void dispose() {
    ScreenSecurityHelper.disableSecureScreen();
    super.dispose();
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
    }).toList();
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

  Widget _buildActionButton({
    required dynamic icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isEnabled = true,
    double size = 42,
  }) {
    return InkWell(
      onTap: isEnabled ? onPressed : null,
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
          child: icon is IconData
              ? Icon(
                  icon,
                  color: isEnabled ? color : Colors.white24,
                  size: size * 0.42,
                )
              : FaIcon(
                  icon,
                  color: isEnabled ? color : Colors.white24,
                  size: size * 0.42,
                ),
        ),
      ),
    );
  }

  Future<void> _exportarPDF() async {
    final listToShow = _obtenerResultadosFiltrados();
    if (listToShow.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay resultados para exportar")),
      );
      return;
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "ETERLOTTO - ${widget.config.nombre.toUpperCase()}",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.amber900,
                  ),
                ),
                pw.Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "Historial Completo de Resultados - Sorteo: $_selectedSorteo (${listToShow.length} sorteos)",
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (pw.Context ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "Generado desde Eterlotto App",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              "Página ${ctx.pageNumber} de ${ctx.pagesCount}",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (pw.Context ctx) => [
          pw.TableHelper.fromTextArray(
            headers: [
              "#",
              "Fecha",
              "Resultados",
              if (widget.config.maxBalotasRojas > 0 || widget.config.tieneComplementario)
                widget.config.superbalotaNombre.isNotEmpty ? widget.config.superbalotaNombre : "Especial"
            ],
            data: listToShow.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final r = entry.value;
              final rawNums = (r["numeros"] as List<dynamic>? ?? []);
              final nums = rawNums.map((e) => int.tryParse(e.toString()) ?? -1).where((n) => n >= 0).toList();
              final rawRed = r["balotaroja"] ?? r["superbalota"] ?? r["comodin"] ?? r["reintegro"];
              final red = (rawRed != null && (int.tryParse(rawRed.toString()) ?? -1) >= 0) ? int.parse(rawRed.toString()) : null;

              final mainBalls = nums.length > widget.config.maxSeleccion ? nums.sublist(0, widget.config.maxSeleccion) : nums;
              final numbersStr = mainBalls.join(' - ');

              final rowData = ["$index", r["fecha"].toString(), numbersStr];
              if (widget.config.maxBalotasRojas > 0 || widget.config.tieneComplementario) {
                rowData.add(red?.toString() ?? "-");
              }
              return rowData;
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.amber800),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellHeight: 20,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
            },
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: "Historial_${widget.config.nombre}_$_selectedSorteo.pdf",
    );
  }

  Future<void> _exportarExcel() async {
    final listToShow = _obtenerResultadosFiltrados();
    if (listToShow.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay resultados para exportar")),
      );
      return;
    }

    final buffer = StringBuffer();
    // UTF-8 BOM para que Excel abra acentos y símbolos correctamente
    buffer.write('\uFEFF');
    buffer.writeln("#,Fecha,Sorteo,Numeros_Ganadores,Especial_Superbalota");

    for (int i = 0; i < listToShow.length; i++) {
      final r = listToShow[i];
      final rawNums = (r["numeros"] as List<dynamic>? ?? []);
      final nums = rawNums.map((e) => int.tryParse(e.toString()) ?? -1).where((n) => n >= 0).toList();
      final rawRed = r["balotaroja"] ?? r["superbalota"] ?? r["comodin"] ?? r["reintegro"];
      final red = (rawRed != null && (int.tryParse(rawRed.toString()) ?? -1) >= 0) ? int.parse(rawRed.toString()) : null;

      final mainBalls = nums.length > widget.config.maxSeleccion ? nums.sublist(0, widget.config.maxSeleccion) : nums;
      final numbersStr = mainBalls.join(' - ');
      final specialStr = red?.toString() ?? "";

      buffer.writeln('${i + 1},"${r["fecha"]}","${r["sorteo"] ?? _selectedSorteo}","$numbersStr","$specialStr"');
    }

    final bytes = utf8.encode(buffer.toString());
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'text/csv',
          name: 'Historial_${widget.config.nombre}_$_selectedSorteo.csv',
        ),
      ],
      subject: 'Historial de Resultados ${widget.config.nombre} ($_selectedSorteo)',
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
        body: RefreshIndicator(
          color: Colors.transparent,
          backgroundColor: Colors.transparent,
          elevation: 0,
          onRefresh: _cargarHistorico,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              CustomSliverAppBar(
                title: widget.config.nombre,
              ),
              if (_isLoading && _todosResultados.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: LinearProgressIndicator(
                      backgroundColor: Color(0xFF1E2029),
                      color: AppColors.yellow,
                      minHeight: 2.5,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Título, Subtítulo y Botones de Exportar
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
                                    ? "Todos los sorteos registrados (${listToShow.length} sorteos)"
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildActionButton(
                              icon: Icons.picture_as_pdf,
                              color: const Color(0xFFC026D3), // Fucsia/Púrpura estilo Mis Jugadas
                              onPressed: _exportarPDF,
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(
                              icon: FontAwesomeIcons.fileExcel,
                              color: const Color(0xFF10B981), // Verde Esmeralda Excel
                              onPressed: _exportarExcel,
                            ),
                          ],
                        ),
                      ],
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
