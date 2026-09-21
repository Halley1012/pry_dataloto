import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:eterlotto/widgets/data_state_widgets.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'package:eterlotto/screens/directorioLocal.dart';
import 'package:eterlotto/screens/loteriasPais.dart';
import 'package:eterlotto/widgets/lottery_avatar_3d.dart';
import 'package:eterlotto/screens/loteria_screen.dart';
import 'package:eterlotto/screens/profile_screen.dart';
import 'package:eterlotto/screens/mis_jugadas_selector_screen.dart';
import 'package:eterlotto/screens/resultados_selector_screen.dart';

import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/models/post.dart';
import 'package:eterlotto/screens/createpostscreen.dart';
import 'package:eterlotto/screens/notifications_screen.dart';
import 'package:eterlotto/screens/post.dart';
import 'package:eterlotto/screens/combination_generator_screen.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:provider/provider.dart';
import 'package:eterlotto/providers/notification_provider.dart';
import 'package:eterlotto/utils/pais_helper.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/widgets/banner_ad_widget.dart';
import 'package:eterlotto/widgets/user_balota_avatar.dart';
import 'package:eterlotto/widgets/premium_header_background.dart';
import 'package:eterlotto/widgets/premium_crown_badge.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final storage = AppSecureStorage.instance;
  List<Map<String, dynamic>> anuncios = [];
  bool isLoading = true;
  bool _showingStaleHomeData = false;
  String? _homeLoadError;
  List<Post> posts = [];
  int _postsVersion = 0;
  String? currentUserId;
  String? pais;
  String? userName;
  String? avatarUrl;
  List<dynamic> _loterias = [];
  List<dynamic> _filteredLoterias = [];
  List<dynamic> _globalLoterias = [];
  final Map<String, String> _paisNombrePorId = <String, String>{};
  int _selectedIndex = 0;
  final Set<int> _loadedBottomTabs = <int>{0};
  DateTime? _lastBackPressTime;
  static const String _bottomNavOrderStorageKey =
      'eterlotto_bottom_nav_order_v4';
  static const double _bottomNavDockHeight = 82.0;
  static const List<int> _defaultBottomNavOrder = [1, 3, 0, 2];

  // Cada valor representa el índice del botón que ocupa ese slot del dock.
  // El orden base conserva Inicio en el centro de la barra.
  List<int> _bottomNavDockOrder = List<int>.from(_defaultBottomNavOrder);
  final ValueNotifier<Offset?> _flagPositionNotifier = ValueNotifier<Offset?>(
    null,
  );
  final ValueNotifier<Offset?> _profilePositionNotifier =
      ValueNotifier<Offset?>(null);
  final GlobalKey _homeTabStackKey = GlobalKey();
  Future<void>? _homeLoadFuture;
  String? _activeHomeControlId;
  int? _activeHomePointer;
  Offset? _activeHomePointerStart;
  DateTime? _lastHomeScreenTapAt;
  Offset? _lastHomeScreenTapPosition;
  bool _isHomeControlHeld = false;
  late final AnimationController _welcomeWaveController;
  late final Animation<double> _welcomeWaveAngle;
  bool _hasPlayedWelcomeWave = false;
  // La comunidad se muestra como una vista previa para no alargar el inicio.
  // El usuario puede desplegar el feed completo cuando lo necesite.
  bool _isCommunityExpanded = false;

  @override
  void initState() {
    super.initState();
    _welcomeWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _welcomeWaveAngle = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -0.26,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -0.26,
          end: 0.22,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.22,
          end: -0.16,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -0.16,
          end: 0.12,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.12,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 16,
      ),
    ]).animate(_welcomeWaveController);
    DataRefreshManager.instance.refreshNotifier.addListener(
      _onDataRefreshNotification,
    );
    _restoreBottomNavLayout();
    _loadUserAndData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().fetchNotifications();
      }
    });
  }

  @override
  void dispose() {
    DataRefreshManager.instance.refreshNotifier.removeListener(
      _onDataRefreshNotification,
    );
    _flagPositionNotifier.dispose();
    _profilePositionNotifier.dispose();
    _welcomeWaveController.dispose();
    super.dispose();
  }

  void _onDataRefreshNotification() {
    final module = DataRefreshManager.instance.refreshNotifier.value;
    if (module == RefreshModules.home ||
        module == RefreshModules.loterias ||
        module == 'all') {
      if (mounted) {
        _loadUserAndData(forceRefresh: false);
      }
    }
  }

  Future<T?> _keepCachedValueOnFailure<T>(Future<T> future) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }

  /// Conserva el catálogo tal como llega del backend. Además del nombre, la
  /// tarjeta de Inicio usa `background_url` para que el arte dependa del país
  /// y no de cada lotería.
  void _indexCountryCatalog(List<Map<String, dynamic>> countries) {
    _paisNombrePorId.clear();
    _paisesPorId.clear();

    for (final country in countries) {
      final id = country['id']?.toString().trim();
      final name = country['nombre']?.toString().trim();
      if (id == null || id.isEmpty) continue;

      _paisesPorId[id] = Map<String, dynamic>.from(country);
      if (name != null && name.isNotEmpty) {
        _paisNombrePorId[id] = name;
      }
    }
  }

  Map<String, dynamic>? _currentCountryData() {
    final selectedId = _paisId?.trim();
    if (selectedId != null && selectedId.isNotEmpty) {
      final country = _paisesPorId[selectedId];
      if (country != null) return country;
    }

    // Compatibilidad con sesiones antiguas que sólo guardaban el nombre.
    final selectedName = pais?.trim().toLowerCase();
    if (selectedName == null || selectedName.isEmpty) return null;
    for (final country in _paisesPorId.values) {
      if (country['nombre']?.toString().trim().toLowerCase() == selectedName) {
        return country;
      }
    }
    return null;
  }

  String? _currentCountryBackgroundUrl() {
    return _resolveCountryRemoteUrl(
      _currentCountryData()?['background_url']?.toString(),
    );
  }

  String? _currentCountryFlagUrl() {
    return _resolveCountryRemoteUrl(
      _currentCountryData()?['flag_url']?.toString(),
    );
  }

  String _currentCountryIsoCode(String countryName) {
    final rawCode = _currentCountryData()?['codigo_iso']?.toString().trim();
    if (rawCode != null && RegExp(r'^[a-zA-Z]{2}$').hasMatch(rawCode)) {
      return rawCode.toUpperCase();
    }
    // El catálogo es la fuente principal. Este helper sólo cubre catálogos
    // históricos y respuestas sin código ISO.
    return PaisHelper.getIsoCode(countryName).toUpperCase();
  }

  String? _resolveCountryRemoteUrl(String? rawValue) {
    final rawUrl = rawValue?.trim();
    if (rawUrl == null || rawUrl.isEmpty) return null;

    final uri = Uri.tryParse(rawUrl);
    if (uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http')) {
      return rawUrl;
    }

    // También permitimos que el backend publique rutas relativas, sin forzar
    // una imagen dentro del APK. Las demás entradas inválidas usan el fondo
    // universal de la tarjeta.
    if (rawUrl.startsWith('/')) return '${ApiService.baseUrl}$rawUrl';
    return null;
  }

  List<Post> _postsFromCache(dynamic cachedPosts) {
    if (cachedPosts is! List) return <Post>[];
    final result = <Post>[];
    for (final rawPost in cachedPosts) {
      if (rawPost is! Map) continue;
      try {
        result.add(Post.fromJson(Map<String, dynamic>.from(rawPost)));
      } catch (_) {
        // Una entrada dañada no debe descartar el resto del feed cacheado.
      }
    }
    return result;
  }

  Future<void> _persistPostsCache() {
    return CacheService.setJson(
      CacheService.homePostsKey,
      posts.map((post) => post.toJson()).toList(),
    );
  }

  Future<void> _loadUserAndData({bool forceRefresh = false}) {
    final inFlight = _homeLoadFuture;
    if (inFlight != null) return inFlight;

    final future = _loadUserAndDataInternal(forceRefresh: forceRefresh);
    _homeLoadFuture = future;
    return future.whenComplete(() {
      if (identical(_homeLoadFuture, future)) _homeLoadFuture = null;
    });
  }

  Future<void> _loadUserAndDataInternal({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await CacheService.invalidateLotteryCatalogCaches();
      }

      // SubscriptionProvider hidrata y valida el plan por cuenta al iniciar y
      // tras login. Home no dispara una segunda consulta redundante.

      // 1. Resolver la sesión antes de leer o aplicar cualquier dato privado.
      final keys = await Future.wait([
        storage.read(key: 'user_id'),
        storage.read(key: 'pais_id'),
        storage.read(key: 'pais_nombre'),
      ]);

      String? userIdStr = keys[0];
      if (userIdStr == null || userIdStr.isEmpty) {
        final uid = await ApiService.getUserId();
        userIdStr = uid?.toString();
      }
      userIdStr = userIdStr?.trim();
      if (userIdStr?.isEmpty == true) userIdStr = null;

      final rawPaisId = keys[1];
      final paisNombreStr = keys[2];

      String? paisIdStr =
          (rawPaisId != null && rawPaisId != 'null' && rawPaisId.isNotEmpty)
          ? rawPaisId
          : null;

      // Si una sesión antigua sólo conservó el nombre del país, resolvemos su
      // ID desde el catálogo. Nunca asumimos IDs concretos por nombre.
      if ((paisIdStr == null || paisIdStr.isEmpty) &&
          paisNombreStr != null &&
          paisNombreStr.trim().isNotEmpty) {
        try {
          final paisesCatalogo = await ApiService.getPaises();
          _indexCountryCatalog(paisesCatalogo);
          final target = paisNombreStr.trim().toLowerCase();
          for (final p in paisesCatalogo) {
            final nombre = p['nombre']?.toString().trim().toLowerCase() ?? '';
            if (nombre == target) {
              final resolvedId = int.tryParse(p['id']?.toString() ?? '');
              if (resolvedId != null) {
                paisIdStr = resolvedId.toString();
                await storage.write(key: 'pais_id', value: paisIdStr);
              }
              break;
            }
          }
        } catch (_) {
          // El país queda sin filtrar hasta que el catálogo vuelva a estar
          // disponible; es preferible a asignar un país incorrecto.
        }
      }

      final paisIdInt = paisIdStr != null ? int.tryParse(paisIdStr) : null;
      final cacheKeySuffix = paisIdStr ?? "global";
      final profileKey = CacheService.perfilUsuarioKey(userIdStr);

      // Si cambió la cuenta, se limpia inmediatamente el perfil anterior.
      // Los catálogos públicos pueden conservarse mientras llega la nueva red.
      if (mounted && currentUserId != userIdStr) {
        setState(() {
          currentUserId = userIdStr;
          userName = null;
          avatarUrl = null;
          pais = paisNombreStr ?? 'Internacional';
          _paisId = paisIdStr;
        });
      }

      // 2. Cache-first/SWR: primero se intenta la entrada fresca; si venció se
      // usa el último valor conocido sin borrar la UI mientras la red actualiza.
      dynamic cachedLoterias;
      dynamic cachedAnuncios;
      dynamic cachedGlobal;
      dynamic cachedPosts;
      dynamic cachedProfile;
      final freshValues = await Future.wait([
        CacheService.getJson('home_loterias_$cacheKeySuffix'),
        CacheService.getJson('home_anuncios_$cacheKeySuffix'),
        CacheService.getJson('home_loterias_globales'),
        CacheService.getJson(CacheService.homePostsKey),
        CacheService.getJson(profileKey),
      ]);
      final staleValues = await Future.wait([
        freshValues[0] != null
            ? Future.value(freshValues[0])
            : CacheService.getStaleJson('home_loterias_$cacheKeySuffix'),
        freshValues[1] != null
            ? Future.value(freshValues[1])
            : CacheService.getStaleJson('home_anuncios_$cacheKeySuffix'),
        freshValues[2] != null
            ? Future.value(freshValues[2])
            : CacheService.getStaleJson('home_loterias_globales'),
        freshValues[3] != null
            ? Future.value(freshValues[3])
            : CacheService.getStaleJson(CacheService.homePostsKey),
        freshValues[4] != null
            ? Future.value(freshValues[4])
            : CacheService.getStaleJson(profileKey),
      ]);
      cachedLoterias = staleValues[0];
      cachedAnuncios = staleValues[1];
      cachedGlobal = staleValues[2];
      cachedPosts = staleValues[3];
      cachedProfile = staleValues[4];
      if (!await _isCurrentHomeSession(userIdStr)) return;
      final postsCache = _postsFromCache(cachedPosts);
      final profileMap = cachedProfile is Map
          ? Map<String, dynamic>.from(cachedProfile)
          : const <String, dynamic>{};

      if (mounted &&
          (cachedLoterias is List ||
              cachedAnuncios is List ||
              cachedGlobal is List ||
              postsCache.isNotEmpty ||
              profileMap.isNotEmpty)) {
        setState(() {
          currentUserId = userIdStr;
          pais = paisNombreStr ?? "Internacional";
          _paisId = paisIdStr;
          userName = profileMap['name']?.toString();
          avatarUrl = profileMap['avatar_url']?.toString();
          if (cachedLoterias is List) {
            _loterias = List<dynamic>.from(cachedLoterias);
          }
          _filteredLoterias = List<dynamic>.from(_loterias);
          if (cachedGlobal is List) {
            _globalLoterias = List<dynamic>.from(cachedGlobal);
          }
          if (cachedAnuncios is List) {
            anuncios = List<Map<String, dynamic>>.from(cachedAnuncios);
          }
          if (postsCache.isNotEmpty) posts = postsCache;
          isLoading = cachedLoterias is! List && cachedGlobal is! List;
          // El dato stale es una fase normal de SWR; no mostramos una alerta
          // hasta confirmar que el refresco remoto falló.
          _showingStaleHomeData = false;
          _homeLoadError = null;
        });
      }

      if (_loterias.isEmpty) setState(() => isLoading = true);

      // 3. Refresco de red en paralelo. El catálogo global se refresca siempre
      // por su propio TTL, aun cuando el país tenga loterías disponibles.
      // Si el usuario crea/edita/elimina mientras una carga está en curso, una
      // respuesta anterior no puede pisar esa mutación local ni revivir datos.
      final postsLoadVersion = _postsVersion;
      final postsFuture = _keepCachedValueOnFailure(ApiService.getPosts());
      final anunciosFuture = _keepCachedValueOnFailure(
        ApiService.getPublicidades(paisId: paisIdInt),
      );
      final loteriasFuture = _keepCachedValueOnFailure(
        paisIdStr != null && paisIdStr.isNotEmpty
            ? ApiService.getLoteriasPorPais(
                paisIdStr,
                forceRefresh: forceRefresh,
              )
            : ApiService.getAllLoterias(forceRefresh: forceRefresh),
      );
      final globalFuture = paisIdStr == null || paisIdStr.isEmpty
          ? Future<List<dynamic>?>.value(null)
          : _keepCachedValueOnFailure(
              ApiService.getAllLoterias(forceRefresh: forceRefresh),
            );
      final profileFuture = _fetchProfile(userIdStr);
      final paisesFuture = _keepCachedValueOnFailure(ApiService.getPaises());

      final resultados = await Future.wait([
        postsFuture,
        anunciosFuture,
        loteriasFuture,
        globalFuture,
        profileFuture,
        paisesFuture,
      ]);

      final networkPosts = resultados[0] as List<Post>?;
      final networkAnuncios = resultados[1] as List<Map<String, dynamic>>?;
      final networkLoterias = resultados[2] as List<dynamic>?;
      final networkGlobal = resultados[3] as List<dynamic>?;
      final networkProfile = resultados[4] as Map<String, dynamic>?;
      final networkPaises = resultados[5] as List<Map<String, dynamic>>?;
      if (networkPaises != null) {
        _indexCountryCatalog(networkPaises);
      }
      final refreshedFromNetwork =
          networkPosts != null ||
          networkAnuncios != null ||
          networkLoterias != null ||
          networkGlobal != null ||
          networkProfile != null;
      final canApplyNetworkPosts = postsLoadVersion == _postsVersion;
      final rawPosts = canApplyNetworkPosts ? (networkPosts ?? posts) : posts;
      final anunciosRes = networkAnuncios ?? anuncios;
      final loteriasRes = networkLoterias ?? _loterias;
      final globalRes =
          networkGlobal ??
          ((paisIdStr == null || paisIdStr.isEmpty)
              ? (networkLoterias ?? _globalLoterias)
              : _globalLoterias);
      final cachedProfileMap = cachedProfile is Map
          ? Map<String, dynamic>.from(cachedProfile)
          : const <String, dynamic>{};
      final finalName =
          networkProfile?['name']?.toString() ??
          cachedProfileMap['name']?.toString();
      final finalAvatar =
          networkProfile?['avatar_url']?.toString() ??
          cachedProfileMap['avatar_url']?.toString();

      if (!await _isCurrentHomeSession(userIdStr)) return;

      final hasLotteryData = loteriasRes.isNotEmpty || globalRes.isNotEmpty;
      final hasStaleLotteryData =
          cachedLoterias is List ||
          cachedGlobal is List ||
          _loterias.isNotEmpty;
      final staleCatalogInUse =
          (networkLoterias == null && cachedLoterias is List) ||
          (loteriasRes.isEmpty &&
              networkGlobal == null &&
              cachedGlobal is List);

      setState(() {
        currentUserId = userIdStr;
        pais = paisNombreStr ?? "Internacional";
        _paisId = paisIdStr;
        userName = finalName;
        avatarUrl = finalAvatar;
        posts = rawPosts;
        anuncios = List<Map<String, dynamic>>.from(anunciosRes);
        _loterias = loteriasRes;
        _filteredLoterias = List<dynamic>.from(_loterias);
        _globalLoterias = globalRes;
        isLoading = false;
        _showingStaleHomeData =
            (!hasLotteryData && hasStaleLotteryData) || staleCatalogInUse;
        _homeLoadError = !hasLotteryData && !hasStaleLotteryData
            ? 'offline_or_unavailable'
            : null;
      });

      // 4. Sólo la sesión que inició la carga puede escribir sus datos privados.
      await Future.wait([
        if (networkLoterias != null)
          CacheService.setJson(
            'home_loterias_$cacheKeySuffix',
            networkLoterias,
          ),
        if (networkGlobal != null)
          CacheService.setJson('home_loterias_globales', networkGlobal),
        if ((paisIdStr == null || paisIdStr.isEmpty) && networkLoterias != null)
          CacheService.setJson('home_loterias_globales', networkLoterias),
        if (networkAnuncios != null)
          CacheService.setJson(
            'home_anuncios_$cacheKeySuffix',
            networkAnuncios,
          ),
        if (networkPosts != null && canApplyNetworkPosts)
          CacheService.setJson(
            CacheService.homePostsKey,
            networkPosts.map((post) => post.toJson()).toList(),
          ),
        if (networkProfile != null && userIdStr != null)
          CacheService.setJson(profileKey, networkProfile),
      ]);
      if (refreshedFromNetwork) {
        DataRefreshManager.instance.markUpdated(RefreshModules.home);
      }
      if (networkLoterias != null || networkGlobal != null) {
        DataRefreshManager.instance.markUpdated(RefreshModules.loterias);
        if (forceRefresh) {
          DataRefreshManager.instance.requestRefresh(RefreshModules.loterias);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _homeLoadError = _loterias.isEmpty && _globalLoterias.isEmpty
            ? 'offline_or_unavailable'
            : null;
      });
    }
  }

  Widget _buildWelcomeGreeting() {
    _playWelcomeWaveIfNeeded();
    final l10n = AppLocalizations.of(context);
    final rawName = userName?.trim();
    final displayName = (rawName != null && rawName.isNotEmpty)
        ? rawName.split(' ').first
        : "Usuario";
    final greeting =
        (l10n?.saludoUsuario(displayName) ?? "¡Hola, $displayName! 👋")
            .replaceFirst('👋', '')
            .trimRight();

    return Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 30.0,
        bottom: 4.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  greeting,
                  style: AppTextStyles.h1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: _welcomeWaveAngle,
                child: const Text('👋', style: TextStyle(fontSize: 28)),
                builder: (context, child) => Transform.translate(
                  offset: const Offset(0, -4),
                  child: Transform.rotate(
                    angle: _welcomeWaveAngle.value,
                    alignment: Alignment.bottomLeft,
                    child: child,
                  ),
                ),
              ),
            ],
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

  Widget _buildCountryHeader(bool isPremium) {
    final langCode = Localizations.localeOf(context).languageCode;
    final nombrePaisDisplay = PaisHelper.getNombreTraducido(
      pais ?? "Internacional",
      langCode,
    );
    final esInternacional =
        (pais == null || pais == "Internacional" || pais == "Todos");
    final subtituloPais = esInternacional
        ? (langCode == 'en'
              ? "Explore the most played lotteries in the world."
              : (langCode == 'pt'
                    ? "Explore as loterias mais jogadas no mundo."
                    : "Explora las loterías más jugadas en el mundo."))
        : (langCode == 'en'
              ? "Explore the most played lotteries in the country."
              : (langCode == 'pt'
                    ? "Explore as loterias mais jogadas no país."
                    : "Explora las loterias más jugadas en el país."));
    final backgroundUrl = _currentCountryBackgroundUrl();
    final borderColor = isPremium
        ? AppColors.yellow.withValues(alpha: 0.54)
        : Colors.white.withValues(alpha: 0.30);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 25.0, 16.0, 12.0),
      child: Semantics(
        button: true,
        label: '$nombrePaisDisplay. $subtituloPais',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoteriasPais()),
              );
              if (mounted) _loadUserAndData(forceRefresh: true);
            },
            borderRadius: BorderRadius.circular(18),
            splashColor: AppColors.yellow.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.05),
            child: Ink(
              height: 148,
              decoration: BoxDecoration(
                color: const Color(0xFF0F1622),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                  if (isPremium)
                    BoxShadow(
                      color: AppColors.yellow.withValues(alpha: 0.10),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: _buildCountryBackground(backgroundUrl),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xE9091424),
                          Color(0xA6091322),
                          Color(0xCC02060D),
                        ],
                        stops: [0.0, 0.56, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    left: 0,
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 10, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombrePaisDisplay,
                                style: AppTextStyles.tituloPrincipal.copyWith(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                subtituloPais,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white.withValues(alpha: 0.86),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 6,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildHeaderFlagWidget(isPremium),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 32,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 7,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryBackground(String? backgroundUrl) {
    if (backgroundUrl == null) return _buildGenericCountryBackground();

    return CachedNetworkImage(
      imageUrl: backgroundUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => _buildGenericCountryBackground(),
      errorWidget: (_, __, ___) => _buildGenericCountryBackground(),
    );
  }

  /// Fondo de reserva ligero para países sin imagen o sin conexión. Evita
  /// cargar assets por lotería y conserva legibilidad en toda la tarjeta.
  Widget _buildGenericCountryBackground() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF102946), Color(0xFF13223A), Color(0xFF090E18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: const Alignment(0.9, -0.9),
            child: Container(
              width: 158,
              height: 158,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x5555C5FF), Color(0x0011202F)],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.22, 0.8),
            child: Container(
              width: 270,
              height: 110,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(220, 95)),
                gradient: LinearGradient(
                  colors: [Color(0x55538BBC), Color(0x003D6D9C)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.82, 0.64),
            child: Icon(
              Icons.public_rounded,
              size: 78,
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderFlagWidget(bool isPremium) {
    return ValueListenableBuilder<Offset?>(
      valueListenable: _flagPositionNotifier,
      builder: (context, pos, child) {
        if (pos != null) {
          // Conserva el espacio de la fila mientras la bandera flota.
          return const SizedBox(width: 64, height: 64);
        }

        return _buildFlagAction(isPremium);
      },
    );
  }

  Widget _buildFlagAction(
    bool isPremium, {
    GestureDoubleTapCallback? onDoubleTap,
  }) {
    const visualSize = 56.0;
    const hitSize = 64.0;
    final langCode = Localizations.localeOf(context).languageCode;
    final semanticsLabel = langCode == 'en'
        ? 'Open combination generator'
        : (langCode == 'pt'
              ? 'Abrir gerador de combinações'
              : 'Abrir generador de combinaciones');

    // El área táctil es mayor que la bandera visible, en la tarjeta y cuando
    // flota. Así el control sigue respondiendo tras arrastrarlo.
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: SizedBox(
        width: hitSize,
        height: hitSize,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _startHomeControlPointer('flag', event),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openCombinationGenerator(isPremium),
            onDoubleTap: onDoubleTap,
            child: Center(child: _buildFlagCircle(size: visualSize)),
          ),
        ),
      ),
    );
  }

  Future<void> _openCombinationGenerator(bool isPremium) async {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final featureDescription = langCode == 'en'
        ? 'Watch a short video ad to use the combination generator for free.'
        : (langCode == 'pt'
              ? 'Assista a um breve vídeo publicitário para usar o gerador de combinações gratuitamente.'
              : 'Mira un breve video publicitario para usar gratis el generador de combinaciones.');

    await AdService.instance.showRewardedFeatureGate(
      context: context,
      isPremium: isPremium,
      featureKey: 'home_combination_generator',
      featureTitle:
          l10n?.generaTusPropiasCombinaciones ??
          'Genera tus propias combinaciones',
      featureActionDescription: featureDescription,
      onRewardGranted: () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CombinationGeneratorScreen()),
        );
      },
    );
  }

  Widget _buildFlagCircle({double size = 55.0}) {
    final countryName = pais?.trim() ?? '';
    final isInternational =
        countryName.isEmpty || countryName.toLowerCase() == 'internacional';
    final isoCode = _currentCountryIsoCode(countryName).toLowerCase();
    final flagUrl = _currentCountryFlagUrl();
    // `flag_url` del backend tiene prioridad. FlagCDN y el emoji sólo cubren
    // catálogos previos que aún no declaran los medios del país.
    final imageUrl =
        flagUrl ??
        (!isInternational && isoCode.isNotEmpty
            ? 'https://flagcdn.com/w320/$isoCode.png'
            : null);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: AppColors.yellow.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      // El recorte se aplica a la imagen, sin borde interno que reduzca
      // el área visible de ninguna bandera.
      child: ClipOval(
        child: imageUrl == null
            ? _buildFlagFallback(
                countryName: countryName,
                isInternational: isInternational,
                size: size,
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                fadeInDuration: Duration.zero,
                placeholder: (_, __) => _buildFlagFallback(
                  countryName: countryName,
                  isInternational: isInternational,
                  size: size,
                ),
                errorWidget: (_, __, ___) => _buildFlagFallback(
                  countryName: countryName,
                  isInternational: isInternational,
                  size: size,
                ),
              ),
      ),
    );
  }

  Widget _buildFlagFallback({
    required String countryName,
    required bool isInternational,
    required double size,
  }) {
    return Container(
      color: const Color(0xFF1E2029),
      alignment: Alignment.center,
      child: isInternational
          ? Icon(
              Icons.public_rounded,
              color: Colors.white70,
              size: size * 0.5,
            )
          : Text(
              PaisHelper.getBanderaEmoji(countryName),
              style: TextStyle(fontSize: size * 0.52),
            ),
    );
  }

  Future<bool> _isCurrentHomeSession(String? expectedUserId) async {
    if (!mounted) return false;
    final current = (await storage.read(key: 'user_id'))?.trim();
    return (current?.isNotEmpty == true ? current : null) == expectedUserId;
  }

  Future<Map<String, dynamic>?> _fetchProfile(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      final response = await ApiService.get('/users/$userId');
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic>
          ? decoded
          : (decoded is Map ? Map<String, dynamic>.from(decoded) : null);
    } catch (_) {
      return null;
    }
  }

  void _playWelcomeWaveIfNeeded() {
    if (_hasPlayedWelcomeWave) return;
    _hasPlayedWelcomeWave = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) {
        _welcomeWaveController.forward(from: 0);
      }
    });
  }

  ValueNotifier<Offset?> _positionForHomeControl(String controlId) {
    return controlId == 'flag'
        ? _flagPositionNotifier
        : _profilePositionNotifier;
  }

  double _sizeForHomeControl(String controlId) {
    // La bandera visible mide 56 px, pero su contenedor táctil mide 64 px.
    return controlId == 'flag' ? 64.0 : 52.0;
  }

  void _startHomeControlPointer(String controlId, PointerDownEvent event) {
    _activeHomeControlId = controlId;
    _activeHomePointer = event.pointer;
    _activeHomePointerStart = event.position;
    if (!_isHomeControlHeld && mounted) {
      setState(() => _isHomeControlHeld = true);
    }
  }

  void _onHomeControlPointerMove(PointerMoveEvent event) {
    final controlId = _activeHomeControlId;
    final start = _activeHomePointerStart;
    if (controlId == null ||
        start == null ||
        event.pointer != _activeHomePointer) {
      return;
    }

    final notifier = _positionForHomeControl(controlId);
    // Igual que en Mis jugadas: un toque no desplaza, pero sólo seis píxeles
    // bastan para desprender el control y hacerlo sentir inmediato.
    if (notifier.value == null && (event.position - start).distance < 6) {
      return;
    }

    final rootBox =
        _homeTabStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (rootBox == null) return;

    final size = _sizeForHomeControl(controlId);
    final local = rootBox.globalToLocal(event.position);
    notifier.value = _clampFloatingPosition(
      local - Offset(size / 2, size / 2),
      rootBox.size,
      size,
    );
  }

  void _finishHomeControlPointer(PointerEvent event) {
    if (event.pointer != _activeHomePointer) return;
    _activeHomeControlId = null;
    _activeHomePointer = null;
    _activeHomePointerStart = null;
    if (_isHomeControlHeld && mounted) {
      setState(() => _isHomeControlHeld = false);
    }
  }

  void _handleHomeScreenPointerUp(PointerUpEvent event) {
    final wasHomeControl = event.pointer == _activeHomePointer;
    _finishHomeControlPointer(event);
    if (wasHomeControl ||
        (_flagPositionNotifier.value == null &&
            _profilePositionNotifier.value == null)) {
      return;
    }

    final now = DateTime.now();
    final previousTime = _lastHomeScreenTapAt;
    final previousPosition = _lastHomeScreenTapPosition;
    final isDoubleTap =
        previousTime != null &&
        previousPosition != null &&
        now.difference(previousTime) <= const Duration(milliseconds: 300) &&
        (event.position - previousPosition).distance <= 32;

    if (isDoubleTap) {
      _flagPositionNotifier.value = null;
      _profilePositionNotifier.value = null;
      _lastHomeScreenTapAt = null;
      _lastHomeScreenTapPosition = null;
      return;
    }

    _lastHomeScreenTapAt = now;
    _lastHomeScreenTapPosition = event.position;
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
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoteriasPais()),
                ),
                child: Text(
                  l10n?.verTodas ?? "Ver todas",
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredLoterias.length > 3
              ? 3
              : _filteredLoterias.length,
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
      final parsed =
          DateTime.tryParse(clean) ??
          (clean.length >= 10
              ? DateTime.tryParse(clean.substring(0, 10))
              : null);
      if (parsed == null) return fecha;

      final langCode = Localizations.localeOf(context).languageCode;
      final dias = langCode == 'en'
          ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
          : (langCode == 'pt'
                ? ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
                : ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]);

      final meses = langCode == 'en'
          ? [
              "Jan",
              "Feb",
              "Mar",
              "Apr",
              "May",
              "Jun",
              "Jul",
              "Aug",
              "Sep",
              "Oct",
              "Nov",
              "Dec",
            ]
          : (langCode == 'pt'
                ? [
                    "Jan",
                    "Fev",
                    "Mar",
                    "Abr",
                    "Mai",
                    "Jun",
                    "Jul",
                    "Ago",
                    "Set",
                    "Out",
                    "Nov",
                    "Dez",
                  ]
                : [
                    "Ene",
                    "Feb",
                    "Mar",
                    "Abr",
                    "May",
                    "Jun",
                    "Jul",
                    "Ago",
                    "Sep",
                    "Oct",
                    "Nov",
                    "Dic",
                  ]);

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
      final parsed =
          DateTime.tryParse(clean) ??
          (clean.length >= 10
              ? DateTime.tryParse(clean.substring(0, 10))
              : null);
      if (parsed == null) return "";

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(parsed.year, parsed.month, parsed.day);
      final diff = target.difference(today).inDays;

      final langCode = Localizations.localeOf(context).languageCode;

      if (diff == 0) {
        return langCode == 'en'
            ? "Draws today"
            : (langCode == 'pt' ? "Sorteia hoje" : "Sortea hoy");
      } else if (diff == 1) {
        return langCode == 'en'
            ? "Tomorrow"
            : (langCode == 'pt' ? "Amanhã" : "Mañana");
      } else if (diff > 1) {
        return langCode == 'en'
            ? "In $diff days"
            : (langCode == 'pt' ? "Faltam $diff dias" : "Faltan $diff días");
      } else if (diff == -1) {
        return langCode == 'en'
            ? "Drew yesterday"
            : (langCode == 'pt' ? "Sorteado ontem" : "Sorteó ayer");
      } else {
        final dias = diff.abs();
        return langCode == 'en'
            ? "Drew $dias days ago"
            : (langCode == 'pt'
                  ? "Sorteado há $dias dias"
                  : "Sorteó hace $dias días");
      }
    } catch (_) {
      return "";
    }
  }

  String _getPaisNombre(dynamic loteria) {
    String rawPais = pais ?? "Internacional";
    if (loteria["pais_nombre"] != null &&
        loteria["pais_nombre"].toString().isNotEmpty) {
      rawPais = loteria["pais_nombre"].toString();
    } else {
      final pId = loteria["pais_id"]?.toString();
      rawPais = pId != null
          ? (_paisNombrePorId[pId] ?? "Internacional")
          : (pais ?? "Internacional");
    }
    final langCode = Localizations.localeOf(context).languageCode;
    return PaisHelper.getNombreTraducido(rawPais, langCode);
  }

  Widget _buildLoteriaCard(dynamic loteria, {bool showCountry = true}) {
    final rawFecha =
        loteria["proximo_sorteo"] ??
        loteria["fecha"] ??
        loteria["ultimo_sorteo"];
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
                    AppLocalizations.of(context)?.proximoSorteo ??
                        "Próximo sorteo",
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9.5,
                    ),
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
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white24,
                size: 14,
              ),
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
            AppLocalizations.of(context)?.todasLasLoterias ??
                "Todas las loterías",
            style: AppTextStyles.h2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredLoterias.length - 3,
          itemBuilder: (context, index) {
            final loteria = _filteredLoterias[index + 3];
            return _buildCompactLoteriaCard(loteria);
          },
        ),
      ],
    );
  }

  Widget _buildCompactLoteriaCard(dynamic loteria) {
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                nombreFormateado,
                style: AppTextStyles.mensajeImportante.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.0,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white38,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reorderBottomNav(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    setState(() {
      final moved = _bottomNavDockOrder.removeAt(oldIndex);
      _bottomNavDockOrder.insert(newIndex, moved);
    });
    _persistBottomNavLayout();
  }

  Widget _buildBottomNavBar() {
    final l10n = AppLocalizations.of(context);
    final labels = <String>[
      l10n?.inicio ?? 'Inicio',
      l10n?.explorar ?? 'Explorar',
      l10n?.misJugadas ?? 'Mis Jugadas',
      l10n?.resultados ?? 'Resultados',
    ];
    const icons = <IconData>[
      Icons.home_outlined,
      Icons.explore_outlined,
      Icons.bookmark_outline,
      Icons.analytics_outlined,
    ];
    const activeIcons = <IconData>[
      Icons.home,
      Icons.explore,
      Icons.bookmark,
      Icons.analytics,
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: _bottomNavDockHeight,
        decoration: const BoxDecoration(color: Colors.transparent),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / 4;
            return ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              onReorder: _reorderBottomNav,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final scale = 1.0 + (0.04 * animation.value);
                    return Transform.scale(
                      scale: scale,
                      child: Material(
                        color: Colors.transparent,
                        elevation: 0,
                        child: child,
                      ),
                    );
                  },
                );
              },
              itemBuilder: (context, slot) {
                final index = _bottomNavDockOrder[slot];
                return SizedBox(
                  key: ValueKey<int>(index),
                  width: itemWidth,
                  child: ReorderableDelayedDragStartListener(
                    index: slot,
                    child: _buildBottomNavItem(
                      index: index,
                      label: labels[index],
                      icon: icons[index],
                      activeIcon: activeIcons[index],
                    ),
                  ),
                );
              },
            );
          }
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectBottomTab(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppColors.yellow.withValues(alpha: 0.08)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected ? AppColors.yellow : Colors.white24,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.yellow.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.yellow : Colors.white60,
              size: 25,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              color: isSelected ? AppColors.yellow : Colors.white54,
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _selectBottomTab(int index) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
      _loadedBottomTabs.add(index);
    });
  }

  Future<void> _restoreBottomNavLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawOrder = prefs.getString(_bottomNavOrderStorageKey);
      if (rawOrder != null && rawOrder.isNotEmpty) {
        final decoded = jsonDecode(rawOrder);
        if (decoded is List) {
          final restoredOrder = decoded
              .whereType<num>()
              .map((value) => value.toInt())
              .toList();
          if (restoredOrder.length == _defaultBottomNavOrder.length &&
              restoredOrder.toSet().length == _defaultBottomNavOrder.length &&
              restoredOrder.every(
                (item) => _defaultBottomNavOrder.contains(item),
              )) {
            if (!mounted) return;
            setState(() => _bottomNavDockOrder = restoredOrder);
          }
        }
      }
    } catch (_) {
      // Preferencias visuales: si fallan, se usa el dock base.
    }
  }

  Future<void> _persistBottomNavLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _bottomNavOrderStorageKey,
        jsonEncode(_bottomNavDockOrder),
      );
    } catch (_) {
      // El menú continúa funcionando aunque no se pueda persistir el ajuste.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute && route.settings.arguments == true) {
      _loadUserAndData(forceRefresh: true);
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
        _postsVersion++;
      });
      await _persistPostsCache();
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
        _postsVersion++;
      });
      await _persistPostsCache();
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
            _postsVersion++;
          });
          await _persistPostsCache();
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n?.postEliminado ?? "Post eliminado correctamente",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n?.errorEliminarPost(e.toString()) ??
                    "Error al eliminar el post: $e",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildTopHeaderSection(BuildContext context, bool isPremium) {
    if (!isPremium) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [_buildHeaderRow(context, false), _buildWelcomeGreeting()],
      );
    }

    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: PremiumHeaderBackground()),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [_buildHeaderRow(context, true), _buildWelcomeGreeting()],
        ),
      ],
    );
  }

  Widget _buildHeaderRow(BuildContext context, bool isPremium) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 4.0),
      child: SizedBox(
        height: 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo Eterlotto adaptado a las especificaciones (110-130px ancho, 25-35px alto)
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 8,
                  ), // Lo empuja ligeramente hacia abajo para alinearse con los iconos
                  child: Image.asset(
                    "assets/images/eterlotto_gold_trans.png",
                    width: 140,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Acciones: Campanita de Notificaciones + Avatar de Perfil con Corona Premium
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
                            constraints: const BoxConstraints(
                              minWidth: 42,
                              minHeight: 42,
                            ),
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: AppColors.yellow,
                              size: 30,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
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
                _buildHeaderProfileAvatar(isPremium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openProfile() {
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
  }

  Widget _buildProfileAvatar(bool isPremium) {
    return PremiumCrownBadge(
      isPremium: isPremium,
      crownSize: 20.0,
      crownAngle: 0.62,
      // Mantiene la corona más cerca del contorno, también al arrastrarlo.
      crownOffset: const Offset(-7, -11),
      child: UserBalotaAvatar(
        avatarUrl: avatarUrl,
        userName: userName,
        userId: int.tryParse(currentUserId ?? '0'),
        radius: 26,
        showGlow: true,
        showBorder: true,
        borderColor: isPremium ? const Color(0xFFFFD700) : AppColors.yellow,
      ),
    );
  }

  Widget _buildHeaderProfileAvatar(bool isPremium) {
    return ValueListenableBuilder<Offset?>(
      valueListenable: _profilePositionNotifier,
      builder: (context, position, child) {
        // Conserva el espacio de la cabecera mientras el avatar flota.
        if (position != null) return const SizedBox(width: 52, height: 52);

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _startHomeControlPointer('profile', event),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openProfile,
            child: _buildProfileAvatar(isPremium),
          ),
        );
      },
    );
  }

  Offset _clampFloatingPosition(Offset position, Size bounds, double size) {
    final maxX = (bounds.width - size - 10).clamp(10.0, double.infinity);
    final maxY = (bounds.height - size - 10).clamp(10.0, double.infinity);
    return Offset(position.dx.clamp(10.0, maxX), position.dy.clamp(10.0, maxY));
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
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n?.presionaOtraVezSalir ?? "Presiona otra vez para salir",
              ),
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
          children: [const BannerAdWidget(), _buildBottomNavBar()],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeTab(),
            _loadedBottomTabs.contains(1)
                ? const LoteriasPais()
                : const SizedBox.shrink(),
            _loadedBottomTabs.contains(2)
                ? const MisJugadasSelectorScreen()
                : const SizedBox.shrink(),
            _loadedBottomTabs.contains(3)
                ? const ResultadosSelectorScreen()
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLoteriasState() {
    final langCode = Localizations.localeOf(context).languageCode;
    final countryName = PaisHelper.getNombreTraducido(
      pais ?? "Internacional",
      langCode,
    );

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
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoteriasPais()),
                ),
                child: Text(
                  l10n?.verTodas ?? "Ver todas",
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
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
    } catch (_) {}
  }

  Widget _buildHomeTab() {
    final subscription = context.watch<SubscriptionProvider>();
    final isPremium = subscription.isPremium;
    // El proveedor arranca neutral para no heredar el VIP de otra cuenta. No
    // debemos representar ese estado transitorio como una cuenta básica: la
    // cabecera aparece cuando ya conocemos el estado de la sesión actual.
    final subscriptionStatusResolved =
        subscription.isSubscriptionStatusResolved;
    final showInitialSkeleton = isLoading && _loterias.isEmpty;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerMove: _onHomeControlPointerMove,
            onPointerUp: _handleHomeScreenPointerUp,
            onPointerCancel: _finishHomeControlPointer,
            child: Stack(
              key: _homeTabStackKey,
              children: [
                RefreshIndicator(
                  color: AppColors.yellow,
                  backgroundColor: const Color(0xFF1E1E1E),
                  displacement: 40.0,
                  notificationPredicate: (_) => !_isHomeControlHeld,
                  onRefresh: () => _isHomeControlHeld
                      ? Future<void>.value()
                      : _refreshHome(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (showInitialSkeleton)
                        SliverToBoxAdapter(child: _buildHomeSkeleton())
                      else ...[
                        SliverToBoxAdapter(
                          child: AnimatedOpacity(
                            opacity: subscriptionStatusResolved ? 1 : 0,
                            duration: const Duration(milliseconds: 120),
                            child: IgnorePointer(
                              ignoring: !subscriptionStatusResolved,
                              child: _buildTopHeaderSection(context, isPremium),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: AnimatedOpacity(
                            opacity: subscriptionStatusResolved ? 1 : 0,
                            duration: const Duration(milliseconds: 120),
                            child: IgnorePointer(
                              ignoring: !subscriptionStatusResolved,
                              child: _buildCountryHeader(isPremium),
                            ),
                          ),
                        ),
                        if (_showingStaleHomeData)
                          SliverToBoxAdapter(child: _buildStaleHomeNotice()),
                        if (_filteredLoterias.isEmpty) ...[
                          SliverToBoxAdapter(
                            child:
                                _homeLoadError != null &&
                                    _globalLoterias.isEmpty
                                ? _buildHomeUnavailableState()
                                : _buildEmptyLoteriasState(),
                          ),
                          if (_globalLoterias.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _buildGlobalFallbackSection(),
                              ),
                            ),
                        ] else ...[
                          SliverToBoxAdapter(child: _buildPopularesSection()),
                          const SliverToBoxAdapter(child: SizedBox(height: 15)),
                          SliverToBoxAdapter(
                            child: _buildTodasLoteriasSection(),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 30)),
                        SliverToBoxAdapter(child: _buildBuscaloAquiSection()),
                        const SliverToBoxAdapter(child: SizedBox(height: 30)),
                        SliverToBoxAdapter(child: _buildComunidadSection()),
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ],
                  ),
                ),
                if (subscriptionStatusResolved) ...[
                  _buildDraggableFlagFab(context, constraints, isPremium),
                  _buildDraggableProfileFab(context, constraints, isPremium),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDraggableFlagFab(
    BuildContext context,
    BoxConstraints constraints,
    bool isPremium,
  ) {
    const double flagHitSize = 64.0;

    final double maxW = constraints.maxWidth > 0
        ? constraints.maxWidth
        : MediaQuery.of(context).size.width;
    final double maxH = constraints.maxHeight > 0
        ? constraints.maxHeight
        : MediaQuery.of(context).size.height;

    return ValueListenableBuilder<Offset?>(
      valueListenable: _flagPositionNotifier,
      builder: (context, pos, child) {
        // Por defecto se muestra dentro de la tarjeta del país (como en la foto).
        // Solo cuando el usuario VIP lo arrastra (pos != null) flota por la pantalla.
        if (pos == null) {
          return const SizedBox.shrink();
        }

        final currentX = pos.dx.clamp(
          10.0,
          (maxW - flagHitSize - 10.0).clamp(10.0, double.infinity),
        );
        final currentY = pos.dy.clamp(
          10.0,
          (maxH - flagHitSize - 10.0).clamp(10.0, double.infinity),
        );

        return Positioned(
          left: currentX,
          top: currentY,
          child: _buildFlagAction(
            isPremium,
            onDoubleTap: () => _flagPositionNotifier.value = null,
          ),
        );
      },
    );
  }

  Widget _buildHomeUnavailableState() {
    return AppDataStateCard(
      isConnectionError: true,
      onRetry: () => _loadUserAndData(forceRefresh: true),
      retrying: isLoading,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildStaleHomeNotice() {
    return const AppStaleDataBanner(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 4),
    );
  }

  Widget _buildDraggableProfileFab(
    BuildContext context,
    BoxConstraints constraints,
    bool isPremium,
  ) {
    const double avatarSize = 52.0;
    final maxW = constraints.maxWidth > 0
        ? constraints.maxWidth
        : MediaQuery.of(context).size.width;
    final maxH = constraints.maxHeight > 0
        ? constraints.maxHeight
        : MediaQuery.of(context).size.height;

    return ValueListenableBuilder<Offset?>(
      valueListenable: _profilePositionNotifier,
      builder: (context, position, child) {
        // Por defecto, el avatar permanece en la cabecera. Solo flota al arrastrarlo.
        if (position == null) return const SizedBox.shrink();

        final currentX = position.dx.clamp(
          10.0,
          (maxW - avatarSize - 10.0).clamp(10.0, double.infinity),
        );
        final currentY = position.dy.clamp(
          10.0,
          (maxH - avatarSize - 10.0).clamp(10.0, double.infinity),
        );

        return Positioned(
          left: currentX,
          top: currentY,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) =>
                _startHomeControlPointer('profile', event),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openProfile,
              onDoubleTap: () => _profilePositionNotifier.value = null,
              child: _buildProfileAvatar(isPremium),
            ),
          ),
        );
      },
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
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
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
                      l10n?.buscarDirectorioHint ??
                          "Encuentra negocios, servicios y comercios...",
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white38,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComunidadSection() {
    final totalMessages = posts.fold<int>(
      0,
      (total, post) => total + 1 + post.commentsCount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF1D1D20), Color(0xFF131315)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: AppColors.yellow.withValues(alpha: 0.58),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.yellow.withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCommunityHeader(totalMessages),
              const SizedBox(height: 10),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _buildCommunityBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityHeader(int totalMessages) {
    final commentsLabel =
        AppLocalizations.of(context)?.comentarios ?? 'Comentarios';

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.yellow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.forum_outlined,
            color: AppColors.yellow,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(
              () => _isCommunityExpanded = !_isCommunityExpanded,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      commentsLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildCommunityCountBadge(totalMessages),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: _isCommunityExpanded
              ? 'Contraer comentarios'
              : 'Ver todos los comentarios',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(
            () => _isCommunityExpanded = !_isCommunityExpanded,
          ),
          icon: AnimatedRotation(
            turns: _isCommunityExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          color: Colors.white70,
        ),
        IconButton(
          tooltip: 'Crear comentario',
          visualDensity: VisualDensity.compact,
          onPressed: _createCommunityPost,
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: AppColors.yellow,
        ),
      ],
    );
  }

  Widget _buildCommunityCountBadge(int totalMessages) {
    final countLabel = totalMessages > 99 ? '99+' : '$totalMessages';
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B58),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        countLabel,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildCommunityBody() {
    if (_isCommunityExpanded) return _buildExpandedCommunityFeed();
    if (isLoading && posts.isEmpty) return _buildCommunityLoadingPreview();
    if (posts.isEmpty) return _buildCommunityEmptyPreview();
    return _buildCommunityPreview(posts.first);
  }

  Widget _buildCommunityLoadingPreview() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF222225),
      highlightColor: const Color(0xFF343438),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildCommunityEmptyPreview() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _createCommunityPost,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: AppColors.yellow),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.sinPosts ?? 'No hay posts',
                style: AppTextStyles.mensajeSecundario.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityPreview(Post post) {
    final displayName = post.userName.trim().isEmpty
        ? 'Comunidad'
        : post.userName.trim();
    final repliesLabel = post.commentsCount == 1
        ? (AppLocalizations.of(context)?.respuesta ?? 'respuesta')
        : (AppLocalizations.of(context)?.respuestas ?? 'respuestas');

    return Semantics(
      button: true,
      label: 'Abrir comentarios de $displayName',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _abrirPostScreen(post),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserBalotaAvatar(
                  userName: displayName,
                  userId: post.userId,
                  radius: 18,
                  animateGradient: false,
                  showGlow: false,
                  showBorder: false,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '@$displayName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            post.relativeTime,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (post.title.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          post.title.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        post.content.trim().isEmpty
                            ? post.title.trim()
                            : post.content.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.mensajeSecundario.copyWith(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.yellow,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${post.commentsCount} $repliesLabel',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white54,
                    size: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedCommunityFeed() {
    if (isLoading && posts.isEmpty) return _buildCommunityLoadingPreview();
    if (posts.isEmpty) return _buildCommunityEmptyPreview();

    return SizedBox(
      height: 360,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final isOwner =
              currentUserId != null && post.userId == int.tryParse(currentUserId!);
          return _buildPostItem(post, isOwner);
        },
      ),
    );
  }

  Future<void> _createCommunityPost() async {
    final newPost = await Navigator.of(context).push<Post>(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (newPost == null || !mounted) return;

    setState(() {
      posts.insert(0, newPost);
      _postsVersion++;
    });
    await _persistPostsCache();
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
                    Expanded(
                      child: Text(
                        "@${post.userName}  ·  ${post.relativeTime}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.mensajeSecundario.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (isOwner) _buildPostOptions(post),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  post.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  post.content,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _abrirPostScreen(post),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.reply_outlined,
                              color: AppColors.yellow,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)?.responder ??
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
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
          PopupMenuItem(
            value: 'delete',
            child: Text(
              l10n?.eliminar ?? "Eliminar",
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
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
    Widget box({double? width, required double height, double radius = 10}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    Widget sectionTitle({double width = 150}) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
        child: box(width: width, height: 19, radius: 6),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El logo es local: se muestra real incluso mientras el perfil carga.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                Image.asset(
                  'assets/images/eterlotto_gold_trans.png',
                  width: 140,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.yellow,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFF252525),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
        Shimmer.fromColors(
          baseColor: const Color(0xFF1A1A1A),
          highlightColor: const Color(0xFF2C2C2C),
          period: const Duration(milliseconds: 1400),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 30, 16, 4),
                  child: box(width: 210, height: 23, radius: 7),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: box(width: 160, height: 14, radius: 5),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 30, 16, 12),
                  child: box(height: 92, radius: 16),
                ),
                sectionTitle(),
                ...List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: box(height: 86, radius: 16),
                  ),
                ),
                sectionTitle(width: 125),
                ...List.generate(
                  2,
                  (_) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    child: box(height: 70, radius: 14),
                  ),
                ),
                sectionTitle(width: 110),
                ...List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: box(height: 58, radius: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
