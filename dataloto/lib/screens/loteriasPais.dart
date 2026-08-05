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
import 'package:dataloto/widgets/custom_app_bar.dart';
import 'package:dataloto/utils/pais_helper.dart';


class LoteriasPais extends StatefulWidget {
  const LoteriasPais({super.key});

  @override
  State<LoteriasPais> createState() => _LoteriasPaisState();
}

class _LoteriasPaisState extends State<LoteriasPais> {
  static const String titulo = 'Loterías por País';

  final _storage = const FlutterSecureStorage();

  List<Map<String, dynamic>> _loterias = [];
  List<Map<String, dynamic>> _filteredLoterias = [];
  List<Map<String, dynamic>> _paises = [];
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isShowingAll = false;

  @override
  void initState() {
    super.initState();
    _cargarExplorarMundial();
  }

  Future<void> _cargarExplorarMundial() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Obtener todos los países
      final paisesRaw = await ApiService.getPaises();
      _paises = paisesRaw.cast<Map<String, dynamic>>();
      
      List<Map<String, dynamic>> todas = [];
      
      // 2. Intentar cargar loterías de TODOS los países para la vista "Explorar Mundial"
      // Usamos Future.wait para hacerlo en paralelo y que sea rápido
      final listadoFutures = _paises.map((p) => ApiService.getLoteriasPorPais(p['id'].toString()).catchError((e) {
        debugPrint("Error cargando loterías para país ${p['id']}: $e");
        return [];
      }));

      final resultadosLoterias = await Future.wait(listadoFutures);

      for (int i = 0; i < _paises.length; i++) {
        final pId = _paises[i]['id'].toString();
        final list = resultadosLoterias[i];
        if (list is List) {
          for (var item in list) {
            final mapItem = Map<String, dynamic>.from(item as Map);
            // Aseguramos que el item tenga el pais_id para el filtrado del buscador
            mapItem['pais_id'] = mapItem['pais_id'] ?? pId;
            todas.add(mapItem);
          }
        }
      }

      if (mounted) {
        setState(() {
          _loterias = todas;
          _filteredLoterias = todas;
          _isLoading = false;
        });
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
    // Si hay búsqueda activa, mostramos todo lo que coincida (sin límite de 2)
    if (_searchController.text.trim().isNotEmpty) {
      return _filteredLoterias;
    }
    
    if (_isShowingAll) {
      return _filteredLoterias;
    }

    // Lógica para mostrar máximo 2 por país
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
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                : _buildLotteryList(),
            ),
            _buildFooterButton(),
          ],
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text("Destacadas en el mundo", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final loteria = displayList[index];
              return _buildExploreItem(loteria);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExploreItem(Map<String, dynamic> loteria) {
    final nombre = loteria["nombre"] ?? "";
    final paisNombre = _getPaisNombre(loteria["pais_id"]);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _resolveScreen(nombre))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        leading: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: Center(
            child: Transform.scale(
              scale: 1.8, // Escala el emoji para que llene el círculo
              child: Text(
                PaisHelper.getBanderaEmoji(paisNombre),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        ),
        title: Text(
          nombre,
          style: AppTextStyles.mensajeImportante.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          paisNombre,
          style: AppTextStyles.mensajeSecundario.copyWith(
            color: Colors.white38,
            fontSize: 12,
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
