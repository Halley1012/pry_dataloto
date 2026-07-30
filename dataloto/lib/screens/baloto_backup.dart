import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/widgets/contenedor2.dart';
import 'package:dataloto/widgets/contenedor3.dart';
import 'package:dataloto/widgets/jugadas_list_bloto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import '../widgets/contenedor.dart';
import '../widgets/custom_app_bar.dart';
import 'dart:math';
import 'package:dataloto/widgets/carrusel.dart';
import 'package:dataloto/screens/directorioLocal.dart';

class BalotoScreen extends StatefulWidget {
  const BalotoScreen({super.key});

  @override
  State<BalotoScreen> createState() => _BalotoScreenState();
}

class _BalotoScreenState extends State<BalotoScreen>
    with TickerProviderStateMixin {
  static const String loteria = 'Baloto/Revancha';
  final storage = const FlutterSecureStorage();

  final int maxSeleccion = 5;
  int? balotaRojaSeleccionada;
  List<int> seleccionados = [];
  List<int> listaProbables = [];
  List<int> listaBalotaRoja = [];
  List<Map<String, dynamic>> ultimosResultados = [];
  List<Map<String, dynamic>> _jugadasList = [];
  bool cargando = false;
  static const String backendUrl = "https://pry-dataloto.onrender.com/bloto";
  String? fechaPrediccion;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _shineController;
  late AnimationController _jugadasController;
  late Animation<double> _jugadasAnimation;

  final GlobalKey<JugadasListBlotoState> _jugadasListKey = GlobalKey<JugadasListBlotoState>();
  String? userId;
  bool isSaving = false;
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> anuncios = [];
  bool mostrarResultados = false;

  @override
  void initState() {
    super.initState();
    _cargarBalotoOptimizado();

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

    _jugadasController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _jugadasAnimation = CurvedAnimation(
      parent: _jugadasController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _shineController.dispose();
    _jugadasController.dispose();
    super.dispose();
  }

  Future<void> _cargarBalotoOptimizado() async {
    if (!mounted) return;
    setState(() => cargando = true);

    try {
      final keys = await Future.wait([
        storage.read(key: 'user_id'),
        _storage.read(key: 'pais_id'),
      ]);

      final uId = keys[0];
      final pIdStr = keys[1];
      final pIdInt = pIdStr != null ? int.tryParse(pIdStr) : null;

      if (mounted) setState(() => userId = uId);

      await Future.wait([
        fetchNumeros(),
        _fetchUltimosResultados(),
        _loadJugadas(),
        ApiService.getPublicidades(paisId: pIdInt).then((ads) {
          if (mounted) setState(() => anuncios = ads);
        }),
      ]);

      if (mounted && _jugadasList.isNotEmpty) {
        _jugadasController.forward();
      }
    } catch (e) {
      debugPrint("❌ Error al cargar Baloto en paralelo: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _loadUserId() async {
  final id = await storage.read(key: 'user_id');
  setState(() {
    userId = id;
  });
}

  Future<void> buscarAnuncios([String titulo = ""]) async {
    if (!mounted) return;
    setState(() => cargando = true);

    try {
      // 🧠 1. Cargar los filtros guardados del usuario (por ID) usando FlutterSecureStorage
      final paisIdStr = await _storage.read(key: "pais_id");
      final departamentoIdStr = await _storage.read(key: "departamento_id");
      final ciudadIdStr = await _storage.read(key: "ciudad_id");

      final paisId = paisIdStr != null ? int.tryParse(paisIdStr) : null;
      final departamentoId = departamentoIdStr != null
          ? int.tryParse(departamentoIdStr)
          : null;
      final ciudadId = ciudadIdStr != null ? int.tryParse(ciudadIdStr) : null;

      // 🛰️ 2. Llamar al API con los filtros por defecto
      final data = await ApiService.getPublicidades(
        paisId: paisId,
        //departamentoId: departamentoId,
        //ciudadId: ciudadId,
        //titulo: titulo.trim().isEmpty ? null : titulo.trim(),
      );

      if (!mounted) return;

      // 🧩 3. Actualizar la lista de anuncios
      setState(() {
        anuncios = data;
      });
    } catch (e, st) {
      debugPrint("❌ Error al buscar anuncios: $e");
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar los anuncios.')),
        );
      }
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _fetchUltimosResultados() async {
    try {
      final response = await http.get(
        Uri.parse("https://pry-dataloto.onrender.com/bloto/ultimos5"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["resultados"] != null && mounted) {
          setState(() {
            ultimosResultados = List<Map<String, dynamic>>.from(
              data["resultados"],
            );
          });
        } else {
          if (mounted) {
            setState(() {
              ultimosResultados = [];
            });
          }
          debugPrint("Respuesta sin resultados válidos: $data");
        }
      } else {
        if (mounted) {
          setState(() {
            ultimosResultados = [];
          });
        }
        debugPrint("Error HTTP: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          ultimosResultados = [];
        });
      }
      debugPrint("Excepción al consultar últimos resultados: $e");
    }
  }

  Future<void> fetchNumeros() async {
    if (!mounted) return;
    setState(() => cargando = true);

    try {
      final response = await http.get(Uri.parse(backendUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic>? numeros = data["numeros"];
        final List<dynamic>? balotaroja = data["balotaroja"];
        final String? fecha = data["fecha"];

        if (numeros != null && fecha != null && balotaroja != null && mounted) {
          setState(() {
            listaProbables = numeros
                .map((e) => int.tryParse(e.toString()) ?? 0)
                .where((e) => e != 0)
                .toList();
            listaBalotaRoja = balotaroja
                .map((e) => int.tryParse(e.toString()) ?? 0)
                .where((e) => e != 0)
                .toList();
            fechaPrediccion = fecha;
            cargando = false;
            debugPrint("Probables: $listaProbables");
            debugPrint("Rojas: $listaBalotaRoja");
          });
        } else {
          if (mounted) {
            setState(() => cargando = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Aún no hay predicciones..."),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          setState(() => cargando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error de servidor..."),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error en fetchNumeros: $e");
      if (!mounted) return;
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al obtener los números"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void toggleNumero(int numero) {
    if (!mounted) return;
    setState(() {
      if (seleccionados.contains(numero)) {
        seleccionados.remove(numero);
      } else if (seleccionados.length < maxSeleccion) {
        seleccionados.add(numero);
      }
    });
  }

  String _formatearFecha(String fecha) {
    try {
      String soloFecha = fecha.substring(0, 10);
      DateTime parsed = DateTime.parse(soloFecha);
      const meses = [
        "enero",
        "febrero",
        "marzo",
        "abril",
        "mayo",
        "junio",
        "julio",
        "agosto",
        "septiembre",
        "octubre",
        "noviembre",
        "diciembre",
      ];
      String mes = meses[parsed.month - 1];
      return "${parsed.day} de $mes, ${parsed.year}";
    } catch (_) {
      return fecha;
    }
  }

  void _generarAleatorios() {
    if (listaProbables.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No hay números probables cargados")),
        );
      }
      return;
    }
    if (listaBalotaRoja.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No hay balotas rojas disponibles")),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      final Random _random = Random();
      seleccionados = [];

      while (seleccionados.length < maxSeleccion && listaProbables.isNotEmpty) {
        int nuevoNumero =
            listaProbables[_random.nextInt(listaProbables.length)];
        if (!seleccionados.contains(nuevoNumero)) {
          seleccionados.add(nuevoNumero);
        }
      }

      balotaRojaSeleccionada =
          listaBalotaRoja[_random.nextInt(listaBalotaRoja.length)];

      _bounceController.reset();
      _bounceController.forward();
      if (!_shineController.isAnimating) _shineController.repeat();

      debugPrint("Generada: $seleccionados + Roja: $balotaRojaSeleccionada");
    });
  }

  Future<void> _loadJugadas() async {
    try {
      final response = await ApiService.listarJugadasBloto();
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
        response,
      );

      if (mounted) {
        setState(() {
          _jugadasList = data;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar jugadas: $e");
    }
  }

  Future<void> _guardarJugada() async {
  if (!mounted) return;

  // 🧱 Validaciones iniciales
  if (userId == null || userId!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No se encontró el usuario. Inicia sesión.")),
    );
    return;
  }

  if (seleccionados.isEmpty || balotaRojaSeleccionada == null) return;

  if (seleccionados.length != 5) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Debes seleccionar exactamente 5 balotas y 1 roja"),
      ),
    );
    return;
  }

  setState(() => isSaving = true);

  try {
    // 🧮 Ordenamos y formamos la jugada nueva
    final whites = List<int>.from(seleccionados)..sort();
    final nuevaJugada = [...whites, balotaRojaSeleccionada!];

    // 🔄 Actualiza jugadas antes de validar duplicados
    await _loadJugadas();
    print("📌 Validando jugada: $nuevaJugada");
    print("📌 Lista actual: $_jugadasList");

    // 🔍 Validación de duplicados
    final yaExiste = _jugadasList.any((jugada) {
      final nums = (jugada["numeros"] as List<dynamic>?)?.cast<int>() ?? [];
      if (nums.length != 6) return false;

      final storedWhites = nums.sublist(0, 5)..sort();
      final storedRed = nums[5];

      return const ListEquality().equals(storedWhites, whites) &&
          storedRed == balotaRojaSeleccionada;
    });

    if (yaExiste) {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Esa jugada ya existe")),
      );
      return;
    }

    // 🚀 Crear jugada (optimistic update)
    await _jugadasListKey.currentState!.addJugada(
      nuevaJugada,
      userId!, // ← YA NO ES NULL
    );

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("⚠️ Error: $e")),
    );
  }

  if (mounted) setState(() => isSaving = false);
}

