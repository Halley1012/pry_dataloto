import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../styles/app_text_styles.dart';
import '../styles/colores.dart';

class JugadasListGenerico extends StatefulWidget {
  final AnimationController jugadasController;
  final String loteriaRoute;

  const JugadasListGenerico({
    super.key,
    required this.jugadasController,
    required this.loteriaRoute,
  });

  @override
  JugadasListGenericoState createState() => JugadasListGenericoState();
}

class JugadasListGenericoState extends State<JugadasListGenerico> with SingleTickerProviderStateMixin {
  List<dynamic> _jugadasList = [];
  List<dynamic> get jugadas => _jugadasList;
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
    if (mounted) setState(() {});
  }

  Future<void> reload() async {
    await _fetchJugadas();
  }

  Future<void> _fetchJugadas() async {
    try {
      final jugadas = await ApiService.listarJugadasGenerica(widget.loteriaRoute);
      if (!mounted) return;
      setState(() {
        _jugadasList = jugadas;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> addJugada(List<int> numeros, String userId, {int? balotaRoja, String? fechaSorteo}) async {
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempJugada = {
      "id": tempId,
      "numeros": numeros,
      "user_id": userId,
      if (balotaRoja != null) "balota_roja": balotaRoja,
      "fecha_sorteo": fechaSorteo,
      "fecha": fechaSorteo ?? DateTime.now().toIso8601String(),
      "created_at": DateTime.now().toIso8601String(),
    };

    setState(() {
      _jugadasList.add(tempJugada);
    });
    widget.jugadasController.reset();
    widget.jugadasController.forward();

    try {
      final newJugada = await ApiService.crearJugadaGenerica(
        widget.loteriaRoute,
        numeros,
        userId,
        balotaRoja: balotaRoja,
        fechaSorteo: fechaSorteo,
      );
      if (!mounted) return;
      setState(() {
        final index = _jugadasList.indexWhere((j) => j["id"] == tempId);
        if (index != -1) {
          _jugadasList[index] = newJugada;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _jugadasList.removeWhere((j) => j["id"] == tempId);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al agregar jugada: $e')));
    }
  }

  Future<void> deleteJugada(int jugadaId) async {
    if (!mounted || userId == null) return;
    final removedJugada = _jugadasList.firstWhere(
      (j) => j["id"] == jugadaId,
      orElse: () => {},
    );

    if (removedJugada.isEmpty) return;

    setState(() {
      _jugadasList.removeWhere((j) => j["id"] == jugadaId);
    });

    try {
      await ApiService.borrarJugadaGenerica(widget.loteriaRoute, jugadaId, userId!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _jugadasList.insert(0, removedJugada);
      });
    }
  }

  bool _esDeHoy(dynamic dateRaw) {
    if (dateRaw == null) return true;
    try {
      final parsed = DateTime.parse(dateRaw.toString()).toLocal();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final parsedDateOnly = DateTime(parsed.year, parsed.month, parsed.day);
      return !parsedDateOnly.isBefore(todayStart);
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final jugadas = _jugadasList.where((j) => _esDeHoy(j["fecha_guardado"] ?? j["created_at"] ?? j["fecha"])).toList();

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
                      const Icon(Icons.casino, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text("Tus jugadas para hoy", style: AppTextStyles.mensajeImportante),
                    ],
                  ),
                  Text("Total: ${jugadas.length}", style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white70, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 2),
              jugadas.isEmpty
                  ? Text("Aún no has guardado jugadas", style: AppTextStyles.mensajeSecundario)
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: jugadas.length,
                      itemBuilder: (context, index) {
                        final jugada = jugadas[index];
                        final rawNums = (jugada["numeros"] as List<dynamic>? ?? []).map((e) => int.tryParse(e.toString()) ?? 0).toList();
                        final bRoja = jugada["balota_roja"] ?? jugada["balotaroja"];
                        final numeros = (rawNums.length == 5 && bRoja != null)
                            ? [...rawNums, int.tryParse(bRoja.toString()) ?? 0]
                            : rawNums;

                        final Color color = [
                          Colors.blueAccent,
                          Colors.purpleAccent,
                          Colors.tealAccent,
                          Colors.orangeAccent,
                          Colors.greenAccent,
                          Colors.pinkAccent,
                          Colors.indigoAccent,
                          Colors.cyanAccent,
                          Colors.deepOrangeAccent,
                          Colors.amberAccent,
                        ][index % 10];

                        return Container(
                          key: Key(jugada["id"].toString()),
                          margin: const EdgeInsets.symmetric(vertical: 5.0),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.15), Colors.black.withValues(alpha: 0.1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color: color.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Nro. ${index + 1}", style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white70, fontSize: 13)),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: numeros.isEmpty
                                      ? [Text("Sin números", style: AppTextStyles.mensajeSecundario)]
                                      : numeros.asMap().entries.map((entry) {
                                          int ballIndex = entry.key;
                                          int numero = entry.value;
                                          bool isSuperBall = ballIndex == numeros.length - 1;

                                          Widget ball = _build3DBall(
                                            numero,
                                            baseColor: isSuperBall ? Colors.redAccent : color,
                                            size: 35,
                                          );

                                          if (index == jugadas.length - 1) {
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                              child: ScaleTransition(
                                                scale: Tween<double>(begin: 0.0, end: 1.0).animate(
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
                                            padding: const EdgeInsets.symmetric(horizontal: 3.0),
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

  Widget _build3DBall(int? numero, {Color baseColor = const Color(0xFFF33A21), double size = 36}) {
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
            offset: const Offset(3, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: 0.3),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "–",
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: numero != null ? Colors.white : Colors.white54,
            shadows: numero != null
                ? [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
