import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-configured allowed app-version range, stored at the single
/// document `app_config/version_gate`. Read publicly (even signed-out —
/// the gate is checked before login), written admin-only.
class VersionGateConfig {
  const VersionGateConfig({
    required this.minVersion,
    required this.maxVersion,
    required this.blockMessage,
    this.updatedAt,
    this.updatedByName,
  });

  /// Empty string = no lower bound.
  final String minVersion;

  /// Empty string = no upper bound.
  final String maxVersion;

  final String blockMessage;
  final DateTime? updatedAt;
  final String? updatedByName;

  static const defaultBlockMessage = 'A newer version of OfficeAI is required. Please install the latest build.';

  /// Absence of a document (never configured yet) means "allow everything"
  /// — fail-open, not fail-closed, since write access requires an admin to
  /// already be signed in and a fail-closed default would lock everyone
  /// out with no way to fix it.
  static const unset = VersionGateConfig(minVersion: '', maxVersion: '', blockMessage: defaultBlockMessage);

  factory VersionGateConfig.fromMap(Map<String, dynamic> data) {
    return VersionGateConfig(
      minVersion: data['minVersion'] as String? ?? '',
      maxVersion: data['maxVersion'] as String? ?? '',
      blockMessage: (data['blockMessage'] as String?)?.trim().isNotEmpty == true
          ? data['blockMessage'] as String
          : defaultBlockMessage,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedByName: data['updatedByName'] as String?,
    );
  }

  Map<String, dynamic> toMap({required String updatedByName}) {
    return {
      'minVersion': minVersion.trim(),
      'maxVersion': maxVersion.trim(),
      'blockMessage': blockMessage.trim(),
      'updatedByName': updatedByName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
