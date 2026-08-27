import 'dart:async';
import 'package:flutter/material.dart';
import 'package:eterlotto/screens/publicidad.dart';
import 'package:eterlotto/services/api_service.dart';
import '../services/cache_service.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/widgets/cardbussiness.dart';
import 'package:eterlotto/widgets/custom_app_bar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eterlotto/utils/pais_helper.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';

class DirectorioLocalScreen extends StatefulWidget {
  const DirectorioLocalScreen({super.key});

  @override
  State<DirectorioLocalScreen> createState() => _DirectorioLocalScreenState();
}

class _DirectorioLocalScreenState extends State<DirectorioLocalScreen> {
  bool cargando = false;


  final tituloController = TextEditingController();
  final categoriaController = TextEditingController();
  final departamentoController = TextEditingController();
  final paisController = TextEditingController();

  final _storage = const FlutterSecureStorage();

  List<Map<String, dynamic>> anuncios = [];

  late Future<List<Map<String, dynamic>>> _paisesFuture;
  late Future<List<Map<String, dynamic>>> _departamentosFuture;
  late Future<List<Map<String, dynamic>>> _categoriasFuture;
  int? _paisSeleccionadoId;
  int? _departamentoSeleccionadoId;
  int? _categoriaSeleccionadaId;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _paisesFuture = ApiService.getPaises();
    _departamentosFuture = Future.value(<Map<String, dynamic>>[]);
    _categoriasFuture = ApiService.getCategorias();

