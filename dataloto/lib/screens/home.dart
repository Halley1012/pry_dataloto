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

// HomeScreen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final storage = const FlutterSecureStorage();
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
    super.dispose();
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

  Future<void> _loadUserAndPosts() async {
    await _loadCurrentUserId(); // Esperamos al userId
    await _loadPosts(); // Luego cargamos posts
  }

  // Cargar ID del usuario actual
  Future<void> _loadCurrentUserId() async {
    final userId = await storage.read(key: 'user_id'); // CLAVE CORRECTA
    //print("Usuario actual (user_id): $userId"); // DEBUG

    if (mounted) {
      setState(() => currentUserId = userId);
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

  Future<String> _getUserName() async {
    final name = await storage.read(key: 'name');
    if (name != null && name.isNotEmpty) return name;
    return "?";
  }

  void _showDialog(BuildContext context, String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: GoogleFonts.montserrat(color: Colors.white)),
        content: Text(
          content,
          style: GoogleFonts.montserrat(color: Colors.white70),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Text(
              "Cerrar sesión",
              style: AppTextStyles.h2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          "¿Seguro que quieres cerrar sesión?",
          style: AppTextStyles.mensajeSecundario.copyWith(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancelar",
              style: AppTextStyles.mensajeSecundario.copyWith(
                color: Colors.amber,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await storage.deleteAll();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
              );
            },
            child: Text(
              "Cerrar sesión",
              style: AppTextStyles.mensajeSecundario.copyWith(
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
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

  void _denunciarPost(BuildContext context, Post post) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Has denunciado el post de @${post.userName}")),
    );
  }

  Future<void> _eliminarCuenta(BuildContext context) async {
    // Estado del botón
    bool isDeleting = false;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Evita cerrar tocando fuera
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                "Eliminar cuenta",
                style: AppTextStyles.h2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: isDeleting
              ? const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.yellow,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text(
                "Borrando cuenta...",
                style: TextStyle(color: AppColors.yellow),
              ),
            ],
          )
              : Text(
            "¿Estás seguro de que deseas eliminar tu cuenta? Esta acción es irreversible.",
            style: AppTextStyles.mensajeSecundario.copyWith(
              color: Colors.white70,
            ),
          ),
          actions: [
            // CANCELAR (solo si no está borrando)
            if (!isDeleting)
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  "Cancelar",
                  style: AppTextStyles.mensajeSecundario.copyWith(
                    color: Colors.amber,
                  ),
                ),
              ),

            // ELIMINAR O "BORRANDO..."
            TextButton(
              onPressed: isDeleting
                  ? null // Desactiva el botón
                  : () async {
                Navigator.pop(context, true); // Cierra diálogo con true
              },
              child: isDeleting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.redAccent,
                  strokeWidth: 2,
                ),
              )
                  : Text(
                "Eliminar",
                style: AppTextStyles.mensajeSecundario.copyWith(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Si no confirmó → salir
    if (confirm != true) return;

    // Evitar múltiples ejecuciones
    if (isDeleting) return;
    isDeleting = true;

    try {
      final userIdStr = await storage.read(key: 'user_id');
      final userId = int.tryParse(userIdStr ?? '');

      if (userId == null) {
        _showDialog(context, "Error", "No se encontró el ID del usuario.");
        return;
      }

      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.yellow),
        ),
      );

      final result = await ApiService.deleteUser(userId);

      // Cerrar loader
      if (context.mounted) Navigator.pop(context);

      // Éxito
      _showDialog(
        context,
        "Cuenta eliminada",
        result['message'] ?? "Tu cuenta fue eliminada exitosamente.",
      );

      await storage.deleteAll();

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Cierra loader
      _showDialog(context, "Error", "No se pudo eliminar la cuenta: $e");
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
                  return PopupMenuButton<int>(
                constraints: const BoxConstraints(minWidth: 180),
                offset: const Offset(0, 55),
                color: AppColors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                icon: Container(
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
                onSelected: (value) async {
                  if (!mounted) return;
                  switch (value) {
                    case 0:
                      _showJustifiedDialog(
                        context,
                        "Aviso legal",
                        "Esta app no es oficial ni está asociada con operadores de loterías ni con entidades reguladoras de juegos de azar en ningún país. No es un juego de lotería, sino una herramienta de análisis estadístico e inteligencia artificial que genera predicciones para que elijas tus números con más confianza. Los resultados no garantizan premios y su uso es únicamente con fines informativos y de entretenimiento.",
                      );
                      break;

                    case 1:
                      _showJustifiedDialog(
                        context,
                        "Acerca de",
                        "DataLoto utiliza inteligencia artificial para analizar patrones históricos de loterías y ofrecer predicciones informadas. Aunque nuestras predicciones se basan en datos, no hay certeza absoluta de que esos números sean los ganadores, ya que la lotería es un juego de azar. No garantizamos premios, solo te ayudamos a elegir con más confianza. Usa la app con responsabilidad y solo con fines de entretenimiento. La decisión de utilizar estas predicciones queda bajo tu propia responsabilidad.",
                      );
                      break;
                    case 2:
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MisAnunciosScreen(),
                        ),
                      );
                      break;
                    case 3:
                      final allData = await storage.readAll();

                      if (allData['user_id'] == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Debes iniciar sesión"),
                          ),
                        );
                        break;
                      }

                      final user = {
                        'name': allData['name'],
                        'email': allData['email'],
                        'pais_id': int.tryParse(allData['pais_id'] ?? '0'),
                        'departamento_id': int.tryParse(
                          allData['departamento_id'] ?? '0',
                        ),
                      };

                      final userId = int.tryParse(allData['user_id'] ?? '0');

                      if (!context.mounted) return;

                      final updatedUser = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RegistroScreen(user: user, userId: userId),
                        ),
                      );

                      if (updatedUser != null &&
                          updatedUser is Map<String, dynamic>) {
                        await storage.write(
                          key: 'name',
                          value: updatedUser['name'] ?? allData['name'],
                        );
                        await storage.write(
                          key: 'email',
                          value: updatedUser['email'] ?? allData['email'],
                        );
                        await storage.write(
                          key: 'pais_id',
                          value:
                          updatedUser['pais_id']?.toString() ??
                              allData['pais_id'],
                        );
                        await storage.write(
                          key: 'departamento_id',
                          value:
                          updatedUser['departamento_id']?.toString() ??
                              allData['departamento_id'],
                        );
                      }

                      break;

                    case 4:
                      _showLogoutDialog(context);
                      break;
                    case 5:
                      await _eliminarCuenta(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 0,
                    child: Text(
                      "Aviso legal",
                      style: AppTextStyles.mensajeSecundario,
                    ),
                  ),
                  PopupMenuItem(
                    value: 1,
                    child: Text(
                      "Acerca de",
                      style: AppTextStyles.mensajeSecundario,
                    ),
                  ),
                  PopupMenuItem(
                    value: 2,
                    child: Text(
                      "Mis anuncios",
                      style: AppTextStyles.mensajeSecundario,
                    ),
                  ),
                  PopupMenuItem(
                    value: 3,
                    child: Text(
                      "Mis datos",
                      style: AppTextStyles.mensajeSecundario,
                    ),
                  ),
                  PopupMenuItem(
                    value: 4,
                    child: Text(
                      "Cerrar sesión",
                      style: AppTextStyles.mensajeSecundario,
                    ),
                  ),
                  PopupMenuItem(
                    value: 5,
                    child: Text(
                      "Eliminar cuenta",
                      style: AppTextStyles.mensajeSecundario.copyWith(
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      body: SafeArea(
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
              children: [
                _buildHeaderRow(context),
                const SizedBox(height: 10),
                FutureBuilder<String>(
                  future: _getUserName(),
                  builder: (context, snapshot) {
                    final name = snapshot.data ?? "";
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text("Hola, $name", style: AppTextStyles.h2),
                          ),
                          //const AnimatedShimmerClover(),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ShimmerBorderContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Text(
                        "Olvídate del azar, aquí analizamos por ti. Predicciones con IA para que elijas tus números con más confianza.",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.mensajeSecundario.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 50),
                Text(
                  "Loterías disponibles en ${pais ?? 'tu país'}",
                  style: AppTextStyles.mensajeImportante,
                ),
                const SizedBox(height: 15),
                Center(
                  child: SizedBox(
                    width: 300,
                    child: Divider(
                      color: AppColors.yellow,
                      thickness: 1,
                      height: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                      : Column(
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _loterias.length > 4
                            ? 4
                            : _loterias.length,
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 1.45,
                        ),
                        itemBuilder: (context, index) {
                          final loteria = _loterias[index];

                          return _buildGameCardIcon(
                            context,
                            loteria["nombre"],
                            null,
                            AppColors.darkGray,
                                () => _resolveScreen(loteria["nombre"]),
                          );
                        },
                      ),

                      if (_loterias.length > 4) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoteriasPais(),
                                ),
                              );
                            },
                            child: Text(
                              "Ver más loterías",
                              style: AppTextStyles.mensajeSecundario
                                  .copyWith(color: AppColors.yellow),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: cargando
                      ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                      : anuncios.isEmpty
                      ? Column(
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
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 Encabezado: "Explora negocios cerca de ti"
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const DirectorioLocalScreen(),
                                ),
                              ),
                              child: Text(
                                "Explora negocios cerca de ti",
                                style: AppTextStyles.h2,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const DirectorioLocalScreen(),
                                ),
                              ),
                              icon: Icon(
                                Icons.search,
                                color: AppColors.yellow,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 🔸 Carrusel horizontal
                      InfiniteAdsCarousel(
                        key: ValueKey(anuncios.length),
                        anuncios: anuncios,
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                // SECCIÓN DE POSTS
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Comentarios", style: AppTextStyles.h2),
                          IconButton(
                            icon: const Icon(Icons.add),
                            color: AppColors.yellow,
                            iconSize: 30,
                            onPressed: () async {
                              if (!mounted) return;
                              final newPost = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreatePostScreen(),
                                ),
                              );
                              if (newPost != null && mounted) {
                                setState(() => posts.insert(0, newPost));
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // LISTA DE POSTS
                      AppContainer4(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                            : posts.isEmpty
                            ? const Center(
                          child: Text(
                            "No hay posts",
                            style: TextStyle(color: AppColors.yellow),
                          ),
                        )
                            : SizedBox(
                          height: 500,
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final post = posts[index];

                              // DETERMINAR SI ES DUEÑO
                              final bool isOwner =
                                  currentUserId != null &&
                                      post.userId ==
                                          int.tryParse(currentUserId!);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                  horizontal: 2.0,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () => _abrirPostScreen(post),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          // 1. FILA DE ENCABEZADO: Avatar + @userName • hace X d + Menú Opciones (⋮)
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundColor: AppColors.getAvatarColor(post.userName, userId: post.userId),
                                                child: Text(
                                                  post.userName.isNotEmpty ? post.userName[0].toUpperCase() : "?",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "@${post.userName}",
                                                style: AppTextStyles.mensajeSecundario
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                "•",
                                                style: TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                post.relativeTime,
                                                style: AppTextStyles
                                                    .caption
                                                    .copyWith(
                                                  fontSize: 11,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                              const Spacer(),
                                              if (isOwner)
                                                PopupMenuButton<String>(
                                                  icon: const Icon(
                                                    Icons.more_vert,
                                                    color: Colors.white54,
                                                    size: 18,
                                                  ),
                                                  color: const Color(0xFF1E1E2E),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  onSelected: (value) {
                                                    if (value == 'edit') {
                                                      _editarPost(context, post);
                                                    } else if (value == 'delete') {
                                                      _eliminarPost(context, post);
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.edit_outlined,
                                                            color: Colors.lightBlueAccent,
                                                            size: 16,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text('Editar', style: TextStyle(color: Colors.white, fontSize: 13)),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'delete',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.delete_outline,
                                                            color: Colors.redAccent,
                                                            size: 16,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          // 2. DEBAJO DEL ICONO DE LA INICIAL: TÍTULO DEL POST
                                          Text(
                                            post.title,
                                            style: AppTextStyles.h2.copyWith(
                                              fontSize: 15,
                                              color: AppColors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),

                                          // 3. DESCRIPCIÓN / CONTENIDO DEL POST
                                          Text(
                                            post.content,
                                            style: AppTextStyles.mensajeSecundario.copyWith(
                                              color: Colors.white.withValues(alpha: 0.9),
                                              fontSize: 13.5,
                                              height: 1.35,
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          // 4. FILA DE ACCIONES (RESPONDER Y RESPUESTAS)
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
                                                        "Responder",
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
                                                        Icons.keyboard_arrow_down,
                                                        color: AppColors.yellow,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        "${post.commentsCount} ${post.commentsCount == 1 ? 'respuesta' : 'respuestas'}",
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
                                    const SizedBox(height: 8),
                                    const Divider(
                                      color: AppColors.grayBlue,
                                      thickness: 0.3,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                const Footer(),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
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

  Widget _resolveScreen(String? tipo) {
    switch (tipo) {
      case "Baloto / Revancha":
        return BalotoScreen();
      case "Miloto":
        return MilotoScreen();
      default:
        return ColorLotoScreen();
    }
  }
}
