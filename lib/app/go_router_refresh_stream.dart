import 'dart:async';

import 'package:flutter/foundation.dart';

/// Standard go_router + stream-based auth adapter: turns
/// [AuthRepository.authStateChanges] into a [Listenable] so `GoRouter`'s
/// `refreshListenable` re-evaluates `redirect` whenever auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
