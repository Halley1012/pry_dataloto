import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Push notifications always open above Home, including a resumed session.
void openNotificationsAboveHome(NavigatorState navigator) {
  var foundHome = false;
  navigator.popUntil((route) {
    foundHome = route.settings.name == '/home';
    return foundHome || route.isFirst;
  });
  if (!foundHome) {
    navigator.pushNamedAndRemoveUntil('/home', (_) => false);
  }
  navigator.pushNamed('/notifications');
}

/// A notification route opened without a previous screen still returns Home.
class ReturnHomeOnBack extends StatelessWidget {
  const ReturnHomeOnBack({super.key, required this.child});
  final Widget child;

  static void goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: Navigator.of(context).canPop(),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && ModalRoute.of(context)?.isCurrent == true) goBack(context);
    },
    child: child,
  );
}
