import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/services/cache_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/widgets/lottery_avatar_3d.dart';
import 'package:dataloto/utils/pais_helper.dart';
import 'package:dataloto/screens/resultados_dashboard_screen.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

class ResultadosSelectorScreen extends StatefulWidget {
  const ResultadosSelectorScreen({super.key});

  @override
  State<ResultadosSelectorScreen> createState() => _ResultadosSelectorScreenState();
}

class _ResultadosSelectorScreenState extends State<ResultadosSelectorScreen> {
  List<Map<String, dynamic>> _loterias = [];
  List<Map<String, dynamic>> _filteredLoterias = [];
  List<Map<String, dynamic>> _paises = [];
  final TextEditingController _searchController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  String? _userCountry;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarLoterias();
  }

  Future<void> _cargarLoterias() async {
    if (!mounted) return;

    final uId = await _storage.read(key: 'user_id');
    final cacheKey = 'resultados_selector_${uId ?? "anon"}';
    final uCountry = await _storage.read(key: 'pais_nombre');

    // ⚡ 1. Cargar caché de despliegue instantáneo (0 ms)
    final cached = await CacheService.getJson(cacheKey);
    final cachedPaises = await CacheService.getJson('paises_list_cache');

    if (cached != null && mounted) {
      setState(() {
        _userCountry = uCountry;
        _loterias = List<Map<String, dynamic>>.from(cached);
        _filteredLoterias = List<Map<String, dynamic>>.from(_loterias);
        if (cachedPaises != null) {
          _paises = List<Map<String, dynamic>>.from(cachedPaises);
        }
        _isLoading = false;
      });
    }

    if (_loterias.isEmpty) setState(() => _isLoading = true);

    try {
      // ⚡ 2. Obtener jugadas activas y todas las loterías en paralelo
      final resultados = await Future.wait([
        ApiService.getLoteriasConJugadas().catchError((e) {
          debugPrint("⚠️ Error obteniendo jugadas activas: $e");
          return <String>[];
        }),
        _obtenerTodasLasLoterias(),
      ]);

      final List<String> activas = List<String>.from(resultados[0] as List);
      final List<Map<String, dynamic>> todas = resultados[1] as List<Map<String, dynamic>>;

      // Filtrar solo las loterías que el usuario HA JUGADO
      final List<Map<String, dynamic>> jugadasLoterias = todas.where((mapItem) {
        final route = _getRouteFromName(mapItem['nombre'] ?? "");
        return activas.contains(route);
      }).toList();

      if (mounted) {
        setState(() {
          _userCountry = uCountry;
          _loterias = jugadasLoterias;
          _filteredLoterias = jugadasLoterias;
          _isLoading = false;
        });
        CacheService.setJson(cacheKey, jugadasLoterias);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerTodasLasLoterias() async {
    final cachedMapeo = await CacheService.getJson('loterias_mapeadas_all');
    if (cachedMapeo != null) {
      return List<Map<String, dynamic>>.from(cachedMapeo);
    }

    final paisesRaw = await ApiService.getPaises().catchError((_) => <Map<String, dynamic>>[]);
    _paises = paisesRaw.cast<Map<String, dynamic>>();
    CacheService.setJson('paises_list_cache', _paises);

    final listadoFutures = _paises.map((p) => ApiService.getLoteriasPorPais(p['id'].toString()).catchError((e) => <dynamic>[]));
    final resultadosLoterias = await Future.wait(listadoFutures);

    List<Map<String, dynamic>> todas = [];
    for (int i = 0; i < _paises.length; i++) {
      final pId = _paises[i]['id'].toString();
      final list = resultadosLoterias[i];
      for (var item in list) {
        final mapItem = Map<String, dynamic>.from(item as Map);
        mapItem['pais_id'] = mapItem['pais_id'] ?? pId;
        todas.add(mapItem);
      }
    }

    if (todas.isNotEmpty) {
      CacheService.setJson('loterias_mapeadas_all', todas);
    }
    return todas;
  }

  String _getRouteFromName(String nombre) {
    String clean = nombre.trim().toLowerCase();
    if (clean.contains("baloto") || clean.contains("revancha")) return "bloto";
    if (clean.contains("miloto") || clean.contains("mloto")) return "mloto";
    if (clean.contains("colorloto")) return "colorloto";
    if (clean.contains("powerball")) return "powerball";
    if (clean.contains("mega millions") || clean.contains("megamillions")) return "megamillions";
    if (clean.contains("millionaire")) return "millionaire_life";
    if (clean.contains("lotto america")) return "lotto_america";
    if (clean.contains("double play")) return "double_play";

    // Dynamic normalization for future lotteries
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

  void _onSearchChanged(String query) {
    setState(() {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        _filteredLoterias = _loterias;
      } else {
        _filteredLoterias = _loterias.where((l) {
          final name = (l["nombre"] ?? "").toString().toLowerCase();
          final pNombre = _getPaisNombre(l["pais_id"]).toLowerCase();
          return name.contains(q) || pNombre.contains(q);
        }).toList();
      }
    });
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
          color: AppColors.yellow,
          onRefresh: _cargarLoterias,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Text(
                    l10n?.analisisYResultados ?? "Análisis y Resultados",
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildSearchBar(l10n),
              ),
              if (_isLoading && _loterias.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  ),
                )
              else if (_filteredLoterias.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(l10n),
                )
              else
                _buildSliverLotteryList(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n?.buscarPorLoteriaOPais ?? "Buscar por lotería o país...",
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white38),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations? l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, color: Colors.white24, size: 80),
            const SizedBox(height: 20),
            Text(
              l10n?.sinResultadosAnalisis ?? "Aún no tienes análisis de resultados",
              style: AppTextStyles.h2.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              l10n?.empiezaAGuardarNumeros ?? "Empieza a guardar tus números favoritos desde la sección Explorar para ver tus análisis y resultados.",
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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Text(PaisHelper.getBanderaEmoji(country), style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                countryDisplay,
                style: AppTextStyles.h2.copyWith(color: AppColors.white),
              ),
            ],
          ),
        ),
      );

      for (var loteria in lots) {
        sliverItems.add(_buildLotteryItem(loteria));
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

  Widget _buildLotteryItem(Map<String, dynamic> loteria) {
    final nombre = loteria["nombre"] ?? "";
    final String nombreFormateado = nombre.isNotEmpty
        ? nombre[0].toUpperCase() + nombre.substring(1).toLowerCase()
        : "";
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => _navigateToEstadisticas(nombre),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        leading: LotteryAvatar3D(nombre: nombre, size: 46),
        title: Text(
          nombreFormateado,
          style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: const Icon(Icons.analytics_outlined, color: AppColors.yellow, size: 20),
      ),
    );
  }

  void _navigateToEstadisticas(String nombre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadosDashboardScreen(loteriaNombreInicial: nombre),
      ),
    );
  }
}
