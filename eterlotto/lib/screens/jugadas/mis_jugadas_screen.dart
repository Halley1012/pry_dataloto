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
  final bool soloProximos;

  const MisJugadasScreen({
    super.key,
    required this.loteriaNombre,
    required this.loteriaRoute,
    this.soloProximos = true,
  });

  @override
  State<MisJugadasScreen> createState() => _MisJugadasScreenState();
}

class _ToolbarActionSpec {
  final String id;
  final dynamic icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final String tooltip;

  const _ToolbarActionSpec({
    required this.id,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.isEnabled,
    required this.tooltip,
  });
}


class _MisJugadasScreenState extends State<MisJugadasScreen> {
  List<Map<String, dynamic>> _jugadasList = [];
  Set<int> _selectedIds = {};
  bool _cargando = true;
  bool _loadFailed = false;
  String? _userId;
  LoteriaConfig? _config;
  late bool _soloProximos = widget.soloProximos;
  final ValueNotifier<Offset?> _compareFabPositionNotifier =
      ValueNotifier<Offset?>(null);
  final ValueNotifier<Offset?> _drawResultsFabPositionNotifier =
      ValueNotifier<Offset?>(null);
  final GlobalKey _screenStackKey = GlobalKey();
  final Map<String, ValueNotifier<Offset?>> _toolbarActionPositions = {
    'select': ValueNotifier<Offset?>(null),
    'whatsapp': ValueNotifier<Offset?>(null),
    'pdf': ValueNotifier<Offset?>(null),
    'results': ValueNotifier<Offset?>(null),
    'delete': ValueNotifier<Offset?>(null),
  };
  String? _activeToolbarActionId;
  int? _activeToolbarPointer;
  Offset? _activeToolbarPointerStart;
  bool _isToolbarActionHeld = false;
  DateTime? _lastScreenTapAt;
  Offset? _lastScreenTapPosition;

  List<Map<String, dynamic>> get _jugadasFiltradas {
    return _jugadasList.where((item) {
      final fecha =
          item["fecha_sorteo"] ??
          item["fecha_guardado"] ??
          item["created_at"] ??
          item["fecha"];
      final diff = _getDiffDays(fecha?.toString());
      if (_soloProximos) {
        return diff >= 0;
      } else {
        return diff < 0;
      }
    }).toList();
  }

