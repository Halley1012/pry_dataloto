import 'dart:convert';

import '../config/app_config.dart';
import 'api_service.dart';

/// DEV usa créditos y pases por defecto, también con `flutter run` sin opciones.
/// PRD requiere REWARDS_BACKEND_ENABLED=true explícito en la compilación.
class RewardBackendService {
  RewardBackendService._();

  static const bool _requested = bool.fromEnvironment(
    'REWARDS_BACKEND_ENABLED',
    defaultValue: true,
  );

  static const bool _explicitlyConfigured = bool.hasEnvironment(
    'REWARDS_BACKEND_ENABLED',
  );

  static bool get enabled =>
      _requested && (AppConfig.isDevelopment || _explicitlyConfigured);

  static Future<RewardBackendStatus> getStatus() async {
    final response = await ApiService.get(
      '/rewards/status',
      forceRefresh: true,
      timeout: const Duration(seconds: 4),
    );
    if (response.statusCode != 200) {
      throw RewardBackendException(
        'GET /rewards/status: HTTP ${response.statusCode}',
      );
    }
    return RewardBackendStatus.fromJson(_parseObject(response.body));
  }

  static Future<RewardVideoSession> startVideo({
    required String origin,
    required String adUnitId,
    String? featureKey,
  }) async {
    final response = await ApiService.post('/rewards/video-session', {
      'origen': origin,
      'funcion_clave': featureKey,
      'ad_unit_id': adUnitId,
    }, timeout: const Duration(seconds: 6));
    if (response.statusCode != 201) {
      String? code;
      try {
        code = _parseObject(response.body)['detail']?.toString();
      } catch (_) {}
      throw RewardBackendException(
        'POST /rewards/video-session: HTTP ${response.statusCode}',
        code: code,
      );
    }
    final json = _parseObject(response.body);
    final session = json['session_id']?.toString() ?? '';
    final custom = json['ssv_custom_data']?.toString() ?? '';
    final user = json['ssv_user_id']?.toString() ?? '';
    if (session.isEmpty || custom.isEmpty || user.isEmpty) {
      throw RewardBackendException('Sesión SSV incompleta');
    }
    return RewardVideoSession(session, custom, user);
  }

  static Future<bool> isVideoVerified(String sessionId) async {
    final response = await ApiService.get(
      '/rewards/video-session/${Uri.encodeComponent(sessionId)}',
      forceRefresh: true,
      timeout: const Duration(seconds: 4),
    );
    if (response.statusCode != 200) {
      throw RewardBackendException(
        'GET video-session: HTTP ${response.statusCode}',
      );
    }
    return _parseObject(response.body)['verified'] == true;
  }

  static Future<void> activatePass() async {
    final response = await ApiService.post('/rewards/pass/activate', {});
    if (response.statusCode != 200) {
      throw RewardBackendException(
        'POST /rewards/pass/activate: HTTP ${response.statusCode}',
      );
    }
  }

  static Map<String, dynamic> _parseObject(String body) {
    final value = jsonDecode(body);
    if (value is! Map<String, dynamic>) {
      throw RewardBackendException('Respuesta inesperada de Rewards');
    }
    return value;
  }
}

class RewardBackendException implements Exception {
  const RewardBackendException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class RewardVideoSession {
  const RewardVideoSession(this.id, this.customData, this.userId);
  final String id;
  final String customData;
  final String userId;
}

class RewardBackendStatus {
  const RewardBackendStatus({
    required this.videosRequired,
    required this.videosCompleted,
    required this.challengeExpiresAt,
    required this.passesAvailable,
    required this.availablePasses,
    required this.passExpiresAt,
    required this.featureUnlocks,
    this.serverTimeOffset = Duration.zero,
  });

  final int videosRequired;
  final int videosCompleted;
  final DateTime? challengeExpiresAt;
  final int passesAvailable;
  final List<String> availablePasses;
  final DateTime? passExpiresAt;
  final Map<String, DateTime> featureUnlocks;
  final Duration serverTimeOffset;
  DateTime get _now => DateTime.now().add(serverTimeOffset);

  bool get passActive => passExpiresAt != null && _now.isBefore(passExpiresAt!);
  Duration get remaining =>
      passActive ? passExpiresAt!.difference(_now) : Duration.zero;
  bool isFeatureUnlocked(String key) =>
      passActive || (featureUnlocks[key]?.isAfter(_now) ?? false);

  factory RewardBackendStatus.fromJson(Map<String, dynamic> data) {
    DateTime? parseTime(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString())?.toLocal();
    }

    final unlocked = <String, DateTime>{};
    final rawFeatures = data['feature_unlocks'];
    if (rawFeatures is Map) {
      for (final entry in rawFeatures.entries) {
        final until = parseTime(entry.value);
        if (until != null) unlocked[entry.key.toString()] = until;
      }
    }
    final passes = <String>[];
    final rawPasses = data['available_passes'];
    if (rawPasses is List) {
      for (final item in rawPasses) {
        if (item is Map && item['id'] != null) {
          passes.add(item['id'].toString());
        }
      }
    }

