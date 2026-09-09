import 'package:flutter/material.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/widgets/lottery_avatar_3d.dart';
import 'package:eterlotto/utils/pais_helper.dart';
import 'package:eterlotto/screens/resultados_dashboard_screen.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';



import 'package:eterlotto/services/data_refresh_manager.dart';
import 'package:provider/provider.dart';
import 'package:eterlotto/providers/subscription_provider.dart';
import 'package:eterlotto/widgets/premium_crown_badge.dart';
import '../utils/secure_storage_helper.dart';

class ResultadosSelectorScreen extends StatefulWidget {
  const ResultadosSelectorScreen({super.key});

  @override
  State<ResultadosSelectorScreen> createState() => ResultadosSelectorScreenState();
}

class ResultadosSelectorScreenState extends State<ResultadosSelectorScreen> {
  List<Map<String, dynamic>> _loterias = [];
  List<Map<String, dynamic>> _filteredLoterias = [];
  List<Map<String, dynamic>> _paises = [];
  final _storage = AppSecureStorage.instance;
  String? _userCountry;
  bool _isLoading = true;
  String _selectedFilter = 'recientes';

  @override
  void initState() {
    super.initState();
    CacheService.jugadasChangeNotifier.addListener(_onJugadasChanged);
    DataRefreshManager.instance.refreshNotifier.addListener(_onDataRefreshNotification);
    cargarLoterias();
  }

  @override
  void dispose() {
    CacheService.jugadasChangeNotifier.removeListener(_onJugadasChanged);
    DataRefreshManager.instance.refreshNotifier.removeListener(_onDataRefreshNotification);
    super.dispose();
  }

  void _onJugadasChanged() {
    if (mounted) {
      cargarLoterias(forceRefresh: true);
    }
  }

  void _onDataRefreshNotification() {
    final module = DataRefreshManager.instance.refreshNotifier.value;
    if (module == RefreshModules.resultados || module == 'all') {
      if (mounted) {
        cargarLoterias(forceRefresh: false);
      }
    }
  }

