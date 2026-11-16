import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/roles.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/app_restart.dart';
import '../../auth/application/auth_providers.dart';
import '../../users/application/user_providers.dart';
import '../data/system_control_repository.dart';
import '../domain/system_control_config.dart';

final systemControlRepositoryProvider = Provider<SystemControlRepository>((ref) {
  // Always production: these switches apply to the whole app, like the
  // version gate and licence.
  return SystemControlRepository(ref.watch(productionFirestoreProvider));
});

final systemControlConfigProvider = StreamProvider<SystemControlConfig>((ref) {
  return ref.watch(systemControlRepositoryProvider).watch();
});

/// Current time; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// When this run of the app started. Recreated by a restart (a fresh
/// ProviderScope), which is what clears a due force refresh.
final appStartedAtProvider = Provider<DateTime>((ref) => ref.watch(clockProvider)());

/// True once the scheduled force-refresh time has been reached by an app
/// that was started before it. Re-evaluates itself exactly when a future
/// refresh time arrives.
final forceRefreshDueProvider = Provider<bool>((ref) {
  // Read first so the start time is fixed at app start, not when the
  // config happens to arrive.
  final startedAt = ref.watch(appStartedAtProvider);
  final at = ref.watch(systemControlConfigProvider).value?.forceRefreshAt;
  if (at == null || !at.isAfter(startedAt)) return false;
  final now = ref.watch(clockProvider)();
  if (!now.isBefore(at)) return true;
  final timer = Timer(at.difference(now) + const Duration(milliseconds: 100), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return false;
});

enum MaintenanceAccess {
  /// Not in maintenance, signed out, or the profile is still loading.
  none,

  /// Admin: warn, then let them continue.
  adminWarning,

  /// Anyone else signed in: sign out and close the app.
  blocked,
}

final maintenanceAccessProvider = Provider<MaintenanceAccess>((ref) {
  final config = ref.watch(systemControlConfigProvider).value;
  if (config == null || !config.maintenanceMode) return MaintenanceAccess.none;
  if (ref.watch(authStateChangesProvider).value == null) return MaintenanceAccess.none;
  final appUser = ref.watch(currentAppUserProvider).value;
  if (appUser == null) return MaintenanceAccess.none;
  return appUser.role.isAtLeast(AppRole.admin) && appUser.isActive
      ? MaintenanceAccess.adminWarning
      : MaintenanceAccess.blocked;
});

/// Set once an admin has dismissed the maintenance warning (or turned
/// maintenance on themselves); cleared when maintenance is switched off,
/// so the next maintenance window warns again.
final maintenanceWarningAcknowledgedProvider = StateProvider<bool>((ref) => false);

/// Closes the app (overridden in tests, where exiting would end the run).
final appExitProvider = Provider<void Function()>((ref) => exitApp);

/// Restarts the app in place (overridden in tests).
final appRestartProvider = Provider<void Function(BuildContext)>((ref) => RestartScope.restart);
