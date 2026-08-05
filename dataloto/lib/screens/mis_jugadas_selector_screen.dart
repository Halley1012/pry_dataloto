import 'package:flutter/material.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/utils/pais_helper.dart';
import 'package:dataloto/screens/baloto_mis_jugadas.dart';
import 'package:dataloto/screens/miloto_mis_jugadas.dart';
import 'package:dataloto/screens/loterias_mis_jugadas_generica.dart';

class MisJugadasSelectorScreen extends StatefulWidget {
  const MisJugadasSelectorScreen({super.key});

  @override
  State<MisJugadasSelectorScreen> createState() => _MisJugadasSelectorScreenState();
}

class _MisJugadasSelectorScreenState extends State<MisJugadasSelectorScreen> {
  List<Map<String, dynamic>> _loterias = [];
  List<Map<String, dynamic>> _filteredLoterias = [];
  List<Map<String, dynamic>> _paises = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarLoterias();
  }

  Future<void> _cargarLoterias() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Obtener qué loterías tienen jugadas para este usuario
      final activas = await ApiService.getLoteriasConJugadas();
      
      // Si no hay ninguna, paramos aquí
      if (activas.isEmpty && mounted) {
        setState(() {
          _loterias = [];
          _filteredLoterias = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Obtener la lista completa de loterías para el mapeo
      final paisesRaw = await ApiService.getPaises();
      _paises = paisesRaw.cast<Map<String, dynamic>>();
      
      List<Map<String, dynamic>> todas = [];
      final listadoFutures = _paises.map((p) => ApiService.getLoteriasPorPais(p['id'].toString()).catchError((e) => []));
      final resultadosLoterias = await Future.wait(listadoFutures);

      for (int i = 0; i < _paises.length; i++) {
        final pId = _paises[i]['id'].toString();
        final list = resultadosLoterias[i];
        for (var item in list) {
          final mapItem = Map<String, dynamic>.from(item as Map);
          mapItem['pais_id'] = mapItem['pais_id'] ?? pId;
          
          // 3. Filtrar: Solo agregar si está en la lista de 'activas'
          final route = _getRouteFromName(mapItem['nombre'] ?? "");
          if (activas.contains(route)) {
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getRouteFromName(String nombre) {
    final n = nombre.toLowerCase().trim();
    if (n.contains("baloto")) return "bloto";
    if (n.contains("miloto")) return "mloto";
    if (n.contains("colorloto")) return "colorloto";
    if (n.contains("powerball")) return "powerball";
    if (n.contains("mega millions")) return "megamillions";
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
    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text(
                "Mis Jugadas",
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            _buildSearchBar(),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                : _buildLotteryList(),
            ),
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
                "Aún no tienes jugadas",
                style: AppTextStyles.h2.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Empieza a guardar tus números favoritos desde la sección Explorar.",
                style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _filteredLoterias.length,
      itemBuilder: (context, index) {
        final loteria = _filteredLoterias[index];
        return _buildLotteryItem(loteria);
      },
    );
  }

  Widget _buildLotteryItem(Map<String, dynamic> loteria) {
    final nombre = loteria["nombre"] ?? "";
    final paisNombre = _getPaisNombre(loteria["pais_id"]);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => _navigateToJugadas(nombre),
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
              scale: 1.8,
              child: Text(
                PaisHelper.getBanderaEmoji(paisNombre),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        ),
        title: Text(
          nombre,
          style: AppTextStyles.mensajeImportante.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "Ver mis jugadas guardadas",
          style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white38, fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
      ),
    );
  }

  void _navigateToJugadas(String nombre) {
    final route = _getRouteFromName(nombre);
    Widget screen;
    
    if (route == "bloto") {
      screen = const BalotoMisJugadasScreen();
    } else if (route == "mloto") {
      screen = const MilotoMisJugadasScreen();
    } else {
      screen = LoteriasMisJugadasGenericaScreen(
        loteriaNombre: nombre,
        loteriaRoute: route,
      );
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      _cargarLoterias();
    });
  }
}
