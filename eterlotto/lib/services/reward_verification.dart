/// Coordinates callbacks that may arrive before OR after ad dismissal.
/// Only the server can confirm a reward; a local callback starts polling.
class RewardVerification {
  RewardVerification({
    required this.checkVerified,
    required this.isCurrentUser,
    required this.onPending,
    required this.onVerified,
    this.pollingWindow = const Duration(minutes: 2),
    this.retryDelay = const Duration(seconds: 2),
  });

  final Future<bool> Function() checkVerified;
  final bool Function() isCurrentUser;
  final void Function() onPending;
  final void Function() onVerified;
  final Duration pollingWindow;
  final Duration retryDelay;
  bool earned = false;
  bool _dismissed = false;
  bool _verified = false;
  bool _pendingNotified = false;
  bool _confirmedNotified = false;
  Future<void>? _verification;

  Future<void> rewardEarned() {
    earned = true;
    _notify();
    return _verification ??= _poll();
  }

  void dismissed() {
    _dismissed = true;
    _notify();
  }

  void _notify() {
    if (!_dismissed || !earned || !isCurrentUser()) return;
    if (_verified) {
      if (!_confirmedNotified) {
        _confirmedNotified = true;
        onVerified();
      }
    } else if (!_pendingNotified) {
      _pendingNotified = true;
      onPending();
    }
  }

  Future<void> _poll() async {
    final elapsed = Stopwatch()..start();
    while (isCurrentUser() && elapsed.elapsed < pollingWindow) {
      try {
        final verified = await checkVerified();
        if (!isCurrentUser()) return;
        if (verified) {
          _verified = true;
          _notify();
          return;
        }
      } catch (_) {
        // A network error does not cancel a reward already earned.
      }
      if (!isCurrentUser()) return;
      await Future<void>.delayed(retryDelay);
    }
  }
}
