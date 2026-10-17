import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/roles.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/user_repository.dart';
import '../domain/app_user.dart';

/// Users in the active environment's database (Manage Users, role checks).
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider));
});

/// Users in the production database — sign-in bootstrap only
/// ([UserRepository.ensureUserDocument]), since identity and the
/// environment choice always live in production.
final productionUserRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(productionFirestoreProvider));
});

/// The signed-in user's `users/{uid}` document in the active environment,
/// or null if signed out / not yet created. Stays loading until the
/// environment is resolved, so the app shell never briefly mounts
/// production data for an admin who is about to be routed to a test
/// environment.
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final firebaseUser = authState.value;
  if (firebaseUser == null) return Stream.value(null);
  final env = ref.watch(activeEnvironmentProvider);
  if (env.hasError) return Stream.error(env.error!, env.stackTrace);
  if (env.isLoading) return Stream<AppUser?>.multi((_) {});
  return ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid);
});

/// The role actually used for UI gating: the real role from Firestore,
/// defaulting to [AppRole.generalUser] while it's still loading so gated
/// actions don't flash visible before the real role arrives.
final effectiveRoleProvider = Provider<AppRole>((ref) {
  final appUser = ref.watch(currentAppUserProvider).value;
  return appUser?.role ?? AppRole.generalUser;
});
