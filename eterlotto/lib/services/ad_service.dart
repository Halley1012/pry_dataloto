import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import '../styles/colores.dart';
import '../screens/subscription_screen.dart';
import '../utils/secure_storage_helper.dart';
import 'reward_backend_service.dart';
import 'reward_verification.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();


  // ⚙️ Configuración: 'true' para Internal Testing / Desarrollo. Cambiar a 'false' SÓLO al enviar a Producción real.
  static const bool _forceTestAds = bool.fromEnvironment(
    'ADS_USE_TEST_IDS',
    defaultValue: false,
  );

  // Debug siempre usa IDs oficiales de prueba.
  // Release usa AdMob real salvo que se compile con:
  // --dart-define=ADS_USE_TEST_IDS=true
  static bool get isTestMode => kDebugMode || _forceTestAds;

  // DEV SSV: a unit owned by this app, requested ONLY on registered test devices.
  // Shared Google demo units have no callback URL configurable for our server.
  static const String _ssvDevAdUnitId = String.fromEnvironment(
    'REWARDS_SSV_DEV_AD_UNIT_ID', defaultValue: '',
  );
  static const String _adMobTestDeviceIds = String.fromEnvironment(
    'ADMOB_TEST_DEVICE_IDS', defaultValue: '',
  );
  static List<String> get _testDeviceIds => _adMobTestDeviceIds.split(',')
      .map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
  static bool get _useSsvDevAdUnit => useBackendRewards &&
      _ssvDevAdUnitId.trim().isNotEmpty && _testDeviceIds.isNotEmpty;
  static bool get backendUsesDemoAds => rewardedAdUnitId
      .startsWith('ca-app-pub-3940256099942544/');

  // 🛡️ Simulación GDPR europea ÚNICAMENTE para compilaciones de prueba.
  // No se habilita en un release normal, aunque alguien configure UMP_DEBUG_EEA.
  // El hash UMP no es el identificador de ADB ni el ID de prueba de AdMob.
  static const bool _umpDebugEea = bool.fromEnvironment(
    'UMP_DEBUG_EEA',
    defaultValue: false,
  );
  static const String _umpTestDeviceId = String.fromEnvironment(
    'UMP_TEST_DEVICE_ID',
    defaultValue: '',
  );
  static const bool _umpResetConsent = bool.fromEnvironment(
    'UMP_RESET_CONSENT',
    defaultValue: false,
  );

  static bool get _isUmpEeaTestEnabled =>
      isTestMode && _umpDebugEea && _umpTestDeviceId.trim().isNotEmpty;

  // 🔹 IDs de Producción (Reemplazar cuando crees los bloques en Google AdMob)
  static const String _prodAndroidBannerId = 'ca-app-pub-9637733995937134/9568888277';
  static const String _prodAndroidInterstitialId = 'ca-app-pub-9637733995937134/1039661568';
  static const String _prodAndroidRewardedId = 'ca-app-pub-9637733995937134/4124989907';
  static const String _prodAndroidAppOpenId = 'ca-app-pub-9637733995937134/6920517519';
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
    if (useBackendRewards) {
      if (_useSsvDevAdUnit) return _ssvDevAdUnitId.trim();
      return Platform.isAndroid ? _testAndroidRewardedId : _testIosRewardedId;
    }
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
  bool _canRequestAds = false;
  // La solicitud de consentimiento ocurre una sola vez por ejecución,
  // incluso si el Home se vuelve a crear tras navegar o iniciar sesión.
  Future<void>? _initializationFuture;
  bool get isInitialized => _isInitialized;
  bool get canRequestAds => _isInitialized && _canRequestAds;

  // El Banner escucha este notifier para cargarse sólo cuando UMP ya permite
  // solicitar anuncios.
  final ValueNotifier<int> adsReadyRevision = ValueNotifier<int>(0);

  Future<bool> _requestConsentAndCheckAdsPermission() async {
    final completer = Completer<void>();
    bool hadConsentError = false;

    // En pruebas: simula EEE sólo en un dispositivo registrado en UMP.
    // UMP decide el idioma de su formulario según el idioma del DISPOSITIVO;
    // los textos de Eterlotto mantienen AppLocalizations (ES/EN/FR/PT).
    // En producción se conserva ConsentRequestParameters sin depuración.
    if (_isUmpEeaTestEnabled && _umpResetConsent) {
      // Simula una primera apertura; jamás se ejecuta en un release normal.
      await ConsentInformation.instance.reset();
    }

    final params = ConsentRequestParameters(
      consentDebugSettings: _isUmpEeaTestEnabled
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
              testIdentifiers: <String>[_umpTestDeviceId.trim()],
            )
          : null,
    );

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              hadConsentError = true;
            }
            if (!completer.isCompleted) {
              completer.complete();
            }
          });
        },
        (formError) {
          // Si no hay mensaje GDPR configurado en AdMob Console o hay un fallo
          // de red temporal en UMP, canRequestAds() devuelve false en una
          // instalación limpia aunque el usuario no esté sujeto a GDPR.
          hadConsentError = true;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          hadConsentError = true;
        },
      );
    } catch (_) {
      hadConsentError = true;
    }

    try {
      final canRequest = await ConsentInformation.instance.canRequestAds();
      if (canRequest) return true;

      final status = await ConsentInformation.instance.getConsentStatus();
      // Si UMP falló por configuración/red o el consentimiento no es requerido
      // en la región del usuario, permitimos inicializar AdMob normalmente.
      if (hadConsentError || status != ConsentStatus.required) {
        return true;
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<bool> isPrivacyOptionsRequired() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  Future<void> showPrivacyOptionsForm() async {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((formError) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;
  }

  // ==========================================
  // 🎁 PASE DE RECOMPENSA GLOBAL
  // ==========================================
  // Cada Rewarded completado suma 5 minutos.
  // Máximo diario: 60 minutos. El saldo no activado se reinicia
  // al cambiar de día; un pase ya activado puede terminar normalmente.
  static const int rewardMinutesPerVideo = 5;
  static const int maxRewardMinutesPerDay = 60;
  static const int maxRewardBankMinutes = 60;

  // Integración aislada: solo DEV con --dart-define=REWARDS_BACKEND_ENABLED=true.
  // Sin esa opción, el código y los anuncios publicados siguen intactos.
  static bool get useBackendRewards => RewardBackendService.enabled;
  RewardBackendStatus? _backendRewardStatus;
  String? _backendRewardIdentity;
  DateTime? _backendRewardStatusAt;
  Future<bool>? _backendStatusFuture;
  int _rewardAccountRevision = 0;
  bool _backendRewardPreparing = false;
  RewardBackendStatus? get backendRewardStatus => _backendRewardStatus;
  int get backendVideosCompleted => _backendRewardStatus?.videosCompleted ?? 0;
  int get backendVideosRequired => _backendRewardStatus?.videosRequired ?? 7;
  int get backendPassesAvailable => _backendRewardStatus?.passesAvailable ?? 0;
  DateTime? get backendChallengeExpiresAt => _backendRewardStatus?.challengeExpiresAt;

  Future<bool> refreshBackendRewardStatus({bool force = false}) {
    if (!useBackendRewards) return Future.value(false);
    final inFlight = _backendStatusFuture;
    if (inFlight != null) return inFlight;
    final updatedAt = _backendRewardStatusAt;
    if (!force && _backendRewardStatus != null && updatedAt != null &&
        DateTime.now().difference(updatedAt) < const Duration(seconds: 15)) {
      return Future.value(true);
    }
    final request = _fetchBackendRewardStatus();
    _backendStatusFuture = request;
    unawaited(request.whenComplete(() {
      if (identical(_backendStatusFuture, request)) _backendStatusFuture = null;
    }));
    return request;
  }

  Future<bool> _fetchBackendRewardStatus() async {
    if (!useBackendRewards) return false;
    final identity = _rewardUserId;
    final accountRevision = _rewardAccountRevision;
    // Evita publicar una respuesta de una cuenta después de un logout/login.
    if (identity == null || int.tryParse(identity) == null) return false;
    try {
      final status = await RewardBackendService.getStatus();
      if (_rewardUserId != identity || _rewardAccountRevision != accountRevision) return false;
      _backendRewardStatus = status;
      _backendRewardIdentity = identity;
      _backendRewardStatusAt = DateTime.now();
      _rewardPassExpiryTimer?.cancel();
      _rewardPassExpiryTimer = status.passActive ? Timer(status.remaining, () {
        _notifyRewardPassChanged();
        unawaited(refreshBackendRewardStatus(force: true));
      }) : null;
      _notifyRewardPassChanged();
      return true;
    } catch (e) {
      debugPrint('[REWARDS] status DEV falló: $e');
      return false;
    }
  }

  final ValueNotifier<int> rewardPassRevision = ValueNotifier<int>(0);
  static const String _lastRewardUserStorageKey = 'reward_pass_last_user_id_v1';
  String? _rewardUserId;
  int _rewardBankMinutes = 0;
  int _rewardEarnedTodayMinutes = 0;
  String? _rewardDay;
  DateTime? _rewardPassActiveUntil;
  Timer? _rewardPassExpiryTimer;
  Future<void>? _setRewardUserFuture;

  bool get _isRewardDayCurrent => _rewardDay == _currentRewardDay();

  int get rewardBankMinutes =>
      _isRewardDayCurrent ? _rewardBankMinutes : 0;

  int get rewardEarnedTodayMinutes =>
      _isRewardDayCurrent ? _rewardEarnedTodayMinutes : 0;

  int get rewardRemainingTodayMinutes =>
      (maxRewardMinutesPerDay - rewardEarnedTodayMinutes)
          .clamp(0, maxRewardMinutesPerDay)
          .toInt();

  bool get isRewardPassActive {
    if (useBackendRewards) return _backendRewardStatus?.passActive ?? false;
    final until = _rewardPassActiveUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  Duration get rewardPassRemaining {
    if (useBackendRewards) return _backendRewardStatus?.remaining ?? Duration.zero;
    final until = _rewardPassActiveUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get hasRewardBalance => rewardBankMinutes > 0;
  bool get isRewardBankFull =>
      rewardBankMinutes >= maxRewardBankMinutes ||
      rewardEarnedTodayMinutes >= maxRewardMinutesPerDay;

  String _rewardBankKey(String userId) => 'reward_pass_bank_minutes_v1_$userId';
  String _rewardActiveUntilKey(String userId) =>
      'reward_pass_active_until_v1_$userId';
  String _rewardDayKey(String userId) => 'reward_pass_day_v2_$userId';
  String _rewardEarnedTodayKey(String userId) =>
      'reward_pass_earned_today_v2_$userId';

  String? _normalizeRewardUserId(String? userId) {
    final trimmed = userId?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed.toLowerCase() == 'null') {
      return null;
    }
    return trimmed;
  }

  String _currentRewardDay() {
    final now = DateTime.now().toLocal();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _ensureRewardDayCurrent() async {
    final userId = _rewardUserId;
    if (userId == null || userId.isEmpty) return;

    final today = _currentRewardDay();
    if (_rewardDay == today) return;

    final prefs = await SharedPreferences.getInstance();
    final storedDay = prefs.getString(_rewardDayKey(userId));
    if (storedDay == today) {
      // Si _rewardDay estaba en null por una lectura en curso pero el disco ya
      // pertenece a hoy, restauramos el saldo guardado sin reiniciarlo a 0.
      _rewardDay = today;
      _rewardBankMinutes = (prefs.getInt(_rewardBankKey(userId)) ?? 0)
          .clamp(0, maxRewardBankMinutes)
          .toInt();
      _rewardEarnedTodayMinutes =
          (prefs.getInt(_rewardEarnedTodayKey(userId)) ?? _rewardBankMinutes)
              .clamp(0, maxRewardMinutesPerDay)
              .toInt();
      _notifyRewardPassChanged();
      return;
    }

    // Un saldo no activado pertenece al día en que se obtuvo.
    // El pase ya activo NO se corta al llegar medianoche.
    _rewardDay = today;
    _rewardBankMinutes = 0;
    _rewardEarnedTodayMinutes = 0;

    await prefs.setString(_rewardDayKey(userId), today);
    await prefs.setInt(_rewardEarnedTodayKey(userId), 0);
    await prefs.setInt(_rewardBankKey(userId), 0);
    _notifyRewardPassChanged();
  }

  Future<void> clearRewardUser() async {
    final previous = _setRewardUserFuture;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }
    _rewardPassExpiryTimer?.cancel();
    _rewardPassExpiryTimer = null;
    _featureAccessUntil.clear();
    _rewardUserId = null;
    _rewardAccountRevision++;
    _backendStatusFuture = null;
    _backendRewardStatusAt = null;
    _backendRewardStatus = null;
    _backendRewardIdentity = null;
    _rewardBankMinutes = 0;
    _rewardEarnedTodayMinutes = 0;
    _rewardDay = null;
    _rewardPassActiveUntil = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastRewardUserStorageKey);
    } catch (_) {}
    _notifyRewardPassChanged();
  }

  String? _extractUserIdFromJwt(String? token) {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    try {
      final parts = trimmed.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is Map) {
        final raw = payload['sub'] ?? payload['user_id'] ?? payload['id'];
        return _normalizeRewardUserId(raw?.toString());
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _resolveActiveSessionUserId(SharedPreferences prefs) async {
    final fromPrefs = _normalizeRewardUserId(
      prefs.getString(_lastRewardUserStorageKey),
    );
    if (fromPrefs != null) return fromPrefs;

    final storage = AppSecureStorage.instance;
    try {
      final storedUserId = _normalizeRewardUserId(
        await storage.read(key: 'user_id'),
      );
      if (storedUserId != null) return storedUserId;

      final authToken = await storage.read(key: 'auth_token');
      final refreshToken = await storage.read(key: 'refresh_token');
      final fromJwt = _extractUserIdFromJwt(authToken) ??
          _extractUserIdFromJwt(refreshToken);
      if (fromJwt != null) {
        await storage.write(key: 'user_id', value: fromJwt);
        return fromJwt;
      }

      final email = _normalizeRewardUserId(await storage.read(key: 'email'));
      if (email != null) return email;

      final name = _normalizeRewardUserId(await storage.read(key: 'name'));
      if (name != null) return name;

      final hasToken = (authToken != null && authToken.trim().isNotEmpty) ||
          (refreshToken != null && refreshToken.trim().isNotEmpty);
      if (hasToken) {
        return 'active_session_user';
      }
    } catch (_) {}

    final fromUsername = _normalizeRewardUserId(prefs.getString('username'));
    if (fromUsername != null) return fromUsername;

    return null;
  }

  Future<void> setRewardUser(String? userId) {
    final prev = _setRewardUserFuture;
    final next = (prev == null
            ? _setRewardUserInternal(userId)
            : prev.then((_) => _setRewardUserInternal(userId)))
        .catchError((_) {});
    _setRewardUserFuture = next;
    return next;
  }

  Future<void> _setRewardUserInternal(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    String? normalized = _normalizeRewardUserId(userId) ??
        _normalizeRewardUserId(_rewardUserId);
    // Si durante el arranque o tras onboarding aún no teníamos userId en
    // memoria, resolvemos desde SharedPreferences, SecureStorage o el JWT.
    normalized ??= await _resolveActiveSessionUserId(prefs);

    if (normalized != null) {
      try {
        await prefs.setString(_lastRewardUserStorageKey, normalized);
      } catch (_) {}
    }

    if (normalized != null &&
        normalized == _rewardUserId &&
        _rewardDay != null) {
      await _ensureRewardDayCurrent();
      if (useBackendRewards && _backendRewardStatus == null) {
        unawaited(refreshBackendRewardStatus());
      }
      return;
    }

    if (useBackendRewards && _backendRewardIdentity != normalized) {
      _rewardAccountRevision++;
      _backendStatusFuture = null;
      _backendRewardStatusAt = null;
      _backendRewardStatus = null;
      _backendRewardIdentity = normalized;
    }
    _rewardPassExpiryTimer?.cancel();
    _rewardPassExpiryTimer = null;
    _featureAccessUntil.clear();

    if (normalized == null) {
      _rewardUserId = null;
      _rewardBankMinutes = 0;
      _rewardEarnedTodayMinutes = 0;
      _rewardDay = null;
      _rewardPassActiveUntil = null;
      _notifyRewardPassChanged();
      return;
    }

    // Asignamos el usuario inmediatamente para que ningún fallo posterior de
    // lectura de preferencias deje _rewardUserId en null con sesión activa.
    final today = _currentRewardDay();
    _rewardUserId = normalized;
    _rewardDay = today;

    int storedBank = 0;
    String? storedDay;
    try {
      storedDay = prefs.getString(_rewardDayKey(normalized));
      storedBank = (prefs.getInt(_rewardBankKey(normalized)) ?? 0)
          .clamp(0, maxRewardBankMinutes)
          .toInt();
    } catch (_) {}

    int nextBank = 0;
    int nextEarned = 0;

    try {
      if (storedDay == today) {
        nextBank = storedBank;
        nextEarned =
            (prefs.getInt(_rewardEarnedTodayKey(normalized)) ?? storedBank)
                .clamp(0, maxRewardMinutesPerDay)
                .toInt();
      } else if (storedDay == null) {
        // Migración desde la versión anterior del Pase:
        // conserva como máximo 60 min y los cuenta dentro del límite de hoy.
        nextBank = storedBank;
        nextEarned = storedBank;
        await prefs.setString(_rewardDayKey(normalized), today);
        await prefs.setInt(
          _rewardEarnedTodayKey(normalized),
          nextEarned,
        );
        await prefs.setInt(_rewardBankKey(normalized), nextBank);
      } else {
        // Día nuevo: el saldo no activado anterior vence.
        nextBank = 0;
        nextEarned = 0;
        await prefs.setString(_rewardDayKey(normalized), today);
        await prefs.setInt(_rewardEarnedTodayKey(normalized), 0);
        await prefs.setInt(_rewardBankKey(normalized), 0);
      }
    } catch (_) {}

    DateTime? nextActiveUntil;
    try {
      final activeUntilMs = prefs.getInt(_rewardActiveUntilKey(normalized));
      if (activeUntilMs != null && activeUntilMs > 0) {
        final candidate = DateTime.fromMillisecondsSinceEpoch(activeUntilMs);
        if (candidate.isAfter(DateTime.now())) {
          nextActiveUntil = candidate;
        } else {
          await prefs.remove(_rewardActiveUntilKey(normalized));
        }
      }
    } catch (_) {}

    // Recuperar desbloqueos de funciones no vencidos para este usuario.
    // Copiamos la lista de claves antes de remover para evitar ConcurrentModificationError.
    try {
      final prefix = _featureAccessStoragePrefix(normalized);
      final matchingKeys =
          prefs.getKeys().where((key) => key.startsWith(prefix)).toList();
      for (final key in matchingKeys) {
        final expiryMs = prefs.getInt(key);
        if (expiryMs == null ||
            expiryMs <= DateTime.now().millisecondsSinceEpoch) {
          await prefs.remove(key);
          continue;
        }
        _featureAccessUntil[key.substring(prefix.length)] =
            DateTime.fromMillisecondsSinceEpoch(expiryMs);
      }
    } catch (_) {}

    _rewardUserId = normalized;
    _rewardDay = today;
    _rewardBankMinutes = nextBank;
    _rewardEarnedTodayMinutes = nextEarned;
    _rewardPassActiveUntil = nextActiveUntil;
    if (nextActiveUntil != null) {
      _scheduleRewardPassExpiry();
    }

    _notifyRewardPassChanged();
    if (useBackendRewards) {
      unawaited(refreshBackendRewardStatus());
    }
  }

  Future<String> _ensureAuthenticatedRewardUserId() async {
    final pendingUser = _setRewardUserFuture;
    if (pendingUser != null) {
      try {
        await pendingUser;
      } catch (_) {}
    }
    if (_rewardUserId != null && _rewardUserId!.isNotEmpty) {
      return _rewardUserId!;
    }
    await setRewardUser(null);
    if (_rewardUserId != null && _rewardUserId!.isNotEmpty) {
      return _rewardUserId!;
    }
    // Si el usuario ya está dentro de una pantalla autenticada pero el
    // almacenamiento seguro del dispositivo falló, usamos un identificador
    // de sesión local para no bloquearle las recompensas.
    await setRewardUser('active_session_user');
    return _rewardUserId ?? 'active_session_user';
  }

  Future<int> addRewardMinutes({
    int minutes = rewardMinutesPerVideo,
  }) async {
    if (minutes <= 0) return 0;
    final userId = await _ensureAuthenticatedRewardUserId();
    if (userId.isEmpty) return 0;

    await _ensureRewardDayCurrent();

    final remainingToday =
        maxRewardMinutesPerDay - _rewardEarnedTodayMinutes;
    final remainingBank = maxRewardBankMinutes - _rewardBankMinutes;

    if (remainingToday <= 0 || remainingBank <= 0) return 0;

    var added = minutes;
    if (added > remainingToday) added = remainingToday;
    if (added > remainingBank) added = remainingBank;

    _rewardBankMinutes += added;
    _rewardEarnedTodayMinutes += added;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rewardDayKey(userId), _currentRewardDay());
    await prefs.setInt(_rewardBankKey(userId), _rewardBankMinutes);
    await prefs.setInt(
      _rewardEarnedTodayKey(userId),
      _rewardEarnedTodayMinutes,
    );
    _notifyRewardPassChanged();
    return added;
  }

  Future<bool> activateRewardPass() async {
    if (useBackendRewards) {
      try {
        await RewardBackendService.activatePass();
        // Finish any earlier read, then fetch the result of this mutation.
        await _backendStatusFuture;
        return await refreshBackendRewardStatus(force: true);
      } catch (e) {
        debugPrint('[REWARDS] activate DEV: $e');
        return false;
      }
    }
    final userId = await _ensureAuthenticatedRewardUserId();
    if (userId.isEmpty ||
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

  /// Inicializa privacidad + Google Mobile Ads una vez por ejecución.
  /// Nunca solicita anuncios antes de que UMP lo permita.
  Future<void> initialize() {
    if (_isInitialized && _canRequestAds && _initializationFuture != null) {
      return _initializationFuture!;
    }
    final inFlight = _initializationFuture;
    if (inFlight != null) return inFlight;

    final future = _initializeOnce();
    _initializationFuture = future;
    return future.whenComplete(() {
      if (!_isInitialized || !_canRequestAds) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initializeOnce() async {
    _sessionStartTime = DateTime.now();
    _sessionInterstitialShownCount = 0;
    _actionCounter = 0;
    _lastInterstitialShownAt = null;

    if (_isInitialized && _canRequestAds) return;

    if (_useSsvDevAdUnit) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: _testDeviceIds),
      );
    }

    try {
      _canRequestAds = await _requestConsentAndCheckAdsPermission();

      if (!_canRequestAds) {
        adsReadyRevision.value++;
        return;
      }

      if (!_isInitialized) {
        await MobileAds.instance.initialize();
        _isInitialized = true;
      }

      adsReadyRevision.value++;

      // Precargar anuncios sólo cuando ya se pueden solicitar.
      loadInterstitialAd();
      loadRewardedAd();
      loadAppOpenAd();
    } catch (_) {
      try {
        if (!_isInitialized) {
          await MobileAds.instance.initialize();
          _isInitialized = true;
        }
        _canRequestAds = true;
        adsReadyRevision.value++;
        loadInterstitialAd();
        loadRewardedAd();
        loadAppOpenAd();
      } catch (_) {
        _canRequestAds = false;
        adsReadyRevision.value++;
      }
    }
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
    if (!canRequestAds || _appOpenAd != null || _isAppOpenLoading) return;
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
    if (!canRequestAds) return;
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

  // Cada vídeo suma cinco minutos al banco. Una acción protegida también
  // obtiene cinco minutos para esa función, sin activar el pase global.
  bool _rewardedGateDialogOpen = false;

  // El vídeo de una función NO activa el pase global: suma saldo y habilita
  // únicamente esa función durante 5 minutos. Esto evita exigir otro vídeo
  // nada más regresar a la misma pantalla, sin regalar dos horas de acceso.
  static const Duration _featureAccessDuration = Duration(minutes: 5);
  final Map<String, DateTime> _featureAccessUntil = <String, DateTime>{};

  String _featureAccessStoragePrefix(String userId) =>
      'reward_feature_until_v1_${userId}_';

  bool isFeatureUnlocked(String featureKey) {
    if (useBackendRewards) {
      return _backendRewardStatus?.isFeatureUnlocked(featureKey) ?? false;
    }
    if (isRewardPassActive) return true;
    final until = _featureAccessUntil[featureKey];
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _featureAccessUntil.remove(featureKey);
    return false;
  }

  Future<void> _grantFeatureAccess(String? featureKey) async {
    if (featureKey == null || featureKey.isEmpty) return;
    final userId = await _ensureAuthenticatedRewardUserId();
    if (userId.isEmpty) return;
    final until = DateTime.now().add(_featureAccessDuration);
    _featureAccessUntil[featureKey] = until;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        '${_featureAccessStoragePrefix(userId)}$featureKey',
        until.millisecondsSinceEpoch,
      );
    } catch (error) {
      debugPrint('[ADS] No se pudo conservar el acceso a la función: $error');
    }
  }

  Completer<RewardedAd?>? _rewardedLoadCompleter;
  Timer? _rewardedRetryTimer;

  /// Precargar anuncio recompensado en segundo plano
  void loadRewardedAd() {
    if (!canRequestAds) return;
    if (_rewardedAd != null || _isRewardedLoading) return;
    _rewardedRetryTimer?.cancel();
    _rewardedRetryTimer = null;
    _isRewardedLoading = true;
    final completer = Completer<RewardedAd?>();
    _rewardedLoadCompleter = completer;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          if (!completer.isCompleted) {
            completer.complete(ad);
          }
          if (identical(_rewardedLoadCompleter, completer)) {
            _rewardedLoadCompleter = null;
          }
        },
        onAdFailedToLoad: (_) {
          _isRewardedLoading = false;
          _rewardedAd = null;
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          if (identical(_rewardedLoadCompleter, completer)) {
            _rewardedLoadCompleter = null;
          }
          // En producción el inventario real puede tardar o fallar de forma
          // intermitente al iniciar o entre vídeos consecutivos; reintentamos
          // en segundo plano para tener el siguiente vídeo listo.
          _rewardedRetryTimer?.cancel();
          _rewardedRetryTimer = Timer(const Duration(seconds: 5), () {
            if (_rewardedAd == null && !_isRewardedLoading && canRequestAds) {
              loadRewardedAd();
            }
          });
        },
      ),
    );
  }

  /// Espera brevemente a que AdMob termine de inicializar o de cargar el vídeo
  /// en curso cuando el usuario solicita ver un anuncio en Producción.
  Future<RewardedAd?> _ensureRewardedAdReady(BuildContext context) async {
    if (_rewardedAd != null) return _rewardedAd;
    return _withRewardLoading(context, _waitForRewardedAd);
  }

  Future<T> _withRewardLoading<T>(BuildContext context, Future<T> Function() action) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator(color: AppColors.yellow)),
      ),
    );
    unawaited(navigator.push(route));
    try {
      return await action();
    } finally {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    }
  }

  Future<RewardedAd?> _waitForRewardedAd() async {
    Future<RewardedAd?> load() async {
      if (!canRequestAds) await initialize();
      if (_rewardedAd != null) return _rewardedAd;
      loadRewardedAd();
      return await _rewardedLoadCompleter?.future;
    }
    return load().timeout(const Duration(seconds: 6), onTimeout: () => null);
  }

  /// Mostrar diálogo y flujo de anuncio recompensado para funciones especiales
  Future<void> showRewardedFeatureGate({
    required BuildContext context,
    required bool isPremium,
    required String featureTitle,
    required String featureActionDescription,
    String? featureKey,
    required VoidCallback onRewardGranted,
  }) async {
    if (useBackendRewards) {
      await _showBackendFeatureGate(
        context: context,
        isPremium: isPremium,
        featureTitle: featureTitle,
        featureActionDescription: featureActionDescription,
        featureKey: featureKey,
        onRewardGranted: onRewardGranted,
      );
      return;
    }
    // Aseguramos haber resuelto el usuario de la sesión activa antes de
    // evaluar isRewardPassActive o isFeatureUnlocked.
    if (_rewardUserId == null || _rewardUserId!.isEmpty) {
      await _ensureAuthenticatedRewardUserId();
    }

    // El pase global desbloquea todas las funciones; el vídeo de esta
    // función permite volver a ella durante cinco minutos sin otro anuncio.
    if (isPremium || isRewardPassActive ||
        (featureKey != null && isFeatureUnlocked(featureKey))) {
      if (context.mounted) onRewardGranted();
      return;
    }

    // Evitar diálogos duplicados al pulsar varias veces el mismo botón.
    if (!context.mounted || _rewardedGateDialogOpen || _isFullScreenAdShowing) {
      return;
    }
    _rewardedGateDialogOpen = true;

    // Si aún no hay vídeo precargado, iniciamos la carga mientras el usuario
    // lee el diálogo.
    if (_rewardedAd == null && !_isRewardedLoading) {
      loadRewardedAd();
    }

    // Mostrar diálogo explicativo al usuario
    bool? proceed;
    try {
      proceed = await showDialog<bool>(
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
                        AppLocalizations.of(context)!.rewardVideoAddsMinutes(rewardMinutesPerVideo),
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
    } finally {
      _rewardedGateDialogOpen = false;
    }

    if (!context.mounted || proceed != true) return;

    // Otra operación pudo haber activado el pase mientras el diálogo estaba abierto.
    if (isRewardPassActive) {
      onRewardGranted();
      return;
    }

    if (rewardRemainingTodayMinutes <= 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!
                .rewardDailyLimitReached(maxRewardMinutesPerDay),
          ),
        ),
      );
      return;
    }

    // Rewarded se muestra por decisión explícita del usuario: no aplicar
    // el cooldown de anuncios automáticos (Interstitial/App Open).
    if (_isFullScreenAdShowing) return;

    final ad = await _ensureRewardedAdReady(context);
    if (!context.mounted) return;

    // Ejecutar el anuncio recompensado
    if (ad != null) {
      _rewardedAd = null;
      _isFullScreenAdShowing = true;
      bool userEarnedReward = false;
      bool adDismissed = false;
      bool rewardHandledInUi = false;
      Future<int>? rewardGrantFuture;

      Future<int> ensureRewardSaved() {
        return rewardGrantFuture ??= (() async {
          final added = await addRewardMinutes();
          if (added > 0) {
            await _grantFeatureAccess(featureKey);
          }
          return added;
        })();
      }

      Future<void> completeUiAfterReward() async {
        if (rewardHandledInUi || !adDismissed || !userEarnedReward) return;
        rewardHandledInUi = true;
        final added = await ensureRewardSaved();
        if (!context.mounted) return;
        if (added > 0) {
          onRewardGranted();
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.rewardAddedBank(
                  added,
                  rewardBankMinutes,
                ),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!
                    .rewardDailyLimitReached(maxRewardMinutesPerDay),
              ),
            ),
          );
        }
      }

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) {
          _isFullScreenAdShowing = true;
        },
        onAdDismissedFullScreenContent: (ad) async {
          ad.dispose();
          _markFullScreenClosed();
          loadRewardedAd();
          adDismissed = true;
          if (userEarnedReward) {
            await completeUiAfterReward();
          } else {
            // En producción algunos formatos envían onUserEarnedReward pocos
            // milisegundos después de onAdDismissedFullScreenContent.
            await Future<void>.delayed(const Duration(milliseconds: 250));
            if (userEarnedReward) {
              await completeUiAfterReward();
            } else if (context.mounted) {
              final message =
                  AppLocalizations.of(context)!.rewardCompleteToUnlock;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text(message)),
              );
            }
          }
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          _markFullScreenClosed();
          loadRewardedAd();
          if (context.mounted) {
            final message = AppLocalizations.of(context)!.rewardVideoShowError;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
      );

      ad.show(
        onUserEarnedReward: (_, __) {
          userEarnedReward = true;
          // Persistimos de inmediato apenas se gana la recompensa, sin esperar
          // a que se cierre el anuncio, para que nunca se pierda si el usuario
          // cierra la app o si el callback llega después del cierre.
          unawaited(ensureRewardSaved());
          if (adDismissed) {
            unawaited(completeUiAfterReward());
          }
        },
      );
    } else {
      loadRewardedAd();
      if (context.mounted) {
        final message = AppLocalizations.of(context)!.rewardNoVideoAvailable;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  /// Muestra un Rewarded desde el regalo del Home y suma 5 minutos al saldo.
  Future<void> showRewardedForPass({
    required BuildContext context,
  }) async {
    if (useBackendRewards) {
      await _showBackendRewarded(context: context, origin: 'regalo');
      return;
    }
    if (_rewardUserId == null || _rewardUserId!.isEmpty) {
      await _ensureAuthenticatedRewardUserId();
    }

    if (isRewardBankFull) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.rewardDailyLimitReached(maxRewardMinutesPerDay),
            ),
          ),
        );
      }
      return;
    }

    // Los vídeos solicitados voluntariamente no tienen el cooldown de
    // Interstitial/App Open; sólo se impide solapar dos pantallas completas.
    if (!context.mounted || _isFullScreenAdShowing) return;

    final ad = await _ensureRewardedAdReady(context);
    if (!context.mounted) return;

    if (ad == null) {
      loadRewardedAd();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.rewardNoVideoAvailable,
          ),
        ),
      );
      return;
    }

    _rewardedAd = null;
    _isFullScreenAdShowing = true;
    bool userEarnedReward = false;
    bool adDismissed = false;
    bool rewardHandledInUi = false;
    Future<int>? rewardGrantFuture;

    Future<int> ensureRewardSaved() {
      return rewardGrantFuture ??= addRewardMinutes();
    }

    Future<void> completeUiAfterReward() async {
      if (rewardHandledInUi || !adDismissed || !userEarnedReward) return;
      rewardHandledInUi = true;
      final added = await ensureRewardSaved();
      if (!context.mounted) return;
      final total = rewardBankMinutes;
      final message = added > 0
          ? AppLocalizations.of(context)!.rewardAddedBalance(added, total)
          : AppLocalizations.of(context)!
              .rewardDailyLimitReached(maxRewardMinutesPerDay);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _isFullScreenAdShowing = true;
      },
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _markFullScreenClosed();
        loadRewardedAd();
        adDismissed = true;

        if (userEarnedReward) {
          await completeUiAfterReward();
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          if (userEarnedReward) {
            await completeUiAfterReward();
          } else if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!
                      .rewardCompleteForMinutes(rewardMinutesPerVideo),
                ),
              ),
            );
          }
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _markFullScreenClosed();
        loadRewardedAd();
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.rewardVideoShowError,
              ),
            ),
          );
        }
      },
    );

    ad.show(
      onUserEarnedReward: (_, __) {
        userEarnedReward = true;
        unawaited(ensureRewardSaved());
        if (adDismissed) {
          unawaited(completeUiAfterReward());
        }
      },
    );
  }

  /// Flujo nuevo exclusivo de DEV: la recompensa se confirma SOLO desde SSV.
  /// No altera ninguna ruta publicitaria del sistema original.
  Future<void> _showBackendFeatureGate({
    required BuildContext context,
    required bool isPremium,
    required String featureTitle,
    required String featureActionDescription,
    required String? featureKey,
    required VoidCallback onRewardGranted,
  }) async {
    if (isPremium) {
      if (context.mounted) onRewardGranted();
      return;
    }
    await refreshBackendRewardStatus();
    if (isRewardPassActive ||
        (featureKey != null && isFeatureUnlocked(featureKey))) {
      if (context.mounted) onRewardGranted();
      return;
    }
    if (!context.mounted || _rewardedGateDialogOpen || _isFullScreenAdShowing) return;
    _rewardedGateDialogOpen = true;
    bool? accepted;
    try {
      final text = RewardBackendTexts(Localizations.localeOf(context).languageCode);
      accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(featureTitle, style: const TextStyle(color: Colors.white)),
          content: Text('$featureActionDescription\n\n${text.featureInfo}',
            style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(ctx)!.cancelar)),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(ctx)!.verVideo)),
          ],
        ),
      );
    } finally {
      _rewardedGateDialogOpen = false;
    }
    if (!context.mounted || accepted != true) return;
    await _showBackendRewarded(
      context: context,
      origin: 'funcion',
      featureKey: featureKey ?? featureTitle,
      onVerified: onRewardGranted,
    );
  }

  Future<void> _showBackendRewarded({
    required BuildContext context,
    required String origin,
    String? featureKey,
    VoidCallback? onVerified,
  }) async {
    if (!context.mounted || _isFullScreenAdShowing || _backendRewardPreparing) return;
    _backendRewardPreparing = true;
    try {
      await _withRewardLoading(context, () => _prepareAndShowBackendRewarded(
          context: context, origin: origin, featureKey: featureKey,
          onVerified: onVerified,
        ));
    } finally {
      _backendRewardPreparing = false;
    }
  }

  Future<void> _prepareAndShowBackendRewarded({
    required BuildContext context,
    required String origin,
    String? featureKey,
    VoidCallback? onVerified,
  }) async {
    final lang = Localizations.localeOf(context).languageCode;
    final strings = RewardBackendTexts(lang);
    void message(String value) {
      if (context.mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(SnackBar(content: Text(value)));
      }
    }

    if (backendUsesDemoAds) {
      message(strings.testAdsNeedSsv);
      return;
    }
    if (_rewardUserId == null) await setRewardUser(null);
    if (!context.mounted || _rewardUserId == null) return;
    final identity = _rewardUserId;
    final accountRevision = _rewardAccountRevision;
    bool isCurrentUser() => _rewardUserId == identity &&
        _rewardAccountRevision == accountRevision;

    // Preloading continues while the server creates the SSV session.
    loadRewardedAd();

    // Crear sesión ANTES del anuncio. Si no hay backend, no pedir al usuario
    // que vea un video que no podemos asociar a su cuenta.
    RewardVideoSession session;
    RewardedAd? ad;
    try {
      final prepared = await Future.wait<Object?>([
        RewardBackendService.startVideo(
          origin: origin, featureKey: featureKey, adUnitId: rewardedAdUnitId,
        ),
        _waitForRewardedAd(),
      ]);
      session = prepared[0] as RewardVideoSession;
      ad = prepared[1] as RewardedAd?;
    } catch (e) {
      debugPrint('[REWARDS] video-session DEV: $e');
      message(e is RewardBackendException && e.code == 'SSV_AD_UNIT_NOT_CONFIGURED'
          ? strings.ssvNotConfigured : strings.unavailable);
      return;
    }
    if (!context.mounted || !isCurrentUser()) return;
    // Do not replace the active account with an old HTTP response after logout.
    if (session.userId != identity) {
      message(strings.unavailable);
      return;
    }
    if (ad == null) {
      message(AppLocalizations.of(context)!.rewardNoVideoAvailable);
      return;
    }
    try {
      await ad.setServerSideOptions(ServerSideVerificationOptions(
        userId: session.userId,
        customData: session.customData,
      ));
    } catch (e) {
      debugPrint('[REWARDS] no pudo configurar SSV: $e');
      _rewardedAd = null;
      ad.dispose();
      loadRewardedAd();
      message(strings.unavailable);
      return;
    }
    if (!context.mounted || !isCurrentUser()) return;
    _rewardedAd = null;
    _isFullScreenAdShowing = true;
    final verification = RewardVerification(
      isCurrentUser: isCurrentUser,
      checkVerified: () async {
        if (!await RewardBackendService.isVideoVerified(session.id)) return false;
        if (!isCurrentUser()) return false;
        await _backendStatusFuture;
        return isCurrentUser() && await refreshBackendRewardStatus(force: true);
      },
      onPending: () => message(strings.verifying),
      onVerified: () {
        message(strings.confirmed);
        if (origin == 'funcion' && context.mounted) onVerified?.call();
      },
    );

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        _markFullScreenClosed();
        loadRewardedAd();
        verification.dismissed();
        // Some adapters deliver the reward callback just AFTER dismissal.
        Timer(const Duration(milliseconds: 600), () {
          if (!verification.earned && isCurrentUser()) message(strings.canceled);
        });
      },
      onAdFailedToShowFullScreenContent: (shown, error) {
        shown.dispose();
        _markFullScreenClosed();
        loadRewardedAd();
        debugPrint('[REWARDS] video no mostrado: $error');
        if (context.mounted) {
          message(AppLocalizations.of(context)!.rewardVideoShowError);
        }
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, __) {
        unawaited(verification.rewardEarned());
      });
    } catch (e) {
      ad.dispose();
      _markFullScreenClosed();
      loadRewardedAd();
      if (context.mounted) message(AppLocalizations.of(context)!.rewardVideoShowError);
    }
  }

  /// Liberar recursos
  void dispose() {
    _rewardAccountRevision++;
    _backendStatusFuture = null;
    _rewardedRetryTimer?.cancel();
    _rewardedRetryTimer = null;
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
    _rewardedGateDialogOpen = false;
  }
}
