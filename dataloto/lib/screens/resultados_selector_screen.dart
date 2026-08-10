import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/services/cache_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/widgets/lottery_avatar_3d.dart';
import 'package:dataloto/utils/pais_helper.dart';
import 'package:dataloto/screens/estadisticas_bloto.dart';
import 'package:dataloto/screens/estadisticas_mloto.dart';
import 'package:dataloto/screens/estadisticas_powerball.dart';
import 'package:dataloto/screens/estadisticas_megamillions.dart';
import 'package:dataloto/screens/estadisticas_lotto_america.dart';
import 'package:dataloto/screens/estadisticas_double_play.dart';
import 'package:dataloto/screens/estadisticas_millionaire_life.dart';

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

    // ⚡ 1. Cargar caché de despliegue instantáneo (0 ms)
    final cached = await CacheService.getJson('resultados_loterias_selector');
    final cachedPaises = await CacheService.getJson('paises_list_cache');
    final uCountry = await _storage.read(key: 'pais_nombre');

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
      final paisesRaw = await ApiService.getPaises();
      _paises = paisesRaw.cast<Map<String, dynamic>>();
      CacheService.setJson('paises_list_cache', _paises);
      
      List<Map<String, dynamic>> todas = [];
      final listadoFutures = _paises.map((p) => ApiService.getLoteriasPorPais(p['id'].toString()).catchError((e) => <dynamic>[]));
      final resultadosLoterias = await Future.wait(listadoFutures);

      for (int i = 0; i < _paises.length; i++) {
        final pId = _paises[i]['id'].toString();
        final list = resultadosLoterias[i];
        for (var item in list) {
          final mapItem = Map<String, dynamic>.from(item as Map);
          mapItem['pais_id'] = mapItem['pais_id'] ?? pId;
          todas.add(mapItem);
        }
      }

      if (mounted) {
        setState(() {
          _userCountry = uCountry;
          _loterias = todas;
          _filteredLoterias = todas;
          _isLoading = false;
        });
        CacheService.setJson('resultados_loterias_selector', todas);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.yellow,
          onRefresh: _cargarLoterias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Text(
                  "Análisis y Resultados",
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              _buildSearchBar(),
              Expanded(
                child: _isLoading && _loterias.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                  : _buildLotteryList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
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
          decoration: const InputDecoration(
            hintText: "Buscar por lotería o país...",
            hintStyle: TextStyle(color: Colors.white38),
            prefixIcon: Icon(Icons.search, color: Colors.white38),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildLotteryList() {
    final grouped = <String, List<Map<String, dynamic>>>{};
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
                    country.isNotEmpty 
                      ? country[0].toUpperCase() + country.substring(1).toLowerCase() 
                      : "",
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
    final n = nombre.toLowerCase().trim();
    Widget screen;
    
    if (n.contains("baloto")) {
      screen = const EstadisticasBlotoScreen();
    } else if (n.contains("miloto")) {
      screen = const EstadisticasMlotoScreen();
    } else if (n.contains("powerball")) {
      screen = const EstadisticasPowerballScreen();
    } else if (n.contains("mega millions")) {
      screen = const EstadisticasMegaMillionsScreen();
    } else if (n.contains("lotto america")) {
      screen = const EstadisticasLottoAmericaScreen();
    } else if (n.contains("double play")) {
      screen = const EstadisticasDoublePlayScreen();
    } else if (n.contains("millionaire")) {
      screen = const EstadisticasMillionaireLifeScreen();
    } else {
      // Por defecto o si no hay pantalla específica
      screen = const EstadisticasBlotoScreen();
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
