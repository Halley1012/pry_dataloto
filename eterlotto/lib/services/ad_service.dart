import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import '../styles/colores.dart';
import '../screens/subscription_screen.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  String _rewardLocalized(
    BuildContext context, {
    required String es,
    required String en,
    required String fr,
    required String pt,
  }) {
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    switch (lang) {
      case 'en':
        return en;
      case 'fr':
        return fr;
      case 'pt':
        return pt;
      default:
        return es;
    }
  }

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

  // ==========================================
  // 🎁 PASE DE RECOMPENSA GLOBAL
  // ==========================================
  // Cada Rewarded completado suma 15 minutos. El usuario decide cuándo
  // activar el saldo desde el regalo del Home. Máximo acumulable: 2 horas.
  static const int rewardMinutesPerVideo = 15;
  static const int maxRewardBankMinutes = 120;

  final ValueNotifier<int> rewardPassRevision = ValueNotifier<int>(0);
  String? _rewardUserId;
  int _rewardBankMinutes = 0;
  DateTime? _rewardPassActiveUntil;
  Timer? _rewardPassExpiryTimer;

  int get rewardBankMinutes => _rewardBankMinutes;

  bool get isRewardPassActive {
    final until = _rewardPassActiveUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  Duration get rewardPassRemaining {
    final until = _rewardPassActiveUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get hasRewardBalance => _rewardBankMinutes > 0;
  bool get isRewardBankFull => _rewardBankMinutes >= maxRewardBankMinutes;

  String _rewardBankKey(String userId) => 'reward_pass_bank_minutes_v1_$userId';
  String _rewardActiveUntilKey(String userId) =>
      'reward_pass_active_until_v1_$userId';

  Future<void> setRewardUser(String? userId) async {
    final normalized = userId?.trim();
    if (normalized == _rewardUserId) return;

    _rewardPassExpiryTimer?.cancel();
    _rewardPassExpiryTimer = null;
    _rewardUserId = normalized;
    _rewardBankMinutes = 0;
    _rewardPassActiveUntil = null;

    if (normalized == null || normalized.isEmpty) {
      _notifyRewardPassChanged();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _rewardBankMinutes = prefs.getInt(_rewardBankKey(normalized)) ?? 0;
    _rewardBankMinutes = _rewardBankMinutes.clamp(0, maxRewardBankMinutes);

    final activeUntilMs = prefs.getInt(_rewardActiveUntilKey(normalized));
    if (activeUntilMs != null && activeUntilMs > 0) {
      final candidate = DateTime.fromMillisecondsSinceEpoch(activeUntilMs);
      if (candidate.isAfter(DateTime.now())) {
        _rewardPassActiveUntil = candidate;
        _scheduleRewardPassExpiry();
      } else {
        await prefs.remove(_rewardActiveUntilKey(normalized));
      }
    }

    _notifyRewardPassChanged();
  }

  Future<int> addRewardMinutes({
    int minutes = rewardMinutesPerVideo,
  }) async {
    final userId = _rewardUserId;
    if (userId == null || userId.isEmpty || minutes <= 0) return 0;

    final before = _rewardBankMinutes;
    _rewardBankMinutes = (_rewardBankMinutes + minutes)
        .clamp(0, maxRewardBankMinutes);
    final added = _rewardBankMinutes - before;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_rewardBankKey(userId), _rewardBankMinutes);
    _notifyRewardPassChanged();
    return added;
  }

  Future<bool> activateRewardPass() async {
    final userId = _rewardUserId;
    if (userId == null ||
        userId.isEmpty ||
        _rewardBankMinutes <= 0 ||
        isRewardPassActive) {
      return false;
    }

    final minutesToActivate = _rewardBankMinutes;
    _rewardBankMinutes = 0;
    _rewardPassActiveUntil =
        DateTime.now().add(Duration(minutes: minutesToActivate));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_rewardBankKey(userId), 0);
    await prefs.setInt(
      _rewardActiveUntilKey(userId),
      _rewardPassActiveUntil!.millisecondsSinceEpoch,
    );

    _scheduleRewardPassExpiry();
    _notifyRewardPassChanged();
    return true;
  }

  Future<void> _expireRewardPassIfNeeded() async {
    final userId = _rewardUserId;
    if (userId == null || userId.isEmpty || isRewardPassActive) return;

    if (_rewardPassActiveUntil != null) {
      _rewardPassActiveUntil = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rewardActiveUntilKey(userId));
      _notifyRewardPassChanged();
    }
  }

  void _scheduleRewardPassExpiry() {
    _rewardPassExpiryTimer?.cancel();
    final until = _rewardPassActiveUntil;
    if (until == null) return;

    final delay = until.difference(DateTime.now());
    if (delay <= Duration.zero) {
      unawaited(_expireRewardPassIfNeeded());
      return;
    }

    _rewardPassExpiryTimer = Timer(delay, () {
      unawaited(_expireRewardPassIfNeeded());
    });
  }

  void _notifyRewardPassChanged() {
    rewardPassRevision.value++;
  }

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
  bool _appOpenEligible = false;
  bool _appOpenShownThisSession = false;

  // 📐 Reglas de Oro configuradas
  static const Duration _sessionGracePeriod = Duration(seconds: 60); // Primeros 60s protegidos
  static const Duration _minIntervalBetweenInterstitials = Duration(minutes: 2); // 2 min cooldown
  static const int _maxInterstitialsPerSession = 2; // Máximo 2 por sesión
  static const int _actionsThreshold = 3; // Cada 3 acciones de valor
  static const Duration _sessionResetAfterBackground = Duration(hours: 1);
  // App Open debe sentirse ocasional, no como un castigo por cambiar de app.
  // Sólo se considera tras una ausencia real y con un cooldown amplio.
  static const Duration _appOpenMinBackground = Duration(minutes: 15);
  static const Duration _appOpenCooldown = Duration(hours: 4);
  static const Duration _minGapBetweenFullScreenAds = Duration(minutes: 10);
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

  /// Habilita/deshabilita App Open según el estado real de navegación.
  /// Se mantiene deshabilitado durante Splash, Welcome, Login, registro y onboarding.
  void setAppOpenEligibility(bool enabled) {
    _appOpenEligible = enabled;
    if (!enabled) {
      _backgroundedAt = null;
    }
  }

  void onAppBackgrounded() {
    // Un Rewarded/Interstitial/AppOpen también pausa la Activity de Android.
    // Esa pausa NO debe contarse como si el usuario hubiera abandonado Eterlotto.
    if (_isFullScreenAdShowing || !_appOpenEligible) return;
    _backgroundedAt ??= DateTime.now();
  }

  /// Se llama al volver al primer plano. No muestra App Open en el cold start.
  /// En producción exige una ausencia real (15 min), un cooldown amplio (4 h)
  /// y como máximo un App Open por sesión.
  void onAppForegrounded({bool isPremium = false}) {
    final now = DateTime.now();

    if (!_hasCompletedColdStart) {
      _hasCompletedColdStart = true;
      _backgroundedAt = null;
      loadAppOpenAd();
      return;
    }

    // Nunca mostramos App Open antes de que el usuario haya entrado realmente
    // a la experiencia autenticada (Home y pantallas derivadas).
    if (!_appOpenEligible) {
      _backgroundedAt = null;
      return;
    }

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) return;

    final backgroundDuration = now.difference(backgroundedAt);
    if (backgroundDuration >= _sessionResetAfterBackground) {
      _resetSession(now);
    }

    // En pruebas sigue siendo más corto que producción, pero suficientemente
    // largo para evitar un anuncio cada vez que el tester cambia de app.
    final minBackground = isTestMode
        ? const Duration(minutes: 2)
        : _appOpenMinBackground;
    if (backgroundDuration < minBackground) return;

    showAppOpenAdIfAvailable(isPremium: isPremium);
  }

  void _resetSession(DateTime now) {
    _sessionStartTime = now;
    _sessionInterstitialShownCount = 0;
    _actionCounter = 0;
    _lastInterstitialShownAt = null;
    _appOpenShownThisSession = false;
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
    if (!_appOpenEligible ||
        _appOpenShownThisSession ||
        isPremium ||
        isRewardPassActive ||
        !_isInitialized ||
        !_canShowAnotherFullScreenAd()) {
      return false;
    }

    final now = DateTime.now();
    final lastShown = _lastAppOpenShownAt;
    final cooldown = isTestMode
        ? const Duration(minutes: 30)
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
    _appOpenShownThisSession = true;

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
    if (isPremium || isRewardPassActive) {
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
    if (isPremium || isRewardPassActive || !_canShowAnotherFullScreenAd()) {
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
    if (isRewardPassActive) return true;

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
    // VIP y Pase de recompensa activo acceden sin ver otro anuncio.
    if (isPremium ||
        isRewardPassActive ||
        (featureKey != null && isFeatureUnlocked(featureKey))) {
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
                  color: AppColors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.card_giftcard_rounded,
                      color: AppColors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _rewardLocalized(
                          context,
                          es:
                              'Al completar el video sumarás $rewardMinutesPerVideo min a tu Pase de recompensa.',
                          en:
                              'Completing the video adds $rewardMinutesPerVideo min to your Reward Pass.',
                          fr:
                              'Terminer la vidéo ajoute $rewardMinutesPerVideo min à votre Pass récompense.',
                          pt:
                              'Ao concluir o vídeo, você adiciona $rewardMinutesPerVideo min ao seu Passe de recompensa.',
                        ),
                        style: GoogleFonts.montserrat(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
        onAdDismissedFullScreenContent: (ad) async {
          ad.dispose();
          _rewardedAd = null;
          _markFullScreenClosed();
          loadRewardedAd();
          if (userEarnedReward) {
            final added = await addRewardMinutes();
            onRewardGranted();

            if (context.mounted && added > 0) {
              final total = rewardBankMinutes;
              final message = _rewardLocalized(
                context,
                es:
                    '🎁 +$added min. Tienes $total min acumulados para activar.',
                en:
                    '🎁 +$added min. You have $total min saved to activate.',
                fr:
                    '🎁 +$added min. Vous avez $total min accumulées à activer.',
                pt:
                    '🎁 +$added min. Você tem $total min acumulados para ativar.',
              );
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text(message)),
              );
            }
          } else if (context.mounted) {
            final langCode = Localizations.localeOf(context).languageCode;
            final message = langCode == 'en'
                ? 'Complete the video to unlock this feature.'
                : (langCode == 'fr'
                      ? 'Terminez la vidéo pour déverrouiller cette fonction.'
                      : (langCode == 'pt'
                            ? 'Conclua o vídeo para desbloquear esta função.'
                            : 'Completa el video para desbloquear esta función.'));
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
                : (langCode == 'fr'
                      ? 'La vidéo n’a pas pu être affichée. Réessayez.'
                      : (langCode == 'pt'
                            ? 'Não foi possível exibir o vídeo. Tente novamente.'
                            : 'No se pudo mostrar el video. Inténtalo nuevamente.'));
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
            : (langCode == 'fr'
                  ? 'Aucune vidéo n’est disponible pour le moment. Réessayez dans quelques instants.'
                  : (langCode == 'pt'
                        ? 'Nenhum vídeo está disponível agora. Tente novamente em instantes.'
                        : 'No hay video disponible en este momento. Inténtalo de nuevo en unos instantes.'));
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  /// Muestra un Rewarded desde el regalo del Home y suma 15 minutos al saldo.
  Future<void> showRewardedForPass({
    required BuildContext context,
  }) async {
    if (isRewardPassActive) return;

    if (isRewardBankFull) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Ya alcanzaste el máximo de 2 horas acumuladas.'),
          ),
        );
      }
      return;
    }

    if (_rewardedAd == null) {
      loadRewardedAd();
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              _rewardLocalized(
                context,
                es:
                    'No hay video disponible en este momento. Inténtalo nuevamente.',
                en: 'No video is available right now. Please try again.',
                fr:
                    'Aucune vidéo n’est disponible pour le moment. Réessayez.',
                pt:
                    'Nenhum vídeo está disponível no momento. Tente novamente.',
              ),
            ),
          ),
        );
      }
      return;
    }

    if (!_canShowAnotherFullScreenAd()) return;

    bool userEarnedReward = false;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _isFullScreenAdShowing = true;
      },
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _rewardedAd = null;
        _markFullScreenClosed();
        loadRewardedAd();

        if (userEarnedReward) {
          final added = await addRewardMinutes();
          if (context.mounted) {
            final total = rewardBankMinutes;
            final message = added > 0
                ? _rewardLocalized(
                    context,
                    es: '🎁 +$added min. Saldo acumulado: $total min.',
                    en: '🎁 +$added min. Saved balance: $total min.',
                    fr: '🎁 +$added min. Solde accumulé : $total min.',
                    pt: '🎁 +$added min. Saldo acumulado: $total min.',
                  )
                : _rewardLocalized(
                    context,
                    es: 'Ya alcanzaste el máximo de 2 horas acumuladas.',
                    en: 'You have reached the 2-hour maximum balance.',
                    fr: 'Vous avez atteint le maximum de 2 heures accumulées.',
                    pt: 'Você atingiu o máximo de 2 horas acumuladas.',
                  );
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        } else if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                _rewardLocalized(
                  context,
                  es: 'Completa el video para recibir los 15 minutos.',
                  en: 'Complete the video to receive the 15 minutes.',
                  fr: 'Terminez la vidéo pour recevoir les 15 minutes.',
                  pt: 'Conclua o vídeo para receber os 15 minutos.',
                ),
              ),
            ),
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        _markFullScreenClosed();
        loadRewardedAd();
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                _rewardLocalized(
                  context,
                  es: 'No se pudo mostrar el video. Inténtalo nuevamente.',
                  en: 'The video could not be shown. Please try again.',
                  fr: 'La vidéo n’a pas pu être affichée. Réessayez.',
                  pt: 'Não foi possível exibir o vídeo. Tente novamente.',
                ),
              ),
            ),
          );
        }
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (_, __) {
        userEarnedReward = true;
      },
    );
  }

  /// Liberar recursos
  void dispose() {
    _rewardPassExpiryTimer?.cancel();
    _rewardPassExpiryTimer = null;
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
