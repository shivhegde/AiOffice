import 'package:cloud_firestore/cloud_firestore.dart';

import '../../inward_outward/domain/io_followup.dart' show FollowupStatus;

export '../../inward_outward/domain/io_followup.dart' show FollowupStatus;

/// One followup entry for a vehicle insurance policy, stored in its own `vehicle_followups`
/// collection — the same shape as Inward/Outward's `io_followups`. Linked
/// to the policy by [policyId] (the stable Firestore id); [vehicleNumber] is carried
/// alongside for display.
class VehicleFollowup {
  const VehicleFollowup({
    required this.id,
    required this.policyId,
    required this.vehicleNumber,
    required this.followupDate,
    required this.remark,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String policyId;
  final String vehicleNumber;
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

  factory VehicleFollowup.fromMap(String id, Map<String, dynamic> data) {
    return VehicleFollowup(
      id: id,
      policyId: data['policyId'] as String? ?? '',
      vehicleNumber: data['vehicleNumber'] as String? ?? '',
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
      'policyId': policyId,
      'vehicleNumber': vehicleNumber,
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

/// The followup shown in the policy table: the earliest-dated active
/// followup, or — when none are active — the most recent closed one.
/// Same rule as Inward/Outward's `currentFollowup`.
VehicleFollowup? currentVehicleFollowup(List<VehicleFollowup> followups) {
  VehicleFollowup? earliestActive;
  VehicleFollowup? latestClosed;
  for (final f in followups) {
    if (f.isActive) {
      if (earliestActive == null || f.followupDate.isBefore(earliestActive.followupDate)) earliestActive = f;
    } else {
      if (latestClosed == null || f.followupDate.isAfter(latestClosed.followupDate)) latestClosed = f;
    }
  }
  return earliestActive ?? latestClosed;
}
