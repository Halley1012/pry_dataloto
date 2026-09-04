import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eterlotto/services/api_service.dart';
import '../../services/cache_service.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/widgets/contenedor3.dart';
import 'package:eterlotto/widgets/custom_app_bar.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:eterlotto/services/ad_service.dart';
import 'package:eterlotto/providers/subscription_provider.dart';
import '../../utils/screen_security_helper.dart';
import '../loteria_screen.dart';
import '../estadisticas_dashboard_screen.dart';
import '../resultados_dashboard_screen.dart';
import 'package:shimmer/shimmer.dart';

class MisJugadasScreen extends StatefulWidget {
  final String loteriaNombre;
  final String loteriaRoute;

  const MisJugadasScreen({
    super.key,
    required this.loteriaNombre,
    required this.loteriaRoute,
  });

  @override
  State<MisJugadasScreen> createState() => _MisJugadasScreenState();
}

class _MisJugadasScreenState extends State<MisJugadasScreen> {
  List<Map<String, dynamic>> _jugadasList = [];
  Set<int> _selectedIds = {};
  bool _cargando = true;
  String? _userId;
  LoteriaConfig? _config;
  final ValueNotifier<Offset?> _fabPositionNotifier = ValueNotifier<Offset?>(null);

  @override
  void initState() {
    super.initState();
    ScreenSecurityHelper.enableSecureScreen();
    _cargarConfig();
    _cargarJugadas();
  }

  @override
  void dispose() {
    ScreenSecurityHelper.disableSecureScreen();
    _fabPositionNotifier.dispose();
    super.dispose();
  }

