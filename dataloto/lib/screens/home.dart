import 'package:dataloto/services/cache_service.dart';
import 'package:dataloto/screens/directorioLocal.dart';
import 'package:dataloto/screens/loteriasPais.dart';
import 'package:dataloto/screens/misanuncios.dart';
import 'package:dataloto/screens/welcome.dart';
import 'package:dataloto/widgets/carrusel.dart';
import 'package:dataloto/widgets/contenedor2.dart';
import 'package:dataloto/widgets/contenedor4.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'baloto.dart';
import 'miloto.dart';
import 'color_loto.dart';
import 'powerball.dart';
import 'lotto_america.dart';
import 'double_play.dart';
import 'millionaire_life.dart';
import 'megamillions.dart';
import 'baloto_mis_jugadas.dart';
import 'estadisticas_bloto.dart';
import 'profile_screen.dart';

import 'package:dataloto/styles/app_text_styles.dart';
import 'login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dataloto/widgets/footer.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../screens/createpostscreen.dart';
import '../screens/notifications_screen.dart';
import 'post.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/screens/registro.dart';
import 'package:provider/provider.dart';
import 'package:dataloto/providers/notification_provider.dart';
import '../utils/pais_helper.dart';

// HomeScreen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final storage = const FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool cargando = false;
  List<Map<String, dynamic>> anuncios = [];
  bool isLoading = false;
  List<Post> posts = [];
  String? currentUserId;
  String? pais;
  List<dynamic> _loterias = [];
  List<dynamic> _filteredLoterias = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _loadUserAndData();
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
      if (cachedLoterias != null && mounted) {
        setState(() {
          currentUserId = userIdStr;
          pais = paisNombreStr ?? "Colombia";
          _loterias = List<dynamic>.from(cachedLoterias);
          _filteredLoterias = List<dynamic>.from(_loterias);
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

      if (!mounted) return;

      setState(() {
        currentUserId = userIdStr;
        pais = paisNombreStr ?? "Colombia";
        posts = postsConConteo;
        anuncios = resultados[1] as List<Map<String, dynamic>>;
        _loterias = resultados[2] as List<dynamic>;
        _filteredLoterias = List<dynamic>.from(_loterias);
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
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildCountryHeader() {
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
            pais ?? "Colombia",
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
            hintText: "Buscar lotería...",
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Populares", style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoteriasPais())),
                child: Text("Ver todas", style: TextStyle(color: Colors.white54, fontSize: 14)),
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
            return _buildLoteriaCard(loteria);
          },
        ),
      ],
    );
  }

  String _formatearFechaSimple(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "Próximamente";
    try {
      DateTime parsed = DateTime.parse(fecha.substring(0, 10));
      const meses = [
        "Ene", "Feb", "Mar", "Abr", "May", "Jun",
        "Jul", "Ago", "Sep", "Oct", "Nov", "Dic",
      ];
      String mes = meses[parsed.month - 1];
      return "${parsed.day.toString().padLeft(2, '0')} $mes ${parsed.year}";
    } catch (_) {
      return fecha;
    }
  }

  Widget _buildLoteriaCard(dynamic loteria) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _resolveScreen(loteria["nombre"])),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              loteria["nombre"][0],
              style: const TextStyle(color: AppColors.yellow, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
        ),
        title: Text(
          loteria["nombre"],
          style: AppTextStyles.mensajeImportante.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text("Próximo sorteo", style: TextStyle(color: Colors.white38, fontSize: 10)),
            Text(
              _formatearFechaSimple(loteria["proximo_sorteo"]), 
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
      ),
    );
  }

  Widget _buildTodasLoteriasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text("Todas las loterías", style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredLoterias.length > 3 ? _filteredLoterias.length - 3 : 0,
          separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, index) {
            final loteria = _filteredLoterias[index + 3];
            return ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => _resolveScreen(loteria["nombre"])),
                );
              },
              title: Text(loteria["nombre"], style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white70)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        if (index == 0) _loadUserData(); // Actualizar país al volver al inicio
        setState(() => _selectedIndex = index);
      },
      backgroundColor: AppColors.black,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.yellow,
      unselectedItemColor: Colors.white54,
      selectedLabelStyle: const TextStyle(fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Inicio"),
        BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: "Explorar"),
        BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline), activeIcon: Icon(Icons.bookmark), label: "Mis Jugadas"),
        BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: "Resultados"),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Perfil"),
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

      if (mounted) {
        setState(() {
          _loterias = data;
          _filteredLoterias = List<dynamic>.from(_loterias);
          isLoading = false;
        });
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
      final departamentoIdStr = await storage.read(key: "departamento_id");
      final ciudadIdStr = await storage.read(key: "ciudad_id");

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

  // NUEVO: MÉTODO PARA RECARGAR DATOS DEL USUARIO
  Future<void> _loadUserData() async {
    final name = await storage.read(key: 'name');
    final paisNombre = await storage.read(key: 'pais_nombre');
    final departamentoNombre = await storage.read(key: 'departamento_nombre');
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

  Future<String> _getUserInitial() async {
    final name = await storage.read(key: 'name');
    if (name != null && name.isNotEmpty) return name[0].toUpperCase();
    return "?";
  }

  void _showJustifiedDialog(
      BuildContext context,
      String title,
      String content,
      ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.blackfondo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title, style: AppTextStyles.h2),
          content: SingleChildScrollView(
            child: Text(
              content,
              textAlign: TextAlign.justify, // texto justificado
              style: AppTextStyles.mensajeSecundario, // mantiene tus estilos
            ),
          ),
        );
      },
    );
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
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 2.0, bottom: 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 110,
            child: Image.asset(
              "assets/images/logo_letras.png",
              fit: BoxFit.contain,
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
              const SizedBox(width: 8),
              FutureBuilder<String>(
                future: _getUserInitial(),
                builder: (context, snapshot) {
                  final initial = snapshot.data ?? "?";
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedIndex = 4);
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF252B35),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.yellow,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.yellow,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      bottomNavigationBar: _buildBottomNavBar(),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          const LoteriasPais(),
          const BalotoMisJugadasScreen(),
          const EstadisticasBlotoScreen(),
          const ProfileScreen(),
        ],
      ),
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
              else ...[
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
                            child: Text("Anuncios destacados", style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        Text("Comentarios", style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          ? const Center(child: Text("No hay posts", style: TextStyle(color: AppColors.yellow)))
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
                    const Spacer(),
                    if (isOwner) _buildPostOptions(post),
                  ],
                ),
                const SizedBox(height: 6),
                Text(post.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(post.content, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
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
        if (val == 'edit') _editarPost(context, post);
        else if (val == 'delete') _eliminarPost(context, post);
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'edit', child: Text("Editar")),
        const PopupMenuItem(value: 'delete', child: Text("Eliminar", style: TextStyle(color: Colors.redAccent))),
      ],
    );
  }

  Widget _buildGameCardIcon(
      BuildContext context,
      String title,
      IconData? icon,
      Color color,
      Widget Function() destinationBuilder,
      ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destinationBuilder()),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        width: 140,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF282E3B), Color(0xFF191D26)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.yellow,
              ),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, size: 32, color: AppColors.grayBlue)
                  : Text(
                title.isNotEmpty ? title[0].toUpperCase() : "?",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.grayBlue,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.mensajeImportante.copyWith(
                shadows: [
                  const Shadow(
                    blurRadius: 4,
                    color: Colors.black26,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

}
