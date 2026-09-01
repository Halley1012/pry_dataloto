import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import '../services/ad_service.dart';
import '../providers/subscription_provider.dart';
import '../screens/subscription_screen.dart';
import '../styles/colores.dart';

class BannerAdWidget extends StatefulWidget {
  final AdSize adSize;
  final bool showHeader;

  // 📸 MODO CAPTURAS / PLAY CONSOLE: Cambia a 'false' cuando desees volver a mostrar el banner
  static const bool hideBanner = true;

  const BannerAdWidget({
    super.key,
    this.adSize = AdSize.banner,
    this.showHeader = true,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  Timer? _delayTimer;

  // ⏱️ Periodo de gracia para el banner inferior (40 segundos sin publicidad al inicio)
  static const Duration _bannerGracePeriod = Duration(seconds: 40);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (BannerAdWidget.hideBanner) return;
    final isSubscribed = Provider.of<SubscriptionProvider>(context).isSubscribed;
    if (!isSubscribed) {
      _scheduleBannerLoad();
    } else if (isSubscribed) {
      _disposeBanner();
    }
  }

  void _scheduleBannerLoad() {
    if (BannerAdWidget.hideBanner) return;
    if (_bannerAd != null || _isAdLoaded) return;

    final sessionElapsed = AdService.instance.sessionDuration;
    if (sessionElapsed < _bannerGracePeriod) {
      final remaining = _bannerGracePeriod - sessionElapsed;
      debugPrint('🛡️ [Banner AdMob] En espera: Aparecerá en ${remaining.inSeconds}s (gracia de 40s de sesión)');
      _delayTimer?.cancel();
      _delayTimer = Timer(remaining, () {
        if (mounted) {
          final isSubscribed = context.read<SubscriptionProvider>().isSubscribed;
          if (!isSubscribed && _bannerAd == null) {
            _loadBanner();
          }
        }
      });
    } else {
      _loadBanner();
    }
  }

  void _loadBanner() {
    if (_bannerAd != null || !mounted) return;

    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
            debugPrint('✅ [Banner AdMob] Banner cargado y visible.');
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ [Banner AdMob] Falló al cargar: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _bannerAd = null;
            });
          }
        },
      ),
    );

    _bannerAd?.load();
  }

  void _disposeBanner() {
    _delayTimer?.cancel();
    _delayTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (BannerAdWidget.hideBanner) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    // Si el usuario tiene suscripción activa, está en los primeros 40s o no ha cargado, 0 px
    final isSubscribed = context.watch<SubscriptionProvider>().isSubscribed;
    if (isSubscribed || !_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.showHeader) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n?.publicidadLabel ?? "PUBLICIDAD",
                        style: GoogleFonts.montserrat(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            l10n?.quitarAnuncios ?? "Quitar anuncios",
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.amber,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.stars,
                            size: 11,
                            color: AppColors.amber,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],

          // 📱 Contenedor del Banner centrado
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
        ],
      ),
    );
  }
}
