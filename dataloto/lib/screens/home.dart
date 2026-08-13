import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dataloto/services/cache_service.dart';
import 'package:dataloto/screens/directorioLocal.dart';
import 'package:dataloto/screens/loteriasPais.dart';
import 'package:dataloto/widgets/carrusel.dart';
import 'package:dataloto/widgets/contenedor4.dart';
import 'package:dataloto/widgets/lottery_avatar_3d.dart';
import 'baloto.dart';
import 'miloto.dart';
import 'color_loto.dart';
import 'powerball.dart';
import 'lotto_america.dart';
import 'double_play.dart';
import 'millionaire_life.dart';
import 'megamillions.dart';
import 'profile_screen.dart';
import 'mis_jugadas_selector_screen.dart';
import 'resultados_selector_screen.dart';

import 'package:dataloto/styles/app_text_styles.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dataloto/widgets/footer.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../screens/createpostscreen.dart';
import '../screens/notifications_screen.dart';
import 'post.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:provider/provider.dart';
import 'package:dataloto/providers/notification_provider.dart';
import '../utils/pais_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

// HomeScreen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final storage = const FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();
  bool cargando = false;
  List<Map<String, dynamic>> anuncios = [];
  bool isLoading = false;
  List<Post> posts = [];
  String? currentUserId;
  String? pais;
  List<dynamic> _loterias = [];
  List<dynamic> _filteredLoterias = [];
  List<dynamic> _globalLoterias = [];
  int _selectedIndex = 0;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
    _setupFirebaseMessaging(); // 🔥 Activar notificaciones
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().fetchNotifications();
      }
    });
  }

  Future<void> _loadUserAndData() async {
    try {
      // 1. Leer credenciales de storage en paralelo
      final keys = await Future.wait([
        storage.read(key: 'user_id'),
        storage.read(key: 'pais_id'),
        storage.read(key: 'pais_nombre'),
      ]);

      final userIdStr = keys[0];
      final rawPaisId = keys[1];
      final paisNombreStr = keys[2];

      final paisIdStr = (rawPaisId != null && rawPaisId != 'null' && rawPaisId.isNotEmpty)
          ? rawPaisId
          : "1";
      final paisIdInt = int.tryParse(paisIdStr);

      // ⚡ 1. Cargar desde caché local para despliegue instantáneo (0 ms)
      final cachedLoterias = await CacheService.getJson('home_loterias_$paisIdStr');
      final cachedAnuncios = await CacheService.getJson('home_anuncios_$paisIdStr');
      final cachedGlobal = await CacheService.getJson('home_loterias_globales');
      if (cachedLoterias != null && mounted) {
        setState(() {
          currentUserId = userIdStr;
          pais = paisNombreStr ?? "Colombia";
          _loterias = List<dynamic>.from(cachedLoterias);
          _filteredLoterias = List<dynamic>.from(_loterias);
          if (cachedGlobal != null) _globalLoterias = List<dynamic>.from(cachedGlobal);
          if (cachedAnuncios != null) anuncios = List<Map<String, dynamic>>.from(cachedAnuncios);
          isLoading = false;
          cargando = false;
        });
      }

      if (_loterias.isEmpty) setState(() => isLoading = true);

      // 2. Cargar Posts, Anuncios y Loterías en PARALELO
      final postsFuture = ApiService.getPosts().catchError((e) {
        debugPrint("⚠️ Error al obtener posts: $e");
        return <Post>[];
      });

      final anunciosFuture = ApiService.getPublicidades(paisId: paisIdInt).catchError((e) {
        debugPrint("⚠️ Error al obtener publicidad: $e");
        return <Map<String, dynamic>>[];
      });

      final loteriasFuture = ApiService.getLoteriasPorPais(paisIdStr).catchError((e) {
        debugPrint("⚠️ Error al obtener loterías: $e");
        return <dynamic>[];
      });

      final resultados = await Future.wait([
        postsFuture,
        anunciosFuture,
        loteriasFuture,
      ]);

      final rawPosts = resultados[0] as List<Post>;

      final postsConConteo = await Future.wait(
        rawPosts.map<Future<Post>>((p) async {
          try {
            final comments = await ApiService.getComments(p.id);
            return Post(
              id: p.id,
              title: p.title,
              content: p.content,
              userId: p.userId,
              userName: p.userName,
              createdAt: p.createdAt,
              commentsCount: comments.length,
            );
          } catch (_) {}
          return p;
        }),
      );

      List<dynamic> loteriasRes = resultados[2];
      List<dynamic> globalRes = [];
      if (loteriasRes.isEmpty) {
        try {
          final resCol = await ApiService.getLoteriasPorPais("5");
          final resUsa = await ApiService.getLoteriasPorPais("21");
          globalRes = [...resCol, ...resUsa];
          CacheService.setJson('home_loterias_globales', globalRes);
        } catch (e) {
          debugPrint("⚠️ Error obteniendo loterías globales: $e");
        }
      }

      if (!mounted) return;

      setState(() {
        currentUserId = userIdStr;
        pais = paisNombreStr ?? "Colombia";
        posts = postsConConteo;
        anuncios = List<Map<String, dynamic>>.from(resultados[1]);
        _loterias = loteriasRes;
        _filteredLoterias = List<dynamic>.from(_loterias);
        _globalLoterias = globalRes;
        isLoading = false;
        cargando = false;
      });

      // 💾 Guardar en caché local
      CacheService.setJson('home_loterias_$paisIdStr', resultados[2]);
      CacheService.setJson('home_anuncios_$paisIdStr', resultados[1]);
    } catch (e) {
      debugPrint("❌ Error al cargar la página principal: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
        cargando = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildCountryHeader() {
    final langCode = Localizations.localeOf(context).languageCode;
    final nombrePaisDisplay = PaisHelper.getNombreTraducido(pais ?? "Colombia", langCode);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          Text(
            PaisHelper.getBanderaEmoji(pais ?? "Colombia"),
            style: const TextStyle(fontSize: 32),
          ), 
          const SizedBox(width: 12),
          Text(
            nombrePaisDisplay,
            style: AppTextStyles.tituloPrincipal.copyWith(fontSize: 28),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredLoterias = List<dynamic>.from(_loterias);
      } else {
        _filteredLoterias = _loterias
            .where((l) => l["nombre"]
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Widget _buildSearchBar() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n?.buscarLoteria ?? "Buscar lotería...",
            hintStyle: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white38),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularesSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n?.populares ?? "Populares", style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoteriasPais())),
                child: Text(l10n?.verTodas ?? "Ver todas", style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredLoterias.length > 3 ? 3 : _filteredLoterias.length,
          itemBuilder: (context, index) {
            final loteria = _filteredLoterias[index];
            return _buildLoteriaCard(loteria, showCountry: false);
          },
        ),
      ],
    );
  }

  String _formatearFechaSimple(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "Próximamente";
    try {
      DateTime parsed = DateTime.parse(fecha.substring(0, 10));
      DateTime now = DateTime.now();
      DateTime hoy = DateTime(now.year, now.month, now.day);
      DateTime fechaSorteo = DateTime(parsed.year, parsed.month, parsed.day);
      if (fechaSorteo.isBefore(hoy)) {
        return "Próximamente";
      }
      final langCode = Localizations.localeOf(context).languageCode;
      List<String> meses;
      if (langCode == 'en') {
        meses = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return "${parsed.day.toString().padLeft(2, '0')} ${meses[parsed.month - 1]} ${parsed.year}";
      } else if (langCode == 'pt') {
        meses = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
        return "${parsed.day.toString().padLeft(2, '0')} ${meses[parsed.month - 1]} ${parsed.year}";
      } else {
        meses = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
        return "${parsed.day.toString().padLeft(2, '0')} ${meses[parsed.month - 1]} ${parsed.year}";
      }
    } catch (_) {
      return fecha;
    }
  }

  String _getPaisNombre(dynamic loteria) {
    String rawPais = "Colombia";
    if (loteria["pais_nombre"] != null && loteria["pais_nombre"].toString().isNotEmpty) {
      rawPais = loteria["pais_nombre"].toString();
    } else {
      final pId = loteria["pais_id"]?.toString();
      if (pId == "5") {
        rawPais = "Colombia";
      } else if (pId == "21") {
        rawPais = "Estados Unidos";
      } else {
        final nombre = (loteria["nombre"] ?? "").toString().toLowerCase();
        if (nombre.contains("powerball") || nombre.contains("mega millions") || nombre.contains("double play") || nombre.contains("lotto america") || nombre.contains("millionaire")) {
          rawPais = "Estados Unidos";
        } else if (nombre.contains("baloto") || nombre.contains("miloto") || nombre.contains("colorloto") || nombre.contains("boyacá") || nombre.contains("bogotá") || nombre.contains("cundinamarca") || nombre.contains("cauca") || nombre.contains("nariño")) {
          rawPais = "Colombia";
        } else {
          rawPais = pais ?? "Internacional";
        }
      }
    }
    final langCode = Localizations.localeOf(context).languageCode;
    return PaisHelper.getNombreTraducido(rawPais, langCode);
  }

  Widget _buildLoteriaCard(dynamic loteria, {bool showCountry = true}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _resolveScreen(loteria["nombre"])),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LotteryAvatar3D(nombre: loteria["nombre"] ?? "", size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loteria["nombre"],
                      style: AppTextStyles.mensajeImportante.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (showCountry) ...[
                      const SizedBox(height: 2),
                      Text(
                        _getPaisNombre(loteria),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppLocalizations.of(context)?.proximoSorteo ?? "Próximo sorteo",
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  Text(
                    _formatearFechaSimple(loteria["proximo_sorteo"]),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodasLoteriasSection() {
    // Si solo hay 3 o menos, ya se muestran en populares, ocultamos esta sección.
    if (_filteredLoterias.length <= 3) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            AppLocalizations.of(context)?.todasLasLoterias ?? "Todas las loterías",
            style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredLoterias.length - 3,
          itemBuilder: (context, index) {
            final loteria = _filteredLoterias[index + 3];
            final String rawNombre = loteria["nombre"] ?? "";
            // Transformar a Sentence Case (primera mayúscula)
            final String nombreFormateado = rawNombre.isNotEmpty
                ? rawNombre[0].toUpperCase() + rawNombre.substring(1).toLowerCase()
                : "";

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => _resolveScreen(rawNombre)),
                  );
                },
                title: Text(
                  nombreFormateado,
                  style: AppTextStyles.h2.copyWith(color: Colors.white70, fontSize: 15),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    final l10n = AppLocalizations.of(context);
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        if (index == 0) _loadUserData(); // Actualizar país al volver al inicio
        if (index == 2) {
          _misJugadasKey.currentState?.cargarLoterias(forceRefresh: true);
        }
        setState(() => _selectedIndex = index);
      },
      backgroundColor: AppColors.black,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.yellow,
      unselectedItemColor: Colors.white54,
      selectedLabelStyle: const TextStyle(fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: l10n?.inicio ?? "Inicio"),
        BottomNavigationBarItem(icon: const Icon(Icons.explore_outlined), activeIcon: const Icon(Icons.explore), label: l10n?.explorar ?? "Explorar"),
        BottomNavigationBarItem(icon: const Icon(Icons.bookmark_outline), activeIcon: const Icon(Icons.bookmark), label: l10n?.misJugadas ?? "Mis Jugadas"),
        BottomNavigationBarItem(icon: const Icon(Icons.analytics_outlined), activeIcon: const Icon(Icons.analytics), label: l10n?.resultados ?? "Resultados"),
        BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: l10n?.perfil ?? "Perfil"),
      ],
    );
  }

  Future<void> _loadLoterias() async {
    try {
      String? paisId = await storage.read(key: "pais_id");
      if (paisId == null || paisId == 'null' || paisId.isEmpty) {
        paisId = "1";
      }

      final data = await ApiService.getLoteriasPorPais(paisId);
      List<dynamic> globalRes = [];
      if (data.isEmpty) {
        try {
          final resCol = await ApiService.getLoteriasPorPais("5");
          final resUsa = await ApiService.getLoteriasPorPais("21");
          globalRes = [...resCol, ...resUsa];
          CacheService.setJson('home_loterias_globales', globalRes);
        } catch (e) {
          debugPrint("⚠️ Error obteniendo loterías globales: $e");
        }
      }

      if (mounted) {
        setState(() {
          _loterias = data;
          _filteredLoterias = List<dynamic>.from(_loterias);
          _globalLoterias = globalRes;
          isLoading = false;
        });
        CacheService.setJson('home_loterias_$paisId', data);
      }
    } catch (e) {
      debugPrint("❌ Error cargando loterías: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> buscarAnuncios([String titulo = ""]) async {
    if (!mounted) return;
    setState(() => cargando = true);

    try {
      // 🧠 1. Cargar los filtros guardados del usuario (por ID) usando FlutterSecureStorage
      final paisIdStr = await storage.read(key: "pais_id");

      final paisId = paisIdStr != null ? int.tryParse(paisIdStr) : null;

      // 🛰️ 2. Llamar al API con los filtros por defecto
      final data = await ApiService.getPublicidades(
        paisId: paisId,
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

  // NUEVO: MÉTODO PARA RECARGAR DATOS DEL USUARIO
  Future<void> _loadUserData() async {
    final paisNombre = await storage.read(key: 'pais_nombre');
    // Puedes usar estos valores en otros FutureBuilder si necesitas

    if (mounted) {
      setState(() {
        pais = paisNombre; // 👈 aquí la guardas
      }); // Forzar rebuild del FutureBuilder del nombre
    }
  }

  // NUEVO: DETECTA CUANDO REGRESAS DEL PERFIL
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute && route.settings.arguments == true) {
      _loadUserData(); // ← Recarga nombre, país, etc.
    }
  }

  // Cargar posts
  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final rawPosts = await ApiService.getPosts();
      final postsConConteo = await Future.wait(
        rawPosts.map<Future<Post>>((p) async {
          try {
            final comments = await ApiService.getComments(p.id);
            return Post(
              id: p.id,
              title: p.title,
              content: p.content,
              userId: p.userId,
              userName: p.userName,
              createdAt: p.createdAt,
              commentsCount: comments.length,
            );
          } catch (_) {}
          return p;
        }),
      );

      if (!mounted) return;
      setState(() {
        posts = postsConConteo;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al cargar posts: $e")));
      }
    }
  }

  Future<void> _abrirPostScreen(Post post) async {
    final updatedCount = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => PostScreen(
          postId: post.id,
          postTitle: post.title,
          postUserName: post.userName,
        ),
      ),
    );

    if (updatedCount != null && mounted) {
      setState(() {
        final index = posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          final existing = posts[index];
          posts[index] = Post(
            id: existing.id,
            title: existing.title,
            content: existing.content,
            userId: existing.userId,
            userName: existing.userName,
            createdAt: existing.createdAt,
            commentsCount: updatedCount,
          );
        }
      });
    }
  }

  void _editarPost(BuildContext context, Post post) async {
    final updatedPost = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreatePostScreen(post: post)),
    );

    if (updatedPost != null && mounted) {
      setState(() {
        final index = posts.indexWhere((p) => p.id == updatedPost.id);
        if (index != -1) {
          final existing = posts[index];
          posts[index] = Post(
            id: updatedPost.id,
            title: updatedPost.title,
            content: updatedPost.content,
            userId: updatedPost.userId,
            userName: updatedPost.userName,
            createdAt: updatedPost.createdAt,
            commentsCount: updatedPost.commentsCount > 0
                ? updatedPost.commentsCount
                : existing.commentsCount,
          );
        }
      });
    }
  }

  void _eliminarPost(BuildContext context, Post post) async {
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
              "Eliminar post",
              style: AppTextStyles.h2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          "¿Seguro que deseas eliminar este post?",
          style: AppTextStyles.mensajeSecundario.copyWith(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancelar",
              style: AppTextStyles.mensajeSecundario.copyWith(
                color: Colors.amber,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Eliminar",
              style: AppTextStyles.mensajeSecundario.copyWith(
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deletePost(post.id);
        if (mounted) {
          setState(() {
            posts.removeWhere((p) => p.id == post.id); // CORREGIDO: usa ID
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Post eliminado correctamente"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error al eliminar el post: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 3.0, right: 1.0, top: 0.0, bottom: 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 110,
            child: Image.asset(
              "assets/images/logo_letras.png",
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          ),
          Row(
            children: [
              Consumer<NotificationProvider>(
                builder: (context, provider, child) {
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: AppColors.yellow, size: 28),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                          );
                        },
                      ),
                      if (provider.unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${provider.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  final GlobalKey<MisJugadasSelectorScreenState> _misJugadasKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Si el usuario se encuentra en alguna pestaña secundaria del BottomNav, volver a la pestaña Home (0)
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return;
        }

        // Si está en la pestaña principal Home, solicitar doble toque para salir
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Presiona otra vez para salir"),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.blackfondo,
        bottomNavigationBar: _buildBottomNavBar(),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeTab(),
            const LoteriasPais(),
            MisJugadasSelectorScreen(key: _misJugadasKey),
            const ResultadosSelectorScreen(),
            ProfileScreen(
              onTabChange: (index) {
                if (index == 2) {
                  _misJugadasKey.currentState?.cargarLoterias(forceRefresh: true);
                }
                setState(() => _selectedIndex = index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLoteriasState() {
    final langCode = Localizations.localeOf(context).languageCode;
    final countryName = PaisHelper.getNombreTraducido(pais ?? "Colombia", langCode);

    final String titleText = langCode == 'en'
        ? "No lotteries registered for $countryName"
        : langCode == 'pt'
            ? "Não há loterias registradas para $countryName"
            : "No hay loterías registradas para $countryName";

    final String bodyText = langCode == 'en'
        ? "Currently there are no local lotteries for this country. Below you can explore the most played lotteries in the world!"
        : langCode == 'pt'
            ? "Atualmente não há loterias locais para este país. Abaixo você pode explorar as loterias mais jogadas no mundo!"
            : "Actualmente no hay loterías locales para este país. ¡A continuación puedes explorar las loterías más jugadas en el mundo!";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.public_outlined,
              color: AppColors.yellow,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            titleText,
            style: AppTextStyles.h2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            bodyText,
            style: AppTextStyles.mensajeSecundario.copyWith(
              color: Colors.white54,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalFallbackSection() {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final String featuredTitle = langCode == 'en'
        ? "Featured Lotteries"
        : langCode == 'pt'
            ? "Loterias em Destaque"
            : "Loterías Destacadas";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                featuredTitle,
                style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoteriasPais())),
                child: Text(l10n?.verTodas ?? "Ver todas", style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _globalLoterias.length > 4 ? 4 : _globalLoterias.length,
          itemBuilder: (context, index) {
            final loteria = _globalLoterias[index];
            return _buildLoteriaCard(loteria);
          },
        ),
      ],
    );
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: RefreshIndicator(
        color: Colors.amber,
        onRefresh: () async {
          await Future.wait([
            _loadUserData(),
            buscarAnuncios(),
            _loadPosts(),
            _loadLoterias(),
            context.read<NotificationProvider>().fetchNotifications(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderRow(context),
              _buildCountryHeader(),
              _buildSearchBar(),
              
              if (isLoading && _loterias.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: AppColors.yellow),
                ))
              else if (_filteredLoterias.isEmpty) ...[
                _buildEmptyLoteriasState(),
                if (_globalLoterias.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildGlobalFallbackSection(),
                ],
              ] else ...[
                _buildPopularesSection(),
                const SizedBox(height: 10),
                _buildTodasLoteriasSection(),
              ],

              const SizedBox(height: 30),

              // SECCIÓN DE PUBLICIDAD (SE MANTIENE)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: cargando
                    ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                    : anuncios.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectorioLocalScreen())),
                            child: Text(AppLocalizations.of(context)?.anunciosDestacados ?? "Anuncios destacados", style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectorioLocalScreen())),
                            icon: const Icon(Icons.search, color: AppColors.yellow, size: 24),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    InfiniteAdsCarousel(key: ValueKey(anuncios.length), anuncios: anuncios),
                  ],
                ),
              ),

              // SECCIÓN DE POSTS (SE MANTIENE)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLocalizations.of(context)?.comentarios ?? "Comentarios", style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          color: AppColors.yellow,
                          iconSize: 28,
                          onPressed: () async {
                            final newPost = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
                            if (newPost != null && mounted) setState(() => posts.insert(0, newPost));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppContainer4(
                      child: isLoading && posts.isEmpty
                          ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                          : posts.isEmpty
                          ? Center(child: Text(AppLocalizations.of(context)?.sinPosts ?? "No hay posts", style: const TextStyle(color: AppColors.yellow)))
                          : SizedBox(
                        height: 400,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            final bool isOwner = currentUserId != null && post.userId == int.tryParse(currentUserId!);
                            return _buildPostItem(post, isOwner);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Footer(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostItem(Post post, bool isOwner) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _abrirPostScreen(post),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.getAvatarColor(post.userName, userId: post.userId),
                      child: Text(post.userName.isNotEmpty ? post.userName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                    const SizedBox(width: 8),
                    Text("@${post.userName}", style: AppTextStyles.mensajeSecundario.copyWith(fontSize: 12)),
                    const SizedBox(width: 6),
                    const Text("•", style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      post.relativeTime,
                      style: AppTextStyles.caption.copyWith(fontSize: 11, color: Colors.white54),
                    ),
                    const Spacer(),
                    if (isOwner) _buildPostOptions(post),
                  ],
                ),
                const SizedBox(height: 6),
                Text(post.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(post.content, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _abrirPostScreen(post),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.reply_outlined, color: AppColors.yellow, size: 15),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)?.responder ?? "Responder",
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => _abrirPostScreen(post),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              color: AppColors.yellow,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${post.commentsCount} ${post.commentsCount == 1 ? (AppLocalizations.of(context)?.respuesta ?? 'respuesta') : (AppLocalizations.of(context)?.respuestas ?? 'respuestas')}",
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, thickness: 0.5),
        ],
      ),
    );
  }

  Widget _buildPostOptions(Post post) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: Colors.white38, size: 18),
      onSelected: (val) {
        if (val == 'edit') {
          _editarPost(context, post);
        } else if (val == 'delete') {
          _eliminarPost(context, post);
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'edit', child: Text("Editar")),
        const PopupMenuItem(value: 'delete', child: Text("Eliminar", style: TextStyle(color: Colors.redAccent))),
      ],
    );
  }


  Widget _resolveScreen(String? tipo) {
    final t = (tipo ?? "").toLowerCase().trim();
    if (t.contains("baloto")) return const BalotoScreen();
    if (t.contains("miloto")) return const MilotoScreen();
    if (t.contains("powerball")) return const PowerballScreen();
    if (t.contains("lotto america")) return const LottoAmericaScreen();
    if (t.contains("double play")) return const DoublePlayScreen();
    if (t.contains("millionaire")) return const MillionaireLifeScreen();
    if (t.contains("mega millions") || t.contains("megamillions")) return const MegaMillionsScreen();
    return ColorLotoScreen();
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Esperar un momento para asegurar que el userId esté disponible en el storage
      await Future.delayed(const Duration(seconds: 2));

      // Obtener el token único del dispositivo
      String? token = await messaging.getToken();
      if (token != null) {
        debugPrint("📱 FCM Token obtenido: $token");
        // Enviar al backend para guardarlo en el perfil del usuario
        final success = await ApiService.updateFCMToken(token);
        if (success) {
          debugPrint("✅ FCM Token registrado exitosamente en el servidor");
        } else {
          debugPrint("⚠️ No se pudo registrar el FCM Token en el servidor (Posiblemente sesión no iniciada)");
        }
      }

      // Escuchar cambios de token
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        ApiService.updateFCMToken(newToken);
      });

      // Escuchar mensajes cuando la app está en primer plano
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("📩 Notificación Push recibida en primer plano: ${message.notification?.title}");
        if (mounted) {
          // Refrescar contador de notificaciones en el provider
          context.read<NotificationProvider>().fetchNotifications();

          final title = message.notification?.title;
          final body = message.notification?.body;
          
          if (title != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: AppColors.yellow),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          if (body != null) Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF1E2028),
                duration: const Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      });
    } catch (e) {
      debugPrint("⚠️ Error en configuración FCM: $e");
    }
  }
}
