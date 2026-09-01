import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'package:eterlotto/screens/directorioLocal.dart';
import 'package:eterlotto/screens/loteriasPais.dart';
import 'package:eterlotto/widgets/contenedor4.dart';
import 'package:eterlotto/widgets/lottery_avatar_3d.dart';
import 'package:eterlotto/screens/loteria_screen.dart';
import 'package:eterlotto/screens/profile_screen.dart';
import 'package:eterlotto/screens/mis_jugadas_selector_screen.dart';
import 'package:eterlotto/screens/resultados_selector_screen.dart';

import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/models/post.dart';
import 'package:eterlotto/screens/createpostscreen.dart';
import 'package:eterlotto/screens/notifications_screen.dart';
import 'package:eterlotto/screens/post.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:provider/provider.dart';
import 'package:eterlotto/providers/notification_provider.dart';
import 'package:eterlotto/utils/pais_helper.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/widgets/banner_ad_widget.dart';
import 'package:eterlotto/widgets/user_balota_avatar.dart';
import 'package:eterlotto/services/data_refresh_manager.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/subscription_provider.dart';
import '../utils/secure_storage_helper.dart';

// HomeScreen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final storage = AppSecureStorage.instance;
  bool cargando = false;
  List<Map<String, dynamic>> anuncios = [];
  bool isLoading = false;
  List<Post> posts = [];
  String? currentUserId;
  String? pais;
  String? userName;
  String? avatarUrl;
  List<dynamic> _loterias = [];
  List<dynamic> _filteredLoterias = [];
  List<dynamic> _globalLoterias = [];
  int _selectedIndex = 0;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    DataRefreshManager.instance.refreshNotifier.addListener(_onDataRefreshNotification);
    _loadUserAndData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().fetchNotifications();
      }
    });
  }

  @override
  void dispose() {
    DataRefreshManager.instance.refreshNotifier.removeListener(_onDataRefreshNotification);
    super.dispose();
  }

  void _onDataRefreshNotification() {
    final module = DataRefreshManager.instance.refreshNotifier.value;
    if (module == RefreshModules.home || module == 'all') {
      if (mounted) {
        debugPrint("🔄 [HomeScreen] Auto-refrescando datos por notificación de ciclo de vida / TTL");
        _loadUserAndData(forceRefresh: false);
      }
    }
  }

  Future<void> _loadUserAndData({bool forceRefresh = false}) async {
    try {
      if (mounted) {
        context.read<SubscriptionProvider>().refreshSubscriptionStatus();
      }

      // 1. Leer credenciales de storage en paralelo
      final keys = await Future.wait([
        storage.read(key: 'user_id'),
        storage.read(key: 'pais_id'),
        storage.read(key: 'pais_nombre'),
        storage.read(key: 'name'),
        storage.read(key: 'avatar_url'),
      ]);

      String? userIdStr = keys[0];
      if (userIdStr == null || userIdStr.isEmpty) {
        final uid = await ApiService.getUserId();
        userIdStr = uid?.toString();
      }
      final rawPaisId = keys[1];
      final paisNombreStr = keys[2];
      final nameStr = keys[3];
      final avatarUrlStr = keys[4];

      String paisIdStr = (rawPaisId != null && rawPaisId != 'null' && rawPaisId.isNotEmpty)
          ? rawPaisId
          : "5";
      if (paisNombreStr != null && paisNombreStr.toLowerCase().contains("estados")) {
        paisIdStr = "21";
      } else if (paisNombreStr != null && paisNombreStr.toLowerCase().contains("colombia")) {
        paisIdStr = "5";
      }
      final paisIdInt = int.tryParse(paisIdStr);

      // ⚡ 1. Cargar desde caché local para despliegue instantáneo (0 ms) si no es forceRefresh
      if (!forceRefresh) {
        final cachedLoterias = await CacheService.getJson('home_loterias_$paisIdStr');
        final cachedAnuncios = await CacheService.getJson('home_anuncios_$paisIdStr');
        final cachedGlobal = await CacheService.getJson('home_loterias_globales');
        if (cachedLoterias != null && mounted) {
          setState(() {
            currentUserId = userIdStr;
            pais = paisNombreStr ?? "Colombia";
            userName = nameStr;
            avatarUrl = avatarUrlStr;
            _loterias = List<dynamic>.from(cachedLoterias);
            _filteredLoterias = List<dynamic>.from(_loterias);
            if (cachedGlobal != null) _globalLoterias = List<dynamic>.from(cachedGlobal);
            if (cachedAnuncios != null) anuncios = List<Map<String, dynamic>>.from(cachedAnuncios);
            isLoading = false;
            cargando = false;
          });
        }
      }

      if (_loterias.isEmpty) setState(() => isLoading = true);

      // 2. Cargar Posts, Anuncios y Loterías en PARALELO directamente desde el servidor
      final Future<List<Post>> postsFuture = ApiService.getPosts().catchError((e) {
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

      String? finalName = nameStr;
      String? finalAvatar = avatarUrlStr;

      // 🔍 Recuperar de SharedPreferences si falta en storage
      if (finalName == null || finalName.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final spName = prefs.getString("username");
          if (spName != null && spName.isNotEmpty) {
            finalName = spName;
            await storage.write(key: 'name', value: spName);
          }
        } catch (_) {}
      }

      // 🔍 Si falta nombre o avatar y tenemos userId, consultar al backend
      if (((finalName == null || finalName.isEmpty) || finalAvatar == null) && userIdStr != null && userIdStr.isNotEmpty) {
        try {
          final profileRes = await ApiService.get("/users/$userIdStr");
          if (profileRes.statusCode == 200) {
            final profileData = jsonDecode(profileRes.body);
            if (profileData is Map) {
              final remoteName = profileData["name"]?.toString();
              final remoteAvatar = profileData["avatar_url"]?.toString();
              if (remoteName != null && remoteName.isNotEmpty) {
                finalName = remoteName;
                await storage.write(key: 'name', value: remoteName);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString("username", remoteName);
              }
              if (remoteAvatar != null && remoteAvatar.isNotEmpty) {
                finalAvatar = remoteAvatar;
                await storage.write(key: 'avatar_url', value: remoteAvatar);
              }
            }
          }
        } catch (e) {
          debugPrint("⚠️ Error consultando perfil de usuario: $e");
        }
      }

      if (!mounted) return;

      setState(() {
        currentUserId = userIdStr;
        pais = paisNombreStr ?? "Colombia";
        userName = finalName;
        avatarUrl = finalAvatar;
        posts = rawPosts;
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
      DataRefreshManager.instance.markUpdated(RefreshModules.home);
    } catch (e) {
      debugPrint("❌ Error al cargar la página principal: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
        cargando = false;
      });
    }
  }

  Widget _buildWelcomeGreeting() {
    final l10n = AppLocalizations.of(context);
    final rawName = userName?.trim();
    final displayName = (rawName != null && rawName.isNotEmpty)
        ? rawName.split(' ').first
        : "Usuario";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.saludoUsuario(displayName) ?? "¡Hola, $displayName! 👋",
            style: AppTextStyles.h1.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            l10n?.subtituloSuerte ?? "Tu suerte comienza aquí.",
            style: GoogleFonts.montserrat(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCountryHeader() {
    final langCode = Localizations.localeOf(context).languageCode;
    final nombrePaisDisplay = PaisHelper.getNombreTraducido(pais ?? "Colombia", langCode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 40.0, 16.0, 12.0),
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
              Expanded(
                child: Text(
                  l10n?.populares ?? "Populares",
                  style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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

  String _formatearFechaProximo(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "Próximo sorteo";
    try {
      final clean = fecha.trim();
      final parsed = DateTime.tryParse(clean) ?? (clean.length >= 10 ? DateTime.tryParse(clean.substring(0, 10)) : null);
      if (parsed == null) return fecha;

      final langCode = Localizations.localeOf(context).languageCode;
      final dias = langCode == 'en' 
          ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
          : (langCode == 'pt' 
              ? ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
              : ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]);

      final meses = langCode == 'en'
          ? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
          : (langCode == 'pt'
              ? ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]
              : ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]);

      final diaSemana = dias[parsed.weekday - 1];
      final mes = meses[parsed.month - 1];

      return "$diaSemana, ${parsed.day} $mes ${parsed.year}";
    } catch (_) {
      return fecha;
    }
  }

  String _calcularEstadoSorteo(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "";
    try {
      final clean = fecha.trim();
      final parsed = DateTime.tryParse(clean) ?? (clean.length >= 10 ? DateTime.tryParse(clean.substring(0, 10)) : null);
      if (parsed == null) return "";

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(parsed.year, parsed.month, parsed.day);
      final diff = target.difference(today).inDays;

      final langCode = Localizations.localeOf(context).languageCode;

      if (diff == 0) {
        return langCode == 'en' ? "Draws today" : (langCode == 'pt' ? "Sorteia hoje" : "Sortea hoy");
      } else if (diff == 1) {
        return langCode == 'en' ? "Tomorrow" : (langCode == 'pt' ? "Amanhã" : "Mañana");
      } else if (diff > 1) {
        return langCode == 'en' ? "In $diff days" : (langCode == 'pt' ? "Faltam $diff dias" : "Faltan $diff días");
      } else if (diff == -1) {
        return langCode == 'en' ? "Drew yesterday" : (langCode == 'pt' ? "Sorteado ontem" : "Sorteó ayer");
      } else {
        final dias = diff.abs();
        return langCode == 'en' ? "Drew $dias days ago" : (langCode == 'pt' ? "Sorteado há $dias dias" : "Sorteó hace $dias días");
      }
    } catch (_) {
      return "";
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
        rawPais = pais ?? "Internacional";
      }
    }
    final langCode = Localizations.localeOf(context).languageCode;
    return PaisHelper.getNombreTraducido(rawPais, langCode);
  }

  Widget _buildLoteriaCard(dynamic loteria, {bool showCountry = true}) {
    final rawFecha = loteria["proximo_sorteo"] ?? loteria["fecha"] ?? loteria["ultimo_sorteo"];
    final fechaDisplay = _formatearFechaProximo(rawFecha?.toString());
    final estadoDisplay = _calcularEstadoSorteo(rawFecha?.toString());
    final String rawNombre = loteria["nombre"] ?? "";
    final String nombreFormateado = rawNombre.isNotEmpty
        ? rawNombre[0].toUpperCase() + rawNombre.substring(1).toLowerCase()
        : "";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _resolveScreen(loteria)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LotteryAvatar3D(nombre: rawNombre, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreFormateado,
                      style: AppTextStyles.mensajeImportante.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    if (showCountry) ...[
                      const SizedBox(height: 1),
                      Text(
                        _getPaisNombre(loteria),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10.5,
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
                    style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    fechaDisplay,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (estadoDisplay.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      estadoDisplay,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
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
            return _buildLoteriaCard(loteria, showCountry: true);
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
      ],
    );
  }

  Future<void> buscarAnuncios({String titulo = "", bool silent = false}) async {
    if (!mounted) return;
    if (!silent || anuncios.isEmpty) {
      setState(() => cargando = true);
    }

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
      if (mounted && !silent) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.errorAnuncios ?? 'Error al cargar los anuncios.')),
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
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.postEliminado ?? "Post eliminado correctamente"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.errorEliminarPost(e.toString()) ?? "Error al eliminar el post: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 4.0),
      child: SizedBox(
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo Eterlotto más grande y adaptativo a cualquier tamaño de pantalla
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  "assets/images/eterlotto_gold_trans.png",
                  height: 48,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Acciones: Campanita de Notificaciones + Avatar de Perfil
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Consumer<NotificationProvider>(
                  builder: (context, provider, child) {
                    return SizedBox(
                      width: 42,
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: AppColors.yellow,
                              size: 28,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                              );
                            },
                          ),
                          if (provider.unreadCount > 0)
                            Positioned(
                              right: 3,
                              top: 3,
                              child: Container(
                                padding: const EdgeInsets.all(3),
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
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          onProfileUpdated: () {
                            _loadUserAndData(forceRefresh: true);
                          },
                        ),
                      ),
                    );
                  },
                  child: UserBalotaAvatar(
                    avatarUrl: avatarUrl,
                    userName: userName,
                    userId: int.tryParse(currentUserId ?? "0"),
                    radius: 22,
                    showGlow: true,
                    showBorder: true,
                    borderColor: AppColors.yellow,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.presionaOtraVezSalir ?? "Presiona otra vez para salir"),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.blackfondo,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BannerAdWidget(),
            _buildBottomNavBar(),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeTab(),
            const LoteriasPais(),
            const MisJugadasSelectorScreen(),
            const ResultadosSelectorScreen(),
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
              Expanded(
                child: Text(
                  featuredTitle,
                  style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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

  Future<void> _refreshHome() async {
    try {
      await _loadUserAndData(forceRefresh: true);
      if (mounted) {
        await context.read<NotificationProvider>().fetchNotifications();
      }
    } catch (e) {
      debugPrint("⚠️ Error al refrescar Home: $e");
    }
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.yellow,
        backgroundColor: const Color(0xFF1E1E1E),
        displacement: 40.0,
        onRefresh: _refreshHome,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeaderRow(context),
            ),
            SliverToBoxAdapter(
              child: _buildWelcomeGreeting(),
            ),
            SliverToBoxAdapter(
              child: _buildCountryHeader(),
            ),
            if (isLoading && _loterias.isEmpty)
              SliverToBoxAdapter(
                child: _buildHomeSkeleton(),
              )
            else if (_filteredLoterias.isEmpty) ...[
              SliverToBoxAdapter(
                child: _buildEmptyLoteriasState(),
              ),
              if (_globalLoterias.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _buildGlobalFallbackSection(),
                  ),
                ),
            ] else ...[
              SliverToBoxAdapter(
                child: _buildPopularesSection(),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 10),
              ),
              SliverToBoxAdapter(
                child: _buildTodasLoteriasSection(),
              ),
            ],
            const SliverToBoxAdapter(
              child: SizedBox(height: 30),
            ),
            SliverToBoxAdapter(
              child: _buildBuscaloAquiSection(),
            ),
            SliverToBoxAdapter(
              child: _buildComunidadSection(),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 30),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuscaloAquiSection() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n?.buscaloAqui ?? "Búscalo aquí",
                  style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DirectorioLocalScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12, width: 0.8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.yellow, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n?.buscarDirectorioHint ?? "Encuentra negocios, servicios y comercios...",
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComunidadSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)?.comentarios ?? "Comentarios",
                  style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                ? Shimmer.fromColors(
                    baseColor: const Color(0xFF1A1A1A),
                    highlightColor: const Color(0xFF2C2C2C),
                    child: Column(
                      children: List.generate(
                        3,
                        (index) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  )
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
                    UserBalotaAvatar(
                      userName: post.userName,
                      userId: post.userId,
                      radius: 12,
                      animateGradient: false,
                      showGlow: false,
                      showBorder: false,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "@${post.userName}",
                        style: AppTextStyles.mensajeSecundario.copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
      itemBuilder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return [
          PopupMenuItem(value: 'edit', child: Text(l10n?.editar ?? "Editar")),
          PopupMenuItem(value: 'delete', child: Text(l10n?.eliminar ?? "Eliminar", style: const TextStyle(color: Colors.redAccent))),
        ];
      },
    );
  }


  Widget _resolveScreen(dynamic loteria) {
    if (loteria is Map<String, dynamic>) {
      return LoteriaScreen(
        loteriaNombre: loteria["nombre"]?.toString() ?? "Lotería",
        loteriaRoute: loteria["route"]?.toString(),
        loteriaData: loteria,
      );
    }
    return LoteriaScreen(loteriaNombre: loteria?.toString() ?? "Lotería");
  }

  Widget _buildHomeSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2C2C2C),
      period: const Duration(milliseconds: 1400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // Populares carousel skeleton
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: List.generate(
                3,
                (index) => Container(
                  width: 150,
                  height: 180,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Grid skeleton
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
