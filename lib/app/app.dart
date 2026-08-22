import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/users/application/user_providers.dart';
import '../features/version_gate/application/version_gate_providers.dart';
import '../features/version_gate/presentation/version_blocked_screen.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    // Self-creates/refreshes `users/{uid}` on every sign-in (interactive or
    // restored session) — see UserRepository.ensureUserDocument.
    ref.listenManual(authStateChangesProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        ref.read(userRepositoryProvider).ensureUserDocument(user);
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'OfficeAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      // Version gate is checked here — ahead of routing, so a blocked build
      // never reaches even the login screen. See §"version number concept".
      builder: (context, child) {
        final gate = ref.watch(versionGateResultProvider);
        if (gate.status == VersionGateStatus.belowMin || gate.status == VersionGateStatus.aboveMax) {
          return VersionBlockedScreen(result: gate);
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
