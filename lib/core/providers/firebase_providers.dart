import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../constants/firestore_paths.dart';

/// Raw Firebase SDK instance providers. Emulator wiring (if
/// `USE_FIREBASE_EMULATOR` is set) happens once in `main.dart` before
/// `runApp`, so these singletons already point at the right backend by the
/// time any provider below is first read.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// The production `(default)` database, whatever environment is active.
/// Used for identity (`users/{uid}` bootstrap and environment lookup) and
/// for app-wide controls (version gate, licence) that apply to the
/// installed build rather than to a data environment.
final productionFirestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final _signedInUidProvider = StreamProvider<String?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges().map((user) => user?.uid).distinct();
});

/// The signed-in user's data environment — see [AppEnvironment]. Follows
/// the `environment` field on their production `users/{uid}` live, so a
/// change takes effect without restarting (though admins are expected to
/// set it before signing in).
final activeEnvironmentProvider = StreamProvider<AppEnvironment>((ref) {
  // Named databases aren't wired to the local emulator.
  if (useFirebaseEmulator) return Stream.value(AppEnvironment.production);
  final uid = ref.watch(_signedInUidProvider).value;
  if (uid == null) return Stream.value(AppEnvironment.production);
  return ref
      .watch(productionFirestoreProvider)
      .collection(FirestorePaths.users)
      .doc(uid)
      .snapshots()
      .map((snap) => AppEnvironment.fromProductionUserData(snap.data()))
      .distinct();
});

/// Firestore for the active environment's data. Every repository reads
/// this, so switching environment re-points the whole app.
///
/// Deliberately a [NotifierProvider] that notifies on *every* rebuild, and
/// rebuilds whenever the signed-in user or the environment changes:
///
/// - A plain [Provider] only notifies dependents when `previous != next`,
///   and `FirebaseFirestore.==` compares just the app name — so the
///   `test1` instance counted as "equal" to production and repositories
///   built before the environment resolved silently kept using production.
/// - Even with the right instance, a data stream that was live at sign-out
///   gets a terminal permission-denied (its query now runs signed out) and
///   Firestore listeners don't retry. Re-notifying on each sign-in gives
///   every repository — and so every list stream — a fresh start under
///   the new session.
final firestoreProvider = NotifierProvider<_FirestoreNotifier, FirebaseFirestore>(_FirestoreNotifier.new);

class _FirestoreNotifier extends Notifier<FirebaseFirestore> {
  @override
  FirebaseFirestore build() {
    // `select` on the values so loading/refresh transitions alone don't rebuild.
    ref.watch(_signedInUidProvider.select((uid) => uid.value));
    final env = ref.watch(activeEnvironmentProvider.select((e) => e.value)) ?? AppEnvironment.production;
    if (env.isProduction) return ref.watch(productionFirestoreProvider);
    return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: env.databaseId);
  }

  @override
  bool updateShouldNotify(FirebaseFirestore previous, FirebaseFirestore next) => true;
}

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);
