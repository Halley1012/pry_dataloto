import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import '../services/ad_service.dart';
import '../services/ad_load_diagnostics.dart';
import '../providers/subscription_provider.dart';
import '../screens/subscription_screen.dart';
import '../styles/colores.dart';

class BannerAdWidget extends StatefulWidget {
  final AdSize adSize;
  final bool showHeader;

  // 📸 MODO CAPTURAS / PLAY CONSOLE: Cambia a 'true' para ocultar el banner al tomar capturas
  static const bool hideBanner = false;

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
  bool _isAdLoading = false;
  Timer? _delayTimer;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  // ⏱️ Breve margen inicial para que la pantalla pinte su primer frame antes del banner
  static const Duration _bannerGracePeriod = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    AdService.instance.rewardPassRevision.addListener(_onRewardPassChanged);
    AdService.instance.adsReadyRevision.addListener(_onAdsReadyChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!AdService.instance.canRequestAds) {
        unawaited(AdService.instance.initialize());
      } else {
        _scheduleBannerLoad();
      }
    });
  }

  void _onRewardPassChanged() {
    if (!mounted) return;

    if (AdService.instance.isRewardPassActive) {
      _disposeBanner();
      setState(() {});
      return;
    }

    setState(() {});
    _scheduleBannerLoad();
  }

  void _onAdsReadyChanged() {
    if (!mounted) return;
    if (AdService.instance.canRequestAds) {
      _scheduleBannerLoad();
    } else {
      _disposeBanner();
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (BannerAdWidget.hideBanner) return;
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    // Nunca cargar un anuncio mientras el estado VIP de la sesión todavía no
    // está confirmado. El valor inicial `false` no significa "usuario gratis".
    if (!subscriptionProvider.isSubscriptionStatusResolved) {
      _disposeBanner();
      return;
    }

    final isSubscribed = subscriptionProvider.isSubscribed;
    if (!isSubscribed && !AdService.instance.isRewardPassActive) {
      _scheduleBannerLoad();
    } else {
      _disposeBanner();
    }
  }

  void _scheduleBannerLoad() {
    if (BannerAdWidget.hideBanner || !AdService.instance.canRequestAds) return;
    if (_bannerAd != null || _isAdLoaded || _isAdLoading) return;

    final sessionElapsed = AdService.instance.sessionDuration;
    if (sessionElapsed < _bannerGracePeriod) {
      _delayTimer?.cancel();
      _delayTimer = Timer(_bannerGracePeriod - sessionElapsed, () {
        if (mounted) {
          final subscriptionProvider = context.read<SubscriptionProvider>();
          if (subscriptionProvider.isSubscriptionStatusResolved &&
              !subscriptionProvider.isSubscribed &&
              !AdService.instance.isRewardPassActive &&
              _bannerAd == null) {
            _loadBanner();
          }
        }
      });
    } else {
      _loadBanner();
    }
  }

  void _loadBanner() {
    if (_bannerAd != null ||
        _isAdLoading ||
        !mounted ||
        !AdService.instance.canRequestAds) {
      return;
    }

    final subscriptionProvider = context.read<SubscriptionProvider>();
    if (!subscriptionProvider.isSubscriptionStatusResolved ||
        subscriptionProvider.isSubscribed ||
        AdService.instance.isRewardPassActive) {
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = null;
    _isAdLoading = true;

    final banner = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isAdLoading = false;
          _retryAttempt = 0;
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          logAdLoadFailure('banner', error);
          ad.dispose();
          _isAdLoading = false;
          if (!mounted) return;
          setState(() {
            _isAdLoaded = false;
            _bannerAd = null;
          });
          _scheduleRetry();
        },
      ),
    );

    _bannerAd = banner;
    banner.load();
  }

  void _scheduleRetry() {
    if (!mounted ||
        BannerAdWidget.hideBanner ||
        AdService.instance.isRewardPassActive) {
      return;
    }
    _retryTimer?.cancel();
    _retryAttempt = (_retryAttempt + 1).clamp(1, 4);
    final delaySeconds = 8 * _retryAttempt;
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted) return;
      _scheduleBannerLoad();
    });
  }

  void _disposeBanner() {
    _delayTimer?.cancel();
    _delayTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _isAdLoading = false;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
  }

  @override
  void dispose() {
    AdService.instance.rewardPassRevision.removeListener(_onRewardPassChanged);
    AdService.instance.adsReadyRevision.removeListener(_onAdsReadyChanged);
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (BannerAdWidget.hideBanner) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    // El anuncio sólo puede mostrarse después de conocer el estado VIP real.
    if (!subscriptionProvider.isSubscriptionStatusResolved ||
        subscriptionProvider.isSubscribed ||
        AdService.instance.isRewardPassActive ||
        !_isAdLoaded ||
        _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
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
