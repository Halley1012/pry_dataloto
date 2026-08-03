import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../styles/colores.dart';
import '../styles/app_text_styles.dart';
import '../widgets/contenedor3.dart';

class EstadisticasLottoAmericaScreen extends StatefulWidget {
  const EstadisticasLottoAmericaScreen({super.key});
  @override
  State<EstadisticasLottoAmericaScreen> createState() => _EstadisticasLottoAmericaScreenState();
}

class _EstadisticasLottoAmericaScreenState extends State<EstadisticasLottoAmericaScreen> {
  bool cargando = true;
  List<Map<String, dynamic>> todosResultados = [];

  @override
  void initState() { super.initState(); _cargarDatos(); }

  Future<void> _cargarDatos() async {
    try {
      final res = await http.get(Uri.parse("https://pry-dataloto.onrender.com/lotto_america/historico_completo"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() => todosResultados = List<Map<String, dynamic>>.from(data["resultados"]));
      }
    } finally { if (mounted) setState(() => cargando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: AppColors.blackfondo, title: Text("Estadísticas Lotto America", style: AppTextStyles.h2), leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.yellow), onPressed: () => Navigator.pop(context))),
      body: cargando ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          AppContainer3(child: Column(children: [
            Text("Resumen Histórico", style: AppTextStyles.h2),
            const SizedBox(height: 10),
            Text("Total sorteos: ${todosResultados.length}", style: AppTextStyles.mensajeSecundario),
          ])),
        ]),
      ),
    );
  }
}
