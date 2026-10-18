import 'package:cloud_firestore/cloud_firestore.dart';

import '../../inward_outward/domain/io_followup.dart' show FollowupStatus;

export '../../inward_outward/domain/io_followup.dart' show FollowupStatus;

/// One followup entry for an EPF case, stored in its own `epf_followups`
/// collection — the same shape as Inward/Outward's `io_followups`. Linked
/// to the case by [caseId] (the stable Firestore id); [clientId] is carried
/// alongside for display.
class EpfFollowup {
  const EpfFollowup({
    required this.id,
    required this.caseId,
    required this.clientId,
    required this.followupDate,
    required this.remark,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String caseId;
  final String clientId;
  final DateTime followupDate;
  final String remark;
  final FollowupStatus status;
  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == FollowupStatus.active;

  bool get isDueToday {
    final now = DateTime.now();
    return isActive &&
        followupDate.year == now.year &&
        followupDate.month == now.month &&
        followupDate.day == now.day;
  }

  factory EpfFollowup.fromMap(String id, Map<String, dynamic> data) {
    return EpfFollowup(
      id: id,
      caseId: data['caseId'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
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
      'caseId': caseId,
      'clientId': clientId,
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

/// The followup shown in the case table: the earliest-dated active
/// followup, or — when none are active — the most recent closed one.
/// Same rule as Inward/Outward's `currentFollowup`.
EpfFollowup? currentEpfFollowup(List<EpfFollowup> followups) {
  EpfFollowup? earliestActive;
  EpfFollowup? latestClosed;
  for (final f in followups) {
    if (f.isActive) {
      if (earliestActive == null || f.followupDate.isBefore(earliestActive.followupDate)) earliestActive = f;
    } else {
      if (latestClosed == null || f.followupDate.isAfter(latestClosed.followupDate)) latestClosed = f;
    }
  }
  return earliestActive ?? latestClosed;
}
