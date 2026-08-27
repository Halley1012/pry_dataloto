import 'package:flutter/material.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/utils/pais_helper.dart';
import 'package:eterlotto/widgets/lottery_avatar_3d.dart';
import 'package:eterlotto/screens/jugadas/mis_jugadas_screen.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';

import 'package:eterlotto/services/cache_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/utils/top_bouncing_scroll_physics.dart';
import 'package:shimmer/shimmer.dart';

class MisJugadasSelectorScreen extends StatefulWidget {
  const MisJugadasSelectorScreen({super.key});

  @override
  State<MisJugadasSelectorScreen> createState() => MisJugadasSelectorScreenState();
}

class MisJugadasSelectorScreenState extends State<MisJugadasSelectorScreen> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _loterias = [];
  List<Map<String, dynamic>> _filteredLoterias = [];
  List<Map<String, dynamic>> _paises = [];
  Map<String, Map<String, dynamic>> _infoJugadas = {};
  String? _userCountry;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarLoterias();
  }

  /// ⚡ Carga súper rápida con caché a 0ms + peticiones en paralelo (Future.wait)
  Future<void> cargarLoterias({bool forceRefresh = false}) async {
    if (!mounted) return;

    final uId = await _storage.read(key: 'user_id');
    final cacheKey = 'mis_jugadas_selector_v5_${uId ?? "anon"}';
    final uCountry = await _storage.read(key: 'pais_nombre');

    // ⚡ 1. Mostrar caché al instante (0 ms) si existe y no es forceRefresh
    if (!forceRefresh) {
      final cached = await CacheService.getJson(cacheKey);
      final cachedPaises = await CacheService.getJson('paises_list_cache');
      final cachedInfo = await CacheService.getJson('mis_jugadas_info_cache');
      if (cached != null && (cached as List).isNotEmpty && mounted) {
        setState(() {
          _userCountry = uCountry;
          _loterias = List<Map<String, dynamic>>.from(cached);
          _filteredLoterias = List<Map<String, dynamic>>.from(_loterias);
          if (cachedPaises != null) {
            _paises = List<Map<String, dynamic>>.from(cachedPaises);
          }
          if (cachedInfo != null && cachedInfo is Map) {
            _infoJugadas = cachedInfo.map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)));
          }
          _isLoading = false;
        });
      }
    }

    if (_loterias.isEmpty || forceRefresh) setState(() => _isLoading = true);

    try {
      // ⚡ 2. Cargar datos en PARALELO
      final resultados = await Future.wait([
        ApiService.getLoteriasInfoJugadas().catchError((e) {
          debugPrint("⚠️ Error obteniendo info de jugadas: $e");
          return <String, Map<String, dynamic>>{};
        }),
        ApiService.getLoteriasConJugadas().catchError((e) {
          return <String>[];
        }),
        _obtenerTodasLasLoterias(force: forceRefresh),
      ]);

      final Map<String, Map<String, dynamic>> infoMap = Map<String, Map<String, dynamic>>.from(resultados[0] as Map);
      final List<String> activas = List<String>.from(resultados[1] as List);
      final List<Map<String, dynamic>> todas = resultados[2] as List<Map<String, dynamic>>;

      for (final a in activas) {
        infoMap.putIfAbsent(a.toLowerCase(), () => {"count": 1, "fecha": null});
      }

      final List<Map<String, dynamic>> jugadasLoterias = todas.where((mapItem) {
        final rawRoute = mapItem['route']?.toString().trim().toLowerCase();
        final route = (rawRoute != null && rawRoute.isNotEmpty)
            ? rawRoute
            : _getRouteFromName(mapItem['nombre'] ?? "");
        return infoMap.containsKey(route) || activas.contains(route);
      }).toList();

      if (mounted) {
        setState(() {
          _userCountry = uCountry;
          _infoJugadas = infoMap;
          _loterias = jugadasLoterias;
          _filteredLoterias = jugadasLoterias;
          _isLoading = false;
        });
        if (jugadasLoterias.isNotEmpty) {
          CacheService.setJson(cacheKey, jugadasLoterias);
          CacheService.setJson('mis_jugadas_info_cache', infoMap);
        }
      }
    } catch (e) {
      debugPrint("❌ Error al cargar loterías de Mis Jugadas: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerTodasLasLoterias({bool force = false}) async {
    if (!force) {
      final cachedMapeo = await CacheService.getJson('loterias_mapeadas_all_v3');
      if (cachedMapeo != null && (cachedMapeo as List).isNotEmpty) {
        return List<Map<String, dynamic>>.from(cachedMapeo);
      }
    }

    try {
      // Cargar países y loterías en paralelo de manera ultra rápida
      final results = await Future.wait([
        ApiService.getPaises().catchError((_) => <Map<String, dynamic>>[]),
        ApiService.getAllLoterias().catchError((e) {
          debugPrint("⚠️ Error obteniendo todas las loterías: $e");
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
        CacheService.setJson('loterias_mapeadas_all', todas);
      }
      return todas;
    } catch (e) {
      debugPrint("⚠️ Error en _obtenerTodasLasLoterias: $e");
      return [];
    }
  }

  String _getRouteFromName(String nombre) {
    String clean = nombre.trim().toLowerCase();
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

  String _getPaisNombre(dynamic id) {
    if (_paises.isEmpty) return "Cargando...";
    final p = _paises.firstWhere(
      (p) => p["id"].toString() == id.toString(), 
      orElse: () => {"nombre": "Internacional"}
    );
    return p["nombre"];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.transparent,
          backgroundColor: Colors.transparent,
          elevation: 0,
          displacement: 65.0,
          triggerMode: RefreshIndicatorTriggerMode.onEdge,
          onRefresh: () async => cargarLoterias(forceRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: TopBouncingScrollPhysics()),
            slivers: [
              if (_isLoading && _loterias.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: LinearProgressIndicator(
                      backgroundColor: Color(0xFF1E2029),
                      color: AppColors.yellow,
                      minHeight: 2.5,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    l10n?.misJugadas ?? "Mis Jugadas",
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildInfoBanner(l10n),
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
                    const Text("💡", style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      l10n?.misJugadas ?? "Mis jugadas",
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n?.descripcionMisJugadasBanner ??
                      "Aquí encontrarás todas tus jugadas y el próximo sorteo de cada lotería",
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

  Widget _buildSliverSkeletonList() {
    return SliverToBoxAdapter(
      child: _buildSkeletonList(),
    );
  }

  Widget _buildEmptyState(AppLocalizations? l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_border, color: Colors.white24, size: 80),
            const SizedBox(height: 20),
            Text(
              l10n?.aunNoTienesJugadas ?? "Aún no tienes jugadas",
              style: AppTextStyles.h2.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              l10n?.empiezaAGuardarNumeros ?? "Empieza a guardar tus números favoritos desde la sección Explorar.",
              style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
              Text(
                countryDisplay,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => sliverItems[index],
        childCount: sliverItems.length,
      ),
    );
  }

  String _formatearFechaProximo(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "Próximo sorteo";
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
    final rawRoute = loteria['route']?.toString().trim().toLowerCase();
    final route = (rawRoute != null && rawRoute.isNotEmpty)
        ? rawRoute
        : _getRouteFromName(nombre);

    final info = _infoJugadas[route];
    final count = info?['count'] ?? 1;
    final rawFecha = info?['fecha'] ?? loteria["proximo_sorteo"] ?? loteria["fecha"] ?? loteria["ultimo_sorteo"];
    final fechaDisplay = _formatearFechaProximo(rawFecha?.toString());
    final estadoDisplay = _calcularEstadoSorteo(rawFecha?.toString());
    final baseColor = LotteryAvatar3D.getColorForNombre(nombre);
    final langCode = Localizations.localeOf(context).languageCode;
    final jugadasText = count == 1 
        ? (langCode == 'en' ? 'play' : (langCode == 'pt' ? 'jogada' : 'jugada'))
        : (langCode == 'en' ? 'plays' : (langCode == 'pt' ? 'jugadas' : 'jugadas'));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToJugadas(loteria),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            child: Row(
              children: [
                LotteryAvatar3D(nombre: nombre, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nombreFormateado,
                        style: AppTextStyles.h2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
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
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$count",
                        style: TextStyle(
                          color: baseColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        jugadasText,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.analytics_outlined, color: AppColors.yellow, size: 18),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToJugadas(Map<String, dynamic> loteria) {
    final nombre = (loteria['nombre'] ?? 'Lotería').toString();
    final rawRoute = loteria['route']?.toString().trim().toLowerCase();
    final route = (rawRoute != null && rawRoute.isNotEmpty)
        ? rawRoute
        : _getRouteFromName(nombre);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MisJugadasScreen(
          loteriaNombre: nombre,
          loteriaRoute: route,
        ),
      ),
    ).then((_) {
      cargarLoterias();
    });
  }

  Widget _buildSkeletonList() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2C2C2C),
      period: const Duration(milliseconds: 1400),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}