  int _getDiffDays(String? fecha) {
    if (fecha == null || fecha.isEmpty) return 0;
    try {
      final clean = fecha.trim();
      final parsed =
          DateTime.tryParse(clean) ??
          (clean.length >= 10
              ? DateTime.tryParse(clean.substring(0, 10))
              : null);
      if (parsed == null) return 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(parsed.year, parsed.month, parsed.day);
      return target.difference(today).inDays;
    } catch (_) {
      return 0;
    }
  }

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
    _compareFabPositionNotifier.dispose();
    _drawResultsFabPositionNotifier.dispose();
    for (final position in _toolbarActionPositions.values) {
      position.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarConfig() async {
    bool aplicarConfig(dynamic rawLoterias) {
      if (rawLoterias is! List) return false;
      final match = rawLoterias.cast<dynamic>().firstWhere((item) {
        if (item is! Map) return false;
        return (item['route']?.toString().toLowerCase() ==
                widget.loteriaRoute.toLowerCase()) ||
            (item['nombre']?.toString().toLowerCase() ==
                widget.loteriaNombre.toLowerCase());
      }, orElse: () => null);
      if (match is! Map || match.isEmpty || !mounted) return false;
      setState(() {
        _config = LoteriaConfig.fromJson(
          Map<String, dynamic>.from(match),
          fallbackNombre: widget.loteriaNombre,
        );
      });
      return true;
    }

    try {
      // La configuración es pública y suele existir desde Home/selector. Leerla
      // primero evita que la última especial cambie de aspecto al terminar la red.
      final cachedSources = await Future.wait([
        CacheService.getJson(CacheService.catalogoLoteriasKey),
        CacheService.getJson('home_loterias_globales'),
      ]);
      for (final source in cachedSources) {
        if (aplicarConfig(source)) break;
      }

      final loteriasData = await ApiService.getAllLoterias();
      aplicarConfig(loteriasData);
    } catch (_) {}
  }

  Future<void> _cargarJugadas({bool force = false}) async {
    final uId = await ApiService.getUserId();
    final uIdStr = uId?.toString();
    final cacheKeyUser = CacheService.jugadasUsuarioKey(
      widget.loteriaRoute,
      uIdStr,
    );

    // La lista es privada, pero puede mostrarse aunque venza mientras el
    // backend valida su versión. La clave incluye usuario y lotería.
    final cached = await CacheService.getStaleJson(cacheKeyUser);
    if (cached != null && mounted) {
      setState(() {
        _userId = uIdStr;
        _jugadasList = List<Map<String, dynamic>>.from(cached);
        _cargando = false;
      });
    }

    if (!mounted) return;
    if (_jugadasList.isEmpty) {
      setState(() {
        _cargando = true;
        _loadFailed = false;
      });
    }

    try {
      final response = await ApiService.listarJugadasGenerica(
        widget.loteriaRoute,
      );
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
        response,
      );

      // La cuenta pudo cambiar mientras la petición estaba en vuelo. Nunca
      // aplicamos su respuesta sobre la caché ni la UI de la nueva sesión.
      final currentUserId = (await ApiService.getUserId())?.toString();
      if (currentUserId != uIdStr) return;

      if (mounted) {
        setState(() {
          _userId = uIdStr;
          _jugadasList = data;
          _selectedIds.clear();
          _cargando = false;
          _loadFailed = false;
        });
        await CacheService.setJson(cacheKeyUser, data);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _loadFailed = _jugadasList.isEmpty;
        });
      }
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _jugadasFiltradas.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _jugadasFiltradas
            .map((j) => j["id"] as int? ?? 0)
            .where((id) => id > 0)
            .toSet();
      }
    });
  }

  Future<void> _eliminarSeleccionadas() async {
    if (_selectedIds.isEmpty) return;

    final l10n = AppLocalizations.of(context);

    final String confirmMsg =
        l10n?.confirmarEliminarVarios(_selectedIds.length) ??
        "¿Seguro que deseas eliminar ${_selectedIds.length} jugada(s)?";

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
              style: AppTextStyles.h2.copyWith(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          confirmMsg,
          style: AppTextStyles.mensajeSecundario.copyWith(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n?.cancelar ?? "Cancelar",
              style: const TextStyle(color: Colors.amber),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n?.eliminar ?? "Eliminar",
              style: const TextStyle(color: Colors.redAccent),
            ),
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
    await CacheService.setJson(
      CacheService.jugadasUsuarioKey(widget.loteriaRoute, uIdStr),
      _jugadasList,
    );

    // 3. Ejecutar eliminación en el backend (en paralelo)
    final results = await Future.wait(
      deletedIds.map(
        (id) =>
            ApiService.borrarJugadaGenerica(widget.loteriaRoute, id, _userId!),
      ),
    );

    // Una baja múltiple puede tener éxito parcial. Conservamos exactamente el
    // estado que confirmó el backend, en vez de restaurar registros que sí se
    // eliminaron en otra petición paralela.
    if (results.any((ok) => !ok)) {
      final successfulIds = <int>{};
      for (var index = 0; index < results.length; index++) {
        if (results[index]) successfulIds.add(deletedIds.elementAt(index));
      }
      final confirmedList = backupList
          .where((j) => !successfulIds.contains(j['id']))
          .toList();
      if (mounted) {
        setState(() {
          _jugadasList = confirmedList;
        });
        await CacheService.setJson(
          CacheService.jugadasUsuarioKey(widget.loteriaRoute, uIdStr),
          confirmedList,
        );
        await CacheService.invalidarCachesDeJugadas(
          specificRoute: widget.loteriaRoute,
          userId: uIdStr,
          preserveRouteJugadas: true,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No se pudieron eliminar algunas jugadas. Se conservaron las que siguen vigentes.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // 4. Confirmar estado desde el servidor
    await _cargarJugadas(force: true);
  }

  (List<int>, List<int>) _parsearJugada(Map<String, dynamic> item) {
    final rawNums = (item["numeros"] as List<dynamic>? ?? []);
    final nums = rawNums
        .map((n) => int.tryParse(n.toString()) ?? -1)
        .where((n) => n >= 0)
        .toList();

    // La configuración define los roles. Nunca separamos por igualdad de valor:
    // [1, 4, 8, 9, 20, 9] conserva ambos 9 en posiciones diferentes.
    final config = _config;
    if (config != null) {
      final groups = config.numberLayout.split(nums);
      final principales = groups.main;
      final especiales = List<int>.from(groups.specials);

      // Compatibilidad con jugadas antiguas que guardaban la especial fuera
      // del arreglo de números.
      final legacyEspecial =
          item["balota_roja"] ?? item["balotaroja"] ?? item["superbalota"];
      if (especiales.isEmpty &&
          legacyEspecial != null &&
          config.cantidadEspeciales > 0) {
        final valor = int.tryParse(legacyEspecial.toString());
        if (valor != null) especiales.add(valor);
      }
      return (principales, especiales);
    }

    // Fallback temporal únicamente cuando aún no llega la configuración.
    final legacyEspecial =
        item["balota_roja"] ?? item["balotaroja"] ?? item["superbalota"];
    final valor = legacyEspecial == null
        ? null
        : int.tryParse(legacyEspecial.toString());
    if (valor != null && nums.length > 5) {
      return (nums.take(nums.length - 1).toList(), [nums.last]);
    }
    return (nums, valor == null ? [] : [valor]);
  }

  void _compartirWhatsApp() async {
    final l10n = AppLocalizations.of(context);
    final jugadasACompartir = _jugadasList
        .where((j) => _selectedIds.isEmpty || _selectedIds.contains(j["id"]))
        .toList();

    if (jugadasACompartir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.noHayJugadasCompartir ?? "No hay jugadas para compartir",
          ),
        ),
      );
      return;
    }

    final isPremium = context.read<SubscriptionProvider>().isSubscribed;

    await AdService.instance.showRewardedFeatureGate(
      context: context,
      isPremium: isPremium,
      featureTitle: "Compartir por WhatsApp",
      featureActionDescription:
          "Mira un breve video publicitario para generar y compartir tu tiquete de jugadas por WhatsApp gratis.",
      onRewardGranted: () async {
        final StringBuffer buffer = StringBuffer();
        buffer.writeln(
          "🎰 *${l10n?.misJugadasLoteria(widget.loteriaNombre) ?? "Mis Jugadas de ${widget.loteriaNombre} - Eterlotto"}* 🎰\n",
        );

        for (int i = 0; i < jugadasACompartir.length; i++) {
          final play = jugadasACompartir[i];
          final (whites, specials) = _parsearJugada(play);
          final String jugadaLabel =
              l10n?.jugadaShare(i + 1) ?? "Jugada #${i + 1}";
          if (specials.isNotEmpty) {
            final String superbalota =
                "${_config?.superbalotaNombre ?? 'Especial'}: ${specials.join(', ')}";
            buffer.writeln(
              "📌 *$jugadaLabel*: ${whites.join(', ')} | 🔴 *$superbalota*",
            );
          } else {
            buffer.writeln("📌 *$jugadaLabel*: ${whites.join(', ')}");
          }
        }

        buffer.writeln(
          "\n🍀 _${l10n?.buenaSuerteDataLoto ?? "¡Buena suerte con Eterlotto!"}_",
        );

        final text = buffer.toString();
        final whatsappUrl = Uri.parse(
          "https://wa.me/?text=${Uri.encodeComponent(text)}",
        );

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
        SnackBar(
          content: Text(
            l10n?.noHayJugadasSeleccionadasImprimir ??
                "No hay jugadas seleccionadas para imprimir",
          ),
        ),
      );
      return;
    }

    final isPremium = context.read<SubscriptionProvider>().isSubscribed;

    await AdService.instance.showRewardedFeatureGate(
      context: context,
      isPremium: isPremium,
      featureTitle: "Exportar Tiquete en PDF",
      featureActionDescription:
          "Mira un breve video publicitario para generar y descargar tu tiquete de jugadas en PDF gratis.",
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
                            l10n?.tiqueteDataloto(
                                  widget.loteriaNombre.toUpperCase(),
                                ) ??
                                "ETERLOTTO - TICKET ${widget.loteriaNombre.toUpperCase()}",
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amber900,
                            ),
                          ),
                          pw.Text(
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(DateTime.now()),
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      l10n?.reporteJugadasGuardadas(jugadasAImprimir.length) ??
                          "Reporte de Jugadas Guardadas (${jugadasAImprimir.length} jugada(s))",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.TableHelper.fromTextArray(
                      headers: [
                        l10n?.nro ?? "#",
                        l10n?.fechaGuardado ?? "Fecha Guardado",
                        l10n?.balotasLoteria(widget.loteriaNombre) ??
                            "Balotas ${widget.loteriaNombre}",
                      ],
                      data: jugadasAImprimir.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final item = entry.value;
                        final (whites, specials) = _parsearJugada(item);
                        final fecha = _formatFecha(
                          item["fecha_sorteo"] ??
                              item["fecha_guardado"] ??
                              item["created_at"] ??
                              item["fecha"],
                        );

                        final balotasStr = specials.isNotEmpty
                            ? "${whites.join(' - ')}  [${_config?.superbalotaNombre ?? 'Especial'}: ${specials.join(' - ')}]"
                            : whites.join(' - ');

                        return ["$index", fecha, balotasStr];
                      }).toList(),
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                      headerDecoration: const pw.BoxDecoration(
                        color: PdfColors.amber800,
                      ),
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
                        l10n?.muchosExitosJuego ??
                            "¡Muchos éxitos en tu juego! - Generado desde Eterlotto App",
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
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
          name:
              l10n?.nombreArchivoPDF(widget.loteriaNombre) ??
              "Tiquete_${widget.loteriaNombre}_Eterlotto.pdf",
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
    String? toolbarActionId,
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

    if (toolbarActionId != null) {
      // Listener recibe el movimiento antes de que el CustomScrollView pueda
      // convertirlo en desplazamiento vertical. Así cada acción se desprende
      // del panel con cualquier dirección de arrastre.
      btn = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) =>
            _startToolbarPointer(toolbarActionId, event),
        child: btn,
      );
    }

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  List<_ToolbarActionSpec> _toolbarActionSpecs(
    AppLocalizations? l10n,
    bool hasSelection,
  ) {
    return [
      _ToolbarActionSpec(
        id: 'select',
        icon: hasSelection ? Icons.deselect : Icons.check_circle_outline,
        color: AppColors.yellow,
        onPressed: _toggleSelectAll,
        isEnabled: true,
        tooltip: hasSelection ? 'Deseleccionar' : 'Seleccionar todo',
      ),
      _ToolbarActionSpec(
        id: 'whatsapp',
        icon: FontAwesomeIcons.whatsapp,
        color: const Color(0xFF25D366),
        onPressed: _compartirWhatsApp,
        isEnabled: hasSelection,
        tooltip: 'Compartir WhatsApp',
      ),
      _ToolbarActionSpec(
        id: 'pdf',
        icon: Icons.picture_as_pdf,
        color: Colors.purpleAccent,
        onPressed: _imprimirPDF,
        isEnabled: true,
        tooltip: 'Exportar PDF',
      ),
      _ToolbarActionSpec(
        id: 'results',
        icon: Icons.analytics_outlined,
        color: const Color(0xFF00E5FF),
        onPressed: _irAResultados,
        isEnabled: true,
        tooltip: l10n?.resultados ?? 'Resultados',
      ),
      _ToolbarActionSpec(
        id: 'delete',
        icon: Icons.delete_outline,
        color: Colors.redAccent,
        onPressed: hasSelection ? _eliminarSeleccionadas : null,
        isEnabled: hasSelection,
        tooltip: 'Eliminar seleccionadas',
      ),
    ];
  }

  Widget _buildToolbarActionPanel(AppLocalizations? l10n, bool hasSelection) {
    final actions = _toolbarActionSpecs(l10n, hasSelection);
    return AppContainer3(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map(_buildToolbarActionInPanel).toList(),
      ),
    );
  }

  Widget _buildToolbarActionInPanel(_ToolbarActionSpec spec) {
    final position = _toolbarActionPositions[spec.id]!;
    return ValueListenableBuilder<Offset?>(
      valueListenable: position,
      builder: (context, floatingPosition, _) {
        if (floatingPosition != null) {
          // Mantiene el espacio original para que el panel no cambie de forma
          // cuando un botón se convierta en flotante.
          return const SizedBox(width: 48, height: 48);
        }
        return _buildActionButton(
          icon: spec.icon,
          color: spec.color,
          onPressed: spec.onPressed,
          isEnabled: spec.isEnabled,
          tooltip: spec.tooltip,
          toolbarActionId: spec.id,
        );
      },
    );
  }

  List<Widget> _buildFloatingToolbarActions(
    BoxConstraints constraints,
    AppLocalizations? l10n,
    bool hasSelection,
  ) {
    return _toolbarActionSpecs(l10n, hasSelection)
        .map((spec) => _buildFloatingToolbarAction(spec, constraints))
        .toList();
  }

  Widget _buildFloatingToolbarAction(
    _ToolbarActionSpec spec,
    BoxConstraints constraints,
  ) {
    const size = 48.0;
    final position = _toolbarActionPositions[spec.id]!;
    return ValueListenableBuilder<Offset?>(
      valueListenable: position,
      builder: (context, floatingPosition, _) {
        if (floatingPosition == null) return const SizedBox.shrink();
        final bounded = _clampFloatingToolbarPosition(
          floatingPosition,
          size,
          constraints,
        );
        return Positioned(
          left: bounded.dx,
          top: bounded.dy,
          child: _buildActionButton(
            icon: spec.icon,
            color: spec.color,
            onPressed: spec.onPressed,
            isEnabled: spec.isEnabled,
            tooltip: spec.tooltip,
            toolbarActionId: spec.id,
          ),
        );
      },
    );
  }

  void _startToolbarPointer(String id, PointerDownEvent event) {
    _activeToolbarActionId = id;
    _activeToolbarPointer = event.pointer;
    _activeToolbarPointerStart = event.position;
    if (!_isToolbarActionHeld && mounted) {
      setState(() => _isToolbarActionHeld = true);
    }
  }

  void _onActiveToolbarPointerMove(PointerMoveEvent event) {
    const size = 48.0;
    final id = _activeToolbarActionId;
    final start = _activeToolbarPointerStart;
    if (id == null || start == null || event.pointer != _activeToolbarPointer) {
      return;
    }
    final rootBox = _screenStackKey.currentContext?.findRenderObject()
        as RenderBox?;
    if (rootBox == null || start == null) return;

    // Un toque normal no mueve el botón; se necesita un pequeño umbral para
    // iniciar el modo flotante y dejar intactos los taps de las acciones.
    if (_toolbarActionPositions[id]!.value == null &&
        (event.position - start).distance < 6) {
      return;
    }

    final local = rootBox.globalToLocal(event.position);
    _toolbarActionPositions[id]!.value = _clampFloatingToolbarPosition(
      local - Offset(size / 2, size / 2),
      size,
      BoxConstraints.tight(rootBox.size),
    );
  }

  void _finishActiveToolbarPointer(PointerEvent event) {
    if (event.pointer != _activeToolbarPointer) return;
    _activeToolbarActionId = null;
    _activeToolbarPointer = null;
    _activeToolbarPointerStart = null;
    if (_isToolbarActionHeld && mounted) {
      setState(() => _isToolbarActionHeld = false);
    }
  }

  void _handleScreenPointerUp(PointerUpEvent event) {
    final wasToolbarAction = event.pointer == _activeToolbarPointer;
    _finishActiveToolbarPointer(event);
    if (wasToolbarAction ||
        !_toolbarActionPositions.values.any((position) => position.value != null)) {
      return;
    }

    final now = DateTime.now();
    final previousTime = _lastScreenTapAt;
    final previousPosition = _lastScreenTapPosition;
    final isDoubleTap =
        previousTime != null &&
        previousPosition != null &&
        now.difference(previousTime) <= const Duration(milliseconds: 300) &&
        (event.position - previousPosition).distance <= 32;

    if (isDoubleTap) {
      _restoreToolbarActionsToPanel();
      _lastScreenTapAt = null;
      _lastScreenTapPosition = null;
      return;
    }

    _lastScreenTapAt = now;
    _lastScreenTapPosition = event.position;
  }

  void _restoreToolbarActionsToPanel() {
    var hasFloatingAction = false;
    for (final position in _toolbarActionPositions.values) {
      if (position.value != null) {
        hasFloatingAction = true;
        position.value = null;
      }
    }
    if (hasFloatingAction) {
      _activeToolbarActionId = null;
      _activeToolbarPointer = null;
      _activeToolbarPointerStart = null;
      if (_isToolbarActionHeld && mounted) {
        setState(() => _isToolbarActionHeld = false);
      }
    }
  }

  Offset _clampFloatingToolbarPosition(
    Offset position,
    double size,
    BoxConstraints constraints,
  ) {
    final maxWidth = constraints.maxWidth;
    final maxHeight = constraints.maxHeight;
    return Offset(
      position.dx.clamp(8.0, (maxWidth - size - 8.0).clamp(8.0, maxWidth)),
      position.dy.clamp(8.0, (maxHeight - size - 8.0).clamp(8.0, maxHeight)),
    );
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.2,
        ),
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

    final String emptySubtext =
        l10n?.generaGuardaJugadas(widget.loteriaNombre) ??
        "Genera y guarda tus jugadas desde la pantalla de ${widget.loteriaNombre}";

    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerMove: _onActiveToolbarPointerMove,
            onPointerUp: _handleScreenPointerUp,
            onPointerCancel: _finishActiveToolbarPointer,
            child: Stack(
              key: _screenStackKey,
              children: [
              RefreshIndicator(
                color: AppColors.yellow,
                backgroundColor: const Color(0xFF1E1E1E),
                displacement: 25.0,
                // Un botón arrastrado hacia abajo no debe iniciar a la vez
                // el gesto de actualización de la lista.
                notificationPredicate: (_) => !_isToolbarActionHeld,
                onRefresh: () => _isToolbarActionHeld
                    ? Future<void>.value()
                    : _cargarJugadas(force: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    CustomSliverAppBar(
                      title:
                          l10n?.misJugadasConLoteria(widget.loteriaNombre) ??
                          "${l10n?.misJugadas ?? 'Mis Jugadas'} - ${widget.loteriaNombre}",
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildToolbarActionPanel(l10n, hasSelection),
                            const SizedBox(height: 12),
                            _buildMisJugadasToggleButtons(l10n),
                            const SizedBox(height: 16),
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    _soloProximos
                                        ? (l10n?.proximoSorteo ??
                                              "Próximo sorteo")
                                        : (l10n?.historialJugadas ??
                                              "Historial de Jugadas"),
                                    style: AppTextStyles.h2.copyWith(
                                      fontSize: 18,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_jugadasFiltradas.length} ${l10n?.guardadasCantidad ?? 'guardada(s)'}",
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
                                : _jugadasFiltradas.isEmpty
                                ? _buildEmptyJugadasState(l10n, emptySubtext)
                                : Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white12,
                                        width: 0.8,
                                      ),
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
                                        const Divider(
                                          color: Colors.white12,
                                          height: 16,
                                        ),

                                        // Filas de jugadas
                                        ...List.generate(_jugadasFiltradas.length, (
                                          index,
                                        ) {
                                          final item = _jugadasFiltradas[index];
                                          final id = item["id"] as int? ?? 0;
                                          final isSelected = _selectedIds
                                              .contains(id);
                                          final fechaStr = _formatFecha(
                                            item["fecha_sorteo"] ??
                                                item["fecha_guardado"] ??
                                                item["created_at"] ??
                                                item["fecha"],
                                          );
                                          final (whites, specials) =
                                              _parsearJugada(item);

                                          final int totalBalls =
                                              whites.length + specials.length;
                                          final double ballSize =
                                              totalBalls <= 5
                                              ? 32.0
                                              : (totalBalls == 6
                                                    ? 30.0
                                                    : (totalBalls == 7
                                                          ? 27.0
                                                          : 24.0));
                                          final double hPadding =
                                              totalBalls <= 5
                                              ? 2.5
                                              : (totalBalls == 6
                                                    ? 2.0
                                                    : (totalBalls == 7
                                                          ? 1.5
                                                          : 1.0));

                                          final Color color = [
                                            const Color(0xFF1E3A8A), // Blue
                                            const Color(0xFF4C1D95), // Purple
                                            const Color(0xFF0F766E), // Teal
                                            const Color(
                                              0xFF9A3412,
                                            ), // Rust / Orange
                                            const Color(0xFF065F46), // Emerald
                                            const Color(0xFF831843), // Pink
                                            const Color(0xFF312E81), // Indigo
                                            const Color(0xFF155E75), // Cyan
                                            const Color(
                                              0xFF7C2D12,
                                            ), // Deep Orange
                                            const Color(0xFF78350F), // Amber
                                          ][index % 10];

                                          return Container(
                                            key: Key(id.toString()),
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 2.0,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6.0,
                                              horizontal: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.yellow.withValues(
                                                      alpha: 0.12,
                                                    )
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: isSelected
                                                  ? Border.all(
                                                      color: AppColors.yellow
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
                                                      width: 1,
                                                    )
                                                  : Border(
                                                      bottom: BorderSide(
                                                        color:
                                                            index ==
                                                                _jugadasList
                                                                        .length -
                                                                    1
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Row(
                                                children: [
                                                  // 1. Número (#)
                                                  SizedBox(
                                                    width: 28,
                                                    child: Center(
                                                      child: Text(
                                                        "${index + 1}",
                                                        style:
                                                            GoogleFonts.montserrat(
                                                              fontSize: 11,
                                                              color: isSelected
                                                                  ? AppColors
                                                                        .yellow
                                                                  : Colors
                                                                        .white70,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
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
                                                      textAlign:
                                                          TextAlign.center,
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontSize: 11,
                                                            color: isSelected
                                                                ? Colors.white
                                                                : Colors
                                                                      .white70,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),

                                                  // 3. Balotas
                                                  Expanded(
                                                    child: Center(
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        alignment:
                                                            Alignment.center,
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            for (final n
                                                                in whites)
                                                              Padding(
                                                                padding:
                                                                    EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          hPadding,
                                                                    ),
                                                                child: _build3DBall(
                                                                  n,
                                                                  baseColor:
                                                                      color,
                                                                  size:
                                                                      ballSize,
                                                                ),
                                                              ),
                                                            if (specials
                                                                .isNotEmpty) ...[
                                                              SizedBox(
                                                                width:
                                                                    hPadding *
                                                                    1.5,
                                                              ),
                                                              for (final special
                                                                  in specials)
                                                                Padding(
                                                                  padding: EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        hPadding,
                                                                  ),
                                                                  child: _build3DBall(
                                                                    special,
                                                                    baseColor:
                                                                        const Color(
                                                                          0xFFB91C1C,
                                                                        ),
                                                                    size:
                                                                        ballSize,
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
              if (_selectedIds.length == 1) ...[
                _buildDraggableCompareFab(context, constraints),
                if (_canOpenSelectedDrawResults)
                  _buildDraggableDrawResultsFab(context, constraints),
              ],
                ..._buildFloatingToolbarActions(
                  constraints,
                  l10n,
                  hasSelection,
                ),
              ],
            ),
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
    final (whites, specials) = _parsearJugada(item);
    final jugadaIndex = index + 1;
    final fechaStr = _formatFecha(
      item["fecha_sorteo"] ??
          item["fecha_guardado"] ??
          item["created_at"] ??
          item["fecha"],
    );

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
                  child: const Icon(
                    Icons.query_stats_rounded,
                    color: AppColors.yellow,
                    size: 28,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.yellow.withValues(alpha: 0.4),
                    ),
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
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...whites.map(
                              (n) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: _build3DBall(
                                  n,
                                  baseColor: rowColor,
                                  size: 38,
                                ),
                              ),
                            ),
                            if (specials.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              for (final special in specials)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: _build3DBall(
                                    special,
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        icon: const Icon(
                          Icons.query_stats_rounded,
                          size: 20,
                          color: Colors.black,
                        ),
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
                          final isPremium = context
                              .read<SubscriptionProvider>()
                              .isSubscribed;

                          await AdService.instance.showRewardedFeatureGate(
                            context: context,
                            isPremium: isPremium,
                            featureTitle: "Comparar con Estadísticas",
                            featureActionDescription:
                                "Mira un breve video publicitario para acceder y comparar tu jugada con las estadísticas.",
                            onRewardGranted: () async {
                              final Map<String, dynamic> jugadaComparacionData =
                                  {
                                    "id": id,
                                    "index": jugadaIndex,
                                    "titulo": "Jugada #$jugadaIndex",
                                    "color": rowColor.toARGB32(),
                                    "numeros": whites,
                                    "balota_roja": specials.isNotEmpty
                                        ? specials.first
                                        : null,
                                    "especiales": specials,
                                    "fecha": fechaStr,
                                  };
                              final bool? editada = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EstadisticasDashboardScreen(
                                    loteriaNombreInicial: widget.loteriaNombre,
                                    loteriaRoute: widget.loteriaRoute,
                                    jugadaComparacion: jugadaComparacionData,
                                    loteriaData: _config?.toJson(),
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

  Map<String, dynamic>? get _selectedJugada {
    if (_selectedIds.length != 1) return null;
    final id = _selectedIds.first;
    for (final jugada in _jugadasList) {
      if ((jugada['id'] as int? ?? 0) == id) return jugada;
    }
    return null;
  }

  String _fechaSorteoISO(Map<String, dynamic> jugada) {
    // `fecha_sorteo` es la fuente correcta. Los demás campos son respaldo
    // para jugadas antiguas que se hayan guardado antes de ese campo.
    return _formatFecha(
      jugada['fecha_sorteo'] ??
          jugada['fecha'] ??
          jugada['fecha_guardado'] ??
          jugada['created_at'],
    );
  }

  void _irAResultadosDeJugadaSeleccionada() {
    final jugada = _selectedJugada;
    if (jugada == null) return;

    final fechaSorteo = _fechaSorteoISO(jugada);
    if (fechaSorteo.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadosDashboardScreen(
          loteriaNombreInicial: widget.loteriaNombre,
          loteriaRoute: widget.loteriaRoute,
          loteriaData: _config?.toJson(),
          targetDrawDate: fechaSorteo,
        ),
      ),
    );
  }

  bool get _canOpenSelectedDrawResults {
    final selectedJugada = _selectedJugada;
    return !_soloProximos &&
        selectedJugada != null &&
        _fechaSorteoISO(selectedJugada).isNotEmpty;
  }

  Widget _buildDraggableCompareFab(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    return _buildIndependentSelectionFab(
      context: context,
      constraints: constraints,
      positionNotifier: _compareFabPositionNotifier,
      color: AppColors.yellow,
      icon: Icons.query_stats_rounded,
      tooltip: 'Comparar con estadísticas',
      bottomOffset: 30,
      onTap: _abrirModalComparar,
    );
  }

  Widget _buildDraggableDrawResultsFab(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    return _buildIndependentSelectionFab(
      context: context,
      constraints: constraints,
      positionNotifier: _drawResultsFabPositionNotifier,
      color: const Color(0xFF00E5FF),
      icon: Icons.analytics_outlined,
      tooltip: 'Ver resultados de este sorteo',
      bottomOffset: 98,
      onTap: _irAResultadosDeJugadaSeleccionada,
    );
  }

  Widget _buildIndependentSelectionFab({
    required BuildContext context,
    required BoxConstraints constraints,
    required ValueNotifier<Offset?> positionNotifier,
    required Color color,
    required IconData icon,
    required String tooltip,
    required double bottomOffset,
    required VoidCallback onTap,
  }) {
    const double fabSize = 58.0;

    final double maxW = constraints.maxWidth > 0
        ? constraints.maxWidth
        : MediaQuery.of(context).size.width;
    final double maxH = constraints.maxHeight > 0
        ? constraints.maxHeight
        : MediaQuery.of(context).size.height;

    final defaultX = (maxW - fabSize - 16.0).clamp(10.0, maxW);
    final defaultY = (maxH - fabSize - bottomOffset).clamp(10.0, maxH);

    return ValueListenableBuilder<Offset?>(
      valueListenable: positionNotifier,
      builder: (context, pos, child) {
        final currentX = (pos?.dx ?? defaultX).clamp(
          10.0,
          (maxW - fabSize - 10.0).clamp(10.0, double.infinity),
        );
        final currentY = (pos?.dy ?? defaultY).clamp(
          10.0,
          (maxH - fabSize - 10.0).clamp(10.0, double.infinity),
        );

        return Positioned(
          left: currentX,
          top: currentY,
          child: _buildDraggableFabAction(
            size: fabSize,
            color: color,
            icon: icon,
            tooltip: tooltip,
            positionNotifier: positionNotifier,
            defaultPosition: Offset(defaultX, defaultY),
            maxW: maxW,
            maxH: maxH,
            onTap: onTap,
          ),
        );
      },
    );
  }

  Widget _buildDraggableFabAction({
    required double size,
    required Color color,
    required IconData icon,
    required String tooltip,
    required ValueNotifier<Offset?> positionNotifier,
    required Offset defaultPosition,
    required double maxW,
    required double maxH,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final current = positionNotifier.value ?? defaultPosition;
          final newX = (current.dx + details.delta.dx).clamp(
            10.0,
            (maxW - size - 10.0).clamp(10.0, double.infinity),
          );
          final newY = (current.dy + details.delta.dy).clamp(
            10.0,
            (maxH - size - 10.0).clamp(10.0, double.infinity),
          );
          positionNotifier.value = Offset(newX, newY);
        },
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
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
          child: Center(child: Icon(icon, size: 30, color: Colors.black)),
        ),
      ),
    );
  }

  Widget _buildMisJugadasToggleButtons(AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _soloProximos = true;
                  _selectedIds.clear();
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _soloProximos
                      ? AppColors.yellow
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _soloProximos ? AppColors.yellow : Colors.white12,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 17,
                      color: _soloProximos ? Colors.black : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n?.proximoSorteo ?? "Próximos sorteos",
                      style: GoogleFonts.montserrat(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: _soloProximos ? Colors.black : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _soloProximos = false;
                  _selectedIds.clear();
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: !_soloProximos
                      ? AppColors.yellow
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !_soloProximos ? AppColors.yellow : Colors.white12,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 17,
                      color: !_soloProximos ? Colors.black : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n?.historialJugadas ?? "Historial de jugadas",
                      style: GoogleFonts.montserrat(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: !_soloProximos ? Colors.black : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyJugadasState(AppLocalizations? l10n, String emptySubtext) {
    final isConnectionIssue = _loadFailed && _jugadasList.isEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
        child: Column(
          children: [
            Icon(
              isConnectionIssue
                  ? Icons.cloud_off_outlined
                  : Icons.bookmark_border,
              color: isConnectionIssue ? Colors.redAccent : Colors.white38,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              isConnectionIssue
                  ? (l10n?.errorConexion ?? 'Error de conexión')
                  : (l10n?.noTienesJugadasGuardadas ??
                        'No tienes jugadas guardadas aún'),
              style: AppTextStyles.h2.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isConnectionIssue
                  ? (l10n?.datosLoteriaSinConexion ??
                        'No pudimos actualizar los datos. Revisa tu conexión e inténtalo de nuevo.')
                  : emptySubtext,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            if (isConnectionIssue) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _cargando ? null : () => _cargarJugadas(force: true),
                icon: const Icon(Icons.refresh),
                label: Text(l10n?.reintentar ?? 'Reintentar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.yellow,
                  side: const BorderSide(color: AppColors.yellow),
                ),
              ),
            ],
          ],
        ),
      ),
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
