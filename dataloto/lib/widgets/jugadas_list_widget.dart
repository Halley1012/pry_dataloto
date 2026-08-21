import 'package:flutter/material.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../styles/app_text_styles.dart';
import '../styles/colores.dart';

class JugadasListWidget extends StatefulWidget {
  final AnimationController jugadasController;
  final String loteriaRoute;
  final String? loteriaNombre;

  const JugadasListWidget({
    super.key,
    required this.jugadasController,
    required this.loteriaRoute,
    this.loteriaNombre,
  });

  @override
  JugadasListWidgetState createState() => JugadasListWidgetState();
}

class JugadasListWidgetState extends State<JugadasListWidget>
    with SingleTickerProviderStateMixin {
  List<dynamic> _jugadasList = [];
  List<dynamic> get jugadas => _jugadasList;
  bool _isLoading = true;
  String? userId;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await cargarUserId();
    await _cargarJugadasDesdeCache();
    await _fetchJugadas();
  }

  Future<void> cargarUserId() async {
    final uidInt = await ApiService.getUserId();
    userId = uidInt?.toString();
    if (mounted) setState(() {});
  }

  String get _cacheKey => 'jugadas_list_${widget.loteriaRoute}_${userId ?? "anon"}';

  Future<void> _cargarJugadasDesdeCache() async {
    final cached = await CacheService.getJson(_cacheKey);
    if (cached != null && cached is List && mounted) {
      setState(() {
        _jugadasList = List<dynamic>.from(cached);
        _isLoading = false;
      });
    }
  }

  Future<void> reload() async {
    await _fetchJugadas(force: true);
  }

  Future<void> _fetchJugadas({bool force = false}) async {
    if (_jugadasList.isEmpty || force) {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final jugadas = await ApiService.listarJugadasGenerica(widget.loteriaRoute);
      if (!mounted) return;

      setState(() {
        _jugadasList = jugadas;
        _isLoading = false;
      });

      if (jugadas.isNotEmpty) {
        CacheService.setJson(_cacheKey, jugadas);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint("⚠️ Error cargando jugadas para ${widget.loteriaRoute}: $e");
    }
  }

  Future<void> addJugada(
    List<int> numeros,
    String uId, {
    int? balotaRoja,
    String? fechaSorteo,
  }) async {
    final tempId = DateTime.now().millisecondsSinceEpoch;
    
    // Si viene balota roja y los números son 5, asegurar que el array o campo estén listos
    final List<int> numerosCompletos = List<int>.from(numeros);
    if (balotaRoja != null && numerosCompletos.length == 5 && _usaSuperbalota) {
      numerosCompletos.add(balotaRoja);
    }

    final tempJugada = {
      "id": tempId,
      "numeros": numerosCompletos,
      "user_id": uId,
      if (balotaRoja != null) "balota_roja": balotaRoja,
      if (balotaRoja != null) "balotaroja": balotaRoja,
      "fecha_sorteo": fechaSorteo,
      "fecha": fechaSorteo ?? DateTime.now().toIso8601String(),
      "fecha_guardado": DateTime.now().toIso8601String(),
      "created_at": DateTime.now().toIso8601String(),
    };

    setState(() {
      _jugadasList.insert(0, tempJugada);
    });

    widget.jugadasController.reset();
    widget.jugadasController.forward();

    try {
      final newJugada = await ApiService.crearJugadaGenerica(
        widget.loteriaRoute,
        numeros,
        uId,
        balotaRoja: balotaRoja,
        fechaSorteo: fechaSorteo,
      );

      if (!mounted) return;
      setState(() {
        final index = _jugadasList.indexWhere((j) => j["id"] == tempId);
        if (index != -1) {
          _jugadasList[index] = newJugada.isNotEmpty ? newJugada : tempJugada;
        }
      });
      CacheService.setJson(_cacheKey, _jugadasList);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _jugadasList.removeWhere((j) => j["id"] == tempId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.errorAgregarJugada}: $e')),
      );
    }
  }

  Future<void> deleteJugada(int jugadaId) async {
    if (!mounted) return;

    if (userId == null || userId!.isEmpty) {
      await cargarUserId();
    }
    if (userId == null) return;

    final removedIndex = _jugadasList.indexWhere((j) => j["id"] == jugadaId);
    if (removedIndex == -1) return;

    final removedJugada = _jugadasList[removedIndex];

    // Eliminación optimista inmediata
    setState(() {
      _jugadasList.removeAt(removedIndex);
    });

    try {
      final ok = await ApiService.borrarJugadaGenerica(
        widget.loteriaRoute,
        jugadaId,
        userId!,
      );
      if (ok) {
        CacheService.setJson(_cacheKey, _jugadasList);
      } else {
        throw Exception("Error al borrar en el servidor");
      }
    } catch (e) {
      if (!mounted) return;
      // Rollback si falla
      setState(() {
        _jugadasList.insert(removedIndex, removedJugada);
      });
    }
  }

  bool get _usaSuperbalota {
    for (var j in _jugadasList) {
      if (j['balota_roja'] != null || j['superbalota'] != null) return true;
      final nums = j['numeros'];
      if (nums is List && nums.length > 5) return true;
    }
    return false;
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
    final l10n = AppLocalizations.of(context);
    final listaMostrar = _jugadasList;

    return _isLoading && listaMostrar.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
          )
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
                      Text(
                        l10n?.tusJugadasHoy ?? "Tus jugadas",
                        style: AppTextStyles.mensajeImportante,
                      ),
                    ],
                  ),
                  Text(
                    "${l10n?.totalLabel ?? 'Total'}: ${listaMostrar.length}",
                    style: AppTextStyles.mensajeSecundario.copyWith(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              listaMostrar.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        l10n?.aunNoTienesJugadas ?? "Aún no has guardado jugadas",
                        style: AppTextStyles.mensajeSecundario,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: listaMostrar.length,
                      itemBuilder: (context, index) {
                        final jugada = listaMostrar[index];
                        final rawNums = (jugada["numeros"] as List<dynamic>? ?? []);
                        final numeros = rawNums.map((n) => int.tryParse(n.toString()) ?? -1).where((n) => n >= 0).toList();

                        final bRoja = jugada["balota_roja"] ?? jugada["balotaroja"];
                        final int? superBallVal = _usaSuperbalota
                            ? (bRoja != null
                                ? int.tryParse(bRoja.toString())
                                : (numeros.length >= 6 ? numeros.last : null))
                            : null;

                        final whites = _usaSuperbalota && bRoja == null && numeros.length >= 6
                            ? numeros.sublist(0, numeros.length - 1)
                            : numeros;

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
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [
                                color.withValues(alpha: 0.15),
                                Colors.black.withValues(alpha: 0.1),
                              ],
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
                              Text(
                                "${l10n?.nro ?? 'Nro.'} ${index + 1}",
                                style: AppTextStyles.mensajeSecundario.copyWith(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: numeros.isEmpty
                                      ? [
                                          Text(
                                            l10n?.sinNumeros ?? "Sin números",
                                            style: AppTextStyles.mensajeSecundario,
                                          ),
                                        ]
                                      : [
                                          ...whites.map((n) {
                                            Widget ball = _build3DBall(
                                              n,
                                              baseColor: color,
                                              size: 34,
                                            );

                                            if (index == 0) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                                child: ScaleTransition(
                                                  scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                                                    CurvedAnimation(
                                                      parent: widget.jugadasController,
                                                      curve: const Interval(0.0, 1.0, curve: Curves.elasticOut),
                                                    ),
                                                  ),
                                                  child: ball,
                                                ),
                                              );
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                              child: ball,
                                            );
                                          }),
                                          if (superBallVal != null)
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                              child: _build3DBall(
                                                superBallVal,
                                                baseColor: Colors.redAccent,
                                                size: 34,
                                              ),
                                            ),
                                        ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  final jId = jugada["id"];
                                  if (jId != null && jId is int) {
                                    deleteJugada(jId);
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.delete_forever_rounded,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
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
    double size = 34,
  }) {
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
            blurRadius: 5,
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: 0.3),
            offset: const Offset(-1, -1),
            blurRadius: 3,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "–",
          style: TextStyle(
            fontSize: size * 0.42,
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
