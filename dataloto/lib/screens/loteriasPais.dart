import 'package:dataloto/screens/baloto.dart';
import 'package:dataloto/screens/color_loto.dart';
import 'package:dataloto/screens/miloto.dart';
import 'package:dataloto/screens/powerball.dart';
import 'package:dataloto/screens/lotto_america.dart';
import 'package:dataloto/screens/double_play.dart';
import 'package:dataloto/screens/millionaire_life.dart';
import 'package:dataloto/screens/megamillions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/services/cache_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/widgets/lottery_avatar_3d.dart';
import 'package:dataloto/utils/pais_helper.dart';

class LoteriasPais extends StatefulWidget {
  const LoteriasPais({super.key});

  @override
  State<LoteriasPais> createState() => _LoteriasPaisState();
}

class _LoteriasPaisState extends State<LoteriasPais> {

  List<Map<String, dynamic>> _loterias = [];
  List<Map<String, dynamic>> _filteredLoterias = [];
  List<Map<String, dynamic>> _paises = [];
  final TextEditingController _searchController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  String? _userCountry;

  bool _isLoading = true;
  bool _isShowingAll = false;

  @override
  void initState() {
    super.initState();
    _cargarExplorarMundial();
  }

  Future<void> _cargarExplorarMundial() async {
    if (!mounted) return;

    // ⚡ 1. Mostrar caché al instante (0 ms)
    final cached = await CacheService.getJson('explorar_loterias_mundial');
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
      // 1. Obtener todos los países
      final paisesRaw = await ApiService.getPaises();
      _paises = paisesRaw.cast<Map<String, dynamic>>();
      CacheService.setJson('paises_list_cache', _paises);
      
      List<Map<String, dynamic>> todas = [];
      
      // 2. Cargar loterías de TODOS los países en paralelo
      final listadoFutures = _paises.map((p) => ApiService.getLoteriasPorPais(p['id'].toString()).catchError((e) {
        debugPrint("Error cargando loterías para país ${p['id']}: $e");
        return [];
      }));

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
        CacheService.setJson('explorar_loterias_mundial', todas);
      }
    } catch (e) {
      debugPrint("❌ Error crítico en Explorar Mundial: $e");
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

  List<Map<String, dynamic>> _getDisplayList() {
    if (_searchController.text.trim().isNotEmpty) {
      return _filteredLoterias;
    }
    
    if (_isShowingAll) {
      return _filteredLoterias;
    }

    final Map<String, int> countsPerCountry = {};
    final List<Map<String, dynamic>> limitedList = [];

    for (var loteria in _filteredLoterias) {
      final pId = loteria["pais_id"]?.toString() ?? "unknown";
      final currentCount = countsPerCountry[pId] ?? 0;

      if (currentCount < 2) {
        limitedList.add(loteria);
        countsPerCountry[pId] = currentCount + 1;
      }
    }

    return limitedList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.yellow,
          onRefresh: _cargarExplorarMundial,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Text(
                  "Explorar Loterías",
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              _buildSearchBar(),
              Expanded(
                child: _isLoading && _loterias.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                  : _buildLotteryList(),
              ),
              _buildFooterButton(),
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
            hintText: "Buscar lotería o país...",
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
    final displayList = _getDisplayList();
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (var lot in displayList) {
      final pNombre = _getPaisNombre(lot["pais_id"]);
      grouped.putIfAbsent(pNombre, () => []).add(lot);
    }

    // Ordenar países: Usuario primero, luego resto alfabético
    final sortedCountries = grouped.keys.toList()
      ..sort((a, b) {
        if (a == _userCountry) return -1;
        if (b == _userCountry) return 1;
        return a.compareTo(b);
      });

    return ListView.builder(
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
            ...lots.map((loteria) => _buildExploreItem(loteria)),
          ],
        );
      },
    );
  }

  Widget _buildExploreItem(Map<String, dynamic> loteria) {
    final nombre = loteria["nombre"] ?? "";
    final fechaSorteo = _formatearFechaSimple(loteria["proximo_sorteo"]);
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
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _resolveScreen(nombre))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        leading: LotteryAvatar3D(nombre: nombre, size: 46),
        title: Text(
          nombreFormateado,
          style: AppTextStyles.h2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          "Próximo sorteo: $fechaSorteo",
          style: AppTextStyles.mensajeSecundario.copyWith(
            color: Colors.white38,
            fontSize: 11,
          ),
        ),
        trailing: const Icon(
          Icons.star_outline,
          color: AppColors.yellow,
          size: 22,
        ),
      ),
    );
  }

  String _formatearFechaSimple(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "Próximamente";
    try {
      DateTime parsed = DateTime.parse(fecha.substring(0, 10));
      DateTime now = DateTime.now();
      DateTime hoy = DateTime(now.year, now.month, now.day);
      DateTime fechaS = DateTime(parsed.year, parsed.month, parsed.day);
      if (fechaS.isBefore(hoy)) return "Próximamente";

      const meses = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
      return "${parsed.day.toString().padLeft(2, '0')} ${meses[parsed.month - 1]} ${parsed.year}";
    } catch (_) {
      return "Próximamente";
    }
  }

  String _getPaisNombre(dynamic id) {
    if (_paises.isEmpty) return "Cargando...";
    final p = _paises.firstWhere(
      (p) => p["id"].toString() == id.toString(), 
      orElse: () => {"nombre": "Internacional"}
    );
    return p["nombre"];
  }

  Widget _buildFooterButton() {
    if (_isShowingAll || _searchController.text.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
          setState(() => _isShowingAll = true);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: AppColors.yellow,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("Ver todas las loterías del mundo", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _resolveScreen(String? tipo) {
    final t = (tipo ?? "").toLowerCase().trim();
    if (t.contains("baloto")) return const BalotoScreen();
    if (t.contains("miloto")) return const MilotoScreen();
    if (t.contains("powerball")) return const PowerballScreen();
    if (t.contains("lotto america")) return const LottoAmericaScreen();
    if (t.contains("double play")) return const DoublePlayScreen();
    if (t.contains("millionaire")) return const MillionaireLifeScreen();
    if (t.contains("mega millions") || t.contains("megamillions")) return const MegaMillionsScreen();
    return ColorLotoScreen();
  }
}
