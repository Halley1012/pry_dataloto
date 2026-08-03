import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dataloto/services/api_service.dart';
import '../services/cache_service.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/widgets/contenedor3.dart';
import 'package:dataloto/widgets/custom_app_bar.dart';

class LoteriasMisJugadasGenericaScreen extends StatefulWidget {
  final String loteriaNombre;
  final String loteriaRoute;

  const LoteriasMisJugadasGenericaScreen({
    super.key,
    required this.loteriaNombre,
    required this.loteriaRoute,
  });

  @override
  State<LoteriasMisJugadasGenericaScreen> createState() => _LoteriasMisJugadasGenericaScreenState();
}

class _LoteriasMisJugadasGenericaScreenState extends State<LoteriasMisJugadasGenericaScreen> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _jugadasList = [];
  Set<int> _selectedIds = {};
  bool _cargando = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _cargarJugadas();
  }

  Future<void> _cargarJugadas() async {
    final uId = await _storage.read(key: 'user_id');
    final cached = await CacheService.getJson('user_jugadas_${widget.loteriaRoute}_${uId ?? "anon"}');
    if (cached != null && mounted) {
      setState(() {
        _userId = uId;
        _jugadasList = List<Map<String, dynamic>>.from(cached);
        _cargando = false;
      });
    }

    if (!mounted) return;
    if (_jugadasList.isEmpty) setState(() => _cargando = true);

    try {
      final response = await ApiService.listarJugadasGenerica(widget.loteriaRoute);
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _userId = uId;
          _jugadasList = data;
          _selectedIds.clear();
          _cargando = false;
        });
        CacheService.setJson('user_jugadas_${widget.loteriaRoute}_${uId ?? "anon"}', data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _jugadasList.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _jugadasList
            .map((j) => j["id"] as int? ?? 0)
            .where((id) => id > 0)
            .toSet();
      }
    });
  }

  Future<void> _eliminarSeleccionadas() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Text(
              "Eliminar jugadas",
              style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          "¿Estás seguro de que deseas eliminar las ${_selectedIds.length} jugadas seleccionadas?",
          style: AppTextStyles.mensajeSecundario,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || _userId == null) return;

    final idsParaEliminar = Set<int>.from(_selectedIds);
    setState(() {
      _jugadasList.removeWhere((j) => idsParaEliminar.contains(j["id"]));
      _selectedIds.clear();
    });

    for (final id in idsParaEliminar) {
      try {
        await ApiService.borrarJugadaGenerica(widget.loteriaRoute, id, _userId!);
      } catch (_) {}
    }
  }

  Widget _build3DBall(int? numero, {Color baseColor = const Color(0xFFF33A21), double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            baseColor.withValues(alpha: 0.95),
            baseColor.withValues(alpha: 0.75),
            baseColor.withValues(alpha: 0.5),
          ],
          center: Alignment.topLeft,
          radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "–",
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: CustomAppBar(
        title: "Mis Jugadas - ${widget.loteriaNombre}",
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
          : _jugadasList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.style_outlined, color: Colors.grey, size: 64),
                      const SizedBox(height: 16),
                      Text("No tienes jugadas guardadas aún", style: AppTextStyles.h2),
                      const SizedBox(height: 8),
                      Text(
                        "Genera y guarda combinaciones en la pantalla de ${widget.loteriaNombre}.",
                        style: AppTextStyles.mensajeSecundario,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: _toggleSelectAll,
                            icon: Icon(
                              _selectedIds.length == _jugadasList.length
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: AppColors.yellow,
                            ),
                            label: Text(
                              _selectedIds.length == _jugadasList.length
                                  ? "Deseleccionar todas"
                                  : "Seleccionar todas",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          if (_selectedIds.isNotEmpty)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: _eliminarSeleccionadas,
                              icon: const Icon(Icons.delete, size: 18, color: Colors.white),
                              label: Text("Eliminar (${_selectedIds.length})", style: const TextStyle(color: Colors.white)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _jugadasList.length,
                          itemBuilder: (context, index) {
                            final jugada = _jugadasList[index];
                            final id = jugada["id"] as int? ?? 0;
                            final isSelected = _selectedIds.contains(id);
                            final numeros = (jugada["numeros"] as List? ?? []).map((e) => int.tryParse(e.toString()) ?? 0).toList();

                            return AppContainer3(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedIds.remove(id);
                                    } else {
                                      _selectedIds.add(id);
                                    }
                                  });
                                },
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: AppColors.yellow,
                                      checkColor: Colors.black,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedIds.add(id);
                                          } else {
                                            _selectedIds.remove(id);
                                          }
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: List.generate(numeros.length, (bIndex) {
                                          final isLast = bIndex == numeros.length - 1;
                                          return _build3DBall(
                                            numeros[bIndex],
                                            baseColor: isLast ? Colors.redAccent : Colors.amber,
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
