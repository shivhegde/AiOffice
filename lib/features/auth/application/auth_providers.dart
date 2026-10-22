import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

/// Set by the login screen after an interactive sign-in, so the app logs
/// one "logged in" audit entry once the user's profile has loaded (restored
/// sessions on app start don't count as a login).
final pendingLoginAuditProvider = StateProvider<bool>((ref) => false);

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});
