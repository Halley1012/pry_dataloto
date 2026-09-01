import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/secure_storage_helper.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final Function(int)? onTabChange;
  final VoidCallback? onProfileUpdated;
  const ProfileScreen({super.key, this.onLogout, this.onTabChange, this.onProfileUpdated});

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

  Future<void> _loadUserData() async {
    final userData = await storage.readAll();
    if (mounted) {
      context.read<SubscriptionProvider>().refreshSubscriptionStatus();
      setState(() {
        name = userData['name'] ?? "Usuario";
        email = userData['email'] ?? "correo@ejemplo.com";
        userId = userData['user_id'];
        avatarUrl = userData['avatar_url'];
        authProvider = userData['auth_provider'];
        isLoading = false;
      });
    }
  }

  void _showLogoutDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.cerrarSesion, style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(l10n.confirmarCerrarSesion, style: AppTextStyles.mensajeSecundario),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancelar, style: const TextStyle(color: AppColors.yellow))),
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
            child: Text(l10n.cerrarSesion, style: const TextStyle(color: Colors.redAccent)),
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
      'pais_id': int.tryParse(await storage.read(key: 'pais_id') ?? '0'),
      'departamento_id': int.tryParse(await storage.read(key: 'departamento_id') ?? '0'),
    };

    if (!mounted) return;
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegistroScreen(user: user, userId: int.tryParse(userId!))),
    );

    if (updated != null) {
      _loadUserData();
      widget.onProfileUpdated?.call();
    }

  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.yellow));

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
              Text(l10n.perfil, style: AppTextStyles.tituloPrincipal.copyWith(fontSize: 24)),
              const SizedBox(height: 30),
              
              // Header Perfil
              Row(
                children: [
                  UserBalotaAvatar(
                    avatarUrl: avatarUrl,
                    userName: name,
                    userId: int.tryParse(userId ?? "0"),
                    radius: 45,
                    showGlow: true,
                    showBorder: true,
                    borderColor: AppColors.yellow,
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
                              icon: const Icon(Icons.edit, color: AppColors.yellow, size: 20),
                            ),
                          ],
                        ),
                        Text(
                          email ?? l10n.email,
                          style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                          ),
                          child: Consumer<SubscriptionProvider>(
                            builder: (context, subProvider, _) {
                              final isSubscribed = subProvider.isSubscribed;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSubscribed
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : AppColors.amber.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: isSubscribed ? Colors.greenAccent : AppColors.yellow,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSubscribed ? Icons.verified : Icons.star,
                                      color: isSubscribed ? Colors.greenAccent : AppColors.yellow,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isSubscribed
                                          ? (l10n.vipSinAnuncios)
                                          : (l10n.planBasicoHazteVip),
                                      style: GoogleFonts.montserrat(
                                        color: isSubscribed ? Colors.greenAccent : AppColors.yellow,
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
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    ),
                    color: AppColors.amber.withValues(alpha: 0.12),
                    iconColor: AppColors.amber,
                    trailingText: subProvider.isSubscribed ? l10n.activo : l10n.obtener,
                  );
                },
              ),
              _buildOptionItem(Icons.ads_click, l10n.misAnuncios, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisAnunciosScreen()))),
              _buildOptionItem(Icons.settings_outlined, l10n.configuracion, _showConfigMenu),
              _buildOptionItem(Icons.help_outline, l10n.ayudaSoporte, _showHelpMenu),
              
              const SizedBox(height: 16),
              _buildOptionItem(Icons.logout, l10n.cerrarSesion, _showLogoutDialog, color: Colors.redAccent.withValues(alpha: 0.1), iconColor: Colors.redAccent),
              
              const SizedBox(height: 30),
              _buildBrandAndSocialSection(),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.amber),
            title: const Text("Idioma / Language / Idioma", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _showLanguageDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: Text(l10n.eliminarCuenta, style: const TextStyle(color: Colors.white)),
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
        title: Text(l10n.seleccionarIdioma,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text("🇪🇸", style: TextStyle(fontSize: 22)),
              title:
                  const Text("Español", style: TextStyle(color: Colors.white)),
              onTap: () => _confirmLanguageChange(context, const Locale('es')),
            ),
            ListTile(
              leading: const Text("🇺🇸", style: TextStyle(fontSize: 22)),
              title:
                  const Text("English", style: TextStyle(color: Colors.white)),
              onTap: () => _confirmLanguageChange(context, const Locale('en')),
            ),
            ListTile(
              leading: const Text("🇧🇷", style: TextStyle(fontSize: 22)),
              title: const Text("Português",
                  style: TextStyle(color: Colors.white)),
              onTap: () => _confirmLanguageChange(context, const Locale('pt')),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.settings_suggest, color: Colors.amber),
              title: Text(l10n.idiomaSistema,
                  style: const TextStyle(color: Colors.white70)),
              onTap: () => _confirmLanguageChange(context, null),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLanguageChange(
      BuildContext context, Locale? newLocale) async {
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
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.confirmarCambioIdioma,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelar,
                style: const TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.si,
                style: const TextStyle(
                    color: AppColors.yellow, fontWeight: FontWeight.bold)),
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
            Text(l10n.eliminarCuenta, style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(l10n.confirmarEliminarCuenta, style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelar, style: const TextStyle(color: Colors.amber)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.eliminar, style: const TextStyle(color: Colors.redAccent)),
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
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.yellow))
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
          (route) => false
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loader si falló
        showJustifiedDialog(context, l10n.error, "No se pudo eliminar la cuenta: $e");
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.gavel_outlined, color: AppColors.yellow),
            title: Text(avisoTitle, style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              showJustifiedDialog(context, avisoTitle, avisoBody);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.yellow),
            title: Text(acercaTitle, style: const TextStyle(color: Colors.white)),
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

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap, {Color? color, Color? iconColor, String? trailingText}) {
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
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandAndSocialSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialIconButton(
              icon: FontAwesomeIcons.instagram,
              tooltip: 'Instagram',
              url: 'https://instagram.com/lumieter.studios',
            ),
            const SizedBox(width: 16),
            _buildSocialIconButton(
              icon: FontAwesomeIcons.globe,
              tooltip: 'Sitio Web',
              url: 'https://lumieter.com',
            ),
            const SizedBox(width: 16),
            _buildSocialIconButton(
              icon: FontAwesomeIcons.envelope,
              tooltip: 'Contacto',
              url: 'mailto:lumieter.studios@gmail.com',
            ),
            const SizedBox(width: 16),
            _buildSocialIconButton(
              icon: FontAwesomeIcons.xTwitter,
              tooltip: 'X (Twitter)',
              url: 'https://x.com/lumieter',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Desarrollado con ",
              style: GoogleFonts.montserrat(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Icon(Icons.favorite, color: Colors.redAccent, size: 13),
            Text(
              " por ",
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
            child: FaIcon(
              icon,
              size: 16,
              color: AppColors.amber,
            ),
          ),
        ),
      ),
    );
  }
}
