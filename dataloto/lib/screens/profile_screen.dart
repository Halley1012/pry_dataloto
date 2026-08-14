import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/screens/registro.dart';
import 'package:dataloto/screens/login.dart';
import 'package:dataloto/screens/misanuncios.dart';
import 'package:dataloto/screens/welcome.dart';
import 'package:dataloto/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:dataloto/providers/locale_provider.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final Function(int)? onTabChange;
  const ProfileScreen({super.key, this.onLogout, this.onTabChange});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final storage = const FlutterSecureStorage();
  String? name;
  String? email;
  String? userId;
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
      setState(() {
        name = userData['name'] ?? "Usuario";
        email = userData['email'] ?? "correo@ejemplo.com";
        userId = userData['user_id'];
        isLoading = false;
      });
    }
  }

  void _showLogoutDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n?.cerrarSesion ?? "Cerrar sesión", style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(l10n?.confirmarCerrarSesion ?? "¿Estás seguro de que deseas salir?", style: AppTextStyles.mensajeSecundario),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n?.cancelar ?? "Cancelar", style: const TextStyle(color: AppColors.yellow))),
          TextButton(
            onPressed: () async {
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
            child: Text(l10n?.cerrarSesion ?? "Cerrar sesión", style: const TextStyle(color: Colors.redAccent)),
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

    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegistroScreen(user: user, userId: int.tryParse(userId!))),
    );

    if (updated != null) {
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.yellow));

    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            children: [
              Text(l10n?.perfil ?? "Mi Perfil", style: AppTextStyles.tituloPrincipal.copyWith(fontSize: 24)),
              const SizedBox(height: 30),
              
              // Header Perfil
              Row(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: AppColors.getAvatarColor(name ?? "", userId: int.tryParse(userId ?? "0")),
                    child: Text(
                      (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : "?",
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(name ?? (l10n?.nombre ?? "Nombre"), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))),
                            IconButton(onPressed: _editProfile, icon: const Icon(Icons.edit, color: AppColors.yellow, size: 20)),
                          ],
                        ),
                        Text(email ?? (l10n?.email ?? "Email"), style: const TextStyle(color: Colors.white54, fontSize: 14)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.yellow),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: AppColors.yellow, size: 14),
                              const SizedBox(width: 4),
                              Text(l10n?.usuarioPremium ?? "Usuario Premium", style: const TextStyle(color: AppColors.yellow, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Opciones
              _buildOptionItem(Icons.ads_click, l10n?.misAnuncios ?? "Mis anuncios", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisAnunciosScreen()))),
              _buildOptionItem(Icons.payment, l10n?.metodosPago ?? "Métodos de pago", () {}),
              _buildOptionItem(Icons.settings_outlined, l10n?.configuracion ?? "Configuración", _showConfigMenu),
              _buildOptionItem(Icons.help_outline, l10n?.ayudaSoporte ?? "Ayuda y soporte", _showHelpMenu),
              _buildOptionItem(Icons.info_outline, "Versión de la app", () {}, trailingText: _appVersion),
              
              const SizedBox(height: 20),
              _buildOptionItem(Icons.logout, l10n?.cerrarSesion ?? "Cerrar sesión", _showLogoutDialog, color: Colors.redAccent.withOpacity(0.1), iconColor: Colors.redAccent),
              
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfigMenu() {
    final l10n = AppLocalizations.of(context);
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
            title: Text(l10n?.eliminarCuenta ?? "Eliminar cuenta", style: const TextStyle(color: Colors.white)),
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
    final l10n = AppLocalizations.of(context);
    final locProvider = Provider.of<LocaleProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n?.seleccionarIdioma ?? "Seleccionar Idioma / Select Language", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text("🇪🇸", style: TextStyle(fontSize: 22)),
              title: const Text("Español", style: TextStyle(color: Colors.white)),
              onTap: () {
                locProvider.setLocale(const Locale('es'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text("🇺🇸", style: TextStyle(fontSize: 22)),
              title: const Text("English", style: TextStyle(color: Colors.white)),
              onTap: () {
                locProvider.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text("🇧🇷", style: TextStyle(fontSize: 22)),
              title: const Text("Português", style: TextStyle(color: Colors.white)),
              onTap: () {
                locProvider.setLocale(const Locale('pt'));
                Navigator.pop(context);
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.settings_suggest, color: Colors.amber),
              title: Text(l10n?.idiomaSistema ?? "Idioma del Sistema", style: const TextStyle(color: Colors.white70)),
              onTap: () {
                locProvider.clearLocale();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarCuenta(BuildContext context) async {
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
            Text("Eliminar cuenta", style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("¿Estás seguro de que deseas eliminar tu cuenta? Esta acción es irreversible.", style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.amber)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.redAccent)),
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
        _showJustifiedDialog("Error", "No se pudo eliminar la cuenta: $e");
      }
    }
  }

  void _showHelpMenu() {
    final l10n = AppLocalizations.of(context);
    final avisoTitle = l10n?.avisoLegal ?? "Aviso legal";
    final avisoBody = l10n?.contenidoAvisoLegal ?? "Esta app no es oficial ni está asociada con operadores de loterías ni con entidades reguladoras de juegos de azar en ningún país.";
    final acercaTitle = l10n?.acercaDe ?? "Acerca de";
    final acercaBody = l10n?.contenidoAcercaDe ?? "DataLoto utiliza inteligencia artificial para analizar patrones históricos de loterías...";

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
              _showJustifiedDialog(avisoTitle, avisoBody);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.yellow),
            title: Text(acercaTitle, style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _showJustifiedDialog(acercaTitle, acercaBody);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showJustifiedDialog(String title, String content) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.blackfondo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(content, textAlign: TextAlign.justify, style: AppTextStyles.mensajeSecundario),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n?.cerrar ?? "Cerrar", style: const TextStyle(color: AppColors.yellow))),
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
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null) Text(trailingText, style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}
