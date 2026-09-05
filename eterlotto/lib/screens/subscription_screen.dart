import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import '../providers/subscription_provider.dart';
import '../styles/colores.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Future<void> _openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openGooglePlaySubscriptions() {
    _openUrl("https://play.google.com/store/account/subscriptions");
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subProvider = context.watch<SubscriptionProvider>();
    final isSubscribed = subProvider.isSubscribed;
    final product = subProvider.monthlyProduct;
    final priceString = product?.price ??
        (subProvider.isLoading
            ? "Cargando..."
            : "Consultando...");

    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 🌟 Icono / Corona VIP
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [AppColors.amber, Color(0xFFD97706)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.amber.withValues(alpha: 0.4),
                      blurRadius: 25,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Color(0xFF1E1E1E),
                  size: 52,
                ),
              ),
              const SizedBox(height: 20),

              // Título
              Text(
                "Eterlotto VIP",
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.subtituloVip ?? "Disfruta de la mejor experiencia sin interrupciones",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 30),

              // 💎 Tarjeta de Beneficios
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSubscribed ? Colors.green : AppColors.amber.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    _buildBenefitItem(
                      icon: Icons.block,
                      iconColor: Colors.redAccent,
                      title: l10n?.ceroPublicidadTitulo ?? "Cero Publicidad",
                      subtitle: l10n?.ceroPublicidadDesc ?? "Sin banners ni anuncios al consultar resultados y estadísticas.",
                    ),
                    const Divider(color: Colors.white12, height: 28),
                    _buildBenefitItem(
                      icon: Icons.flash_on,
                      iconColor: AppColors.yellow,
                      title: l10n?.maximaVelocidadTitulo ?? "Máxima Velocidad",
                      subtitle: l10n?.maximaVelocidadDesc ?? "Navegación fluida y carga instantánea en todas las pantallas.",
                    ),
                    const Divider(color: Colors.white12, height: 28),
                    _buildBenefitItem(
                      icon: Icons.auto_awesome,
                      iconColor: Colors.amberAccent,
                      title: l10n?.soporteNuevasFuncionesTitulo ?? "Soporte y Nuevas Funciones",
                      subtitle: l10n?.soporteNuevasFuncionesDesc ?? "Acceso preferencial a futuras herramientas y algoritmos.",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 🏷️ Precio y Estado
              if (isSubscribed) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n?.suscripcionActiva ?? "Suscripción Activa",
                              style: GoogleFonts.montserrat(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              l10n?.suscripcionActivaDesc ?? "Tu plan VIP está activo. ¡Gracias por tu apoyo!",
                              style: GoogleFonts.montserrat(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _openGooglePlaySubscriptions,
                  icon: const Icon(Icons.manage_accounts, color: Colors.white70),
                  label: Text(
                    l10n?.administrarGooglePlay ?? "Administrar en Google Play",
                    style: GoogleFonts.montserrat(color: Colors.white70),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                // Tarjeta de Precio
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.amber),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n?.planMensual ?? "Plan Mensual",
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n?.renovacionAutomatica ?? "Renovación mensual automática",
                              style: GoogleFonts.montserrat(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          priceString,
                          style: GoogleFonts.montserrat(
                            color: AppColors.yellow,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botón de Suscripción
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: subProvider.isLoading
                        ? null
                        : () async {
                            final success = await subProvider.buyMonthlySubscription();
                            if (!success && context.mounted && subProvider.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(subProvider.errorMessage!),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: subProvider.isLoading
                        ? const CircularProgressIndicator(color: Color(0xFF121212))
                        : Text(
                            l10n?.suscribirmeAhora ?? "Suscribirme Ahora",
                            style: GoogleFonts.montserrat(
                              color: const Color(0xFF121212),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón Restaurar Compras
                TextButton(
                  onPressed: subProvider.isLoading
                      ? null
                      : () async {
                          await subProvider.restorePurchases();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  subProvider.isSubscribed
                                      ? (l10n?.comprasRestauradasExito ?? "✅ Compras restauradas con éxito.")
                                      : (l10n?.noComprasActivas ?? "ℹ️ No se encontraron compras activas previas."),
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    l10n?.restaurarCompras ?? "Restaurar suscripción",
                    style: GoogleFonts.montserrat(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // 🔍 Botón de Diagnóstico de Google Play (Sólo en Desarrollo)
                if (kDebugMode)
                  TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: const Color(0xFF1E1E1E),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (ctx) => Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Diagnóstico Google Play",
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white60),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF121212),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: SelectableText(
                                  subProvider.diagnosticInfo,
                                  style: GoogleFonts.firaCode(
                                    color: Colors.amberAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await subProvider.loadProducts();
                                  },
                                  icon: const Icon(Icons.refresh, color: Colors.black),
                                  label: Text(
                                    "Reintentar sincronización",
                                    style: GoogleFonts.montserrat(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.amber,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline, size: 16, color: Colors.white38),
                    label: Text(
                      "Ver estado de Google Play",
                      style: GoogleFonts.montserrat(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 24),

              // 📜 Términos y Condiciones Legales (Obligatorio en Google Play)
              Text(
                l10n?.terminosSuscripcionGooglePlay ??
                    "La suscripción se renueva automáticamente cada mes a través de Google Play a menos que se cancele al menos 24 horas antes del final del período actual. Puedes administrar o cancelar tu suscripción en los ajustes de tu cuenta de Google Play en cualquier momento.",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: Colors.white38,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.montserrat(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
