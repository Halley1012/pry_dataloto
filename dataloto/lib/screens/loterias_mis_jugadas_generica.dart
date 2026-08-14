import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dataloto/services/api_service.dart';
import '../services/cache_service.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/widgets/contenedor3.dart';
import 'package:dataloto/widgets/custom_app_bar.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

class LoteriasMisJugadasGenericaScreen extends StatefulWidget {
  final String loteriaNombre;
  final String loteriaRoute;

  const LoteriasMisJugadasGenericaScreen({
    super.key,
    required this.loteriaNombre,
    required this.loteriaRoute,
  });

  @override
  State<LoteriasMisJugadasGenericaScreen> createState() => _LoteriasMisJugadasGenericaScreenState();
}

class _LoteriasMisJugadasGenericaScreenState extends State<LoteriasMisJugadasGenericaScreen> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _jugadasList = [];
  Set<int> _selectedIds = {};
  bool _cargando = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _cargarJugadas();
  }

  Future<void> _cargarJugadas() async {
    final uId = await _storage.read(key: 'user_id');
    final cached = await CacheService.getJson('user_jugadas_${widget.loteriaRoute}_${uId ?? "anon"}');
    if (cached != null && mounted) {
      setState(() {
        _userId = uId;
        _jugadasList = List<Map<String, dynamic>>.from(cached);
        _cargando = false;
      });
    }

    if (!mounted) return;
    if (_jugadasList.isEmpty) setState(() => _cargando = true);

    try {
      final response = await ApiService.listarJugadasGenerica(widget.loteriaRoute);
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _userId = uId;
          _jugadasList = data;
          _selectedIds.clear();
          _cargando = false;
        });
        CacheService.setJson('user_jugadas_${widget.loteriaRoute}_${uId ?? "anon"}', data);
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

    setState(() => _cargando = true);

    for (final id in _selectedIds.toList()) {
      try {
        await ApiService.borrarJugadaGenerica(widget.loteriaRoute, id, _userId!);
      } catch (e) {
        debugPrint("Error al eliminar jugada $id: $e");
      }
    }

    await _cargarJugadas();
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

    final StringBuffer buffer = StringBuffer();
    buffer.writeln("🎰 *${l10n?.misJugadasLoteria(widget.loteriaNombre) ?? "Mis Jugadas de ${widget.loteriaNombre} - DataLoto"}* 🎰\n");

    for (int i = 0; i < jugadasACompartir.length; i++) {
      final play = jugadasACompartir[i];
      final nums = (play["numeros"] as List<dynamic>?)?.cast<int>() ?? [];
      final bRoja = play["balota_roja"] ?? play["balotaroja"];
      final int? redVal = nums.length >= 6
          ? nums[5]
          : (bRoja != null ? int.tryParse(bRoja.toString()) : null);

      final whites = nums.length >= 5 ? nums.sublist(0, 5) : nums;
      final String jugadaLabel = l10n?.jugadaShare(i + 1) ?? "Jugada #${i + 1}";
      if (redVal != null) {
        final String superbalota = l10n?.superbalotaConValor(redVal) ?? "[Roja: $redVal]";
        buffer.writeln("📌 *$jugadaLabel*: ${whites.join(', ')} | 🔴 *$superbalota*");
      } else {
        buffer.writeln("📌 *$jugadaLabel*: ${nums.join(', ')}");
      }
    }

    buffer.writeln("\n🍀 _${l10n?.buenaSuerteDataLoto ?? "¡Buena suerte con DataLoto!"}_");

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
                        l10n?.tiqueteDataloto(widget.loteriaNombre.toUpperCase()) ?? "DATALOTO - TICKET ${widget.loteriaNombre.toUpperCase()}",
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
                    final nums = (item["numeros"] as List<dynamic>?)?.cast<int>() ?? [];
                    final whites = nums.length >= 5 ? nums.sublist(0, 5) : nums;
                    final bRoja = item["balota_roja"] ?? item["balotaroja"];
                    final red = nums.length >= 6 ? nums[5] : (bRoja != null ? int.tryParse(bRoja.toString()) : null);
                    final fecha = _formatFecha(item["fecha_guardado"] ?? item["created_at"] ?? item["fecha"]);

                    final balotasStr = red != null
                        ? "${whites.join(' - ')}  ${l10n?.superbalotaConValor(red) ?? '[Roja: $red]'}"
                        : nums.join(' - ');

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
                    l10n?.muchosExitosJuego ?? "¡Muchos éxitos en tu juego! - Generado desde DataLoto App",
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
      name: l10n?.nombreArchivoPDF(widget.loteriaNombre) ?? "Tiquete_${widget.loteriaNombre}_DataLoto.pdf",
    );
  }

  String _formatFecha(dynamic rawDate) {
    if (rawDate == null) return "";
    try {
      final parsed = DateTime.parse(rawDate.toString()).toLocal();
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return rawDate.toString();
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
      body: RefreshIndicator(
        color: AppColors.yellow,
        onRefresh: _cargarJugadas,
        child: CustomScrollView(
        slivers: [
          CustomSliverAppBar(title: l10n?.misJugadasConLoteria(widget.loteriaNombre) ?? "${l10n?.misJugadas ?? 'Mis Jugadas'} - ${widget.loteriaNombre}"),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppContainer3(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _toggleSelectAll,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                  backgroundColor: AppColors.yellow,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  hasSelection
                                      ? (l10n?.desmarcarTodo ?? "Desmarcar todo")
                                      : (l10n?.seleccionarTodo ?? "Seleccionar todo"),
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.button.copyWith(
                                    fontSize: 13,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: hasSelection ? _eliminarSeleccionadas : null,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                  backgroundColor: hasSelection
                                      ? Colors.redAccent.shade700
                                      : Colors.grey.shade800,
                                  disabledBackgroundColor: Colors.grey.shade800,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  hasSelection
                                      ? "${l10n?.eliminar ?? 'Eliminar'} (${_selectedIds.length})"
                                      : (l10n?.eliminar ?? "Eliminar"),
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.button.copyWith(
                                    fontSize: 13,
                                    color: hasSelection ? Colors.white : Colors.white38,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _compartirWhatsApp,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                  backgroundColor: hasSelection
                                      ? const Color(0xFF25D366)
                                      : AppColors.yellow,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  l10n?.whatsapp ?? "WhatsApp",
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.button.copyWith(
                                    fontSize: 13,
                                    color: hasSelection ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _imprimirPDF,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                  backgroundColor: AppColors.yellow,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  l10n?.imprimirPDF ?? "Imprimir PDF",
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.button.copyWith(
                                    fontSize: 13,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.yellow),
                        )
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
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _jugadasList.length,
                              itemBuilder: (context, index) {
                                final item = _jugadasList[index];
                                final id = item["id"] as int? ?? 0;
                                final isSelected = _selectedIds.contains(id);
                                final fechaStr = _formatFecha(item["fecha_guardado"] ?? item["created_at"] ?? item["fecha"]);
                                final nums = (item["numeros"] as List<dynamic>?)?.cast<int>() ?? [];
                                final whites = nums.length >= 5 ? nums.sublist(0, 5) : nums;
                                final bRoja = item["balota_roja"] ?? item["balotaroja"];
                                final red = nums.length >= 6 ? nums[5] : (bRoja != null ? int.tryParse(bRoja.toString()) : null);

                                final Color color = [
                                  Colors.blueAccent,
                                  Colors.purpleAccent,
                                  Colors.tealAccent,
                                  Colors.orangeAccent,
                                  Colors.greenAccent,
                                  Colors.pinkAccent,
                                  Colors.indigoAccent,
                                  Colors.cyanAccent,
                                  Colors.deepOrangeAccent,
                                  Colors.amberAccent,
                                ][index % 10];

                                return Container(
                                  key: Key(id.toString()),
                                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(
                                      colors: [
                                        color.withValues(alpha: 0.15),
                                        Colors.black.withValues(alpha: 0.1),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.2),
                                        blurRadius: 5,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.yellow
                                          : color.withValues(alpha: 0.3),
                                      width: isSelected ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // 1. Checkbox
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: Checkbox(
                                          value: isSelected,
                                          activeColor: AppColors.yellow,
                                          checkColor: Colors.black,
                                          materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedIds.add(id);
                                              } else {
                                                _selectedIds.remove(id);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),

                                      // 2. Solo el Número (Sin la palabra "Nro.")
                                      Text(
                                        "${index + 1}",
                                        style: AppTextStyles.mensajeSecundario.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // 3. Balotas compactas (5 Amarillas/Colores + 1 Roja)
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ...whites.map((n) => Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                              child: _build3DBall(
                                                n,
                                                baseColor: color,
                                                size: 35,
                                              ),
                                            )),
                                            if (red != null)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                                child: _build3DBall(
                                                  red,
                                                  baseColor: Colors.redAccent,
                                                  size: 35,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // 4. Fecha (dd/MM/yyyy con tamaño reducido)
                                      if (fechaStr.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              fechaStr,
                                              style: AppTextStyles.caption.copyWith(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(width: 6)
                                    ],
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}
