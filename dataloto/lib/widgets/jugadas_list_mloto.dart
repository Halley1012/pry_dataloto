import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../styles/app_text_styles.dart';
import '../styles/colores.dart';

class JugadasListMloto extends StatefulWidget {
  final AnimationController jugadasController;

  const JugadasListMloto({super.key, required this.jugadasController});

  @override
  JugadasListMlotoState createState() => JugadasListMlotoState();
}

class JugadasListMlotoState extends State<JugadasListMloto>
    with SingleTickerProviderStateMixin {
  List<dynamic> _jugadasList = [];
  bool _isLoading = true;
  String? userId;
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    cargarUserId();
    _fetchJugadas();
  }

  Future<void> cargarUserId() async {
    userId = await storage.read(key: 'user_id');
    setState(() {});
  }

  Future<void> reload() async {
    await _fetchJugadas();
  }

  bool _esDeHoy(dynamic rawDate) {
    if (rawDate == null) return true;
    try {
      final parsed = DateTime.parse(rawDate.toString()).toLocal();
      final now = DateTime.now();
      return parsed.year == now.year &&
          parsed.month == now.month &&
          parsed.day == now.day;
    } catch (_) {
      return true;
    }
  }

  Future<void> _fetchJugadas() async {
    try {
      final jugadas = await ApiService.listarJugadasMloto();
      if (!mounted) return;
      setState(() {
        _jugadasList = jugadas;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar jugadas: $e')));
    }
  }


  Future<void> addJugada(List<int> numeros, String userId) async {
    final tempId = DateTime.now().millisecondsSinceEpoch;

    final tempJugada = {
      "id": tempId,
      "numeros": numeros,
      "user_id": userId,
      "created_at": DateTime.now().toIso8601String(),
    };

    setState(() {
      _jugadasList.add(tempJugada);
    });

    widget.jugadasController.reset();
    widget.jugadasController.forward();

    try {
      final newJugada = await ApiService.crearJugada(numeros, userId);
      if (!mounted) return;

      setState(() {
        final index = _jugadasList.indexWhere((j) => j["id"] == tempId);
        if (index != -1) {
          _jugadasList[index] = {...newJugada, "isTemp": false};
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _jugadasList.removeWhere((j) => j["id"] == tempId);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al agregar jugada')));
    }
  }

Future<void> deleteJugada(int jugadaId) async {
  if (!mounted) return;

  // 🔍 Buscar jugada antes de tocar el estado
  final removedJugada = _jugadasList.firstWhere(
    (j) => j["id"] == jugadaId,
    orElse: () => {},
  );

  if (removedJugada.isEmpty) return;

  // 🧨 Eliminación optimista
  setState(() {
    _jugadasList.removeWhere((j) => j["id"] == jugadaId);
  });

  try {
    await ApiService.borrarJugadaMloto(jugadaId, userId!);
    // silencio elegante 😌
  } catch (e) {
    if (!mounted) return;

    // 🔁 Rollback si falla el backend
    setState(() {
      _jugadasList.insert(0, removedJugada);
    });
  }
}


  @override
  void dispose() {
    if (widget.jugadasController.isAnimating) {
      widget.jugadasController.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jugadas = _jugadasList.where((j) {
      final rawDate = j["fecha_guardado"] ?? j["created_at"] ?? j["fecha"];
      return _esDeHoy(rawDate);
    }).toList();

    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.amber))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bookmark, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        "Tus jugadas para hoy",
                        style: AppTextStyles.mensajeImportante,
                      ),
                    ],
                  ),
                  Text(
                    "Total: ${jugadas.length}",
                    style: AppTextStyles.mensajeSecundario.copyWith(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              jugadas.isEmpty
                  ? Text(
                      "Aún no has guardado jugadas",
                      style: AppTextStyles.mensajeSecundario,
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: jugadas.length,
                      itemBuilder: (context, index) {
                        final jugada = jugadas[index];
                        final numeros =
                            (jugada["numeros"] as List<dynamic>? ?? [])
                                .cast<int>();

                        final List<Color> colorPalette = [
                          const Color(0xFF3B82F6),
                          const Color(0xFF8B5CF6),
                          const Color(0xFFF59E0B),
                          const Color(0xFF10B981),
                          const Color(0xFFEC4899),
                          const Color(0xFF6366F1),
                          const Color(0xFF06B6D4),
                          const Color(0xFFEAB308),
                          const Color(0xFF14B8A6),
                          const Color(0xFFF43F5E),
                        ];

                        final Color color =
                            colorPalette[index % colorPalette.length];

                        // Fondo similar al Bloto (gradiente + borde sutil)
                        return Container(
                          key: Key(jugada["id"].toString()),
                          margin: const EdgeInsets.symmetric(vertical: 5.0),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [
                                color.withOpacity(0.15),
                                Colors.black.withOpacity(0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color: color.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Nro. ${index + 1}",
                                style: AppTextStyles.mensajeSecundario.copyWith(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: numeros.isEmpty
                                      ? [
                                          Text(
                                            "Sin números",
                                            style:
                                                AppTextStyles.mensajeSecundario,
                                          ),
                                        ]
                                       : numeros.asMap().entries.map((entry) {
                                           int ballIndex = entry.key;
                                           int numero = entry.value;

                                           Widget ball = _build3DBall(
                                             numero,
                                             baseColor: color,
                                             size: 37,
                                           );

                                           if (index == jugadas.length - 1) {
                                             return Padding(
                                               padding: const EdgeInsets.symmetric(
                                                 horizontal: 3.0,
                                               ),
                                               child: ScaleTransition(
                                                 scale: Tween<double>(begin: 0.0, end: 1.0)
                                                     .animate(
                                                   CurvedAnimation(
                                                     parent: widget.jugadasController,
                                                     curve: Interval(
                                                       (ballIndex * 0.15).clamp(0.0, 1.0),
                                                       1.0,
                                                       curve: Curves.elasticOut,
                                                     ),
                                                   ),
                                                 ),
                                                 child: ball,
                                               ),
                                             );
                                           }

                                           return Padding(
                                             padding: const EdgeInsets.symmetric(
                                               horizontal: 3.0,
                                             ),
                                             child: ball,
                                           );
                                         }).toList(),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => deleteJugada(jugada["id"]),
                                child: const Icon(
                                  Icons.delete_forever_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          );
  }

  Widget _build3DBall(
    int? numero, {
    Color baseColor = const Color(0xFFF33A21),
    double size = 36,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            baseColor.withOpacity(0.95),
            baseColor.withOpacity(0.75),
            baseColor.withOpacity(0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.6),
            offset: const Offset(2, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(1, 1),
            blurRadius: 4,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.2),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "–",
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.7),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
