import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-controlled switches stored at the single document
/// `app_config/system_control` in production. Read by everyone (even
/// signed out — the login screen shows the maintenance notice), written
/// admin-only (see the `app_config` rule in firestore.rules).
class SystemControlConfig {
  const SystemControlConfig({
    this.maintenanceMode = false,
    this.maintenanceMessage = defaultMaintenanceMessage,
    this.maintenanceSince,
    this.forceRefreshAt,
    this.forceRefreshMessage = defaultForceRefreshMessage,
    this.updatedByName,
  });

  /// While true only admins may use the app: everyone else is signed out
  /// and the app closes; admins see a warning and carry on.
  final bool maintenanceMode;
  final String maintenanceMessage;
  final DateTime? maintenanceSince;

  /// Every copy of the app that was started before this moment must
  /// restart once it's reached — admins included. Null = none scheduled.
  final DateTime? forceRefreshAt;
  final String forceRefreshMessage;

  final String? updatedByName;

  static const defaultMaintenanceMessage = 'The database is under maintenance. Please try again later.';
  static const defaultForceRefreshMessage =
      'The administrator has requested a refresh. The app will restart to load the latest changes.';

  /// No document yet = nothing switched on (fail-open, like the version
  /// gate: a fail-closed default could lock everyone out).
  static const unset = SystemControlConfig();

  factory SystemControlConfig.fromMap(Map<String, dynamic> data) {
    String textOr(String key, String fallback) {
      final value = (data[key] as String?)?.trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    return SystemControlConfig(
      maintenanceMode: data['maintenanceMode'] as bool? ?? false,
      maintenanceMessage: textOr('maintenanceMessage', defaultMaintenanceMessage),
      maintenanceSince: (data['maintenanceSince'] as Timestamp?)?.toDate(),
      forceRefreshAt: (data['forceRefreshAt'] as Timestamp?)?.toDate(),
      forceRefreshMessage: textOr('forceRefreshMessage', defaultForceRefreshMessage),
      updatedByName: data['updatedByName'] as String?,
    );
  }
}
