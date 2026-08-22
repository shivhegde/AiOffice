/// The RBAC model, extending REQUIREMENTS.md §4's original 3 roles with a
/// 4th: `manager`. Firestore stores the wire values below verbatim on
/// `users/{uid}.role`.
///
/// `manager` outranks `power_user`: a Manager can do everything a Power
/// User can (create/edit/delete Inward/Outward documents) plus toggle the
/// "Seen" acknowledgement flag (see [IoDocument.seen]) — though since
/// "Seen" is just another document field, Power User already had the
/// ability to set it via a full edit; Manager doesn't gain a capability
/// Power User lacked, it's simply ranked above it. `admin` still outranks
/// both.
enum AppRole {
  generalUser('general_user', 0),
  powerUser('power_user', 1),
  manager('manager', 2),
  admin('admin', 3);

  const AppRole(this.wireValue, this.rank);

  final String wireValue;
  final int rank;

  static AppRole fromWireValue(String? value) {
    return AppRole.values.firstWhere(
      (r) => r.wireValue == value,
      orElse: () => AppRole.generalUser,
    );
  }

  String get label => switch (this) {
    AppRole.generalUser => 'General User',
    AppRole.powerUser => 'Power User',
    AppRole.manager => 'Manager',
    AppRole.admin => 'Admin',
  };

  bool isAtLeast(AppRole other) => rank >= other.rank;
}
