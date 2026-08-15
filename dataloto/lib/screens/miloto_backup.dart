import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/widgets/contenedor2.dart';
import 'package:dataloto/widgets/contenedor3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:http/http.dart' as storage;
import '../widgets/contenedor.dart';
import '../widgets/custom_app_bar.dart';
import 'dart:math';
import 'package:dataloto/widgets/jugadas_list_mloto.dart';
import 'dart:async';
import 'package:dataloto/widgets/carrusel.dart';
import 'package:dataloto/screens/directorioLocal.dart';

class MilotoScreen extends StatefulWidget {
  const MilotoScreen({super.key});

  @override
  State<MilotoScreen> createState() => _MilotoScreenState();
}

class _MilotoScreenState extends State<MilotoScreen>
    with TickerProviderStateMixin {
  static const String loteria = 'Miloto';
  final int maxSeleccion = 5;
  List<int> seleccionados = [];
  List<int> listaProbables = [];
  List<Map<String, dynamic>> ultimosResultados = [];
  List<Map<String, dynamic>> _jugadasList = [];
  bool cargando = false;
  static const String backendUrl = "https://pry-dataloto.onrender.com/mloto";
  String? fechaPrediccion;

  List<Map<String, dynamic>> anuncios = [];
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _shineController;
  late AnimationController _jugadasController;
  late Animation<double> _jugadasAnimation;
  final GlobalKey<JugadasListMlotoState> _jugadasListKey =
      GlobalKey<JugadasListMlotoState>();
  String? userId;
  bool isSaving = false;
  final _storage = const FlutterSecureStorage();
  bool mostrarResultados = false; // Estado inicial

  @override
  void initState() {
    super.initState();
    _cargarMilotoOptimizado();

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
    );

    _jugadasController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _jugadasAnimation = CurvedAnimation(
      parent: _jugadasController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _shineController.dispose();
    _jugadasController.dispose();
    super.dispose();
  }

  Future<void> _cargarMilotoOptimizado() async {
    if (!mounted) return;
    setState(() => cargando = true);

    try {
      final keys = await Future.wait([
        _storage.read(key: 'user_id'),
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
      debugPrint("❌ Error al cargar Miloto en paralelo: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _loadUserId() async {
    final id = await _storage.read(key: 'user_id');
    setState(() {
      userId = id;
    });
  }

  Future<void> buscarAnuncios([String titulo = ""]) async {
    if (!mounted) return;
    setState(() => cargando = true);

    try {
      // 🧠 1. Cargar SOLO el país del storage (para filtrar por país en Miloto)
      final paisIdStr = await _storage.read(key: "pais_id");
      final paisId = paisIdStr != null ? int.tryParse(paisIdStr) : null;

      // Dept y ciudad: null (no se cargan ni se guardan, así que siempre "reiniciados")
      final int? departamentoIdIgnorado = null;
      final int? ciudadIdIgnorada = null;

      print("🔍 IDs en Miloto: País=$paisId (dept/ciudad reiniciados a null)");

      // 🛰️ 2. API con solo país
      final data = await ApiService.getPublicidades(
        paisId: paisId,
        departamentoId: departamentoIdIgnorado,
        ciudadId: ciudadIdIgnorada,
        titulo: titulo.trim().isEmpty ? null : titulo.trim(),
      );

      if (!mounted) return;

      setState(() => anuncios = data);
    } catch (e, st) {
      debugPrint("❌ Error: $e");
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
    if (!mounted) return;
    try {
      final response = await http.get(Uri.parse("$backendUrl/ultimos5"));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["resultados"] != null) {
          setState(() {
            ultimosResultados = List<Map<String, dynamic>>.from(
              data["resultados"],
            );
          });
        } else {
          setState(() {
            ultimosResultados = [];
          });
          debugPrint("Respuesta sin resultados válidos: $data");
        }
      } else {
        setState(() {
          ultimosResultados = [];
        });
        debugPrint("Error HTTP: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        ultimosResultados = [];
      });
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
        final String? fecha = data["fecha"];

        if (numeros != null && fecha != null) {
          setState(() {
            listaProbables = numeros
                .map((e) => int.tryParse(e.toString()) ?? 0)
                .where((e) => e != 0)
                .toList();
            fechaPrediccion = fecha;
            cargando = false;
          });
        } else {
          setState(() => cargando = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Error: Datos del servidor incompletos"),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        setState(() => cargando = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error al conectar con el servidor"),
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
    if (!mounted || listaProbables.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Cargando... por favor espere.",
              style: AppTextStyles.mensajeSecundario,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      final random = Random();
      seleccionados = [];

      while (seleccionados.length < maxSeleccion) {
        int nuevoNumero = listaProbables[random.nextInt(listaProbables.length)];
        if (!seleccionados.contains(nuevoNumero)) {
          seleccionados.add(nuevoNumero);
        }
      }

      _bounceController.reset();
      _bounceController.forward();

      if (!_shineController.isAnimating) {
        _shineController.repeat();
      }
    });
  }

  Future<void> _loadJugadas() async {
    try {
      final response = await ApiService.listarJugadasMloto();
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

  // 🧱 Validaciones iniciales (IGUAL QUE BALOTO)
  if (userId == null || userId!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No se encontró el usuario. Inicia sesión.")),
    );
    return;
  }

  if (seleccionados.isEmpty) return;

  if (seleccionados.length != 5) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Debes seleccionar exactamente 5 balotas"),
      ),
    );
    return;
  }

  setState(() => isSaving = true);

  try {
    // 🧮 Ordenamos y formamos la jugada
    final nuevaJugada = List<int>.from(seleccionados)..sort();

    // 🔄 Actualizar jugadas antes de validar duplicados
    await _loadJugadas();
    print("📌 Validando jugada: $nuevaJugada");
    print("📌 Lista actual: $_jugadasList");

    // 🔍 Validación de duplicados (MISMO ENFOQUE QUE BALOTO)
    final yaExiste = _jugadasList.any((jugada) {
      final nums = (jugada["numeros"] as List<dynamic>?)?.cast<int>() ?? [];
      if (nums.length != 5) return false;

      final stored = List<int>.from(nums)..sort();
      return const ListEquality().equals(stored, nuevaJugada);
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
      userId!, // 🔑 MISMO PATRÓN QUE BALOTO
    );

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("⚠️ Error: $e")),
    );
  }

  if (mounted) setState(() => isSaving = false);
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        color: Colors.amber,
        backgroundColor: const Color(0xFF1E293B),
        onRefresh: () async {
          await _cargarMilotoOptimizado();
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
              padding: const EdgeInsets.all(
                16.0,
              ), // Aumentado a 16 para más espacio
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
                    child: JugadasListMloto(
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
                              children: List.generate(maxSeleccion, (index) {
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
                                                  stops: const [0.2, 0.5, 0.8],
                                                ).createShader(bounds);
                                              },
                                              blendMode: BlendMode.srcATop,
                                              child: Image.asset(
                                                "assets/images/blue-ball.png",
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
                                                      baseColor: Colors.blue,
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
                                  backgroundColor: Colors.amber,
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
                                  backgroundColor: Colors.amber,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "Selecciona tus números",
                          style: AppTextStyles.h2.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 12),
                        // Encabezado de secciones
                        Text(
                          "Números mas probables",
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
                              children: listaProbables.take(20).map((numero) {
                                bool isSelected = seleccionados.contains(
                                  numero,
                                );
                                return GestureDetector(
                                  onTap: () => toggleNumero(numero),
                                  child: SizedBox(
                                    width: ballSize,
                                    height: ballSize,
                                    child: _build3DBall(
                                      numero,
                                      baseColor: isSelected
                                          ? Colors.amber
                                          : const Color.fromARGB(
                                              255,
                                              5,
                                              166,
                                              206,
                                            ),
                                      size: ballSize,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // Lista de menos probables
                        Text(
                          "Poco probables, pero posibles.",
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
                              children: listaProbables.skip(20).map((numero) {
                                bool isSelected = seleccionados.contains(
                                  numero,
                                );
                                return GestureDetector(
                                  onTap: () => toggleNumero(numero),
                                  child: SizedBox(
                                    width: ballSize,
                                    height: ballSize,
                                    child: _build3DBall(
                                      numero,
                                      baseColor: isSelected
                                          ? Colors.amber
                                          : const Color(0xFF607D8B),
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
                  // Dentro de tu StatefulWidget

                  // Luego, reemplaza tu LayoutBuilder por esto:
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final isSmall = screenWidth < 360;
                      final ballSize = isSmall ? 25.0 : 33.0;

                      return AppContainer3(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Encabezado con botón (siempre visible)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  mostrarResultados = !mostrarResultados;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Últimos 5 resultados",
                                      style: AppTextStyles.h2,
                                    ),
                                    Icon(
                                      mostrarResultados
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: AppColors.yellow,
                                      size: 26,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Contenido colapsable: subtítulo + resultados
                            AnimatedCrossFade(
                              firstChild: _buildResultadosContent(
                                ballSize,
                                loteria,
                              ),
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
                      );
                    },
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
                                    color: AppColors
                                        .yellow, // ✅ Amarillo para consistencia
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

  Widget _buildResultadosContent(double ballSize, String loteria) {
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
                  child: Row(
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
                                  return SizedBox(
                                    width: ballSize,
                                    height: ballSize,
                                    child: _build3DBall(
                                      n,
                                      baseColor: const Color.fromARGB(
                                        255,
                                        5,
                                        166,
                                        206,
                                      ),
                                      size: ballSize,
                                    ),
                                  );
                                }),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
      ],
    );
  }
}
