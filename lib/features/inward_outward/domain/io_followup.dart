import 'package:cloud_firestore/cloud_firestore.dart';

import 'io_enums.dart';

enum FollowupStatus {
  active('active', 'Active'),
  closed('closed', 'Closed');

  const FollowupStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static FollowupStatus fromWireValue(String? value) {
    return FollowupStatus.values.firstWhere((s) => s.wireValue == value, orElse: () => FollowupStatus.active);
  }
}

/// One followup entry for an Inward/Outward document, stored in its own
/// `io_followups` collection. Linked to the parent by [documentId] (the
/// stable Firestore id); [docNumber] is carried alongside for display and
/// lookup by document number.
class IoFollowup {
  const IoFollowup({
    required this.id,
    required this.documentId,
    required this.docNumber,
    required this.type,
    required this.followupDate,
    required this.remark,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String documentId;
  final String docNumber;
  final IoType type;
  final DateTime followupDate;
  final String remark;
  final FollowupStatus status;
  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == FollowupStatus.active;

  factory IoFollowup.fromMap(String id, Map<String, dynamic> data) {
    return IoFollowup(
      id: id,
      documentId: data['documentId'] as String? ?? '',
      docNumber: data['docNumber'] as String? ?? '',
      type: IoType.fromWireValue(data['type'] as String?),
      followupDate: (data['followupDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      remark: data['remark'] as String? ?? '',
      status: FollowupStatus.fromWireValue(data['status'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'docNumber': docNumber,
      'type': type.wireValue,
      'followupDate': Timestamp.fromDate(followupDate),
      'remark': remark,
      'status': status.wireValue,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// The followup shown in the document table: the earliest-dated active
/// followup, or — when none are active — the most recent closed one, so a
/// fully closed-out document still shows its last status. Null when the
/// document has no followups.
IoFollowup? currentFollowup(List<IoFollowup> followups) {
  IoFollowup? earliestActive;
  IoFollowup? latestClosed;
  for (final f in followups) {
    if (f.isActive) {
      if (earliestActive == null || f.followupDate.isBefore(earliestActive.followupDate)) earliestActive = f;
    } else {
      if (latestClosed == null || f.followupDate.isAfter(latestClosed.followupDate)) latestClosed = f;
    }
  }
  return earliestActive ?? latestClosed;
}
