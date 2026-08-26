import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ⚙️ Configuración: true para desarrollo/pruebas, false cuando pongas tus IDs reales
  static const bool isTestMode = true;

  // 🔹 IDs de Producción (Reemplazar cuando crees los bloques en Google AdMob)
  static const String _prodAndroidBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodAndroidInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodIosBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodIosInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // 🧪 IDs Oficiales de Prueba de Google
  static const String _testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testIosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

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

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  DateTime? _lastInterstitialShownAt;
  VoidCallback? _currentOnClosedCallback;

  // Intervalo mínimo entre anuncios intersticiales (para no saturar al usuario)
  static const Duration _minIntervalBetweenInterstitials = Duration(minutes: 2);

  /// Inicializar el SDK de Mobile Ads
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final status = await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('✅ Google Mobile Ads inicializado con éxito: ${status.adapterStatuses}');
      // Precargar primer anuncio intersticial
      loadInterstitialAd();
    } catch (e) {
      debugPrint('❌ Error al inicializar Google Mobile Ads: $e');
    }
  }

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
              
              // Ejecutar la acción pendiente (ej: navegar a la pantalla)
              final callback = _currentOnClosedCallback;
              _currentOnClosedCallback = null;
              callback?.call();

              // Precargar el siguiente anuncio
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Error al mostrar Interstitial Ad: $error');
              ad.dispose();
              _interstitialAd = null;

              // Si falla al mostrar, ejecutar la acción pendiente inmediatamente
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

  /// Mostrar anuncio intersticial respetando frecuencia y estado premium
  /// Retorna `true` si el anuncio se mostró (y ejecutará `onAdClosed` cuando el usuario lo cierre),
  /// o `false` si no se mostró (en cuyo caso debes ejecutar la acción de inmediato).
  bool showInterstitialAd({bool isPremium = false, VoidCallback? onAdClosed}) {
    if (isPremium) {
      debugPrint('⭐ Usuario Premium: Anuncio omitido');
      onAdClosed?.call();
      return false;
    }

    // Comprobar limitador de frecuencia
    if (_lastInterstitialShownAt != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialShownAt!);
      if (elapsed < _minIntervalBetweenInterstitials) {
        debugPrint('⏳ Intersticial omitido por frecuencia (${elapsed.inSeconds}s < ${_minIntervalBetweenInterstitials.inSeconds}s)');
        onAdClosed?.call();
        return false;
      }
    }

    if (_interstitialAd != null) {
      _currentOnClosedCallback = onAdClosed;
      _interstitialAd!.show();
      return true;
    } else {
      debugPrint('⚠️ Interstitial no disponible en este momento');
      loadInterstitialAd();
      onAdClosed?.call();
      return false;
    }
  }

  /// Liberar recursos
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _currentOnClosedCallback = null;
  }
}