    return RewardBackendStatus(
      serverTimeOffset:
          parseTime(data['server_time'])?.difference(DateTime.now()) ??
          Duration.zero,
      videosRequired: (data['videos_required'] as num?)?.toInt() ?? 7,
      videosCompleted: (data['videos_completed'] as num?)?.toInt() ?? 0,
      challengeExpiresAt: parseTime(data['challenge_expires_at']),
      passesAvailable: (data['passes_available'] as num?)?.toInt() ?? 0,
      availablePasses: passes,
      passExpiresAt: parseTime(data['pass_expires_at']),
      featureUnlocks: unlocked,
    );
  }
}

/// Textos del flujo nuevo en cuatro idiomas sin alterar archivos l10n actuales.
class RewardBackendTexts {
  RewardBackendTexts(this.language);
  final String language;

  String get ssvNotConfigured => of(
    'La verificación de recompensas no está configurada. No se mostrará un video que no pueda sumar crédito.',
    'Reward verification is not configured. A video that cannot earn credit will not be shown.',
    'La vérification des récompenses n’est pas configurée. Une vidéo ne pouvant pas rapporter de crédit ne sera pas affichée.',
    'A verificação de recompensas não está configurada. Um vídeo que não possa conceder crédito não será exibido.',
  );

  String of(String es, String en, String fr, String pt) => switch (language) {
    'en' => en,
    'fr' => fr,
    'pt' => pt,
    _ => es,
  };

  String get title => of(
    'Pase de 12 horas',
    '12-hour pass',
    'Pass de 12 heures',
    'Passe de 12 horas',
  );
  String progress(int done, int required) => of(
    '$done/$required videos verificados',
    '$done/$required verified videos',
    '$done/$required vidéos vérifiées',
    '$done/$required vídeos verificados',
  );
  String get watch => of(
    'Ver video (+1 crédito)',
    'Watch video (+1 credit)',
    'Voir une vidéo (+1 crédit)',
    'Ver vídeo (+1 crédito)',
  );
  String get activate => of(
    'Activar pase de 12 h',
    'Activate 12-hour pass',
    'Activer le pass de 12 h',
    'Ativar passe de 12 h',
  );
  String get active =>
      of('Pase activo', 'Pass active', 'Pass actif', 'Passe ativo');
  String remaining(String duration) => of(
    'Tiempo restante: $duration',
    'Time remaining: $duration',
    'Temps restant : $duration',
    'Tempo restante: $duration',
  );
  String get ready => of(
    'Tienes un pase listo para activar.',
    'You have a pass ready to activate.',
    'Vous avez un pass prêt à être activé.',
    'Você tem um passe pronto para ativar.',
  );
  String get continueChallenge => of(
    'Completa 7 videos en 7 días para obtener 12 horas sin anuncios y con todas las funciones desbloqueadas.',
    'Complete 7 videos in 7 days to get 12 hours ad-free with all features unlocked.',
    'Terminez 7 vidéos en 7 jours pour obtenir 12 heures sans publicité et déverrouiller les fonctions.',
    'Conclua 7 vídeos em 7 dias para obter 12 horas sem anúncios e todas as funções desbloqueadas.',
  );
  String deadline(String when) => of(
    'Reto hasta: $when',
    'Challenge until: $when',
    'Défi jusqu’au : $when',
    'Desafio até: $when',
  );
  String get verifying => of(
    'Recompensa pendiente de verificación de Google.',
    'Waiting for Google to verify the reward.',
    'Récompense en attente de vérification par Google.',
    'Recompensa aguardando verificação do Google.',
  );
  String get testAdsNeedSsv => of(
    'Este anuncio de demostración no puede acreditar créditos por SSV. Configura un bloque propio de AdMob para probar las recompensas.',
    'This demo ad cannot grant SSV credits. Configure your own AdMob ad unit to test rewards.',
    'Cette annonce de démonstration ne peut pas accorder de crédits SSV. Configurez votre propre bloc AdMob pour tester les récompenses.',
    'Este anúncio de demonstração não pode conceder créditos SSV. Configure seu próprio bloco AdMob para testar recompensas.',
  );
  String get confirmed => of(
    '¡Crédito confirmado!',
    'Credit confirmed!',
    'Crédit confirmé !',
    'Crédito confirmado!',
  );
  String get unavailable => of(
    'No se pudo consultar Rewards. Revisa la conexión.',
    'Could not load Rewards. Check your connection.',
    'Impossible de charger les récompenses. Vérifiez la connexion.',
    'Não foi possível consultar recompensas. Verifique a conexão.',
  );
  String get canceled => of(
    'Video sin recompensa. No se sumó crédito.',
    'Video not rewarded. No credit was added.',
    'Vidéo non récompensée. Aucun crédit ajouté.',
    'Vídeo sem recompensa. Nenhum crédito adicionado.',
  );
  String get featureInfo => of(
    'Completa el anuncio para desbloquear esta función 30 minutos y sumar 1 crédito.',
    'Complete the ad to unlock this feature for 30 minutes and earn 1 credit.',
    'Terminez la publicité pour débloquer cette fonction pendant 30 minutes et gagner 1 crédit.',
    'Conclua o anúncio para desbloquear a função por 30 minutos e ganhar 1 crédito.',
  );
}
