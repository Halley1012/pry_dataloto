import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dataloto/services/api_service.dart';
import '../../services/cache_service.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/widgets/contenedor3.dart';
import 'package:dataloto/widgets/custom_app_bar.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';
import '../loteria_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _cargarConfig();
    _cargarJugadas();
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
    if (_jugadasList.isEmpty || force) setState(() => _cargando = true);

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

    final deletedIds = _selectedIds.toSet();

    // 1. Eliminación optimista inmediata en UI
    setState(() {
      _jugadasList.removeWhere((j) => deletedIds.contains(j["id"]));
      _selectedIds.clear();
      _cargando = true;
    });

    // 2. Sincronizar cache de inmediato con la lista restante
    final uIdStr = _userId ?? "anon";
    await CacheService.setJson('user_jugadas_${widget.loteriaRoute}_$uIdStr', _jugadasList);
    await CacheService.setJson('mis_jugadas_${widget.loteriaRoute}', _jugadasList);

    // 3. Ejecutar eliminación en el backend
    for (final id in deletedIds) {
      try {
        await ApiService.borrarJugadaGenerica(widget.loteriaRoute, id, _userId!);
      } catch (e) {
        debugPrint("Error al eliminar jugada $id: $e");
      }
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

    final StringBuffer buffer = StringBuffer();
    buffer.writeln("🎰 *${l10n?.misJugadasLoteria(widget.loteriaNombre) ?? "Mis Jugadas de ${widget.loteriaNombre} - DataLoto"}* 🎰\n");

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

  Widget _buildActionButton({
    required dynamic icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isEnabled 
                ? [color.withOpacity(0.3), Colors.black] 
                : [Colors.white10, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            if (isEnabled) ...[
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(-2, -2),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 10,
                offset: const Offset(4, 4),
                spreadRadius: 1,
              ),
            ] else 
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 5,
                offset: const Offset(2, 2),
              ),
          ],
          border: Border.all(
            color: isEnabled ? color.withOpacity(0.4) : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Center(
          child: icon is IconData
              ? Icon(
                  icon,
                  color: isEnabled ? color : Colors.white24,
                  size: 22,
                )
              : FaIcon(
                  icon,
                  color: isEnabled ? color : Colors.white24,
                  size: 22,
                ),
        ),
      ),
    );
  }

  String _formatFecha(dynamic rawDate) {
    if (rawDate == null) return "";
    final str = rawDate.toString().trim();
    if (str.isEmpty) return "";
    try {
      if (str.length >= 10 && str[4] == '-' && str[7] == '-') {
        final parts = str.substring(0, 10).split('-');
        if (parts.length == 3) {
          return "${parts[2]}/${parts[1]}/${parts[0]}";
        }
      }
      final parsed = DateTime.parse(str).toLocal();
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return str;
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
        onRefresh: () => _cargarJugadas(force: true),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                          icon: hasSelection ? Icons.deselect : Icons.check_circle_outline,
                          color: AppColors.yellow,
                          onPressed: _toggleSelectAll,
                        ),
                        _buildActionButton(
                          icon: FontAwesomeIcons.whatsapp,
                          color: const Color(0xFF25D366),
                          onPressed: _compartirWhatsApp,
                          isEnabled: hasSelection,
                        ),
                        _buildActionButton(
                          icon: Icons.picture_as_pdf,
                          color: Colors.purpleAccent,
                          onPressed: _imprimirPDF,
                        ),
                        _buildActionButton(
                          icon: Icons.delete_outline,
                          color: Colors.redAccent,
                          onPressed: hasSelection ? _eliminarSeleccionadas : null,
                          isEnabled: hasSelection,
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
                                final fechaStr = _formatFecha(item["fecha_sorteo"] ?? item["fecha_guardado"] ?? item["created_at"] ?? item["fecha"]);
                                final (whites, red) = _parsearJugada(item);

                                final int totalBalls = whites.length + (red != null ? 1 : 0);
                                final double ballSize = totalBalls <= 5
                                    ? 33.0
                                    : (totalBalls == 6 ? 29.0 : (totalBalls == 7 ? 25.5 : 22.5));
                                final double hPadding = totalBalls <= 5
                                    ? 2.5
                                    : (totalBalls == 6 ? 2.0 : (totalBalls == 7 ? 1.5 : 1.2));

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
                                      const SizedBox(width: 4), 

                                      // 2. Solo el Número (Sin la palabra "Nro.")
                                      Text(
                                        "${index + 1}",
                                        style: AppTextStyles.mensajeSecundario.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // 3. Balotas dinámicas y adaptativas
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.center,
                                          child: Row(
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
                                              if (red != null)
                                                Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: hPadding),
                                                  child: _build3DBall(
                                                    red,
                                                    baseColor: Colors.redAccent,
                                                    size: ballSize,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // 4. Fecha (dd/MM/yyyy con tamaño reducido)
                                      if (fechaStr.isNotEmpty)
                                        Text(
                                          fechaStr,
                                          style: AppTextStyles.caption.copyWith(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      const SizedBox(width: 4)
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
