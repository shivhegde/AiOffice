import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/audit/domain/audit_entry.dart';
import '../features/audit/presentation/audit_log_screen.dart';
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
        ref.read(productionUserRepositoryProvider).ensureUserDocument(user);
      }
    }, fireImmediately: true);

    // "Logged in" audit entry — written once the profile (and so the data
    // environment) has loaded after an interactive sign-in. Checked from
    // both sides, as either the flag or the profile can arrive last.
    ref.listenManual(currentAppUserProvider, (_, _) => _logPendingLogin());
    ref.listenManual(pendingLoginAuditProvider, (_, _) => _logPendingLogin());
  }

  void _logPendingLogin() {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null || !ref.read(pendingLoginAuditProvider)) return;
    ref.read(pendingLoginAuditProvider.notifier).state = false;
    ref
        .read(auditLogRepositoryProvider)
        .log(
          actorUid: appUser.uid,
          actorName: appUser.displayName.isNotEmpty ? appUser.displayName : appUser.email,
          action: AuditAction.login,
          module: 'auth',
          targetId: appUser.uid,
          targetLabel: '',
        )
        // Unapproved (pending) accounts can't write the audit log.
        .catchError((_) {});
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