  Future<void> _cargarConfig() async {
    try {
      final loteriasData = await ApiService.getAllLoterias();
      final match = loteriasData.firstWhere(
        (l) =>
            (l['route']?.toString().toLowerCase() == widget.loteriaRoute.toLowerCase()) ||
            (l['nombre']?.toString().toLowerCase() == widget.loteriaNombre.toLowerCase()),
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty && mounted) {
        setState(() {
          _config = LoteriaConfig.fromJson(Map<String, dynamic>.from(match as Map), fallbackNombre: widget.loteriaNombre);
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarJugadas({bool force = false}) async {
    final uId = await ApiService.getUserId();
    final uIdStr = uId?.toString();
    final cacheKeyUser = 'user_jugadas_${widget.loteriaRoute}_${uIdStr ?? "anon"}';
    final cacheKeyGeneral = 'mis_jugadas_${widget.loteriaRoute}';

    if (!force) {
      final cached = await CacheService.getJson(cacheKeyUser) ?? await CacheService.getJson(cacheKeyGeneral);
      if (cached != null && mounted) {
        setState(() {
          _userId = uIdStr;
          _jugadasList = List<Map<String, dynamic>>.from(cached);
          _cargando = false;
        });
      }
    }

    if (!mounted) return;
    if (_jugadasList.isEmpty) setState(() => _cargando = true);

    try {
      final response = await ApiService.listarJugadasGenerica(widget.loteriaRoute);
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _userId = uIdStr;
          _jugadasList = data;
          _selectedIds.clear();
          _cargando = false;
        });
        await CacheService.setJson(cacheKeyUser, data);
        await CacheService.setJson(cacheKeyGeneral, data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _jugadasList.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _jugadasList
            .map((j) => j["id"] as int? ?? 0)
            .where((id) => id > 0)
            .toSet();
      }
    });
  }

  Future<void> _eliminarSeleccionadas() async {
    if (_selectedIds.isEmpty) return;

    final l10n = AppLocalizations.of(context);

    final String confirmMsg = l10n?.confirmarEliminarVarios(_selectedIds.length) ?? "¿Seguro que deseas eliminar ${_selectedIds.length} jugada(s)?";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Text(
              l10n?.eliminarJugadas ?? "Eliminar jugadas",
              style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          confirmMsg,
          style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.cancelar ?? "Cancelar", style: const TextStyle(color: Colors.amber)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.eliminar ?? "Eliminar", style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true || _userId == null) return;

    final backupList = List<Map<String, dynamic>>.from(_jugadasList);
    final deletedIds = _selectedIds.toSet();

    // 1. Eliminación optimista inmediata en UI
    setState(() {
      _jugadasList.removeWhere((j) => deletedIds.contains(j["id"]));
      _selectedIds.clear();
    });

    // 2. Sincronizar cache persistente en SharedPreferences de inmediato
    final uIdStr = _userId ?? "anon";
    await CacheService.setJson('user_jugadas_${widget.loteriaRoute}_$uIdStr', _jugadasList);
    await CacheService.setJson('mis_jugadas_${widget.loteriaRoute}', _jugadasList);
    await CacheService.invalidarCachesDeJugadas(specificRoute: widget.loteriaRoute);

    // 3. Ejecutar eliminación en el backend (en paralelo)
    final results = await Future.wait(
      deletedIds.map((id) => ApiService.borrarJugadaGenerica(widget.loteriaRoute, id, _userId!)),
    );

    // Si falló alguna eliminación, hacemos rollback restaurando el estado previo y la caché
    if (results.any((ok) => !ok)) {
      if (mounted) {
        setState(() {
          _jugadasList = backupList;
        });
        await CacheService.setJson('user_jugadas_${widget.loteriaRoute}_$uIdStr', backupList);
        await CacheService.setJson('mis_jugadas_${widget.loteriaRoute}', backupList);
        await CacheService.invalidarCachesDeJugadas(specificRoute: widget.loteriaRoute);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudieron eliminar algunas jugadas. Se restauraron."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // 4. Confirmar estado desde el servidor
    await _cargarJugadas(force: true);
  }

  bool get _usaSuperbalota {
    if (_config != null) return _config!.tieneBalotaRoja;
    for (var j in _jugadasList) {
      if (j['balota_roja'] != null || j['superbalota'] != null) return true;
      final nums = j['numeros'];
      if (nums is List && nums.length > 6) return true;
    }
    return false;
  }

  (List<int>, int?) _parsearJugada(Map<String, dynamic> item) {
    final rawNums = (item["numeros"] as List<dynamic>? ?? []);
    final nums = rawNums
        .map((n) => int.tryParse(n.toString()) ?? -1)
        .where((n) => n >= 0)
        .toList();

    final bRoja = item["balota_roja"] ?? item["balotaroja"] ?? item["superbalota"];
    final int maxSel = _config?.maxSeleccion ??
        (nums.length >= 7 ? 6 : (nums.length == 6 && !_usaSuperbalota ? 6 : 5));

    final bool tieneRoja = _config?.tieneBalotaRoja ?? _usaSuperbalota;

    int? red;
    List<int> whites;

    if (bRoja != null) {
      red = int.tryParse(bRoja.toString());
      if (nums.length > maxSel) {
        whites = nums.sublist(0, maxSel);
      } else {
        whites = nums.where((n) => n != red).toList();
      }
    } else if (tieneRoja && nums.length > maxSel) {
      whites = nums.sublist(0, maxSel);
      red = nums.last;
    } else {
      whites = nums;
      red = null;
    }

    return (whites, red);
  }

  void _compartirWhatsApp() async {
    final l10n = AppLocalizations.of(context);
    final jugadasACompartir = _jugadasList
        .where((j) => _selectedIds.isEmpty || _selectedIds.contains(j["id"]))
        .toList();

    if (jugadasACompartir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.noHayJugadasCompartir ?? "No hay jugadas para compartir")),
      );
      return;
    }

    final isPremium = context.read<SubscriptionProvider>().isSubscribed;

    await AdService.instance.showRewardedFeatureGate(
      context: context,
      isPremium: isPremium,
      featureTitle: "Compartir por WhatsApp",
      featureActionDescription: "Mira un breve video publicitario para generar y compartir tu tiquete de jugadas por WhatsApp gratis.",
      onRewardGranted: () async {
        final StringBuffer buffer = StringBuffer();
        buffer.writeln("🎰 *${l10n?.misJugadasLoteria(widget.loteriaNombre) ?? "Mis Jugadas de ${widget.loteriaNombre} - Eterlotto"}* 🎰\n");

        for (int i = 0; i < jugadasACompartir.length; i++) {
          final play = jugadasACompartir[i];
          final (whites, redVal) = _parsearJugada(play);
          final String jugadaLabel = l10n?.jugadaShare(i + 1) ?? "Jugada #${i + 1}";
          if (redVal != null) {
            final String superbalota = l10n?.superbalotaConValor(redVal) ?? "[Roja: $redVal]";
            buffer.writeln("📌 *$jugadaLabel*: ${whites.join(', ')} | 🔴 *$superbalota*");
          } else {
            buffer.writeln("📌 *$jugadaLabel*: ${whites.join(', ')}");
          }
        }

        buffer.writeln("\n🍀 _${l10n?.buenaSuerteDataLoto ?? "¡Buena suerte con Eterlotto!"}_");

        final text = buffer.toString();
        final whatsappUrl = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(text)}");

        try {
          if (await canLaunchUrl(whatsappUrl)) {
            await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
          } else {
            await Share.share(text);
          }
        } catch (_) {
          await Share.share(text);
        }
      },
    );
  }

