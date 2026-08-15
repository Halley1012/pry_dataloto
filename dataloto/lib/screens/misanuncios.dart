import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dataloto/screens/publicidad.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/widgets/cardbussiness.dart';
import 'package:dataloto/widgets/custom_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MisAnunciosScreen extends StatefulWidget {
  const MisAnunciosScreen({super.key});

  @override
  State<MisAnunciosScreen> createState() => _MisAnunciosScreenState();
}

class _MisAnunciosScreenState extends State<MisAnunciosScreen> {
  static const String titulo = 'Mis Anuncios';
  bool cargando = false;

  final tituloController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  Timer? _debounce;

  List<Map<String, dynamic>> anuncios = [];

  @override
  void initState() {
    super.initState();
    cargarMisAnuncios();
    tituloController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    tituloController.removeListener(_onSearchChanged);
    tituloController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      cargarMisAnuncios(tituloController.text.trim());
    });
  }

  Future<void> cargarMisAnuncios([String titulo = ""]) async {
    if (!mounted) return;
    setState(() => cargando = true);

    try {
      // === VALIDACIÓN DE TOKEN ELIMINADA (no necesaria para mostrar anuncios) ===

      final data = await ApiService.getMisPublicidades();
      List<Map<String, dynamic>> resultados = data;

      // Filtrar por título localmente
      if (titulo.trim().isNotEmpty) {
        resultados = resultados
            .where(
              (a) => a["titulo"].toString().toLowerCase().contains(
                titulo.toLowerCase(),
              ),
            )
            .toList();
      }

      if (mounted) {
        setState(() => anuncios = resultados);
      }
    } catch (e) {
      // === PRINT ELIMINADO (no se muestra en producción) ===
      // === SNACKBAR ELIMINADO (errores silenciosos) ===
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          const CustomSliverAppBar(
            title: titulo,
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
                  // Encabezado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "¡Anúnciate hoy y haz que todos te conozcan!",
                          style: AppTextStyles.mensajeSecundario.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: AppColors.yellow),
                        iconSize: 30,
                        tooltip: "Crear nueva publicidad",
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CrearPublicidadForm(),
                            ),
                          );
                          if (mounted) cargarMisAnuncios();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Campo de búsqueda
                  TextField(
                    controller: tituloController,
                    decoration: InputDecoration(
                      labelText: 'Buscar por título',
                      labelStyle: AppTextStyles.mensajeSecundario,
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.yellow,
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: AppColors.white),
                  ),
                ],
              ),
            ),
          ),

          // Contenido principal
          if (cargando)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.yellow),
                ),
              ),
            )
          else if (anuncios.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                  child: Text(
                    "No has publicado ningún anuncio todavía.\n¡Crea el primero ahora!",
                    style: AppTextStyles.mensajeSecundario.copyWith(
                      fontSize: 13,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // === TARJETA AMARILLA (solo BusinessCard) ===
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20.0),
                                child: Column(
                                  children: [
                                    BusinessCard(
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
                                  ],
                                ),
                              ),
                            ),

                            // === BOTONES DEBAJO DE LA TARJETA (fuera del fondo amarillo) ===
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                left: 12.0,
                                right: 12.0,
                              ),
                              child: Row(
                                children: [
                                  // === BOTÓN EDITAR (Más ancho) ===
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final actualizado =
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    CrearPublicidadForm(
                                                      publicidad: anuncio,
                                                    ),
                                              ),
                                            );
                                        if (actualizado == true && mounted) {
                                          cargarMisAnuncios(
                                            tituloController.text.trim(),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.yellow,
                                        foregroundColor: Colors.black87,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.black87,
                                        size: 18,
                                      ),
                                      label: Text(
                                        "Editar",
                                        style: AppTextStyles.button.copyWith(
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // === BOTÓN ELIMINAR (Más ancho) ===
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final confirmar = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            backgroundColor:
                                                AppColors.blackfondo,
                                            title: Text(
                                              "Eliminar anuncio",
                                              style: AppTextStyles
                                                  .mensajeSecundario,
                                            ),
                                            content: Text(
                                              "¿Estás seguro de eliminar este anuncio?",
                                              style: AppTextStyles
                                                  .mensajeSecundario,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: Text(
                                                  "Cancelar",
                                                  style: AppTextStyles
                                                      .mensajeSecundario,
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: Text(
                                                  "Eliminar",
                                                  style: AppTextStyles
                                                      .mensajeSecundario
                                                      .copyWith(
                                                        color: Colors.red,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmar == true && mounted) {
                                          try {
                                            await ApiService.eliminarPublicidad(
                                              anuncio["id"],
                                            );
                                            cargarMisAnuncios(
                                              tituloController.text.trim(),
                                            );
                                            // === SNACKBAR DE ÉXITO ELIMINADO ===
                                          } catch (e) {
                                            // === SNACKBAR DE ERROR ELIMINADO ===
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.delete,
                                        color: AppColors.blackfondo,
                                        size: 18,
                                      ),
                                      label: Text(
                                        "Eliminar",
                                        style: AppTextStyles.button,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
}