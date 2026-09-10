import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-configured app-wide licence expiry date, stored at the single
/// document `app_config/licence`. Read by every signed-in user (to drive
/// the expiry banner), written admin-only.
class LicenceConfig {
  const LicenceConfig({required this.expiryDate, this.updatedAt, this.updatedByName});

  /// `null` = no expiry date set (the initial state — never alert).
  final DateTime? expiryDate;

  final DateTime? updatedAt;
  final String? updatedByName;

  /// Absence of a document (never configured yet) means "no expiry" —
  /// matches the requirement that a blank expiry date means the licence
  /// never expires.
  static const unset = LicenceConfig(expiryDate: null);

  factory LicenceConfig.fromMap(Map<String, dynamic> data) {
    return LicenceConfig(
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedByName: data['updatedByName'] as String?,
    );
  }

  Map<String, dynamic> toMap({required String updatedByName}) {
    return {
      'expiryDate': expiryDate == null ? null : Timestamp.fromDate(expiryDate!),
      'updatedByName': updatedByName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