  Future<void> _imprimirPDF() async {
    final l10n = AppLocalizations.of(context);
    final jugadasAImprimir = _selectedIds.isNotEmpty
        ? _jugadasList.where((j) => _selectedIds.contains(j["id"])).toList()
        : _jugadasList;

    if (jugadasAImprimir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.noHayJugadasSeleccionadasImprimir ?? "No hay jugadas seleccionadas para imprimir")),
      );
      return;
    }

    final isPremium = context.read<SubscriptionProvider>().isSubscribed;

    await AdService.instance.showRewardedFeatureGate(
      context: context,
      isPremium: isPremium,
      featureTitle: "Exportar Tiquete en PDF",
      featureActionDescription: "Mira un breve video publicitario para generar y descargar tu tiquete de jugadas en PDF gratis.",
      onRewardGranted: () async {
        final doc = pw.Document();

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context ctx) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Header(
                      level: 0,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            l10n?.tiqueteDataloto(widget.loteriaNombre.toUpperCase()) ?? "ETERLOTTO - TICKET ${widget.loteriaNombre.toUpperCase()}",
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amber900,
                            ),
                          ),
                          pw.Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      l10n?.reporteJugadasGuardadas(jugadasAImprimir.length) ?? "Reporte de Jugadas Guardadas (${jugadasAImprimir.length} jugada(s))",
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 16),
                    pw.TableHelper.fromTextArray(
                      headers: [
                        l10n?.nro ?? "#",
                        l10n?.fechaGuardado ?? "Fecha Guardado",
                        l10n?.balotasLoteria(widget.loteriaNombre) ?? "Balotas ${widget.loteriaNombre}"
                      ],
                      data: jugadasAImprimir.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final item = entry.value;
                        final (whites, red) = _parsearJugada(item);
                        final fecha = _formatFecha(item["fecha_sorteo"] ?? item["fecha_guardado"] ?? item["created_at"] ?? item["fecha"]);

                        final balotasStr = red != null
                            ? "${whites.join(' - ')}  ${l10n?.superbalotaConValor(red) ?? '[Roja: $red]'}"
                            : whites.join(' - ');

                        return [
                          "$index",
                          fecha,
                          balotasStr,
                        ];
                      }).toList(),
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                      headerDecoration: const pw.BoxDecoration(color: PdfColors.amber800),
                      cellHeight: 28,
                      cellAlignments: {
                        0: pw.Alignment.centerLeft,
                        1: pw.Alignment.centerLeft,
                        2: pw.Alignment.center,
                      },
                    ),
                    pw.Spacer(),
                    pw.Divider(),
                    pw.Center(
                      child: pw.Text(
                        l10n?.muchosExitosJuego ?? "¡Muchos éxitos en tu juego! - Generado desde Eterlotto App",
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: l10n?.nombreArchivoPDF(widget.loteriaNombre) ?? "Tiquete_${widget.loteriaNombre}_Eterlotto.pdf",
        );
      },
    );
  }

  void _irAResultados() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadosDashboardScreen(
          loteriaNombreInicial: widget.loteriaNombre,
          loteriaRoute: widget.loteriaRoute,
          loteriaData: _config != null
              ? {
                  'nombre': _config!.nombre,
                  'route': _config!.route,
                  'max_seleccion': _config!.maxSeleccion,
                  'max_balotas_blancas': _config!.maxBalotasBlancas,
                  'max_balotas_rojas': _config!.maxBalotasRojas,
                  'tiene_complementario': _config!.tieneComplementario,
                  'tiene_reintegro': _config!.tieneReintegro,
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required dynamic icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isEnabled = true,
    double size = 48,
    String? tooltip,
  }) {
    Widget btn = InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isEnabled 
                ? [color.withValues(alpha: 0.3), Colors.black] 
                : [Colors.white10, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            if (isEnabled) ...[
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(-2, -2),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 10,
                offset: const Offset(4, 4),
                spreadRadius: 1,
              ),
            ] else 
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 5,
                offset: const Offset(2, 2),
              ),
          ],
          border: Border.all(
            color: isEnabled ? color.withValues(alpha: 0.4) : Colors.white10,
            width: 1.5,
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

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        child: btn,
      );
    }
    return btn;
  }

  String _formatFecha(dynamic rawDate) {
    if (rawDate == null) return "";
    final str = rawDate.toString().trim();
    if (str.isEmpty) return "";
    try {
      if (str.length >= 10 && str[4] == '-' && str[7] == '-') {
        return str.substring(0, 10);
      }
      if (str.length >= 10 && str[2] == '/' && str[5] == '/') {
        final parts = str.substring(0, 10).split('/');
        if (parts.length == 3) {
          return "${parts[2]}-${parts[1]}-${parts[0]}";
        }
      }
      final parsed = DateTime.parse(str).toLocal();
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {
      return str.replaceAll('/', '-');
    }
  }

  Widget _build3DBall(int? numero, {Color baseColor = const Color(0xFFF33A21), double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            baseColor.withValues(alpha: 0.95),
            baseColor.withValues(alpha: 0.75),
            baseColor.withValues(alpha: 0.5),
          ],
          center: Alignment.topLeft,
          radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(3, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: 0.3),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "–",
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: numero != null ? Colors.white : Colors.white54,
            shadows: numero != null
                ? [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bool hasSelection = _selectedIds.isNotEmpty;

    final String emptySubtext = l10n?.generaGuardaJugadas(widget.loteriaNombre) ?? "Genera y guarda tus jugadas desde la pantalla de ${widget.loteriaNombre}";

    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              RefreshIndicator(
                color: AppColors.yellow,
                backgroundColor: const Color(0xFF1E1E1E),
                displacement: 25.0,
                onRefresh: () => _cargarJugadas(force: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
            CustomSliverAppBar(title: l10n?.misJugadasConLoteria(widget.loteriaNombre) ?? "${l10n?.misJugadas ?? 'Mis Jugadas'} - ${widget.loteriaNombre}"),
            SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppContainer3(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                          icon: hasSelection ? Icons.deselect : Icons.check_circle_outline,
                          color: AppColors.yellow,
                          onPressed: _toggleSelectAll,
                          tooltip: hasSelection ? "Deseleccionar" : "Seleccionar todo",
                        ),
                        _buildActionButton(
                          icon: FontAwesomeIcons.whatsapp,
                          color: const Color(0xFF25D366),
                          onPressed: _compartirWhatsApp,
                          isEnabled: hasSelection,
                          tooltip: "Compartir WhatsApp",
                        ),
                        _buildActionButton(
                          icon: Icons.picture_as_pdf,
                          color: Colors.purpleAccent,
                          onPressed: _imprimirPDF,
                          tooltip: "Exportar PDF",
                        ),
                        _buildActionButton(
                          icon: Icons.analytics_outlined,
                          color: const Color(0xFF00E5FF),
                          onPressed: _irAResultados,
                          tooltip: l10n?.resultados ?? "Resultados",
                        ),
                        _buildActionButton(
                          icon: Icons.delete_outline,
                          color: Colors.redAccent,
                          onPressed: hasSelection ? _eliminarSeleccionadas : null,
                          isEnabled: hasSelection,
                          tooltip: "Eliminar seleccionadas",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          l10n?.historialJugadas ?? "Historial de Jugadas",
                          style: AppTextStyles.h2.copyWith(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${_jugadasList.length} ${l10n?.guardadasCantidad ?? 'guardada(s)'}",
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.yellow,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _cargando
                      ? _buildSkeletonJugadas()
                      : _jugadasList.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Column(
                                  children: [
                                    Text(
                                      l10n?.noTienesJugadasGuardadas ?? "No tienes jugadas guardadas aún",
                                      style: AppTextStyles.h2.copyWith(fontSize: 16),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      emptySubtext,
                                      style: AppTextStyles.caption,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Container(
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
                                            l10n?.balotas ?? "Balotas",
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

                                  // Filas de jugadas
                                  ...List.generate(_jugadasList.length, (index) {
                                    final item = _jugadasList[index];
                                    final id = item["id"] as int? ?? 0;
                                    final isSelected = _selectedIds.contains(id);
                                    final fechaStr = _formatFecha(item["fecha_sorteo"] ?? item["fecha_guardado"] ?? item["created_at"] ?? item["fecha"]);
                                    final (whites, red) = _parsearJugada(item);

                                    final int totalBalls = whites.length + (red != null ? 1 : 0);
                                    final double ballSize = totalBalls <= 5
                                        ? 32.0
                                        : (totalBalls == 6 ? 30.0 : (totalBalls == 7 ? 27.0 : 24.0));
                                    final double hPadding = totalBalls <= 5
                                        ? 2.5
                                        : (totalBalls == 6 ? 2.0 : (totalBalls == 7 ? 1.5 : 1.0));

                                    final Color color = [
                                      const Color(0xFF1E3A8A), // Blue
                                      const Color(0xFF4C1D95), // Purple
                                      const Color(0xFF0F766E), // Teal
                                      const Color(0xFF9A3412), // Rust / Orange
                                      const Color(0xFF065F46), // Emerald
                                      const Color(0xFF831843), // Pink
                                      const Color(0xFF312E81), // Indigo
                                      const Color(0xFF155E75), // Cyan
                                      const Color(0xFF7C2D12), // Deep Orange
                                      const Color(0xFF78350F), // Amber
                                    ][index % 10];

                                    return Container(
                                      key: Key(id.toString()),
                                      margin: const EdgeInsets.symmetric(vertical: 2.0),
                                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.yellow.withValues(alpha: 0.12)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: isSelected
                                            ? Border.all(color: AppColors.yellow.withValues(alpha: 0.4), width: 1)
                                            : Border(
                                                bottom: BorderSide(
                                                  color: index == _jugadasList.length - 1
                                                      ? Colors.transparent
                                                      : Colors.white10,
                                                  width: 0.6,
                                                ),
                                              ),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedIds.remove(id);
                                            } else {
                                              _selectedIds.add(id);
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Row(
                                          children: [
                                            // 1. Número (#)
                                            SizedBox(
                                              width: 28,
                                              child: Center(
                                                child: Text(
                                                  "${index + 1}",
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 11,
                                                    color: isSelected ? AppColors.yellow : Colors.white70,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),

                                            // 2. Fecha
                                            SizedBox(
                                              width: 82,
                                              child: Text(
                                                fechaStr,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  color: isSelected ? Colors.white : Colors.white70,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),

                                            // 3. Balotas
                                            Expanded(
                                              child: Center(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.center,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      ...whites.map((n) => Padding(
                                                            padding: EdgeInsets.symmetric(horizontal: hPadding),
                                                            child: _build3DBall(
                                                              n,
                                                              baseColor: color,
                                                              size: ballSize,
                                                            ),
                                                          )),
                                                      if (red != null) ...[
                                                        SizedBox(width: hPadding * 1.5),
                                                        Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: hPadding),
                                                          child: _build3DBall(
                                                            red,
                                                            baseColor: const Color(0xFFB91C1C),
                                                            size: ballSize,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
      if (_selectedIds.length == 1)
        _buildDraggableCompareFab(context, constraints),
    ],
  );
},
),
);
}

  void _abrirModalComparar() {
    if (_selectedIds.length != 1) return;
    final id = _selectedIds.first;
    final index = _jugadasList.indexWhere((j) => (j["id"] as int? ?? 0) == id);
    if (index == -1) return;
    final item = _jugadasList[index];
    final (whites, red) = _parsearJugada(item);
    final jugadaIndex = index + 1;
    final fechaStr = _formatFecha(item["fecha_sorteo"] ?? item["fecha_guardado"] ?? item["created_at"] ?? item["fecha"]);

    final Color rowColor = [
      const Color(0xFF1E3A8A), // Azul
      const Color(0xFF4C1D95), // Morado
      const Color(0xFF0F766E), // Turquesa
      const Color(0xFF9A3412), // Naranja Óxido
      const Color(0xFF065F46), // Esmeralda
      const Color(0xFF831843), // Rosa
      const Color(0xFF312E81), // Índigo
      const Color(0xFF155E75), // Cian
      const Color(0xFF7C2D12), // Naranja Oscuro
      const Color(0xFF78350F), // Ámbar
    ][index % 10];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.yellow, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.yellow.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 14,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Indicador superior
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // Icono con glow
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.yellow.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.yellow, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.yellow.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.query_stats_rounded, color: AppColors.yellow, size: 28),
                ),
                const SizedBox(height: 14),
                // Pregunta clara al usuario
                Text(
                  "¿Quieres comparar con Estadísticas?",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  "Selecciona la jugada que deseas llevar a la pantalla de estadísticas para analizar su coincidencia con los sorteos pasados.",
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                // Card de la jugada
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.yellow.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Jugada #$jugadaIndex",
                            style: GoogleFonts.montserrat(
                              color: AppColors.yellow,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            fechaStr,
                            style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...whites.map((n) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: _build3DBall(
                                    n,
                                    baseColor: rowColor,
                                    size: 38,
                                  ),
                                )),
                            if (red != null) ...[
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: _build3DBall(
                                  red,
                                  baseColor: const Color(0xFFB91C1C),
                                  size: 38,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Botones Cancelar y Confirmar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "Cancelar",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.yellow,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.query_stats_rounded, size: 20, color: Colors.black),
                        label: const Text(
                          "Sí, Comparar",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: Colors.black,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          final isPremium = context.read<SubscriptionProvider>().isSubscribed;

                          await AdService.instance.showRewardedFeatureGate(
                            context: context,
                            isPremium: isPremium,
                            featureTitle: "Comparar con Estadísticas",
                            featureActionDescription: "Mira un breve video publicitario para acceder y comparar tu jugada con las estadísticas.",
                            onRewardGranted: () async {
                              final Map<String, dynamic> jugadaComparacionData = {
                                "id": id,
                                "index": jugadaIndex,
                                "titulo": "Jugada #$jugadaIndex",
                                "color": rowColor.toARGB32(),
                                "numeros": whites,
                                "balota_roja": red,
                                "fecha": fechaStr,
                              };
                              final bool? editada = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EstadisticasDashboardScreen(
                                    loteriaNombreInicial: widget.loteriaNombre,
                                    loteriaRoute: widget.loteriaRoute,
                                    jugadaComparacion: jugadaComparacionData,
                                    loteriaData: _config != null
                                        ? {
                                            'nombre': _config!.nombre,
                                            'route': _config!.route,
                                            'max_seleccion': _config!.maxSeleccion,
                                            'max_balotas_blancas': _config!.maxBalotasBlancas,
                                            'max_balotas_rojas': _config!.maxBalotasRojas,
                                            'tiene_complementario': _config!.tieneComplementario,
                                            'tiene_reintegro': _config!.tieneReintegro,
                                          }
                                        : null,
                                  ),
                                ),
                              );
                              if (editada == true && mounted) {
                                _cargarJugadas();
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraggableCompareFab(BuildContext context, BoxConstraints constraints) {
    const double fabSize = 58.0;

    final double maxW = constraints.maxWidth > 0 ? constraints.maxWidth : MediaQuery.of(context).size.width;
    final double maxH = constraints.maxHeight > 0 ? constraints.maxHeight : MediaQuery.of(context).size.height;

    final defaultX = (maxW - fabSize - 16.0).clamp(10.0, maxW);
    final defaultY = (maxH - fabSize - 30.0).clamp(10.0, maxH);

    return ValueListenableBuilder<Offset?>(
      valueListenable: _fabPositionNotifier,
      builder: (context, pos, child) {
        final currentX = (pos?.dx ?? defaultX).clamp(10.0, (maxW - fabSize - 10.0).clamp(10.0, double.infinity));
        final currentY = (pos?.dy ?? defaultY).clamp(10.0, (maxH - fabSize - 10.0).clamp(10.0, double.infinity));

        return Positioned(
          left: currentX,
          top: currentY,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              final cur = _fabPositionNotifier.value ?? Offset(defaultX, defaultY);
              double newX = cur.dx + details.delta.dx;
              double newY = cur.dy + details.delta.dy;

              newX = newX.clamp(10.0, (maxW - fabSize - 10.0).clamp(10.0, double.infinity));
              newY = newY.clamp(10.0, (maxH - fabSize - 10.0).clamp(10.0, double.infinity));

              _fabPositionNotifier.value = Offset(newX, newY);
            },
            onTap: _abrirModalComparar,
            child: Container(
              width: fabSize,
              height: fabSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.yellow,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.yellow.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.query_stats_rounded,
                  size: 30,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonJugadas() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2C2C2C),
      period: const Duration(milliseconds: 1400),
      child: Column(
        children: List.generate(
          4,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 100,
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
