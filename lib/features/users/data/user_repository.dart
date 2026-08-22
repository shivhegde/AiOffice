import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/roles.dart';
import '../domain/app_user.dart';

/// Users collection access. Role assignment is intentionally NOT writable
/// by the client beyond the one-time self-create at
/// `role: general_user` — see firestore.rules and Phase 1 plan decision #2.
/// The very first admin account is promoted manually via the Firestore
/// console; from then on, admins promote further users via
/// [updateRoleAndStatus].
class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestorePaths.users);

  Stream<AppUser?> watchUser(String uid) {
    return _collection.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return AppUser.fromMap(snap.id, data);
    });
  }

  Stream<List<AppUser>> watchAllUsers() {
    return _collection.orderBy('email').snapshots().map(
      (snap) => snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList(),
    );
  }

  /// Self-creates `users/{uid}` on first successful sign-in. No-ops if the
  /// document already exists.
  Future<void> ensureUserDocument(User firebaseUser) async {
    final ref = _collection.doc(firebaseUser.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) {
      await ref.update({'lastLoginAt': FieldValue.serverTimestamp()});
      return;
    }
    // role/status here are illustrative only — toCreateMap() always writes
    // general_user/pending regardless, matching firestore.rules' create
    // rule (a client can't self-grant anything higher).
    final appUser = AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? (firebaseUser.email ?? 'User'),
      role: AppRole.generalUser,
      status: UserStatus.pending,
    );
    await ref.set(appUser.toCreateMap());
  }

  Future<void> updateRoleAndStatus({
    required String uid,
    required AppRole role,
    required UserStatus status,
  }) async {
    await _collection.doc(uid).update({
      'role': role.wireValue,
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
