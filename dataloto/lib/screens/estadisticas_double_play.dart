import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../styles/colores.dart';
import '../styles/app_text_styles.dart';
import '../widgets/contenedor3.dart';
import '../services/cache_service.dart';

class EstadisticasDoublePlayScreen extends StatefulWidget {
  const EstadisticasDoublePlayScreen({super.key});

  @override
  State<EstadisticasDoublePlayScreen> createState() => _EstadisticasDoublePlayScreenState();
}

class _EstadisticasDoublePlayScreenState extends State<EstadisticasDoublePlayScreen> {
  bool cargando = true;
  String? errorMensaje;
  List<Map<String, dynamic>> todosResultados = [];
  Map<String, dynamic>? prediccionIA;
  int limiteFiltro = 50;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final cachedHist = await CacheService.getJson('double_play_historico_completo');
    final cachedPred = await CacheService.getJson('double_play_prediccion');

    if (cachedHist != null && cachedHist["resultados"] != null && mounted) {
      setState(() {
        todosResultados = List<Map<String, dynamic>>.from(cachedHist["resultados"]);
        if (cachedPred != null) prediccionIA = cachedPred;
        cargando = false;
      });
    }

    try {
      final resHist = await http.get(Uri.parse("https://pry-dataloto.onrender.com/double_play/historico_completo"));
      final resPred = await http.get(Uri.parse("https://pry-dataloto.onrender.com/double_play"));

      if (resHist.statusCode == 200) {
        final data = jsonDecode(resHist.body);
        if (data["resultados"] != null && mounted) {
          setState(() => todosResultados = List<Map<String, dynamic>>.from(data["resultados"]));
          CacheService.setJson('double_play_historico_completo', data);
        }
      }
      if (resPred.statusCode == 200) {
        final dataP = jsonDecode(resPred.body);
        if (mounted) setState(() => prediccionIA = dataP);
        CacheService.setJson('double_play_prediccion', dataP);
      }
    } catch (e) {
      if (todosResultados.isEmpty) errorMensaje = "Error cargando datos.";
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: AppColors.blackfondo,
        elevation: 0,
        centerTitle: true,
        title: Text("Estadísticas Double Play", style: AppTextStyles.h2),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.yellow), onPressed: () => Navigator.pop(context)),
      ),
      body: cargando 
        ? const Center(child: CircularProgressIndicator(color: AppColors.amber))
        : Center(child: Text("Panel avanzado en desarrollo...", style: AppTextStyles.mensajeSecundario)),
    );
  }
}
