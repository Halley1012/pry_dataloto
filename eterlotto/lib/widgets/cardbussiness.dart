import 'package:eterlotto/styles/colores.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class BusinessCard extends StatelessWidget {
  final String title;
  final String logo; // URL del logo/imagen
  final String description;
  final String address;
  final String city;
  final String contact;
  final IconData icon;
  final VoidCallback onAction;
  final String actionLabel;
  final String paginaweb;

  // Redes sociales opcionales
  final String? whatsappUrl;
  final String? facebookUrl;
  final String? instagramUrl;

  // Atributos adicionales para el nuevo diseño (opcionales)
  final bool isDestacado;
  final String? statusText; // Ej: "Abierto 24/7" o "Abierto ahora"
  final bool isFavorite;
  final int? totalLikes;

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
    this.isDestacado = false,
    this.statusText,
    this.isFavorite = false,
    this.totalLikes,
  });

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    String finalUrl = url.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }
    final uri = Uri.parse(finalUrl);

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      }
    } catch (_) {}
  }

  Future<void> _openMaps() async {
    if (address.isEmpty) return;
    final query = city.isNotEmpty ? "$address, $city" : address;
    final encoded = Uri.encodeComponent(query);
    final googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$encoded";
    final geoUrl = "geo:0,0?q=$encoded";

    try {
      if (!await launchUrl(Uri.parse(geoUrl), mode: LaunchMode.externalApplication)) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Future<void> _callPhone() async {
    if (contact.isEmpty) return;
    final phone = contact.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) return;
    final uri = Uri.parse("tel:$phone");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  String _formatLikes(int count) {
    if (count < 1000) return "$count";
    if (count < 1000000) {
      final double k = count / 1000.0;
      final bool hasDecimal = (count % 1000) >= 100 && count < 10000;
      return hasDecimal ? "${k.toStringAsFixed(1)}k" : "${k.toInt()}k";
    }
    final double m = count / 1000000.0;
    final bool hasDecimal = (count % 1000000) >= 100000;
    return hasDecimal ? "${m.toStringAsFixed(1)}M" : "${m.toInt()}M";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF13191E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // --- SECCIÓN SUPERIOR: IMAGEN + DETALLES ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- IMAGEN + BADGE DESTACADO ---
                Stack(
                  children: [
                    GestureDetector(
                      onTap: paginaweb.isNotEmpty ? () => _launchUrl(paginaweb) : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          logo,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 110,
                            height: 110,
                            color: Colors.white10,
                            child: const Icon(Icons.store, color: Colors.white24, size: 40),
                          ),
                        ),
                      ),
                    ),
                    // Badge "★ Destacado"
                    if (isDestacado)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF081C14).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF00E676).withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Color(0xFF00E676), size: 11),
                              const SizedBox(width: 3),
                              Text(
                                "Destacado",
                                style: GoogleFonts.montserrat(
                                  color: const Color(0xFF00E676),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // --- INFORMACIÓN DERECHA ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título + Icono Corazón
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: paginaweb.isNotEmpty ? () => _launchUrl(paginaweb) : null,
                              child: Text(
                                title,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: onAction,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: isFavorite ? Colors.redAccent : AppColors.yellow,
                                  size: 20,
                                ),
                                if (totalLikes != null) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatLikes(totalLikes!),
                                    style: GoogleFonts.montserrat(
                                      color: isFavorite ? Colors.redAccent : AppColors.yellow,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Descripción
                      Text(
                        description,
                        style: GoogleFonts.montserrat(
                          color: Colors.white70,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Detalles (Dirección -> Mapa, Ciudad, Teléfono -> Llamar)
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        address,
                        onTap: address.isNotEmpty ? _openMaps : null,
                        isClickable: address.isNotEmpty,
                      ),
                      _buildInfoRow(
                        Icons.business_outlined,
                        city,
                        onTap: (address.isEmpty && city.isNotEmpty) ? _openMaps : null,
                      ),
                      _buildInfoRow(
                        Icons.phone_outlined,
                        contact,
                        onTap: contact.isNotEmpty ? _callPhone : null,
                        isClickable: contact.isNotEmpty,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // --- LÍNEA DELGADA DIVISORIA ---
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 10),
              child: Container(
                height: 0.8,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),

            // --- SECCIÓN INFERIOR: BADGE DE ESTADO + REDES SOCIALES ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Badge de Estado (Abierto ahora / Abierto 24/7 / Cerrado)
                if (statusText != null && statusText!.isNotEmpty)
                  Builder(
                    builder: (context) {
                      final isClosed = statusText!.toLowerCase().contains("cerrado");
                      final badgeColor = isClosed ? const Color(0xFFFF5252) : const Color(0xFF00E676);
                      final bgColor = isClosed ? const Color(0xFF260D0D) : const Color(0xFF091F17);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: badgeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText!,
                              style: GoogleFonts.montserrat(
                                color: badgeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  const SizedBox.shrink(),

                // Redes Sociales (Iconos más grandes y luminosos)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (facebookUrl != null && facebookUrl!.isNotEmpty)
                      _buildSocialIcon(FontAwesomeIcons.facebookF, const Color(0xFF1877F2), facebookUrl),
                    if (instagramUrl != null && instagramUrl!.isNotEmpty)
                      _buildSocialIcon(FontAwesomeIcons.instagram, const Color(0xFFE4405F), instagramUrl),
                    if (whatsappUrl != null && whatsappUrl!.isNotEmpty)
                      _buildSocialIcon(FontAwesomeIcons.whatsapp, const Color(0xFF25D366), whatsappUrl),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text, {
    VoidCallback? onTap,
    bool isClickable = false,
  }) {
    if (text.isEmpty) return const SizedBox.shrink();
    final row = Row(
      children: [
        Icon(
          icon,
          color: isClickable ? AppColors.yellow : Colors.white38,
          size: 14,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.montserrat(
              color: isClickable ? Colors.white : Colors.white70,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: row,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: row,
    );
  }

  Widget _buildSocialIcon(dynamic icon, Color color, String? url) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () => _launchUrl(url),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: FaIcon(icon, color: color, size: 17),
          ),
        ),
      ),
    );
  }
}
