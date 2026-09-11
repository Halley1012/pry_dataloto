import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/widgets/custom_dialogs.dart';
import 'package:eterlotto/screens/registro.dart';
import 'package:eterlotto/screens/login.dart';
import 'package:eterlotto/screens/misanuncios.dart';
import 'package:eterlotto/screens/welcome.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:eterlotto/providers/locale_provider.dart';
import 'package:eterlotto/providers/subscription_provider.dart';
import 'package:eterlotto/screens/subscription_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/widgets/user_balota_avatar.dart';
import 'package:eterlotto/widgets/premium_crown_badge.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/secure_storage_helper.dart';
import 'package:eterlotto/services/cache_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final Function(int)? onTabChange;
  final VoidCallback? onProfileUpdated;
  const ProfileScreen({
    super.key,
    this.onLogout,
    this.onTabChange,
    this.onProfileUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final storage = AppSecureStorage.instance;
  String? name;
  String? email;
  String? userId;
  String? avatarUrl;
  String? authProvider;
  String _appVersion = "...";
  bool isLoading = true;
  bool _showingStaleProfile = false;
  bool _hasProfileSnapshot = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
        });
      }
    } catch (_) {}
  }

  Future<bool> _isCurrentProfileSession(String expectedUserId) async {
    final current = (await storage.read(key: 'user_id'))?.trim();
    return mounted && current == expectedUserId;
  }

  static const List<String> _safeProfileStorageKeys = [
    'name',
    'email',
    'pais_id',
    'pais_nombre',
    'departamento_id',
    'departamento_nombre',
    'avatar_url',
    'auth_provider',
    'telefono',
    'idioma',
  ];

  Map<String, dynamic> _profileMap(dynamic raw) {
    return CacheService.sanitizeProfileCacheData(raw);
  }

  Future<Map<String, dynamic>> _readSafeProfileStorageSnapshot() async {
    final safe = <String, dynamic>{};

    // Nunca usar readAll() aquí: SecureStorage también contiene auth_token y
    // refresh_token, y el perfil termina cacheándose en SharedPreferences.
    for (final key in _safeProfileStorageKeys) {
      final value = await storage.read(key: key);
      if (value != null && value.isNotEmpty && value != 'null') {
        safe[key] = value;
      }
    }

    return safe;
  }

  bool _containsSensitiveProfileFields(dynamic raw) {
    if (raw is! Map) return false;
    final map = Map<String, dynamic>.from(raw);
    if (map.containsKey('auth_token') || map.containsKey('refresh_token')) {
      return true;
    }

    final nested = map['user'];
    if (nested is Map) {
      return nested.containsKey('auth_token') ||
          nested.containsKey('refresh_token');
    }
    return false;
  }

  Map<String, dynamic> _mergeProfile(
    Map<String, dynamic> storageData,
    Map<String, dynamic> cachedData,
  ) {
    final merged = <String, dynamic>{};

    for (final source in [storageData, cachedData]) {
      for (final entry in source.entries) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          merged[entry.key] = entry.value;
        }
      }
    }

    return CacheService.sanitizeProfileCacheData(merged);
  }

  void _applyProfile(Map<String, dynamic> profile, String activeUserId) {
    if (!mounted) return;
    setState(() {
      name = profile['name']?.toString() ?? 'Usuario';
      email = profile['email']?.toString() ?? 'correo@ejemplo.com';
      userId = activeUserId;
      avatarUrl = profile['avatar_url']?.toString();
      authProvider = profile['auth_provider']?.toString();
      isLoading = false;
    });
  }

  Future<void> _syncProfileStorage(
    String activeUserId,
    Map<String, dynamic> profile,
  ) async {
    if (!await _isCurrentProfileSession(activeUserId)) return;
    const keys = [
      'name',
      'email',
      'pais_id',
      'pais_nombre',
      'departamento_id',
      'departamento_nombre',
      'avatar_url',
      'auth_provider',
      'telefono',
      'idioma',
    ];
    for (final key in keys) {
      if (!profile.containsKey(key)) continue;
      final value = profile[key]?.toString();
      if (value == null || value.isEmpty || value == 'null') {
        await storage.delete(key: key);
      } else {
        await storage.write(key: key, value: value);
      }
    }
  }

  Future<void> _refreshProfileInBackground(String activeUserId) async {
    try {
      final response = await ApiService.get('/users/$activeUserId');
      if (response.statusCode != 200 ||
          !await _isCurrentProfileSession(activeUserId)) {
        return;
      }
      final profile = _profileMap(jsonDecode(response.body));
      if (profile.isEmpty) return;

      // El endpoint puede devolver un perfil parcial. Conservamos los campos
      // ya conocidos (en especial avatar) que el backend no haya incluido.
      final storageData = await _readSafeProfileStorageSnapshot();
      final rawCachedProfile = await CacheService.getStaleJson(
        CacheService.perfilUsuarioKey(activeUserId),
      );
      final cachedProfile = _profileMap(rawCachedProfile);
      if (!await _isCurrentProfileSession(activeUserId)) return;
      final completeProfile = _mergeProfile(
        _mergeProfile(storageData, cachedProfile),
        profile,
      );

      await CacheService.setJson(
        CacheService.perfilUsuarioKey(activeUserId),
        completeProfile,
      );
      await _syncProfileStorage(activeUserId, completeProfile);
      if (!await _isCurrentProfileSession(activeUserId)) return;
      _showingStaleProfile = false;
      _hasProfileSnapshot = true;
      _applyProfile(completeProfile, activeUserId);
    } catch (_) {
      if (await _isCurrentProfileSession(activeUserId) && _hasProfileSnapshot) {
        setState(() => _showingStaleProfile = true);
      }
    }
  }

  Future<void> _loadUserData() async {
    final activeUserId = (await storage.read(key: 'user_id'))?.trim();
    if (activeUserId == null || activeUserId.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    final profileKey = CacheService.perfilUsuarioKey(activeUserId);
    // La caché del perfil ya está sanitizada y su lectura no requiere el
    // Keystore/Keychain. Es la ruta crítica para pintar Perfil de inmediato.
    final rawFreshProfile = await CacheService.getJson(profileKey);
    final freshProfile = _profileMap(rawFreshProfile);
    final rawStaleProfile = freshProfile.isEmpty
        ? await CacheService.getStaleJson(profileKey)
        : null;
    final staleProfile = freshProfile.isEmpty
        ? _profileMap(rawStaleProfile)
        : freshProfile;

    // Migración de seguridad para instalaciones existentes: si una versión
    // anterior llegó a copiar tokens a la caché de perfil, se sobrescribe de
    // inmediato con la versión sanitizada sin bloquear el primer render.
    if (_containsSensitiveProfileFields(rawFreshProfile) ||
        _containsSensitiveProfileFields(rawStaleProfile)) {
      unawaited(CacheService.setJson(profileKey, staleProfile));
    }

    // 1. Cache first: no esperamos lecturas de SecureStorage ni el backend
    // antes de presentar nombre, correo y avatar ya conocidos.
    if (staleProfile.isNotEmpty) {
      if (!await _isCurrentProfileSession(activeUserId)) return;
      _hasProfileSnapshot = true;
      _showingStaleProfile = false;
      _applyProfile(staleProfile, activeUserId);
    } else {
      // En un primer uso sin caché, la copia segura es el único fallback que
      // puede alimentar la UI. Sólo este caso mantiene el loader brevemente.
      final storageData = await _readSafeProfileStorageSnapshot();
      if (!await _isCurrentProfileSession(activeUserId)) return;

      if (storageData.isNotEmpty) {
        _hasProfileSnapshot = true;
        _showingStaleProfile = false;
        _applyProfile(storageData, activeUserId);
      } else if (mounted) {
        setState(() => isLoading = false);
      }
    }

    // 2. Todo lo que toca red o lecturas seguras adicionales queda fuera de
    // la ruta crítica de apertura del Perfil.
    if (mounted) {
      unawaited(
        context.read<SubscriptionProvider>().refreshSubscriptionStatus(),
      );
    }
    unawaited(_refreshProfileInBackground(activeUserId));
  }

  void _showLogoutDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.cerrarSesion,
          style: AppTextStyles.h2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.confirmarCerrarSesion,
          style: AppTextStyles.mensajeSecundario,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancelar,
              style: const TextStyle(color: AppColors.yellow),
            ),
          ),
          TextButton(
            onPressed: () async {
              context.read<SubscriptionProvider>().reset();
              await storage.deleteAll();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: Text(
              l10n.cerrarSesion,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _editProfile() async {
    if (userId == null) return;
    final user = {
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'pais_id': int.tryParse(await storage.read(key: 'pais_id') ?? '0'),
      'departamento_id': int.tryParse(
        await storage.read(key: 'departamento_id') ?? '0',
      ),
    };

    if (!mounted) return;
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RegistroScreen(user: user, userId: int.tryParse(userId!)),
      ),
    );

    if (updated != null) {
      _loadUserData();
      widget.onProfileUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.yellow),
      );

    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                children: [
                  Text(
                    l10n.perfil,
                    style: AppTextStyles.tituloPrincipal.copyWith(fontSize: 24),
                  ),
                  if (_showingStaleProfile) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.yellow.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.sync_problem_outlined,
                            color: AppColors.yellow,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No pudimos actualizar tu perfil · mostrando la última copia',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),

                  // Header Perfil
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _editProfile,
                        child: Consumer<SubscriptionProvider>(
                          builder: (context, subProvider, _) {
                            final isPremium = subProvider.isPremium;
                            return PremiumCrownBadge(
                              isPremium: isPremium,
                              crownSize: 30,
                              crownAngle: 0.62,
                              // Más cerca del borde y ligeramente más alta para
                              // conservar el avatar despejado al inclinarse.
                              crownOffset: const Offset(-10, -17),
                              child: UserBalotaAvatar(
                                avatarUrl: avatarUrl,
                                userName: name,
                                userId: int.tryParse(userId ?? "0"),
                                radius: 45,
                                showGlow: true,
                                showBorder: true,
                                borderColor: isPremium
                                    ? const Color(0xFFFFD700)
                                    : AppColors.yellow,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name ?? l10n.nombre,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _editProfile,
                                  icon: const Icon(
                                    Icons.edit,
                                    color: AppColors.yellow,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              email ?? l10n.email,
                              style: GoogleFonts.montserrat(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SubscriptionScreen(),
                                ),
                              ),
                              child: Consumer<SubscriptionProvider>(
                                builder: (context, subProvider, _) {
                                  final isSubscribed = subProvider.isSubscribed;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSubscribed
                                          ? const Color(
                                              0xFFFFD700,
                                            ).withValues(alpha: 0.15)
                                          : AppColors.amber.withValues(
                                              alpha: 0.15,
                                            ),
                                      border: Border.all(
                                        color: isSubscribed
                                            ? const Color(0xFFFFD700)
                                            : AppColors.yellow,
                                        width: 1.2,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSubscribed)
                                          const FaIcon(
                                            FontAwesomeIcons.crown,
                                            color: Color(0xFFFFD700),
                                            size: 11,
                                          )
                                        else
                                          const Icon(
                                            Icons.star,
                                            color: AppColors.yellow,
                                            size: 14,
                                          ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isSubscribed
                                              ? "Usuario Premium"
                                              : (l10n.planBasicoHazteVip),
                                          style: GoogleFonts.montserrat(
                                            color: isSubscribed
                                                ? const Color(0xFFFFD700)
                                                : AppColors.yellow,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Opciones
                  Consumer<SubscriptionProvider>(
                    builder: (context, subProvider, _) {
                      return _buildOptionItem(
                        Icons.workspace_premium,
                        l10n.eterlottoVipSinAnuncios,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        ),
                        color: AppColors.amber.withValues(alpha: 0.12),
                        iconColor: AppColors.amber,
                        trailingText: subProvider.isSubscribed
                            ? l10n.activo
                            : l10n.obtener,
                      );
                    },
                  ),
                  _buildOptionItem(
                    Icons.ads_click,
                    l10n.misAnuncios,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MisAnunciosScreen(),
                      ),
                    ),
                  ),
                  _buildOptionItem(
                    Icons.settings_outlined,
                    l10n.configuracion,
                    _showConfigMenu,
                  ),
                  _buildOptionItem(
                    Icons.help_outline,
                    l10n.ayudaSoporte,
                    _showHelpMenu,
                  ),

                  const SizedBox(height: 16),
                  _buildOptionItem(
                    Icons.logout,
                    l10n.cerrarSesion,
                    _showLogoutDialog,
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    iconColor: Colors.redAccent,
                  ),

                  const SizedBox(height: 30),
                  _buildBrandAndSocialSection(l10n),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showConfigMenu() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.amber),
            title: const Text(
              "Idioma / Language / Idioma",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _showLanguageDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: Text(
              l10n.eliminarCuenta,
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _eliminarCuenta(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.seleccionarIdioma,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text("🇪🇸", style: TextStyle(fontSize: 22)),
              title: const Text(
                "Español",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => _confirmLanguageChange(context, const Locale('es')),
            ),
            ListTile(
              leading: const Text("🇺🇸", style: TextStyle(fontSize: 22)),
              title: const Text(
                "English",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => _confirmLanguageChange(context, const Locale('en')),
            ),
            ListTile(
              leading: const Text("🇧🇷", style: TextStyle(fontSize: 22)),
              title: const Text(
                "Português",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => _confirmLanguageChange(context, const Locale('pt')),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.settings_suggest, color: Colors.amber),
              title: Text(
                l10n.idiomaSistema,
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () => _confirmLanguageChange(context, null),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLanguageChange(
    BuildContext context,
    Locale? newLocale,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final locProvider = Provider.of<LocaleProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.seleccionarIdioma,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.confirmarCambioIdioma,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n.cancelar,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.si,
              style: const TextStyle(
                color: AppColors.yellow,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (newLocale != null) {
        await locProvider.setLocale(newLocale);
      } else {
        await locProvider.clearLocale();
      }
      if (mounted) {
        Navigator.pop(context); // Cerrar el diálogo de selección de idioma
      }
    }
  }

  Future<void> _eliminarCuenta(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Text(
              l10n.eliminarCuenta,
              style: AppTextStyles.h2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          l10n.confirmarEliminarCuenta,
          style: AppTextStyles.mensajeSecundario.copyWith(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n.cancelar,
              style: const TextStyle(color: Colors.amber),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.eliminar,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (userId == null) return;
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.yellow),
        ),
      );

      await ApiService.deleteUser(int.parse(userId!));

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader

      await storage.deleteAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loader si falló
        showJustifiedDialog(
          context,
          l10n.error,
          "No se pudo eliminar la cuenta: $e",
        );
      }
    }
  }

  void _showHelpMenu() {
    final l10n = AppLocalizations.of(context)!;
    final avisoTitle = l10n.avisoLegal;
    final avisoBody = l10n.contenidoAvisoLegal;
    final acercaTitle = l10n.acercaDe;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.gavel_outlined, color: AppColors.yellow),
            title: Text(
              avisoTitle,
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              showJustifiedDialog(context, avisoTitle, avisoBody);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.yellow),
            title: Text(
              acercaTitle,
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              showAcercaDeDialog(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOptionItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
    Color? iconColor,
    String? trailingText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor ?? Colors.white70),
        title: Text(
          title,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(
                trailingText,
                style: GoogleFonts.montserrat(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white24,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandAndSocialSection(AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialIconButton(
              icon: FontAwesomeIcons.globe,
              tooltip: l10n.sitioWeb,
              url: 'https://lumieter.com',
            ),
            const SizedBox(width: 16),
            _buildSocialIconButton(
              icon: FontAwesomeIcons.envelope,
              tooltip: l10n.contacto,
              url: 'mailto:lumieter.studios@gmail.com',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.desarrolladoCon,
              style: GoogleFonts.montserrat(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Icon(Icons.favorite, color: Colors.redAccent, size: 13),
            Text(
              l10n.por,
              style: GoogleFonts.montserrat(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              "Lumieter Studios",
              style: GoogleFonts.montserrat(
                color: AppColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          "Eterlotto v$_appVersion",
          style: GoogleFonts.montserrat(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIconButton({
    required dynamic icon,
    required String tooltip,
    required String url,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            final uri = Uri.parse(url);
            try {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } catch (_) {}
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: FaIcon(icon, size: 16, color: AppColors.amber),
          ),
        ),
      ),
    );
  }
}
