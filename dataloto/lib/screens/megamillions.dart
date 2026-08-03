import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/services/cache_service.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/widgets/carrusel.dart';
import 'package:dataloto/widgets/custom_app_bar.dart';

class MegaMillionsScreen extends StatefulWidget {
  const MegaMillionsScreen({super.key});

  @override
  State<MegaMillionsScreen> createState() => _MegaMillionsScreenState();
}

class _MegaMillionsScreenState extends State<MegaMillionsScreen> with TickerProviderStateMixin {
  static const String loteriaNombre = 'Mega Millions';
  static const String backendRoute = 'megamillions';
  static const int maxSeleccion = 5;
  static const int totalBalotas = 70;
  static const int totalEspeciales = 25;

  final storage = const FlutterSecureStorage();
  List<int> seleccionados = [];
  int? balotaEspecialSeleccionada;
  List<int> listaProbables = [];
  List<int> listaBalotaEspecial = [];
  List<Map<String, dynamic>> ultimosResultados = [];
  List<Map<String, dynamic>> jugadasList = [];
  bool cargando = false;
  String? fechaPrediccion;
  String? userId;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _shineController;
  List<Map<String, dynamic>> anuncios = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceAnimation = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    );
    _bounceController.forward();

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;

    final cached = await CacheService.getJson('${backendRoute}_prediccion');
    if (cached != null && cached["numeros"] != null && mounted) {
      setState(() {
        listaProbables = (cached["numeros"] as List).map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
        listaBalotaEspecial = (cached["balotaroja"] as List).map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
        fechaPrediccion = cached["fecha"]?.toString();
        cargando = false;
      });
    }

    if (listaProbables.isEmpty && mounted) {
      setState(() => cargando = true);
    }

    try {
      userId = await storage.read(key: 'user_id');
      await Future.wait([
        _fetchPrediccion(),
        _fetchUltimosResultados(),
        _fetchJugadas(),
      ]);
    } catch (e) {
      debugPrint("❌ Error cargando Mega Millions: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _fetchPrediccion() async {
    try {
      final response = await http.get(Uri.parse("${ApiService.baseUrl}/$backendRoute"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["numeros"] != null && mounted) {
          setState(() {
            listaProbables = (data["numeros"] as List).map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
            listaBalotaEspecial = (data["balotaroja"] as List).map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e != 0).toList();
            fechaPrediccion = data["fecha"]?.toString();
          });
          CacheService.setJson('${backendRoute}_prediccion', data);
        }
      }
    } catch (e) {
      debugPrint("❌ Error al obtener predicción de Mega Millions: $e");
    }
  }

  Future<void> _fetchUltimosResultados() async {
    try {
      final response = await http.get(Uri.parse("${ApiService.baseUrl}/$backendRoute/ultimos5"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["resultados"] != null && mounted) {
          setState(() {
            ultimosResultados = List<Map<String, dynamic>>.from(data["resultados"]);
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error al obtener últimos resultados: $e");
    }
  }

  Future<void> _fetchJugadas() async {
    try {
      final res = await ApiService.listarJugadasGenerica(backendRoute);
      if (mounted) {
        setState(() {
          jugadasList = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (_) {}
  }

  Future<void> _guardarJugada() async {
    if (seleccionados.length != maxSeleccion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar exactamente 5 balotas blancas')),
      );
      return;
    }
    if (balotaEspecialSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar 1 Mega Ball roja')),
      );
      return;
    }

    final uId = userId ?? await storage.read(key: 'user_id');
    if (uId == null || uId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para guardar jugadas')),
      );
      return;
    }

    try {
      final jugadaCompleta = [...seleccionados, balotaEspecialSeleccionada!];
      await ApiService.crearJugadaGenerica(backendRoute, jugadaCompleta, uId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ ¡Jugada de Mega Millions guardada exitosamente!')),
      );
      _fetchJugadas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar jugada: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          const CustomSliverAppBar(
            title: loteriaNombre,
            pinned: true,
            floating: true,
            snap: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  if (anuncios.isNotEmpty) ...[
                    PublicidadCarrusel(publicidades: anuncios),
                    const SizedBox(height: 16),
                  ],
                  _buildSeccionPrediccion(),
                  const SizedBox(height: 24),
                  _buildSeccionSeleccion(),
                  const SizedBox(height: 24),
                  _buildSeccionResultados(),
                  const SizedBox(height: 24),
                  _buildSeccionMisJugadas(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionPrediccion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.yellow.withOpacity(0.3)),
      ),
      child: Column(
        crossAlignment: CrossAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "🔮 Predicción $loteriaNombre",
                style: AppTextStyles.tituloPrincipal.copyWith(fontSize: 18, color: AppColors.yellow),
              ),
              if (fechaPrediccion != null)
                Text(
                  "Sorteo: $fechaPrediccion",
                  style: AppTextStyles.mensajeSecundario.copyWith(fontSize: 12, color: Colors.white70),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Top 20 Balotas Blancas con Mayor Probabilidad:",
            style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          if (cargando)
            const Center(child: CircularProgressIndicator(color: AppColors.yellow))
          else if (listaProbables.isEmpty)
            Text("No hay predicciones disponibles.", style: AppTextStyles.mensajeSecundario)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: listaProbables.take(20).map((n) {
                return ScaleTransition(
                  scale: _bounceAnimation,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "$n",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          Text(
            "Mega Ball Propuesta:",
            style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          if (listaBalotaEspecial.isNotEmpty)
            Wrap(
              spacing: 8,
              children: listaBalotaEspecial.take(5).map((r) {
                return Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF4D4D), Color(0xFF990000)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$r",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSeccionSeleccion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAlignment: CrossAlignment.start,
        children: [
          Text(
            "🎰 Simular / Crear Jugada",
            style: AppTextStyles.tituloPrincipal.copyWith(fontSize: 18, color: AppColors.yellow),
          ),
          const SizedBox(height: 8),
          Text(
            "Selecciona 5 balotas blancas (1-$totalBalotas) y 1 Mega Ball (1-$totalEspeciales):",
            style: AppTextStyles.mensajeSecundario,
          ),
          const SizedBox(height: 12),
          Text("Balotas Blancas (${seleccionados.length}/$maxSeleccion):", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: totalBalotas,
            itemBuilder: (context, idx) {
              final val = idx + 1;
              final selected = seleccionados.contains(val);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      seleccionados.remove(val);
                    } else if (seleccionados.length < maxSeleccion) {
                      seleccionados.add(val);
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.yellow : const Color(0xFF2A2A2A),
                    border: Border.all(color: selected ? Colors.white : Colors.white24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$val",
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text("Mega Ball (1-$totalEspeciales):", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: totalEspeciales,
            itemBuilder: (context, idx) {
              final val = idx + 1;
              final selected = balotaEspecialSeleccionada == val;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    balotaEspecialSeleccionada = selected ? null : val;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.redAccent : const Color(0xFF2A2A2A),
                    border: Border.all(color: selected ? Colors.white : Colors.white24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$val",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _guardarJugada,
            icon: const Icon(Icons.save, color: Colors.black),
            label: const Text("Guardar Jugada", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.yellow,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionResultados() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAlignment: CrossAlignment.start,
        children: [
          Text(
            "📊 Últimos 5 Sorteos",
            style: AppTextStyles.tituloPrincipal.copyWith(fontSize: 18, color: AppColors.yellow),
          ),
          const SizedBox(height: 12),
          if (ultimosResultados.isEmpty)
            Text("Cargando resultados...", style: AppTextStyles.mensajeSecundario)
          else
            Column(
              children: ultimosResultados.map((res) {
                final fecha = res["fecha"] ?? "";
                final numList = (res["numeros"] as List? ?? []).map((e) => int.tryParse(e.toString()) ?? 0).toList();
                final blancas = numList.length >= 6 ? numList.sublist(0, 5) : numList;
                final roja = numList.length >= 6 ? numList.last : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282E3B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(fecha, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Row(
                        children: [
                          ...blancas.map((n) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                                child: Text("$n", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              )),
                          if (roja != null)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
                              child: Text("$roja", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSeccionMisJugadas() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAlignment: CrossAlignment.start,
        children: [
          Text(
            "📝 Mis Jugadas Guardadas",
            style: AppTextStyles.tituloPrincipal.copyWith(fontSize: 18, color: AppColors.yellow),
          ),
          const SizedBox(height: 12),
          if (jugadasList.isEmpty)
            Text("No tienes jugadas guardadas para esta lotería.", style: AppTextStyles.mensajeSecundario)
          else
            Column(
              children: jugadasList.map((j) {
                final jId = j["id"];
                final nums = (j["numeros"] as List? ?? []).map((e) => int.tryParse(e.toString()) ?? 0).toList();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282E3B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(nums.join(" - "), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          if (jId != null && userId != null) {
                            await ApiService.borrarJugadaGenerica(backendRoute, jId, userId!);
                            _fetchJugadas();
                          }
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
