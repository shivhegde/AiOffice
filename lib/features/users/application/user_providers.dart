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

/// The role actually used for UI gating: the real role from Firestore,
/// defaulting to [AppRole.generalUser] while it's still loading so gated
/// actions don't flash visible before the real role arrives.
final effectiveRoleProvider = Provider<AppRole>((ref) {
  final appUser = ref.watch(currentAppUserProvider).value;
  return appUser?.role ?? AppRole.generalUser;
});
