import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BusinessCard extends StatelessWidget {
  final String title;
  final String logo; // URL del logo
  final String description;
  final String address;
  final String city;
  final String contact;
  final IconData icon;
  final VoidCallback onAction;
  final String actionLabel;
  final String paginaweb;

  // 👇 redes opcionales (pueden venir luego del backend)
  final String? whatsappUrl;
  final String? facebookUrl;
  final String? instagramUrl;

  const BusinessCard({
    super.key,
    required this.title,
    required this.logo,
    required this.description,
    required this.address,
    required this.city,
    required this.contact,
    this.icon = Icons.business_center,
    required this.onAction,
    this.actionLabel = "Contactar",
    required this.paginaweb,
    this.whatsappUrl,
    this.facebookUrl,
    this.instagramUrl,
  });

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 235),
      margin: const EdgeInsets.all(0),
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
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 🔹 Encabezado con logo + título (Altura fija uniforme)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (logo.isNotEmpty)
                  GestureDetector(
                    onTap: () => _launchUrl(paginaweb),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        logo,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.store,
                              color: Colors.white54,
                              size: 40,
                            ),
                      ),
                    ),
                  )
                else
                  const Icon(Icons.store, color: Colors.white54, size: 40),

                const SizedBox(width: 12),

                Expanded(
                  child: GestureDetector(
                    onTap: () => _launchUrl(paginaweb),
                    child: SizedBox(
                      height: 40,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: AppTextStyles.h2.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 📝 Descripción (Espacio asignado uniforme para 3 líneas)
            SizedBox(
              height: 46,
              child: Text(
                description,
                style: AppTextStyles.caption.copyWith(color: AppColors.white),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),

            // 📍 Dirección
            GestureDetector(
              onTap: () async {
                if (address.isEmpty) return;
                final encoded = Uri.encodeComponent("$address, $city");

                final googleMapsUrl =
                    "https://www.google.com/maps/search/?api=1&query=$encoded";
                final geoUrl = "geo:0,0?q=$encoded";

                try {
                  if (!await launchUrl(
                    Uri.parse(geoUrl),
                    mode: LaunchMode.externalApplication,
                  )) {
                    await launchUrl(
                      Uri.parse(googleMapsUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                } catch (_) {}
              },
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: AppTextStyles.caption2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 🏙️ Ciudad
            Row(
              children: [
                const Icon(
                  Icons.location_city,
                  color: AppColors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    city,
                    style: AppTextStyles.caption2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ☎️ Contacto
            GestureDetector(
              onTap: () {
                if (contact.isEmpty) return;
                final phone = contact.replaceAll(
                  RegExp(r'[^0-9+]'),
                  '',
                );
                final url = "tel:$phone";
                _launchUrl(url);
              },
              child: Row(
                children: [
                  const Icon(Icons.phone, color: AppColors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      contact,
                      style: AppTextStyles.caption2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 2),

            // 🔗 Redes sociales (Colores oficiales)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (facebookUrl != null && facebookUrl!.isNotEmpty)
                  IconButton(
                    onPressed: () => _launchUrl(facebookUrl),
                    icon: const FaIcon(
                      FontAwesomeIcons.facebook,
                      color: Color(0xFF1877F2),
                    ),
                  ),
                if (instagramUrl != null && instagramUrl!.isNotEmpty)
                  IconButton(
                    onPressed: () => _launchUrl(instagramUrl),
                    icon: const FaIcon(
                      FontAwesomeIcons.instagram,
                      color: Color(0xFFE4405F),
                    ),
                  ),
                if (whatsappUrl != null && whatsappUrl!.isNotEmpty)
                  IconButton(
                    onPressed: () => _launchUrl(whatsappUrl),
                    icon: const FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: Color(0xFF25D366),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
