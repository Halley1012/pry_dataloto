import 'package:dataloto/screens/baloto.dart';
import 'package:dataloto/screens/color_loto.dart';
import 'package:dataloto/screens/miloto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/services/cache_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/widgets/custom_app_bar.dart';

class LoteriasPais extends StatefulWidget {
  const LoteriasPais({super.key});

  @override
  State<LoteriasPais> createState() => _LoteriasPaisState();
}

class _LoteriasPaisState extends State<LoteriasPais> {
  static const String titulo = 'Loterías por País';

  final _storage = const FlutterSecureStorage();

  List<Map<String, dynamic>> _loterias = [];
  List<Map<String, dynamic>> _paises = [];

  bool _isLoading = true;

  int? _paisSeleccionadoId;
  String _paisNombre = "Cargando...";

  @override
  void initState() {
    super.initState();
    _cargarPaises();
  }

  // ===============================
  // 🔹 CARGAR PAISES
  // ===============================
  Future<void> _cargarPaises() async {
    // ⚡ 1. Cargar desde caché local para despliegue instantáneo (0 ms)
    final cachedPaises = await CacheService.getJson('loterias_paises');
    final paisIdStr = await _storage.read(key: "pais_id");
    final int? paisId = paisIdStr != null ? int.tryParse(paisIdStr) : null;
    final cachedLoterias = paisId != null ? await CacheService.getJson('loterias_list_$paisId') : null;

    if (cachedPaises != null && mounted) {
      final paisesList = (cachedPaises as List).cast<Map<String, dynamic>>();
      final loteriasList = cachedLoterias != null ? (cachedLoterias as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
      setState(() {
        _paises = paisesList;
        _paisSeleccionadoId = paisId;
        _loterias = loteriasList;
        _paisNombre = paisesList
            .firstWhere(
              (p) => p['id'] == paisId,
              orElse: () => {'nombre': 'Seleccione país'},
            )['nombre']
            .toString();
        _isLoading = false;
      });
    }

    if (!mounted) return;
    if (_paises.isEmpty) setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ApiService.getPaises(),
        if (paisId != null)
          ApiService.getLoteriasPorPais(paisId.toString())
        else
          Future.value(<Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;

      final paises = (results[0] as List).cast<Map<String, dynamic>>();
      final loterias = (results[1] as List).cast<Map<String, dynamic>>();

      setState(() {
        _paises = paises;
        _paisSeleccionadoId = paisId;
        _loterias = loterias;
        _paisNombre = paises
            .firstWhere(
              (p) => p['id'] == paisId,
              orElse: () => {'nombre': 'Seleccione país'},
            )['nombre']
            .toString();
        _isLoading = false;
      });

      // 💾 Guardar en caché local
      CacheService.setJson('loterias_paises', paises);
      if (paisId != null) {
        CacheService.setJson('loterias_list_$paisId', loterias);
      }
    } catch (e) {
      debugPrint("❌ Error cargando datos iniciales: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ===============================
  // 🔹 CARGAR LOTERÍAS
  // ===============================
  Future<void> _loadLoterias(int paisId) async {
    // ⚡ 1. Cargar desde caché local de inmediato (0 ms)
    final cached = await CacheService.getJson('loterias_list_$paisId');
    if (cached != null && mounted) {
      setState(() {
        _loterias = (cached as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    }

    if (!mounted) return;
    if (_loterias.isEmpty) setState(() => _isLoading = true);

    try {
      final data = await ApiService.getLoteriasPorPais(paisId.toString());

      if (!mounted) return;
      final loteriasList = data.cast<Map<String, dynamic>>();
      setState(() {
        _loterias = loteriasList;
        _isLoading = false;
      });

      // 💾 Guardar en caché local
      CacheService.setJson('loterias_list_$paisId', loteriasList);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ===============================
  // 🔹 UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          CustomSliverAppBar(
            title: titulo,
            pinned: true,
            floating: true,
            snap: true,
          ),

          // 🔽 FILTRO PAÍS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildPaisDropdown(),
            ),
          ),

          // 🔄 LOADING
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.yellow),
              ),
            )
          else if (_loterias.isEmpty)
            // ❌ SIN LOTERÍAS
            SliverFillRemaining(
              child: Center(
                child: Text(
                  "No hay loterías para este país",
                  style: AppTextStyles.mensajeSecundario.copyWith(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            // 🎰 GRID LOTERÍAS
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 1,
                  crossAxisSpacing: 1,
                  childAspectRatio: 1.5,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final loteria = _loterias[index];
                  return _buildGameCardIcon(
                    context,
                    loteria["nombre"]?.toString() ?? "Sin nombre",
                    null,
                    AppColors.darkGray,
                    _resolveScreen(loteria["nombre"]?.toString() ?? ""),
                  );
                }, childCount: _loterias.length),
              ),
            ),
        ],
      ),
    );
  }

  // ===============================
  // 🔹 CARD LOTERÍA
  // ===============================
  Widget _buildGameCardIcon(
    BuildContext context,
    String title,
    IconData? icon,
    Color color,
    Widget destinationScreen,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destinationScreen),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        width: 140,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF282E3B), Color(0xFF191D26)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.yellow,
              ),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, size: 32, color: AppColors.grayBlue)
                  : Text(
                      title.isNotEmpty ? title[0].toUpperCase() : "?",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.grayBlue,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.mensajeImportante.copyWith(
                shadows: [
                  const Shadow(
                    blurRadius: 4,
                    color: Colors.black26,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================
  // 🔹 RESOLVER PANTALLA
  // ===============================
  Widget _resolveScreen(String? tipo) {
    switch (tipo) {
      case "Baloto / Revancha":
        return BalotoScreen();
      case "Miloto":
        return MilotoScreen();
      default:
        return ColorLotoScreen();
    }
  }

  Widget _buildPaisDropdown() {
    return DropdownButtonFormField<int>(
      value: _paisSeleccionadoId,
      isExpanded: true,
      dropdownColor: Colors.black87,
      style: AppTextStyles.mensajeSecundario,
      decoration: InputDecoration(
        labelText: "País",
        labelStyle: AppTextStyles.mensajeSecundario,
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      iconEnabledColor: AppColors.yellow,
      items: _paises.map((pais) {
        return DropdownMenuItem<int>(
          value: pais['id'],
          child: Text(pais['nombre'], style: AppTextStyles.mensajeSecundario),
        );
      }).toList(),
      onChanged: (value) async {
        if (value == null) return;

        final pais = _paises.firstWhere((p) => p['id'] == value);

        setState(() {
          _paisSeleccionadoId = value;
          _paisNombre = pais['nombre'];
        });

        await _loadLoterias(value);
      },
    );
  }
}
