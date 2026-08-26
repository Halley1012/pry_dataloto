import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../styles/colores.dart';
import '../screens/subscription_screen.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ⚙️ Configuración: true para desarrollo/pruebas, false cuando pongas tus IDs reales
  static const bool isTestMode = true;

  // 🔹 IDs de Producción (Reemplazar cuando crees los bloques en Google AdMob)
  static const String _prodAndroidBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodAndroidInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodAndroidRewardedId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodIosBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodIosInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodIosRewardedId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // 🧪 IDs Oficiales de Prueba de Google
  static const String _testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testAndroidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testIosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testIosRewardedId = 'ca-app-pub-3940256099942544/1712485313';

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

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // 🛡️ Variables de Control de Sesión y Reglas de Oro
  DateTime _sessionStartTime = DateTime.now();
  Duration get sessionDuration => DateTime.now().difference(_sessionStartTime);
  int _sessionInterstitialShownCount = 0;
  int _actionCounter = 0;
  DateTime? _lastInterstitialShownAt;

  // 📐 Reglas de Oro configuradas
  static const Duration _sessionGracePeriod = Duration(seconds: 60); // Primeros 60s protegidos
  static const Duration _minIntervalBetweenInterstitials = Duration(minutes: 2); // 2 min cooldown
  static const int _maxInterstitialsPerSession = 2; // Máximo 2 por sesión
  static const int _actionsThreshold = 3; // Cada 3 acciones de valor

  // Instancias de Anuncios
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  VoidCallback? _currentOnClosedCallback;

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  /// Inicializar el SDK de Mobile Ads
  Future<void> initialize() async {
    _sessionStartTime = DateTime.now();
    _sessionInterstitialShownCount = 0;
    _actionCounter = 0;
    _lastInterstitialShownAt = null;

    if (_isInitialized) return;
    try {
      final status = await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('✅ Google Mobile Ads inicializado con éxito: ${status.adapterStatuses}');
      // Precargar anuncios
      loadInterstitialAd();
      loadRewardedAd();
    } catch (e) {
      debugPrint('❌ Error al inicializar Google Mobile Ads: $e');
    }
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
          debugPrint('🎯 Interstitial Ad cargado y listo para mostrar');

          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              debugPrint('📺 Interstitial Ad mostrado en pantalla completa');
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('❎ Interstitial Ad cerrado por el usuario');
              ad.dispose();
              _interstitialAd = null;
              _lastInterstitialShownAt = DateTime.now();
              _sessionInterstitialShownCount++;
              
              final callback = _currentOnClosedCallback;
              _currentOnClosedCallback = null;
              callback?.call();

              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Error al mostrar Interstitial Ad: $error');
              ad.dispose();
              _interstitialAd = null;

              final callback = _currentOnClosedCallback;
              _currentOnClosedCallback = null;
              callback?.call();

              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          _interstitialAd = null;
          debugPrint('❌ Falló la carga del Interstitial Ad: $error');
        },
      ),
    );
  }

  /// Mostrar anuncio intersticial respetando todas las Reglas de Oro UX
  bool showInterstitialAd({bool isPremium = false, VoidCallback? onAdClosed}) {
    if (isPremium) {
      debugPrint('⭐ [AdMob UX] Usuario VIP: Anuncio omitido');
      onAdClosed?.call();
      return false;
    }

    // 1. Regla: Periodo de gracia inicial (primeros 60 segundos)
    final sessionDuration = DateTime.now().difference(_sessionStartTime);
    if (sessionDuration < _sessionGracePeriod) {
      final remaining = _sessionGracePeriod.inSeconds - sessionDuration.inSeconds;
      debugPrint('🛡️ [AdMob UX Regla 1] Omitido por Periodo de Gracia Inicial: ${sessionDuration.inSeconds}s transcurridos (quedan ${remaining}s protegidos)');
      onAdClosed?.call();
      return false;
    }

    // 2. Regla: Límite máximo por sesión (máximo 2)
    if (_sessionInterstitialShownCount >= _maxInterstitialsPerSession) {
      debugPrint('🛑 [AdMob UX Regla 2] Omitido por Límite de Sesión: Ya se mostraron $_sessionInterstitialShownCount/$_maxInterstitialsPerSession anuncios.');
      onAdClosed?.call();
      return false;
    }

    // 3. Regla: Contador de acciones de valor (cada 3 acciones)
    _actionCounter++;
    if (_actionCounter % _actionsThreshold != 0) {
      final needed = _actionsThreshold - (_actionCounter % _actionsThreshold);
      debugPrint('🎯 [AdMob UX Regla 3] Omitido por Umbral de Acciones: Acción $_actionCounter (faltan $needed para evaluar anuncio)');
      onAdClosed?.call();
      return false;
    }

    // 4. Regla: Cooldown entre anuncios (mínimo 2 minutos)
    if (_lastInterstitialShownAt != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialShownAt!);
      if (elapsed < _minIntervalBetweenInterstitials) {
        final remaining = _minIntervalBetweenInterstitials.inSeconds - elapsed.inSeconds;
        debugPrint('⏳ [AdMob UX Regla 4] Omitido por Cooldown: ${elapsed.inSeconds}s desde el último (faltan ${remaining}s de enfriamiento)');
        onAdClosed?.call();
        return false;
      }
    }

    if (_interstitialAd != null) {
      debugPrint('🚀 [AdMob UX] ¡Todas las reglas cumplidas! Mostrando Interstitial Ad...');
      _currentOnClosedCallback = onAdClosed;
      _interstitialAd!.show();
      return true;
    } else {
      debugPrint('⚠️ [AdMob UX] Anuncio no precargado en este instante; continuando sin retrasar al usuario.');
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
    debugPrint('🔓 [AdMob UX] Función "$featureKey" desbloqueada durante ${duration.inMinutes} minutos.');
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
          debugPrint('🎁 Rewarded Ad cargado y listo');
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoading = false;
          _rewardedAd = null;
          debugPrint('❌ Falló la carga del Rewarded Ad: $error');
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
      if (featureKey != null && isFeatureUnlocked(featureKey)) {
        debugPrint('⚡ [AdMob UX] Función "$featureKey" ya está desbloqueada. Acceso directo concedido.');
      }
      onRewardGranted();
      return;
    }

    // Mostrar diálogo explicativo al usuario
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                      "Los usuarios VIP disfrutan de esta y todas las funciones sin ver anuncios.",
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
              "Cancelar",
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
              "Hacerme VIP 💎",
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
              "Ver Video",
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
      ),
    );

    if (proceed != true) return;

    // Ejecutar el anuncio recompensado
    if (_rewardedAd != null) {
      bool userEarnedReward = false;

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd();
          if (userEarnedReward) {
            if (featureKey != null) {
              unlockFeature(featureKey, duration: unlockDuration);
            }
            onRewardGranted();
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd();
          // En caso de error, permitir que el usuario continúe y desbloquear
          if (featureKey != null) {
            unlockFeature(featureKey, duration: unlockDuration);
          }
          onRewardGranted();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('🎉 Recompensa otorgada: ${reward.amount} ${reward.type}');
          userEarnedReward = true;
        },
      );
    } else {
      // Si el anuncio no está disponible (ej. sin internet o sin fill), otorgar acceso por cortesía
      debugPrint('ℹ️ Rewarded no disponible, otorgando acceso por cortesía.');
      loadRewardedAd();
      if (featureKey != null) {
        unlockFeature(featureKey, duration: unlockDuration);
      }
      onRewardGranted();
    }
  }

  /// Liberar recursos
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _currentOnClosedCallback = null;
  }
}
