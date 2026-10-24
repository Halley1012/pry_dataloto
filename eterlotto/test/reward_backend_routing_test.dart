import 'package:eterlotto/services/ad_service.dart';
import 'package:eterlotto/services/reward_backend_service.dart';
import 'package:eterlotto/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  // Override expected routing for the explicit PRD / rollback test runs.
  const expectedBackend = bool.fromEnvironment(
    'TEST_EXPECT_BACKEND_REWARDS',
    defaultValue: true,
  );
  const expectedDevUnit = String.fromEnvironment(
    'TEST_EXPECT_REWARDED_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-9637733995937134/1080827469',
  );

  test('backend rewards select the unit for their environment', () {
    if (expectedBackend) {
      expect(
        AdService.rewardedAdUnitId,
        AppConfig.isProduction
            ? 'ca-app-pub-9637733995937134/4124989907'
            : expectedDevUnit,
      );
      expect(AdService.backendUsesDemoAds, isFalse);
    } else {
      expect(AdService.backendUsesDemoAds, isTrue);
    }
  });

  test('normal DEV launch registers the connected AdMob test device', () {
    if (AppConfig.isProduction) {
      expect(AdService.rewardedTestDeviceIds, isEmpty);
      return;
    }
    expect(
      AdService.rewardedTestDeviceIds,
      contains('946343FC3F891EC0159FC883850B7850'),
    );
  });

  test(
    'normal DEV launches select account-backed credits instead of local minutes',
    () {
      expect(RewardBackendService.enabled, expectedBackend);
      expect(AdService.useBackendRewards, expectedBackend);
    },
  );

  test(
    'legacy local minutes cannot become verified credits or a backend pass',
    () async {
      const legacyUser = 'legacy-local-user';
      final today = DateTime.now();
      final day =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'reward_pass_last_user_id_v1': legacyUser,
        'reward_pass_day_v2_$legacyUser': day,
        'reward_pass_bank_minutes_v1_$legacyUser': 10,
        'reward_pass_active_until_v1_$legacyUser': DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      });
      final ads = AdService.instance;
      // A nonnumeric old local identity deliberately avoids HTTP in this test.
      await ads.setRewardUser(legacyUser);
      expect(ads.rewardBankMinutes, 10);
      expect(ads.backendVideosCompleted, 0);
      expect(ads.backendPassesAvailable, 0);
      expect(ads.isRewardPassActive, !expectedBackend);
      await ads.clearRewardUser();
    },
  );
}
