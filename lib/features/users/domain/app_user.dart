import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/roles.dart';

enum UserStatus {
  /// Self-registered accounts start here — no Firestore/Storage access
  /// (per `activeRole()` in firestore.rules, which requires `active`)
  /// until an Admin approves them via Manage Users. Closes the gap where
  /// anyone with the public Firebase config could self-register and read
  /// business data immediately.
  pending,
  active,
  disabled;

  static UserStatus fromWireValue(String? value) {
    return UserStatus.values.firstWhere(
      (s) => s.name == value,
      // Fail closed: an unrecognized/malformed status should not
      // accidentally grant access the way defaulting to `active` would.
      orElse: () => UserStatus.pending,
    );
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final AppRole role;
  final UserStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  bool get isActive => status == UserStatus.active;
  bool get isPending => status == UserStatus.pending;

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: AppRole.fromWireValue(data['role'] as String?),
      status: UserStatus.fromWireValue(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': AppRole.generalUser.wireValue,
      'status': UserStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
  }
}
