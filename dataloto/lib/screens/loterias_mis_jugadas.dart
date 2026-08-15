import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dataloto/services/api_service.dart';
import '../styles/app_text_styles.dart';
import '../styles/colores.dart';
import '../widgets/contenedor3.dart';
import '../widgets/custom_app_bar.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

class LoteriasMisJugadasScreen extends StatefulWidget {
  final String loteria;
  final String route;

  const LoteriasMisJugadasScreen({super.key, required this.loteria, required this.route});

  @override
  State<LoteriasMisJugadasScreen> createState() => _LoteriasMisJugadasScreenState();
}

class _LoteriasMisJugadasScreenState extends State<LoteriasMisJugadasScreen> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _jugadasList = [];
  bool _cargando = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _cargarJugadas();
  }

  Future<void> _cargarJugadas() async {
    _userId = await _storage.read(key: 'user_id');
    try {
      final response = await ApiService.listarJugadasGenerica(widget.route);
      if (mounted) {
        setState(() {
          _jugadasList = List<Map<String, dynamic>>.from(response);
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _borrarJugada(int id) async {
    if (_userId == null) return;
    try {
      await ApiService.borrarJugadaGenerica(widget.route, id, _userId!);
      _cargarJugadas();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: AppColors.blackfondo,
        title: Text(l10n?.misJugadasConLoteria(widget.loteria) ?? "Mis Jugadas - ${widget.loteria}", style: AppTextStyles.h2),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.yellow), onPressed: () => Navigator.pop(context)),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.amber))
          : _jugadasList.isEmpty
              ? Center(child: Text(l10n?.noTienesJugadasGuardadas ?? "No tienes jugadas guardadas", style: AppTextStyles.mensajeSecundario))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _jugadasList.length,
                  itemBuilder: (context, index) {
                    final j = _jugadasList[index];
                    final nums = (j["numeros"] as List).join(" - ");
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(nums, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _borrarJugada(j["id"])),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
