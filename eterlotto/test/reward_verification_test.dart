import 'dart:async';

import 'package:eterlotto/services/reward_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pending feedback is immediate; only server confirmation grants access',
    () async {
      final server = Completer<bool>();
      final events = <String>[];
      final verification = RewardVerification(
        checkVerified: () => server.future,
        isCurrentUser: () => true,
        onPending: () => events.add('pending'),
        onVerified: () => events.add('verified'),
      );
      final polling = verification.rewardEarned();
      expect(events, isEmpty); // Never put a snackbar over the video.
      verification.dismissed();
      expect(events, ['pending']);
      server.complete(true);
      await polling;
      expect(events, ['pending', 'verified']);
      await verification.rewardEarned();
      verification.dismissed();
      expect(events, ['pending', 'verified']);
    },
  );

  test('reward callback after dismissal still verifies exactly once', () async {
    var requests = 0;
    var confirmed = 0;
    final verification = RewardVerification(
      checkVerified: () async {
        requests++;
        return true;
      },
      isCurrentUser: () => true,
      onPending: () {},
      onVerified: () => confirmed++,
    );
    verification.dismissed();
    expect(requests, 0);
    await verification.rewardEarned();
    await verification.rewardEarned();
    expect(requests, 1);
    expect(confirmed, 1);
  });

  test(
    'confirmation before dismissal is delivered when the video closes',
    () async {
      var confirmed = 0;
      var pending = 0;
      final verification = RewardVerification(
        checkVerified: () async => true,
        isCurrentUser: () => true,
        onPending: () => pending++,
        onVerified: () => confirmed++,
      );
      await verification.rewardEarned();
      expect(confirmed, 0);
      verification.dismissed();
      expect(confirmed, 1);
      expect(pending, 0);
    },
  );

  test(
    'delayed SSV and temporary errors survive the old eight-attempt limit',
    () async {
      var requests = 0;
      var confirmed = 0;
      final verification = RewardVerification(
        checkVerified: () async {
          requests++;
          if (requests == 2) throw Exception('temporary network failure');
          return requests == 12;
        },
        isCurrentUser: () => true,
        onPending: () {},
        onVerified: () => confirmed++,
        retryDelay: Duration.zero,
      );
      verification.dismissed();
      await verification.rewardEarned();
      expect(requests, 12);
      expect(confirmed, 1);
    },
  );

  test(
    'an account change discards an in-flight verification response',
    () async {
      final server = Completer<bool>();
      var sameAccount = true;
      var confirmed = 0;
      final verification = RewardVerification(
        checkVerified: () => server.future,
        isCurrentUser: () => sameAccount,
        onPending: () {},
        onVerified: () => confirmed++,
      );
      verification.dismissed();
      final polling = verification.rewardEarned();
      sameAccount = false;
      server.complete(true);
      await polling;
      expect(confirmed, 0);
    },
  );

  test('a canceled video never starts verification or grants access', () {
    var requests = 0;
    var confirmed = 0;
    final verification = RewardVerification(
      checkVerified: () async {
        requests++;
        return true;
      },
      isCurrentUser: () => true,
      onPending: () => fail('canceled video'),
      onVerified: () => confirmed++,
    );
    verification.dismissed();
    expect(requests, 0);
    expect(confirmed, 0);
  });
}
