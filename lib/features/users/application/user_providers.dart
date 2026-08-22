import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/roles.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/user_repository.dart';
import '../domain/app_user.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider));
});

/// The signed-in user's `users/{uid}` document, or null if signed out /
/// not yet created.
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final firebaseUser = authState.value;
  if (firebaseUser == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid);
});

/// Debug-only override for the top bar's "Viewing as" role picker
/// (mirrors the prototype's role switcher). Purely cosmetic — it changes
/// what [RoleGate] renders locally but never touches the real Firestore
/// role, so server-side rules still enforce the actual permission. See
/// Phase 1 plan decision #10.
final debugRoleOverrideProvider = StateProvider<AppRole?>((ref) => null);

/// The role actually used for UI gating: the debug override in debug
/// builds if set, otherwise the real role from Firestore (defaulting to
/// [AppRole.generalUser] while it's still loading, so gated actions don't
/// flash visible before the real role arrives).
final effectiveRoleProvider = Provider<AppRole>((ref) {
  if (kDebugMode) {
    final override = ref.watch(debugRoleOverrideProvider);
    if (override != null) return override;
  }
  final appUser = ref.watch(currentAppUserProvider).value;
  return appUser?.role ?? AppRole.generalUser;
});
