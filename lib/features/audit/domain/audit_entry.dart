import 'package:cloud_firestore/cloud_firestore.dart';

enum AuditAction { create, update, delete, login }

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.action,
    required this.module,
    required this.targetId,
    required this.targetLabel,
    required this.timestamp,
    this.appVersion = '',
  });

  final String id;
  final String actorUid;
  final String actorName;
  final AuditAction action;
  final String module;
  final String targetId;
  final String targetLabel;
  final DateTime timestamp;

  /// App version the actor was running; empty on entries written before
  /// this was recorded.
  final String appVersion;

  factory AuditEntry.fromMap(String id, Map<String, dynamic> data) {
    return AuditEntry(
      id: id,
      actorUid: data['actorUid'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'Unknown',
      action: AuditAction.values.firstWhere((a) => a.name == data['action'], orElse: () => AuditAction.update),
      module: data['module'] as String? ?? '',
      targetId: data['targetId'] as String? ?? '',
      targetLabel: data['targetLabel'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      appVersion: data['appVersion'] as String? ?? '',
    );
  }

  static Map<String, dynamic> toCreateMap({
    required String actorUid,
    required String actorName,
    required AuditAction action,
    required String module,
    required String targetId,
    required String targetLabel,
    String appVersion = '',
  }) {
    return {
      'actorUid': actorUid,
      'actorName': actorName,
      'action': action.name,
      'module': module,
      'targetId': targetId,
      'targetLabel': targetLabel,
      if (appVersion.isNotEmpty) 'appVersion': appVersion,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