  Future<void> cargarLoterias({bool forceRefresh = false}) async {
    if (!mounted) return;

    final uCountry = await _storage.read(key: 'pais_nombre') ?? "Internacional";
    // Los resultados son públicos. La preferencia de país sólo organiza la
    // lista, por lo que la caché puede ser compartida y no depende del usuario.
    const cacheKey = 'resultados_selector_v5';

    if (!forceRefresh) {
      // ⚡ 1. Cargar caché de despliegue instantáneo (0 ms)
      final cached = await CacheService.getJson(cacheKey);
      final cachedPaises = await CacheService.getJson('paises_list_cache');

      if (cached != null && (cached as List).isNotEmpty && mounted) {
        final cachedWithResults = List<Map<String, dynamic>>.from(cached)
            .where(_hasRecordedDraw)
            .toList();
        setState(() {
          _userCountry = uCountry;
          _loterias = cachedWithResults;
          _filteredLoterias = _filterBySelectedView(_loterias);
          if (cachedPaises != null && (cachedPaises as List).isNotEmpty) {
            _paises = List<Map<String, dynamic>>.from(cachedPaises);
          }
          _isLoading = false;
        });
      }
    }

    if (_loterias.isEmpty) setState(() => _isLoading = true);

    try {
      // Sólo una lotería con resultados oficiales entra en Recientes. No se
      // usa "activa", jugadas del usuario ni próximo sorteo como sustitutos.
      final todas = await _obtenerTodasLasLoterias(force: forceRefresh);
      final finalLoterias = todas.where(_hasRecordedDraw).toList()
        ..sort((a, b) => _lastDrawDate(b).compareTo(_lastDrawDate(a)));

      if (mounted) {
        setState(() {
          _userCountry = uCountry;
          _loterias = finalLoterias;
          _filteredLoterias = _filterBySelectedView(finalLoterias);
          _isLoading = false;
        });
        CacheService.setJson(cacheKey, finalLoterias);
        DataRefreshManager.instance.markUpdated(RefreshModules.resultados);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  Future<List<Map<String, dynamic>>> _obtenerTodasLasLoterias({bool force = false}) async {
    if (!force) {
      final cachedMapeo = await CacheService.getJson('loterias_mapeadas_all_v4');
      final cachedPaises = await CacheService.getJson('paises_list_cache');
      if (cachedPaises != null && (cachedPaises as List).isNotEmpty) {
        _paises = List<Map<String, dynamic>>.from(cachedPaises);
      }
      if (cachedMapeo != null && (cachedMapeo as List).isNotEmpty) {
        return List<Map<String, dynamic>>.from(cachedMapeo);
      }
    }

    try {
      final results = await Future.wait([
        ApiService.getPaises().catchError((_) => <Map<String, dynamic>>[]),
        ApiService.getAllLoterias().catchError((_) {
          return <dynamic>[];
        }),
      ]);

      final paisesRaw = results[0] as List<Map<String, dynamic>>;
      if (paisesRaw.isNotEmpty) {
        _paises = paisesRaw;
        CacheService.setJson('paises_list_cache', _paises);
      }

      final loteriasRaw = results[1];
      final List<Map<String, dynamic>> todas = loteriasRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (todas.isNotEmpty) {
        CacheService.setJson('loterias_mapeadas_all_v4', todas);
      }
      return todas;
    } catch (_) {
      return [];
    }
  }

  String? _lastDrawRaw(Map<String, dynamic> loteria) {
    final raw = loteria['ultimo_sorteo'] ?? loteria['fecha_ultimo_sorteo'];
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// `ultimo_sorteo` se calcula en backend sólo con filas de resultados
  /// oficiales. Un próximo sorteo o una predicción nunca habilitan la tarjeta.
  bool _hasRecordedDraw(Map<String, dynamic> loteria) =>
      _lastDrawRaw(loteria) != null;

  int _recordedDrawCount(Map<String, dynamic> loteria) {
    final count = int.tryParse(loteria['sorteos_registrados']?.toString() ?? '');
    // Compatibilidad temporal con caché de una versión previa: si existe la
    // última fecha oficial, por lo menos hay un sorteo reciente.
    return count ?? (_hasRecordedDraw(loteria) ? 1 : 0);
  }

  List<Map<String, dynamic>> _filterBySelectedView(
    List<Map<String, dynamic>> source,
  ) {
    if (_selectedFilter == 'historial') {
      // El último resultado permanece en Recientes. Historial comienza sólo
      // cuando ya existe al menos un sorteo oficial anterior.
      return source.where((lot) => _recordedDrawCount(lot) > 1).toList();
    }
    return source.where(_hasRecordedDraw).toList();
  }

  void _selectView(String view) {
    if (_selectedFilter == view) return;
    setState(() {
      _selectedFilter = view;
      _filteredLoterias = _filterBySelectedView(_loterias);
    });
  }

  DateTime _lastDrawDate(Map<String, dynamic> loteria) {
    final raw = _lastDrawRaw(loteria);
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw) ??
        (raw.length >= 10
            ? DateTime.tryParse(raw.substring(0, 10))
            : null) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _getPaisNombre(dynamic id) {
    if (_paises.isEmpty) {
      return _userCountry ?? "Internacional";
    }
    final p = _paises.firstWhere(
      (p) => p["id"].toString() == id.toString(), 
      orElse: () => {"nombre": _userCountry ?? "Internacional"}
    );
    return p["nombre"] ?? (_userCountry ?? "Internacional");
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.yellow,
          backgroundColor: const Color(0xFF1E1E1E),
          displacement: 25.0,
          onRefresh: () => cargarLoterias(forceRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n?.analisisYResultados ??
                              "Análisis y Resultados",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Consumer<SubscriptionProvider>(
                        builder: (_, sub, __) => PremiumCrownIcon(
                          isPremium: sub.isPremium,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildInfoBanner(l10n),
              ),
              SliverToBoxAdapter(
                child: _buildFilterToggleButtons(l10n),
              ),
              if (_isLoading && _loterias.isEmpty)
                _buildSliverSkeletonList()
              else if (_filteredLoterias.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(l10n),
                )
              else
                _buildSliverLotteryList(l10n),
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner(AppLocalizations? l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 30.0, 16.0, 40.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF141A1E),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.amber,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        l10n?.analisisYResultados ??
                            "Análisis y Resultados",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n?.descripcionResultadosBanner ??
                      "Aquí encontrarás los últimos resultados oficiales, el historial de sorteos y el análisis de predicciones de cada lotería",
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggleButtons(AppLocalizations? l10n) {
    final showingRecent = _selectedFilter == 'recientes';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton(
              isSelected: showingRecent,
              icon: Icons.access_time_rounded,
              label: l10n?.resultadosRecientes ?? 'Recientes',
              onTap: () => _selectView('recientes'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterButton(
              isSelected: !showingRecent,
              icon: Icons.history_rounded,
              label: l10n?.historicoResultadosTitulo ??
                  'Historial de resultados',
              onTap: () => _selectView('historial'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required bool isSelected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final foreground = isSelected ? Colors.black : Colors.white70;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.yellow : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.yellow : Colors.white12,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.montserrat(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations? l10n) {
    final showingHistory = _selectedFilter == 'historial';
    final String titleText = showingHistory
        ? (l10n?.sinHistorialResultados ?? 'Aún no hay resultados históricos')
        : (l10n?.sinResultadosRegistrados ??
              'Aún no hay resultados registrados');
    final String bodyText = showingHistory
        ? (l10n?.sinHistorialResultadosDescripcion ??
              'Los sorteos anteriores aparecerán aquí cuando cada lotería tenga más de un resultado oficial.')
        : (l10n?.sinResultadosRegistradosDescripcion ??
              'Las loterías aparecerán aquí cuando registren su primer sorteo oficial.');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              showingHistory
                  ? Icons.history_toggle_off_rounded
                  : Icons.public_outlined,
              color: AppColors.yellow,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            titleText,
            style: AppTextStyles.h2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            bodyText,
            style: AppTextStyles.mensajeSecundario.copyWith(
              color: Colors.white54,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSliverLotteryList(AppLocalizations? l10n) {


    final grouped = <String, List<Map<String, dynamic>>>{};
    final langCode = Localizations.localeOf(context).languageCode;

    for (var lot in _filteredLoterias) {
      final pNombre = _getPaisNombre(lot["pais_id"]);
      grouped.putIfAbsent(pNombre, () => []).add(lot);
    }

    final sortedCountries = grouped.keys.toList()
      ..sort((a, b) {
        if (a == _userCountry) return -1;
        if (b == _userCountry) return 1;
        return a.compareTo(b);
      });

    final List<Widget> sliverItems = [];
    for (var country in sortedCountries) {
      final lots = grouped[country]!;
      final countryDisplay = PaisHelper.getNombreTraducido(country, langCode);

      sliverItems.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Text(PaisHelper.getBanderaEmoji(country), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  countryDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      for (var loteria in lots) {
        sliverItems.add(_buildLotteryItem(loteria, l10n));
      }
    }

    sliverItems.add(const SizedBox(height: 20));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => sliverItems[index],
        childCount: sliverItems.length,
      ),
    );
  }

  String _formatearFechaSimple(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "";
    try {
      final clean = fecha.trim();
      final parsed = DateTime.tryParse(clean) ?? (clean.length >= 10 ? DateTime.tryParse(clean.substring(0, 10)) : null);
      if (parsed == null) return fecha;

      final langCode = Localizations.localeOf(context).languageCode;
      final dias = langCode == 'en' 
          ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
          : (langCode == 'pt' 
              ? ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
              : ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]);

      final meses = langCode == 'en'
          ? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
          : (langCode == 'pt'
              ? ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]
              : ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]);

      final diaSemana = dias[parsed.weekday - 1];
      final mes = meses[parsed.month - 1];

      return "$diaSemana, ${parsed.day} $mes ${parsed.year}";
    } catch (_) {
      return fecha;
    }
  }

  String _calcularEstadoSorteo(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "";
    try {
      final clean = fecha.trim();
      final parsed = DateTime.tryParse(clean) ?? (clean.length >= 10 ? DateTime.tryParse(clean.substring(0, 10)) : null);
      if (parsed == null) return "";

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(parsed.year, parsed.month, parsed.day);
      final diff = target.difference(today).inDays;

      final langCode = Localizations.localeOf(context).languageCode;

      if (diff == 0) {
        return langCode == 'en' ? "Draws today" : (langCode == 'pt' ? "Sorteia hoje" : "Sortea hoy");
      } else if (diff == 1) {
        return langCode == 'en' ? "Tomorrow" : (langCode == 'pt' ? "Amanhã" : "Mañana");
      } else if (diff > 1) {
        return langCode == 'en' ? "In $diff days" : (langCode == 'pt' ? "Faltam $diff dias" : "Faltan $diff días");
      } else if (diff == -1) {
        return langCode == 'en' ? "Drew yesterday" : (langCode == 'pt' ? "Sorteado ontem" : "Sorteó ayer");
      } else {
        final dias = diff.abs();
        return langCode == 'en' ? "Drew $dias days ago" : (langCode == 'pt' ? "Sorteado há $dias dias" : "Sorteó hace $dias días");
      }
    } catch (_) {
      return "";
    }
  }

  Widget _buildLotteryItem(Map<String, dynamic> loteria, AppLocalizations? l10n) {
    final nombre = loteria["nombre"] ?? "";
    final String nombreFormateado = nombre.isNotEmpty
        ? nombre[0].toUpperCase() + nombre.substring(1).toLowerCase()
        : "";
    final rawFecha = _lastDrawRaw(loteria);
    final fechaDisplay = _formatearFechaSimple(rawFecha);
    final estadoDisplay = _calcularEstadoSorteo(rawFecha);
    final historicalCount = (_recordedDrawCount(loteria) - 1).clamp(0, 9999);
    final openingHistory = _selectedFilter == 'historial';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        onTap: () => _navigateToEstadisticas(
          loteria,
          openHistory: openingHistory,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
        leading: LotteryAvatar3D(nombre: nombre, size: 36),
        title: Text(
          nombreFormateado,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2),
            Text(
              fechaDisplay,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (estadoDisplay.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                estadoDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
        trailing: openingHistory
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '$historicalCount',
                      style: const TextStyle(
                        color: AppColors.yellow,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.history_rounded,
                    color: AppColors.yellow,
                    size: 18,
                  ),
                ],
              )
            : const Icon(
                Icons.analytics_outlined,
                color: AppColors.yellow,
                size: 18,
              ),
      ),
    );
  }

  void _navigateToEstadisticas(
    Map<String, dynamic> loteria, {
    bool openHistory = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadosDashboardScreen(
          loteriaNombreInicial: loteria["nombre"] ?? "Lotería",
          loteriaData: loteria,
          openHistory: openHistory,
        ),
      ),
    );
  }

  Widget _buildSliverSkeletonList() {
    return SliverToBoxAdapter(
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1A1A1A),
        highlightColor: const Color(0xFF2C2C2C),
        period: const Duration(milliseconds: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: List.generate(
              6,
              (index) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
