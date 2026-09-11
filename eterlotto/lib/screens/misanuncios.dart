import 'dart:async';
import 'package:flutter/material.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/screens/publicidad.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/widgets/cardbussiness.dart';
import 'package:eterlotto/widgets/custom_app_bar.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'package:eterlotto/utils/secure_storage_helper.dart';

class MisAnunciosScreen extends StatefulWidget {
  const MisAnunciosScreen({super.key});

  @override
  State<MisAnunciosScreen> createState() => _MisAnunciosScreenState();
}

class _MisAnunciosScreenState extends State<MisAnunciosScreen> {
  bool cargando = false;
  bool _hasCachedSnapshot = false;
  bool _showingStaleData = false;
  bool _lastFetchFailed = false;
  int _requestVersion = 0;
  final _storage = AppSecureStorage.instance;

  final tituloController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> anuncios = [];
  List<Map<String, dynamic>> _allAnuncios = [];

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
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        anuncios = _filterByTitle(_allAnuncios, tituloController.text);
      });
    });
  }

  Future<bool> _isCurrentSession(String expectedUserId) async {
    final current = (await _storage.read(key: 'user_id'))?.trim();
    return mounted && current == expectedUserId;
  }

  List<Map<String, dynamic>> _mapsFrom(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _filterByTitle(
    List<Map<String, dynamic>> source,
    String title,
  ) {
    final query = title.trim().toLowerCase();
    if (query.isEmpty) return List<Map<String, dynamic>>.from(source);
    return source
        .where((ad) => ad['titulo'].toString().toLowerCase().contains(query))
        .toList();
  }

  Future<void> cargarMisAnuncios([String? title]) async {
    final requestVersion = ++_requestVersion;
    final activeUserId = (await _storage.read(key: 'user_id'))?.trim();
    if (activeUserId == null || activeUserId.isEmpty) {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          cargando = false;
          _hasCachedSnapshot = false;
          _lastFetchFailed = true;
        });
      }
      return;
    }
    final cacheKey = CacheService.misAnunciosKey(activeUserId);
    final fresh = await CacheService.getJson(cacheKey);
    final cached = fresh ?? await CacheService.getStaleJson(cacheKey);
    final hasCachedSnapshot = cached is List;
    final currentTitle = title ?? tituloController.text;

    if (hasCachedSnapshot) {
      final cachedAds = _mapsFrom(cached);
      if (requestVersion != _requestVersion ||
          !await _isCurrentSession(activeUserId)) {
        return;
      }
      setState(() {
        _allAnuncios = cachedAds;
        anuncios = _filterByTitle(cachedAds, currentTitle);
        cargando = false;
        _hasCachedSnapshot = true;
        _showingStaleData = fresh == null;
        _lastFetchFailed = false;
      });
    } else if (mounted && requestVersion == _requestVersion) {
      setState(() {
        cargando = true;
        _hasCachedSnapshot = false;
        _showingStaleData = false;
        _lastFetchFailed = false;
      });
    }

    try {
      final data = await ApiService.getMisPublicidades();
      if (requestVersion != _requestVersion ||
          !await _isCurrentSession(activeUserId)) {
        return;
      }
      final freshAds = _mapsFrom(data);
      await CacheService.setJson(cacheKey, freshAds);
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _allAnuncios = freshAds;
        anuncios = _filterByTitle(freshAds, currentTitle);
        _hasCachedSnapshot = true;
        _showingStaleData = false;
        _lastFetchFailed = false;
      });
    } catch (_) {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _lastFetchFailed = true);
      }
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => cargando = false);
      }
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
      body: RefreshIndicator(
        onRefresh: () => cargarMisAnuncios(),
        color: AppColors.yellow,
        backgroundColor: const Color(0xFF1E1E1E),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CustomSliverAppBar(
              title: l10n.misAnunciosTitle,
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
                            l10n.anunciateHoy,
                            style: AppTextStyles.mensajeSecundario.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
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
                        labelText: l10n.buscarPorTitulo,
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

            if (_showingStaleData || (_lastFetchFailed && _hasCachedSnapshot))
              SliverToBoxAdapter(child: _buildOfflineNotice(l10n)),

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
            else if (_lastFetchFailed && !_hasCachedSnapshot)
              SliverToBoxAdapter(child: _buildConnectionError(l10n))
            else if (anuncios.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Center(
                    child: Text(
                      l10n.noHasPublicadoAnuncios,
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
                                        description:
                                            anuncio["descripcion"] ?? "",
                                        address: anuncio["direccion"] ?? "",
                                        city: _getLocation(anuncio),
                                        contact: anuncio["telefono"] ?? "",
                                        whatsappUrl: anuncio["whatsapp_url"],
                                        facebookUrl: anuncio["facebook_url"],
                                        instagramUrl: anuncio["instagram_url"],
                                        isDestacado:
                                            anuncio["is_destacado"] == true ||
                                            anuncio["destacado"] == 1,
                                        statusText:
                                            anuncio["estado_texto"] ??
                                            "Abierto ahora",
                                        totalLikes:
                                            int.tryParse(
                                              anuncio["total_likes"]
                                                      ?.toString() ??
                                                  "0",
                                            ) ??
                                            0,
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
                                          l10n.editar,
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
                                                l10n.eliminarAnuncio,
                                                style: AppTextStyles
                                                    .mensajeSecundario,
                                              ),
                                              content: Text(
                                                l10n.confirmarEliminarAnuncio,
                                                style: AppTextStyles
                                                    .mensajeSecundario,
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: Text(
                                                    l10n.cancelar,
                                                    style: AppTextStyles
                                                        .mensajeSecundario,
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: Text(
                                                    l10n.eliminar,
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
                                          l10n.eliminar,
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
      ),
    );
  }

  Widget _buildOfflineNotice(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.yellow, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.sinConexionAnuncios,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionError(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 60, color: Colors.white38),
          const SizedBox(height: 14),
          Text(
            l10n.errorCargarAnuncios,
            style: AppTextStyles.mensajeSecundario,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: cargarMisAnuncios,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.reintentar),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.yellow),
          ),
        ],
      ),
    );
  }
}
