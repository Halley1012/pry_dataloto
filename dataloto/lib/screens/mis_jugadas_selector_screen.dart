import 'package:flutter/material.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/utils/pais_helper.dart';
import 'package:dataloto/widgets/lottery_avatar_3d.dart';
import 'package:dataloto/screens/jugadas/mis_jugadas_screen.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

import 'package:dataloto/services/cache_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  final TextEditingController _searchController = TextEditingController();
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
    final cacheKey = 'mis_jugadas_selector_${uId ?? "anon"}';
    final uCountry = await _storage.read(key: 'pais_nombre');

    // ⚡ 1. Mostrar caché al instante (0 ms) si existe y no es forceRefresh
    if (!forceRefresh) {
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
    }

    if (_loterias.isEmpty || forceRefresh) setState(() => _isLoading = true);

    try {
      // ⚡ 2. Cargar datos en PARALELO
      final resultados = await Future.wait([
        ApiService.getLoteriasConJugadas().catchError((e) {
          debugPrint("⚠️ Error obteniendo jugadas activas: $e");
          return <String>[];
        }),
        _obtenerTodasLasLoterias(force: forceRefresh),
      ]);

      final List<String> activas = List<String>.from(resultados[0] as List);
      final List<Map<String, dynamic>> todas = resultados[1] as List<Map<String, dynamic>>;

      debugPrint("🔍 Depuración Mis Jugadas:");
      debugPrint("   - Loterías activas (rutas): $activas");
      debugPrint("   - Total loterías disponibles: ${todas.length}");

      final List<Map<String, dynamic>> jugadasLoterias = activas.isNotEmpty
          ? todas.where((mapItem) {
              final route = _getRouteFromName(mapItem['nombre'] ?? "");
              return activas.contains(route);
            }).toList()
          : todas;

      debugPrint("   - Loterías mostradas: ${jugadasLoterias.map((e) => e['nombre']).toList()}");

      if (mounted) {
        setState(() {
          _userCountry = uCountry;
          _loterias = jugadasLoterias;
          _filteredLoterias = jugadasLoterias;
          _isLoading = false;
        });
        if (jugadasLoterias.isNotEmpty) {
          CacheService.setJson(cacheKey, jugadasLoterias);
        }
      }
    } catch (e) {
      debugPrint("❌ Error al cargar loterías de Mis Jugadas: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerTodasLasLoterias({bool force = false}) async {
    if (!force) {
      final cachedMapeo = await CacheService.getJson('loterias_mapeadas_all');
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
    final n = nombre.toLowerCase().trim();
    if (n.contains("baloto") || n.contains("revancha")) return "bloto";
    if (n.contains("miloto") || n.contains("mloto")) return "mloto";
    if (n.contains("colorloto")) return "colorloto";
    if (n.contains("powerball")) return "powerball";
    if (n.contains("mega millions") || n.contains("megamillions")) return "megamillions";
    if (n.contains("lotto america")) return "lotto_america";
    if (n.contains("double play")) return "double_play";
    if (n.contains("millionaire")) return "millionaire_life";
    return "unknown";
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
          onRefresh: () async => cargarLoterias(forceRefresh: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Text(
                  l10n?.misJugadas ?? "Mis Jugadas",
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              _buildSearchBar(l10n),
              Expanded(
                child: _isLoading && _loterias.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                  : _buildLotteryList(l10n),
              ),
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

  Widget _buildLotteryList(AppLocalizations? l10n) {
    if (_filteredLoterias.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: sortedCountries.length,
      itemBuilder: (context, i) {
        final country = sortedCountries[i];
        final lots = grouped[country]!;
        final countryDisplay = PaisHelper.getNombreTraducido(country, langCode);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            ...lots.map((loteria) => _buildLotteryItem(loteria)),
          ],
        );
      },
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
        onTap: () => _navigateToJugadas(nombre),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        leading: LotteryAvatar3D(nombre: nombre, size: 46),
        title: Text(
          nombreFormateado,
          style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
      ),
    );
  }

  void _navigateToJugadas(String nombre) {
    final route = _getRouteFromName(nombre);
    
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
}