    _inicializarFiltros();
    tituloController.addListener(_onSearchChanged);
  }

  Future<void> _inicializarFiltros() async {
    try {
      final results = await Future.wait([
        _storage.read(key: "pais_id"),
        _storage.read(key: "pais_nombre"),
        _paisesFuture,
        _categoriasFuture,
      ]);

      final paisIdStr = results[0] as String?;
      final paisNombre = results[1] as String?;
      final paisesData = results[2] as List<Map<String, dynamic>>;

      if (paisIdStr != null) {
        _paisSeleccionadoId = int.tryParse(paisIdStr);
      } else if (paisNombre != null && paisNombre != "Todos") {
        final seleccionado = paisesData.firstWhere(
          (p) =>
              p['nombre'].toString().toLowerCase() == paisNombre.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        if (seleccionado.isNotEmpty) {
          _paisSeleccionadoId = int.tryParse(seleccionado['id'].toString());
        }
      }

      if (!mounted) return;

      setState(() {
        paisController.text = paisNombre ?? "Todos";
        departamentoController.text = "Todos";
        categoriaController.text = "Todas las categorías";

        if (_paisSeleccionadoId != null) {
          _departamentosFuture = ApiService.getDepartamentosPorPais(
            _paisSeleccionadoId!,
          );
        }
      });

      _departamentoSeleccionadoId = null;
      _categoriaSeleccionadaId = null;

      await buscarAnuncios("");
    } catch (e) {
      debugPrint("❌ Error al inicializar filtros en directorioLocal: $e");
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    tituloController.removeListener(_onSearchChanged);
    tituloController.dispose();
    categoriaController.dispose();
    departamentoController.dispose();
    paisController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      buscarAnuncios(tituloController.text.trim());
    });
  }

  Future<void> buscarAnuncios(String titulo) async {
    final int? paisId = _paisSeleccionadoId;
    final int? departamentoId = _departamentoSeleccionadoId;
    final int? categoriaId = _categoriaSeleccionadaId;
    final cacheKey = 'directorio_anuncios_${paisId}_${departamentoId}_${categoriaId}_$titulo';

    final cached = await CacheService.getJson(cacheKey);
    if (cached != null && mounted) {
      setState(() {
        anuncios = List<Map<String, dynamic>>.from(cached);
        cargando = false;
      });
    }

    if (!mounted) return;
    if (anuncios.isEmpty) setState(() => cargando = true);

    try {
      final data = await ApiService.getPublicidades(
        paisId: paisId,
        departamentoId: departamentoId,
        categoriaId: categoriaId,
        titulo: titulo.trim().isNotEmpty ? titulo.trim() : null,
      );

      if (mounted) {
        setState(() => anuncios = data);
        CacheService.setJson(cacheKey, data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar los anuncios: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  String _getLocation(Map<String, dynamic> anuncio) {
    final city = anuncio["ciudad_nombre"] as String?;
    if (city?.isNotEmpty == true) return city!;
    return anuncio["departamento_nombre"] as String? ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          CustomSliverAppBar(
            title: l10n.buscaloAqui,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.anunciateHoy,
                          style: AppTextStyles.mensajeSecundario.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add, color: AppColors.yellow),
                        iconSize: 30,
                        tooltip: l10n.crearNuevaPublicidad,
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CrearPublicidadForm(),
                            ),
                          );
                          if (mounted) buscarAnuncios(tituloController.text.trim());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(flex: 1, child: _buildPaisDropdown(l10n)),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: _buildDepartamentoDropdown(l10n),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(flex: 1, child: _buildCategoriaDropdown(l10n)),
                        ],
                      ),
                      TextField(
                        controller: tituloController,
                        decoration: InputDecoration(
                          labelText: l10n.buscarPorTitulo,
                          labelStyle: AppTextStyles.mensajeSecundario,
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.yellow,
                          ),
                        ),
                        style: const TextStyle(color: AppColors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (cargando)
            const SliverToBoxAdapter(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.yellow),
              ),
            )
          else if (anuncios.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    l10n.noHayAnunciosFiltros,
                    style: AppTextStyles.mensajeSecundario.copyWith(
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: anuncios.length,
                    itemBuilder: (context, index) {
                      final anuncio = anuncios[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20.0),
                            child: BusinessCard(
                              paginaweb: anuncio["pagina_url"] ?? "",
                              title: anuncio["titulo"] ?? "",
                              logo: anuncio["imagen_url"] ?? "",
                              description: anuncio["descripcion"] ?? "",
                              address: anuncio["direccion"] ?? "",
                              city: _getLocation(anuncio),
                              contact: anuncio["telefono"] ?? "",
                              whatsappUrl: anuncio["whatsapp_url"],
                              facebookUrl: anuncio["facebook_url"],
                              instagramUrl: anuncio["instagram_url"],
                              onAction: () {},
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaisDropdown(AppLocalizations l10n) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _paisesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.yellow),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(
            l10n.noHayPaisesDisponibles,
            style: const TextStyle(color: Colors.white70),
          );
        }
        final paisesData = snapshot.data!;
        final paises = paisesData.map((m) => m['nombre'].toString()).toList();
        final paisesConTodas = [l10n.todos, ...paises];

        String valorActual = paisController.text.trim();
        if (valorActual == "Todos") valorActual = l10n.todos;
        if (valorActual.isEmpty || !paisesConTodas.contains(valorActual)) {
          valorActual = l10n.todos;
          paisController.text = valorActual;
        }

        return DropdownButtonFormField<String>(
          initialValue: valorActual,
          isExpanded: true,
          dropdownColor: Colors.black87,
          style: AppTextStyles.mensajeSecundario,
          decoration: InputDecoration(
            labelText: l10n.pais,
            labelStyle: AppTextStyles.mensajeSecundario,
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          iconEnabledColor: AppColors.yellow,
          items: paisesConTodas.map((p) {
            return DropdownMenuItem<String>(
              value: p,
              child: PaisHelper.buildItemConBandera(
                p,
                style: AppTextStyles.mensajeSecundario,
              ),
            );
          }).toList(),
          onChanged: (value) async {
            if (value == null) return;
            paisController.text = value;
            if (value == l10n.todos) {
              setState(() {
                _paisSeleccionadoId = null;
                _departamentoSeleccionadoId = null;
                departamentoController.text = l10n.todos;
                _departamentosFuture = Future.value(<Map<String, dynamic>>[]);
              });
            } else {
              try {
                final paisesDataLocal = await _paisesFuture;
                final seleccionado = paisesDataLocal.firstWhere(
                  (p) => p['nombre'].toString() == value,
                  orElse: () => <String, dynamic>{},
                );
                if (seleccionado.isNotEmpty) {
                  final nuevoId = int.tryParse(seleccionado['id'].toString());
                  if (nuevoId != null) {
                    setState(() {
                      _paisSeleccionadoId = nuevoId;
                      _departamentoSeleccionadoId = null;
                      _departamentosFuture = ApiService.getDepartamentosPorPais(
                        nuevoId,
                      );
                      departamentoController.text = l10n.todos;
                    });
                  }
                }
              } catch (_) {}
            }
            buscarAnuncios(tituloController.text.trim());
          },
        );
      },
    );
  }

  Widget _buildDepartamentoDropdown(AppLocalizations l10n) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _departamentosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.yellow),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(
            l10n.noHayDepartamentosDisponibles,
            style: AppTextStyles.mensajeSecundario,
          );
        }
        final departamentosData = snapshot.data!;
        final departamentos =
            departamentosData.map((m) => m['nombre'].toString()).toList();
        final depsConTodas = [l10n.todos, ...departamentos];

        String valorActual = departamentoController.text.trim();
        if (valorActual == "Todos") valorActual = l10n.todos;
        if (valorActual.isEmpty || !depsConTodas.contains(valorActual)) {
          valorActual = l10n.todos;
          departamentoController.text = valorActual;
        }

        return DropdownButtonFormField<String>(
          initialValue: valorActual,
          isExpanded: true,
          dropdownColor: Colors.black87,
          style: AppTextStyles.mensajeSecundario,
          decoration: InputDecoration(
            labelText: l10n.estadoProvincia,
            labelStyle: AppTextStyles.mensajeSecundario,
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          iconEnabledColor: AppColors.yellow,
          items: depsConTodas.map((d) {
            return DropdownMenuItem<String>(value: d, child: Text(d));
          }).toList(),
          onChanged: (value) async {
            if (value == null) return;
            departamentoController.text = value;
            if (value == l10n.todos) {
              setState(() => _departamentoSeleccionadoId = null);
            } else {
              try {
                final departamentosDataLocal = await _departamentosFuture;
                final seleccionado = departamentosDataLocal.firstWhere(
                  (d) => d['nombre'].toString() == value,
                  orElse: () => <String, dynamic>{},
                );
                final nuevoId = int.tryParse(seleccionado['id'].toString());
                if (nuevoId != null) {
                  setState(() => _departamentoSeleccionadoId = nuevoId);
                }
              } catch (_) {}
            }
            buscarAnuncios(tituloController.text.trim());
          },
        );
      },
    );
  }

  Widget _buildCategoriaDropdown(AppLocalizations l10n) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _categoriasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.yellow),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(
            l10n.noHayCategoriasDisponibles,
            style: const TextStyle(color: Colors.white70),
          );
        }
        final categoriasData = snapshot.data!;
        final categorias =
            categoriasData.map((m) => m['nombre'].toString()).toList();
        final catsConTodas = [l10n.todasCategorias, ...categorias];

        String valorActual = categoriaController.text.trim();
        if (valorActual == "Todas las categorías") valorActual = l10n.todasCategorias;
        if (valorActual.isEmpty || !catsConTodas.contains(valorActual)) {
          valorActual = l10n.todasCategorias;
          categoriaController.text = valorActual;
        }

        return DropdownButtonFormField<String>(
          initialValue: valorActual,
          isExpanded: true,
          dropdownColor: Colors.black87,
          style: AppTextStyles.mensajeSecundario,
          decoration: InputDecoration(
            labelText: l10n.categoria,
            labelStyle: AppTextStyles.mensajeSecundario,
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          iconEnabledColor: AppColors.yellow,
          items: catsConTodas.map((c) {
            return DropdownMenuItem<String>(value: c, child: Text(c));
          }).toList(),
          onChanged: (value) async {
            if (value == null) return;
            categoriaController.text = value;
            if (value == l10n.todasCategorias) {
              setState(() => _categoriaSeleccionadaId = null);
            } else {
              try {
                final categoriasDataLocal = await _categoriasFuture;
                final seleccionado = categoriasDataLocal.firstWhere(
                  (c) => c['nombre'].toString() == value,
                  orElse: () => <String, dynamic>{},
                );
                final nuevoId = int.tryParse(seleccionado['id'].toString());
                if (nuevoId != null) {
                  setState(() => _categoriaSeleccionadaId = nuevoId);
                }
              } catch (_) {}
            }
            buscarAnuncios(tituloController.text.trim());
          },
        );
      },
    );
  }
}