Future<void> deleteJugada(int jugadaId, String userId) async {
  if (!mounted) return;

  final removedJugada = _jugadasList.firstWhere(
    (j) => j["id"] == jugadaId,
    orElse: () => {},
  );

  if (removedJugada.isEmpty) return;

  setState(() {
    _jugadasList.removeWhere((j) => j["id"] == jugadaId);
  });

  try {
    await ApiService.borrarJugadaBloto(jugadaId, userId);
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _jugadasList.insert(0, removedJugada);
    });
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        color: Colors.amber,
        backgroundColor: const Color(0xFF1E293B),
        onRefresh: () async {
          await _cargarBalotoOptimizado();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          const CustomSliverAppBar(
            title: "$loteria",
            pinned: true,
            floating: true,
            snap: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Predicciones Inteligentes para $loteria",
                          style: AppTextStyles.tituloPrincipal.copyWith(
                            color: Colors.amberAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Números con mayor probabilidad según la IA "
                          "para el sorteo del ${fechaPrediccion != null ? _formatearFecha(fechaPrediccion!) : '...'}",
                          style: AppTextStyles.mensajeSecundario,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppContainer(
                    child: JugadasListBloto(
                      key: _jugadasListKey,
                      jugadasController: _jugadasController,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppContainer3(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Tus números de la suerte",
                          style: AppTextStyles.tituloPrincipal.copyWith(
                            color: Colors.amberAccent,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "✨ Seleccionados especialmente para ti",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final screenWidth = MediaQuery.of(
                              context,
                            ).size.width;
                            final isSmall =
                                screenWidth <
                                360; // Solo ajusta para muy pequeños (<360px, ej. viejos phones)
                            final ballSize = isSmall
                                ? 35.0
                                : 45.0; // Original 45 para S23 FE y mayores
                            final spacing = isSmall ? 4.0 : 6.0;
                            final runSpacing = isSmall ? 6.0 : 8.0;
                            final fontSize = isSmall ? 12.0 : 16.0;

                            return Wrap(
                              spacing: spacing,
                              runSpacing: runSpacing,
                              children: [
                                ...List.generate(maxSeleccion, (index) {
                                  if (index < seleccionados.length) {
                                    return ScaleTransition(
                                      scale: _bounceAnimation,
                                      child: SizedBox(
                                        width: ballSize,
                                        height: ballSize,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            RotationTransition(
                                              turns: Tween(
                                                begin: 0.0,
                                                end: 1.0,
                                              ).animate(_shineController),
                                              child: ShaderMask(
                                                shaderCallback: (bounds) {
                                                  return LinearGradient(
                                                    colors: [
                                                      Colors.white.withOpacity(
                                                        0.25,
                                                      ),
                                                      Colors.transparent,
                                                      Colors.white.withOpacity(
                                                        0.25,
                                                      ),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    stops: const [
                                                      0.2,
                                                      0.5,
                                                      0.8,
                                                    ],
                                                  ).createShader(bounds);
                                                },
                                                blendMode: BlendMode.srcATop,
                                                child: Image.asset(
                                                  "assets/images/yellow-ball.png",
                                                  width: ballSize,
                                                  height: ballSize,
                                                  fit: BoxFit.contain,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => _build3DBall(
                                                        seleccionados[index],
                                                        baseColor:
                                                            Colors.lightGreen,
                                                        size: ballSize,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "${seleccionados[index]}",
                                              style: TextStyle(
                                                fontSize: fontSize,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                shadows: const [
                                                  Shadow(
                                                    blurRadius: 4,
                                                    color: Colors.black,
                                                    offset: Offset(1, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else {
                                    return SizedBox(
                                      width: ballSize,
                                      height: ballSize,
                                      child: _build3DBall(
                                        null,
                                        baseColor: Colors.grey.shade300,
                                        size: ballSize,
                                      ),
                                    );
                                  }
                                }),
                                ScaleTransition(
                                  scale: _bounceAnimation,
                                  child: SizedBox(
                                    width: ballSize,
                                    height: ballSize,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (balotaRojaSeleccionada != null) ...[
                                          RotationTransition(
                                            turns: Tween(
                                              begin: 0.0,
                                              end: 1.0,
                                            ).animate(_shineController),
                                            child: ShaderMask(
                                              shaderCallback: (bounds) {
                                                return LinearGradient(
                                                  colors: [
                                                    Colors.white.withOpacity(
                                                      0.25,
                                                    ),
                                                    Colors.transparent,
                                                    Colors.white.withOpacity(
                                                      0.25,
                                                    ),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  stops: const [0.2, 0.5, 0.8],
                                                ).createShader(bounds);
                                              },
                                              blendMode: BlendMode.srcATop,
                                              child: Image.asset(
                                                "assets/images/red-ball.png",
                                                width: ballSize,
                                                height: ballSize,
                                                fit: BoxFit.contain,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => _build3DBall(
                                                      balotaRojaSeleccionada,
                                                      baseColor:
                                                          Colors.redAccent,
                                                      size: ballSize,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "$balotaRojaSeleccionada",
                                            style: TextStyle(
                                              fontSize: fontSize,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              shadows: const [
                                                Shadow(
                                                  blurRadius: 4,
                                                  color: Colors.black,
                                                  offset: Offset(1, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ] else ...[
                                          _build3DBall(
                                            null,
                                            baseColor: Colors.grey.shade300,
                                            size: ballSize,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 15),
                        ShimmerBorderContainer(
                          child: Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Text(
                              "💡 Nota: son solo tendencias estadísticas, no garantías absolutas. Juega con responsabilidad.",
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppContainer3(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _generarAleatorios,
                                icon: const Icon(
                                  Icons.shuffle,
                                  color: Colors.black,
                                  size: 18,
                                ),
                                label: Text(
                                  "Generar",
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.button.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                  backgroundColor: AppColors.yellow,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : _guardarJugada, // se bloquea mientras guarda
                                icon: isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Color(0xFF1E1E1E),
                                              ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.list,
                                        color: Color(0xFF1E1E1E),
                                        size: 18,
                                      ),
                                label: Text(
                                  isSaving ? "Guardando..." : "Guardar",
                                  style: AppTextStyles.button.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                  backgroundColor: AppColors.yellow,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text("Selecciona tus números", style: AppTextStyles.h2),
                        const SizedBox(height: 15),
                        Text(
                          "Números ordenados de mayor a menor probabilidad,\nColor rojo mayor probabilidad.",
                          style: AppTextStyles.mensajeSecundario.copyWith(
                            fontSize: 12,
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final screenWidth = MediaQuery.of(
                              context,
                            ).size.width;
                            final isSmall = screenWidth < 360;
                            final crossAxisCount = isSmall
                                ? 6
                                : 8; // Reduce columnas en pequeños
                            final ballSize = isSmall
                                ? 32.0
                                : 40.0; // Tamaño responsive para Grid
                            final spacing = isSmall ? 4.0 : 8.0;

                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              childAspectRatio: 1.0, // Cuadrados perfectos
                              children: listaProbables.asMap().entries.map((
                                entry,
                              ) {
                                int index = entry.key;
                                int numero = entry.value;
                                bool isSelected = seleccionados.contains(
                                  numero,
                                );
                                Color baseColor = index < 21
                                    ? Colors.redAccent
                                    : const Color(0xFF607D8B);

                                return GestureDetector(
                                  onTap: () => toggleNumero(numero),
                                  child: SizedBox(
                                    width: ballSize,
                                    height: ballSize,
                                    child: _build3DBall(
                                      numero,
                                      baseColor: isSelected
                                          ? Colors.amber
                                          : baseColor,
                                      size: ballSize,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Balotas Rojas",
                          style: AppTextStyles.h2.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Números ordenados de mayor a menor probabilidad.",
                          style: AppTextStyles.mensajeSecundario.copyWith(
                            fontSize: 12,
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final screenWidth = MediaQuery.of(
                              context,
                            ).size.width;
                            final isSmall = screenWidth < 360;
                            final crossAxisCount = isSmall
                                ? 6
                                : 8; // Reduce columnas en pequeños
                            final ballSize = isSmall
                                ? 32.0
                                : 40.0; // Tamaño responsive
                            final spacing = isSmall ? 4.0 : 8.0;

                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              childAspectRatio: 1.0, // Cuadrados perfectos
                              children: listaBalotaRoja.map((numero) {
                                bool isSelected =
                                    balotaRojaSeleccionada == numero;

                                return GestureDetector(
                                  onTap: () {
                                    if (!mounted) return;
                                    setState(() {
                                      if (balotaRojaSeleccionada == numero) {
                                        balotaRojaSeleccionada = null;
                                      } else {
                                        balotaRojaSeleccionada = numero;
                                        _bounceController.reset();
                                        _bounceController.forward();
                                      }
                                    });
                                  },
                                  child: SizedBox(
                                    width: ballSize,
                                    height: ballSize,
                                    child: _build3DBall(
                                      numero,
                                      baseColor: isSelected
                                          ? Colors.amber
                                          : Colors.redAccent,
                                      size: ballSize,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppContainer3(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Encabezado clicable (siempre visible)
                        InkWell(
                          onTap: () {
                            setState(() {
                              mostrarResultados =
                                  !mostrarResultados; // Asegúrate de tener esta variable en el estado
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Últimos 5 resultados",
                                  style: AppTextStyles.h2,
                                ),
                                Icon(
                                  mostrarResultados
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color:
                                      AppColors.yellow, // o el color que uses
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Contenido colapsable: subtítulo + resultados
                        AnimatedCrossFade(
                          firstChild: _buildResultadosContent(loteria),
                          secondChild: const SizedBox.shrink(),
                          crossFadeState: mostrarResultados
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 500),
                          alignment: Alignment.topCenter,
                          firstCurve: Curves.easeOut,
                          secondCurve: Curves.easeIn,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 🔹 Anuncios (carrusel horizontal + botón "Ver más")
                  if (cargando)
                    const Center(child: CircularProgressIndicator())
                  else if (anuncios.isEmpty)
                    Column(
                      children: [
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            "No hay anuncios disponibles.",
                            style: AppTextStyles.mensajeSecundario.copyWith(
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔸 Título + Botón "Ver más"
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Anuncios destacados",
                                style: AppTextStyles.h2.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DirectorioLocalScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  "Ver más ›",
                                  style: AppTextStyles.mensajeSecundario.copyWith(
                                    color: AppColors.yellow, // ✅ Amarillo para consistencia
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 🔸 Carrusel horizontal (ahora con el widget)
                        InfiniteAdsCarousel(
                          key: ValueKey(
                            anuncios.length,
                          ), // Opcional: fuerza rebuild si cambia la lista
                          anuncios: anuncios, // Pasa la lista
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
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
        gradient: RadialGradient(
          colors: [
            baseColor.withOpacity(0.95),
            baseColor.withOpacity(0.8),
            baseColor.withOpacity(0.6),
          ],
          center: Alignment.topLeft,
          radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            offset: const Offset(3, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: baseColor.withOpacity(0.4),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.2),
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
                      color: Colors.black.withOpacity(0.6),
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

  Widget _buildResultadosContent(String loteria) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          "Historial más reciente del $loteria",
          style: AppTextStyles.mensajeSecundario,
        ),
        const SizedBox(height: 20),

        if (ultimosResultados.isEmpty)
          const Center(child: CircularProgressIndicator())
        else
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      "Fecha",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.fechasResultado,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "Resultados",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.fechasResultado,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...ultimosResultados.map((resultado) {
                final fecha =
                    resultado["fecha"]?.toString() ?? "Fecha desconocida";
                final numeros = List<int>.from(resultado["numeros"] ?? []);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final isSmall = screenWidth < 360;
                      final ballSize = isSmall ? 25.0 : 33.0;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              fecha,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.mensajeImportante,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: numeros.isEmpty
                                  ? [
                                      Text(
                                        "Sin números",
                                        style: AppTextStyles.mensajeSecundario,
                                      ),
                                    ]
                                  : List.generate(numeros.length, (index) {
                                      final n = numeros[index];
                                      final isLast =
                                          index == numeros.length - 1;
                                      return SizedBox(
                                        width: ballSize,
                                        height: ballSize,
                                        child: _build3DBall(
                                          n,
                                          baseColor: isLast
                                              ? Colors.redAccent
                                              : Colors.amber,
                                          size: ballSize,
                                        ),
                                      );
                                    }),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }).toList(),
            ],
          ),
      ],
    );
  }
}
