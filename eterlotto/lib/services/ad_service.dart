import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import '../styles/colores.dart';
import '../screens/subscription_screen.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ⚙️ Configuración: 'true' para Internal Testing / Desarrollo. Cambiar a 'false' SÓLO al enviar a Producción real.
  static const bool isTestMode = true;

  // 🔹 IDs de Producción (Reemplazar cuando crees los bloques en Google AdMob)
  static const String _prodAndroidBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodAndroidInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodAndroidRewardedId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodAndroidAppOpenId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodIosBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodIosInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodIosRewardedId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodIosAppOpenId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // 🧪 IDs Oficiales de Prueba de Google
  static const String _testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testAndroidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testAndroidAppOpenId = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testIosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testIosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testIosRewardedId = 'ca-app-pub-3940256099942544/1712485313';
  static const String _testIosAppOpenId = 'ca-app-pub-3940256099942544/5575463023';

  /// ID de Banner según plataforma y modo
  static String get bannerAdUnitId {
    if (isTestMode || kDebugMode) {
      return Platform.isAndroid ? _testAndroidBannerId : _testIosBannerId;
    }
    return Platform.isAndroid ? _prodAndroidBannerId : _prodIosBannerId;
  }

  /// ID de Intersticial según plataforma y modo
  static String get interstitialAdUnitId {
    if (isTestMode || kDebugMode) {
      return Platform.isAndroid ? _testAndroidInterstitialId : _testIosInterstitialId;
    }
    return Platform.isAndroid ? _prodAndroidInterstitialId : _prodIosInterstitialId;
  }

  /// ID de Anuncio Recompensado según plataforma y modo
  static String get rewardedAdUnitId {
    if (isTestMode || kDebugMode) {
      return Platform.isAndroid ? _testAndroidRewardedId : _testIosRewardedId;
    }
    return Platform.isAndroid ? _prodAndroidRewardedId : _prodIosRewardedId;
  }


  /// ID de App Open según plataforma y modo
  static String get appOpenAdUnitId {
    if (isTestMode || kDebugMode) {
      return Platform.isAndroid ? _testAndroidAppOpenId : _testIosAppOpenId;
    }
    return Platform.isAndroid ? _prodAndroidAppOpenId : _prodIosAppOpenId;
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // 🛡️ Variables de Control de Sesión y Reglas de Oro
  DateTime _sessionStartTime = DateTime.now();
  Duration get sessionDuration => DateTime.now().difference(_sessionStartTime);
  int _sessionInterstitialShownCount = 0;
  int _actionCounter = 0;
  DateTime? _lastInterstitialShownAt;
  DateTime? _backgroundedAt;
  DateTime? _lastAnyFullScreenClosedAt;
  DateTime? _lastAppOpenShownAt;
  bool _hasCompletedColdStart = false;
  bool _isFullScreenAdShowing = false;

  // 📐 Reglas de Oro configuradas
  static const Duration _sessionGracePeriod = Duration(seconds: 60); // Primeros 60s protegidos
  static const Duration _minIntervalBetweenInterstitials = Duration(minutes: 2); // 2 min cooldown
  static const int _maxInterstitialsPerSession = 2; // Máximo 2 por sesión
  static const int _actionsThreshold = 3; // Cada 3 acciones de valor
  static const Duration _sessionResetAfterBackground = Duration(minutes: 30);
  static const Duration _appOpenMinBackground = Duration(minutes: 2);
  static const Duration _appOpenCooldown = Duration(minutes: 10);
  static const Duration _minGapBetweenFullScreenAds = Duration(seconds: 30);
  static const Duration _appOpenMaxCacheDuration = Duration(hours: 4);

  // Instancias de Anuncios
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  VoidCallback? _currentOnClosedCallback;

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  AppOpenAd? _appOpenAd;
  bool _isAppOpenLoading = false;
  DateTime? _appOpenLoadedAt;

  /// Inicializar el SDK de Mobile Ads
  Future<void> initialize() async {
    _sessionStartTime = DateTime.now();
    _sessionInterstitialShownCount = 0;
    _actionCounter = 0;
    _lastInterstitialShownAt = null;

    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      // Precargar anuncios
      loadInterstitialAd();
      loadRewardedAd();
      loadAppOpenAd();
    } catch (_) {}
  }

  // ==========================================
  // 🚪 APP OPEN ADS (REGRESO A PRIMER PLANO)
  // ==========================================

  void onAppBackgrounded() {
    _backgroundedAt ??= DateTime.now();
  }

  /// Se llama al volver al primer plano. No muestra App Open en el cold start.
  /// En producción exige al menos 2 min fuera de la app y 10 min entre App Open.
  void onAppForegrounded({bool isPremium = false}) {
    final now = DateTime.now();

    if (!_hasCompletedColdStart) {
      _hasCompletedColdStart = true;
      _backgroundedAt = null;
      loadAppOpenAd();
      return;
    }

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) return;

    final backgroundDuration = now.difference(backgroundedAt);
    if (backgroundDuration >= _sessionResetAfterBackground) {
      _resetSession(now);
    }

    final minBackground = isTestMode
        ? const Duration(seconds: 15)
        : _appOpenMinBackground;
    if (backgroundDuration < minBackground) return;

    showAppOpenAdIfAvailable(isPremium: isPremium);
  }

  void _resetSession(DateTime now) {
    _sessionStartTime = now;
    _sessionInterstitialShownCount = 0;
    _actionCounter = 0;
    _lastInterstitialShownAt = null;
  }

  bool _canShowAnotherFullScreenAd() {
    if (_isFullScreenAdShowing) return false;
    final lastClosed = _lastAnyFullScreenClosedAt;
    if (lastClosed == null) return true;
    final gap = isTestMode
        ? const Duration(seconds: 5)
        : _minGapBetweenFullScreenAds;
    return DateTime.now().difference(lastClosed) >= gap;
  }

  void _markFullScreenClosed() {
    _isFullScreenAdShowing = false;
    _lastAnyFullScreenClosedAt = DateTime.now();
  }

  void loadAppOpenAd() {
    if (!_isInitialized || _appOpenAd != null || _isAppOpenLoading) return;
    _isAppOpenLoading = true;

    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenLoadedAt = DateTime.now();
          _isAppOpenLoading = false;
        },
        onAdFailedToLoad: (_) {
          _isAppOpenLoading = false;
          _appOpenAd = null;
          _appOpenLoadedAt = null;
        },
      ),
    );
  }

  bool showAppOpenAdIfAvailable({bool isPremium = false}) {
    if (isPremium || !_isInitialized || !_canShowAnotherFullScreenAd()) {
      return false;
    }

    final now = DateTime.now();
    final lastShown = _lastAppOpenShownAt;
    final cooldown = isTestMode
        ? const Duration(seconds: 30)
        : _appOpenCooldown;
    if (lastShown != null && now.difference(lastShown) < cooldown) {
      return false;
    }

    final loadedAt = _appOpenLoadedAt;
    if (_appOpenAd == null || loadedAt == null) {
      loadAppOpenAd();
      return false;
    }

    if (now.difference(loadedAt) >= _appOpenMaxCacheDuration) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _appOpenLoadedAt = null;
      loadAppOpenAd();
      return false;
    }

    final ad = _appOpenAd!;
    _appOpenAd = null;
    _appOpenLoadedAt = null;
    _isFullScreenAdShowing = true;
    _lastAppOpenShownAt = now;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _markFullScreenClosed();
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _markFullScreenClosed();
        loadAppOpenAd();
      },
    );

    ad.show();
    return true;
  }

  // ==========================================
  // 📺 ANUNCIOS INTERSTICIALES (PANTALLA COMPLETA)
  // ==========================================

  /// Precargar anuncio intersticial en segundo plano
  void loadInterstitialAd() {
    if (_interstitialAd != null || _isInterstitialLoading) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) {
              _isFullScreenAdShowing = true;
            },
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _lastInterstitialShownAt = DateTime.now();
              _sessionInterstitialShownCount++;
              _markFullScreenClosed();
              
              final callback = _currentOnClosedCallback;
              _currentOnClosedCallback = null;
              callback?.call();

              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitialAd = null;
              _markFullScreenClosed();

              final callback = _currentOnClosedCallback;
              _currentOnClosedCallback = null;
              callback?.call();

              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _isInterstitialLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Registra una acción de valor (por ejemplo, cambiar de sección principal)
  /// y deja que AdService decida si corresponde mostrar un intersticial.
  ///
  /// La acción nunca bloquea la navegación. Si el umbral ya se alcanzó pero
  /// todavía hay cooldown, el contador se conserva y se vuelve a intentar en
  /// la siguiente acción válida.
  bool recordValueAction({
    bool isPremium = false,
    VoidCallback? onAdClosed,
  }) {
    if (isPremium) {
      onAdClosed?.call();
      return false;
    }

    _actionCounter++;
    if (_actionCounter < _actionsThreshold) {
      onAdClosed?.call();
      return false;
    }

    return showInterstitialAd(
      isPremium: isPremium,
      ignoreThreshold: true,
      onAdClosed: onAdClosed,
    );
  }

  /// Mostrar anuncio intersticial respetando todas las Reglas de Oro UX.
  /// Las llamadas tradicionales sin [ignoreThreshold] también participan del
  /// mismo contador global de acciones de valor.
  bool showInterstitialAd({
    bool isPremium = false,
    bool ignoreThreshold = false,
    VoidCallback? onAdClosed,
  }) {
    if (isPremium || !_canShowAnotherFullScreenAd()) {
      onAdClosed?.call();
      return false;
    }

    // 1. Regla: Periodo de gracia inicial (primeros 60 segundos en prod, 5s en modo prueba)
    final gracePeriod = isTestMode ? const Duration(seconds: 5) : _sessionGracePeriod;
    final sessionDuration = DateTime.now().difference(_sessionStartTime);
    if (sessionDuration < gracePeriod) {
      onAdClosed?.call();
      return false;
    }

    // 2. Regla: Límite máximo por sesión (máximo 2)
    if (_sessionInterstitialShownCount >= _maxInterstitialsPerSession) {
      onAdClosed?.call();
      return false;
    }

    // 3. Regla: Contador global de acciones de valor.
    // Si hay cooldown cuando se alcanza el umbral, NO perdemos el progreso:
    // el siguiente evento volverá a intentar mostrar el anuncio.
    if (!ignoreThreshold) {
      _actionCounter++;
      if (_actionCounter < _actionsThreshold) {
        onAdClosed?.call();
        return false;
      }
    }

    // 4. Regla: Cooldown entre anuncios (mínimo 2 minutos en prod, 15s en modo prueba)
    final minCooldown = isTestMode ? const Duration(seconds: 15) : _minIntervalBetweenInterstitials;
    if (_lastInterstitialShownAt != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialShownAt!);
      if (elapsed < minCooldown) {
        onAdClosed?.call();
        return false;
      }
    }

    if (_interstitialAd != null) {
      // Un intersticial mostrado satisface el umbral global, incluso cuando
      // fue solicitado por una transición explícita (ignoreThreshold=true).
      _actionCounter = 0;
      _currentOnClosedCallback = onAdClosed;
      _interstitialAd!.show();
      return true;
    } else {
      loadInterstitialAd();
      onAdClosed?.call();
      return false;
    }
  }

  // ==========================================
  // 🎁 ANUNCIOS RECOMPENSADOS (REWARDED ADS)
  // ==========================================

  // Registro de funciones desbloqueadas temporalmente en la sesión (ej. 2 horas o toda la sesión)
  final Map<String, DateTime> _unlockedFeatures = {};

  /// Verifica si una función está actualmente desbloqueada por recompensa
  bool isFeatureUnlocked(String featureKey) {
    final expiresAt = _unlockedFeatures[featureKey];
    if (expiresAt == null) return false;
    if (DateTime.now().isAfter(expiresAt)) {
      _unlockedFeatures.remove(featureKey);
      return false;
    }
    return true;
  }

  /// Desbloquea una función por una duración determinada (por defecto 2 horas)
  void unlockFeature(String featureKey, {Duration duration = const Duration(hours: 2)}) {
    _unlockedFeatures[featureKey] = DateTime.now().add(duration);
  }

  /// Precargar anuncio recompensado en segundo plano
  void loadRewardedAd() {
    if (_rewardedAd != null || _isRewardedLoading) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (_) {
          _isRewardedLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Mostrar diálogo y flujo de anuncio recompensado para funciones especiales
  Future<void> showRewardedFeatureGate({
    required BuildContext context,
    required bool isPremium,
    required String featureTitle,
    required String featureActionDescription,
    String? featureKey,
    Duration unlockDuration = const Duration(hours: 2),
    required VoidCallback onRewardGranted,
  }) async {
    // Si el usuario es VIP o ya desbloqueó la función previamente en esta sesión:
    if (isPremium || (featureKey != null && isFeatureUnlocked(featureKey))) {
      onRewardGranted();
      return;
    }

    // Mostrar diálogo explicativo al usuario
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.amber.withValues(alpha: 0.3)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard, color: AppColors.amber, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  featureTitle,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                featureActionDescription,
                style: GoogleFonts.montserrat(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF282828),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: AppColors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n?.usuariosVipSinAnuncios ?? "Los usuarios VIP disfrutan de esta y todas las funciones sin ver anuncios.",
                        style: GoogleFonts.montserrat(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l10n?.cancelar ?? "Cancelar",
                style: GoogleFonts.montserrat(color: Colors.white38),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              child: Text(
                l10n?.hacermeVip ?? "Hacerme VIP 💎",
                style: GoogleFonts.montserrat(
                  color: AppColors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.play_circle_fill, color: Color(0xFF121212), size: 18),
              label: Text(
                l10n?.verVideo ?? "Ver Video",
                style: GoogleFonts.montserrat(
                  color: const Color(0xFF121212),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );

    if (proceed != true) return;

    // Ejecutar el anuncio recompensado
    if (_rewardedAd != null) {
      if (!_canShowAnotherFullScreenAd()) {
        return;
      }
      bool userEarnedReward = false;

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) {
          _isFullScreenAdShowing = true;
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          _markFullScreenClosed();
          loadRewardedAd();
          if (userEarnedReward) {
            if (featureKey != null) {
              unlockFeature(featureKey, duration: unlockDuration);
            }
            onRewardGranted();
          } else if (context.mounted) {
            final langCode = Localizations.localeOf(context).languageCode;
            final message = langCode == 'en'
                ? 'Complete the video to unlock this feature.'
                : (langCode == 'pt'
                      ? 'Conclua o vídeo para desbloquear esta função.'
                      : 'Completa el video para desbloquear esta función.');
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          _rewardedAd = null;
          _markFullScreenClosed();
          loadRewardedAd();
          if (context.mounted) {
            final langCode = Localizations.localeOf(context).languageCode;
            final message = langCode == 'en'
                ? 'The video could not be shown. Please try again.'
                : (langCode == 'pt'
                      ? 'Não foi possível exibir o vídeo. Tente novamente.'
                      : 'No se pudo mostrar el video. Inténtalo nuevamente.');
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (_, __) {
          userEarnedReward = true;
        },
      );
    } else {
      // Para usuarios no VIP la función sólo se desbloquea tras completar
      // realmente el video. Si no hay anuncio disponible, se reintenta la
      // precarga pero no se concede acceso por cortesía.
      loadRewardedAd();
      if (context.mounted) {
        final langCode = Localizations.localeOf(context).languageCode;
        final message = langCode == 'en'
            ? 'No video is available right now. Please try again shortly.'
            : (langCode == 'pt'
                  ? 'Nenhum vídeo está disponível agora. Tente novamente em instantes.'
                  : 'No hay video disponible en este momento. Inténtalo de nuevo en unos instantes.');
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  /// Liberar recursos
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _appOpenLoadedAt = null;
    _currentOnClosedCallback = null;
  }
}
