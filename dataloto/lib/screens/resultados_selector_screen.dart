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
  State<ResultadosSelectorScreen> createState() => ResultadosSelectorScreenState();
}

class ResultadosSelectorScreenState extends State<ResultadosSelectorScreen> {
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
    cargarLoterias();
  }

  Future<void> cargarLoterias({bool forceRefresh = false}) async {
    if (!mounted) return;

    final uId = await _storage.read(key: 'user_id');
    final uPaisId = await _storage.read(key: 'pais_id') ?? "5";
    final uCountry = await _storage.read(key: 'pais_nombre') ?? "Colombia";
    final cacheKey = 'resultados_selector_${uId ?? "anon"}_$uPaisId';

    if (!forceRefresh) {
      // ⚡ 1. Cargar caché de despliegue instantáneo (0 ms)
      final cached = await CacheService.getJson(cacheKey);
      final cachedPaises = await CacheService.getJson('paises_list_cache');

      if (cached != null && (cached as List).isNotEmpty && mounted) {
        setState(() {
          _userCountry = uCountry;
          _loterias = List<Map<String, dynamic>>.from(cached);
          _filteredLoterias = List<Map<String, dynamic>>.from(_loterias);
          if (cachedPaises != null && (cachedPaises as List).isNotEmpty) {
            _paises = List<Map<String, dynamic>>.from(cachedPaises);
          }
          _isLoading = false;
        });
      }
    }

    if (_loterias.isEmpty || forceRefresh) setState(() => _isLoading = true);

    try {
      // ⚡ 2. Obtener jugadas activas y todas las loterías en paralelo
      final resultados = await Future.wait([
        ApiService.getLoteriasConJugadas().catchError((e) {
          debugPrint("⚠️ Error obteniendo jugadas activas: $e");
          return <String>[];
        }),
        _obtenerTodasLasLoterias(force: forceRefresh),
      ]);

      final List<String> activas = List<String>.from(resultados[0] as List);
      final List<Map<String, dynamic>> todas = resultados[1] as List<Map<String, dynamic>>;

      // Identificar el ID del país del usuario
      String targetPaisId = uPaisId;
      if (_paises.isNotEmpty && uCountry.isNotEmpty) {
        try {
          final pMatch = _paises.firstWhere(
            (p) => p["nombre"].toString().toLowerCase() == uCountry.toLowerCase(),
          );
          if (pMatch["id"] != null) {
            targetPaisId = pMatch["id"].toString();
          }
        } catch (_) {}
      }

      // Filtrado inteligente: Loterías de MI PAÍS + Loterías con JUGADAS ACTIVAS
      List<Map<String, dynamic>> finalLoterias = todas.where((mapItem) {
        final rawRoute = mapItem['route']?.toString().trim().toLowerCase();
        final route = (rawRoute != null && rawRoute.isNotEmpty)
            ? rawRoute
            : _getRouteFromName(mapItem['nombre'] ?? "");
        
        final mapPaisId = mapItem['pais_id']?.toString();
        final isFromMyCountry = (mapPaisId != null && mapPaisId == targetPaisId);
        final hasJugadas = activas.contains(route);

        return isFromMyCountry || hasJugadas;
      }).toList();

      // Si por alguna razón la lista quedó vacía, intentar traer directamente las del país
      if (finalLoterias.isEmpty) {
        try {
          final countryLoterias = await ApiService.getLoteriasPorPais(targetPaisId);
          finalLoterias = countryLoterias
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } catch (e) {
          debugPrint("⚠️ Error al obtener loterías de respaldo por país: $e");
        }
      }

      if (mounted) {
        setState(() {
          _userCountry = uCountry;
          _loterias = finalLoterias;
          _filteredLoterias = finalLoterias;
          _isLoading = false;
        });
        if (finalLoterias.isNotEmpty) {
          CacheService.setJson(cacheKey, finalLoterias);
        }
      }
    } catch (e) {
      debugPrint("❌ Error en cargarLoterias (Resultados): $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }



  Future<List<Map<String, dynamic>>> _obtenerTodasLasLoterias({bool force = false}) async {
    if (!force) {
      final cachedMapeo = await CacheService.getJson('loterias_mapeadas_all');
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
          onRefresh: () => cargarLoterias(forceRefresh: true),
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
                SliverToBoxAdapter(
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
    final langCode = Localizations.localeOf(context).languageCode;
    final isSearching = _searchController.text.trim().isNotEmpty;
    final countryName = PaisHelper.getNombreTraducido(_userCountry ?? "Colombia", langCode);

    if (isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_outlined, color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              Text(
                langCode == 'en' ? "No lotteries found" : (langCode == 'pt' ? "Nenhuma loteria encontrada" : "No se encontraron loterías"),
                style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                langCode == 'en' ? "Try another search term." : (langCode == 'pt' ? "Tente outro termo de busca." : "Intenta con otro término de búsqueda."),
                style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final String titleText = langCode == 'en'
        ? "No lotteries registered for $countryName"
        : langCode == 'pt'
            ? "Não há loterias registradas para $countryName"
            : "No hay loterías registradas para $countryName";

    final String bodyText = langCode == 'en'
        ? "Currently there are no local lotteries for this country. Below you can explore the most played lotteries in the world!"
        : langCode == 'pt'
            ? "Atualmente não há loterias locais para este país. Abaixo você pode explorar as loterias mais jogadas no mundo!"
            : "Actualmente no hay loterías locales para este país. ¡A continuación puedes explorar las loterías más jugadas en el mundo!";

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
            child: const Icon(
              Icons.public_outlined,
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
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        onTap: () => _navigateToEstadisticas(loteria),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
        leading: LotteryAvatar3D(nombre: nombre, size: 36),
        title: Text(
          nombreFormateado,
          style: AppTextStyles.h2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
        trailing: const Icon(Icons.analytics_outlined, color: AppColors.yellow, size: 18),
      ),
    );
  }

  void _navigateToEstadisticas(Map<String, dynamic> loteria) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadosDashboardScreen(
          loteriaNombreInicial: loteria["nombre"] ?? "Lotería",
          loteriaData: loteria,
        ),
      ),
    );
  }
}
