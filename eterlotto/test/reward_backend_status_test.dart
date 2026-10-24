import 'package:eterlotto/services/reward_backend_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a completed challenge can reset to zero while exposing an available pass',
    () {
      final status = RewardBackendStatus.fromJson({
        'videos_required': 7,
        'videos_completed': 0,
        'passes_available': 1,
        'available_passes': [
          {'id': 'earned-pass'},
        ],
      });
      expect(status.videosCompleted, 0);
      expect(status.passesAvailable, 1);
      expect(status.availablePasses, ['earned-pass']);
      expect(status.passActive, isFalse); // Activation is always manual.
    },
  );

  test('pass duration uses server time even if the device clock differs', () {
    final server = DateTime.utc(2035, 1, 1);
    final status = RewardBackendStatus.fromJson({
      'server_time': server.toIso8601String(),
      'pass_expires_at': server
          .add(const Duration(hours: 12))
          .toIso8601String(),
    });
    expect(status.passActive, isTrue);
    expect(status.remaining.inSeconds, inInclusiveRange(43198, 43200));
  });

  test(
    'expired pass and expired feature stay locked according to server time',
    () {
      final server = DateTime.utc(2035, 1, 1);
      final expired = server
          .subtract(const Duration(minutes: 1))
          .toIso8601String();
      final status = RewardBackendStatus.fromJson({
        'server_time': server.toIso8601String(),
        'pass_expires_at': expired,
        'feature_unlocks': {
          'expired': expired,
          'statistics': server
              .add(const Duration(minutes: 30))
              .toIso8601String(),
        },
      });
      expect(status.passActive, isFalse);
      expect(status.remaining, Duration.zero);
      expect(status.isFeatureUnlocked('expired'), isFalse);
      expect(status.isFeatureUnlocked('statistics'), isTrue);
      expect(status.isFeatureUnlocked('another-feature'), isFalse);
    },
  );
}
