import 'package:cloud_firestore/cloud_firestore.dart';

import 'work_order_enums.dart';

/// REQUIREMENTS.md §8.1 (Basic Fields) + §8.2 (Department Info) + §8.3
/// (Financial Details) + §8.4 (Fixed Deposit) unified onto one Firestore
/// document (`work_orders/{id}`) — the FD fields are embedded, not a
/// separate collection, matching the prototype's single inline "Fixed
/// Deposit Details" section in the Work Order form (see Phase 2 plan
/// decision #1).
class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.workOrderNumber,
    required this.year,
    required this.workOrderDate,
    required this.departmentName,
    required this.contractType,
    required this.startDate,
    this.endDate,
    required this.extensionAvailable,
    required this.status,
    required this.remarks,
    this.extensionStartDate,
    this.extensionEndDate,
    this.extensionOrderNumber,
    this.extensionReason,
    required this.deptOfficeAddress,
    required this.deptContactPerson,
    required this.deptPhoneNumber,
    required this.deptEmail,
    required this.deptGSTIN,
    required this.contractValue,
    required this.securityDeposit,
    required this.emdAmount,
    required this.tenderNumber,
    required this.tenderName,
    this.fdNumber,
    this.fdBankName,
    this.fdBranchName,
    this.fdAmount,
    this.fdIssueDate,
    this.fdMaturityDate,
    this.fdInterestRate,
    this.fdStoragePath,
    this.fdFileName,
    this.fdStatus,
    this.fdReleasedAt,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String workOrderNumber;
  final int year;
  final DateTime workOrderDate;
  final String departmentName;
  final ContractType contractType;
  final DateTime startDate;
  final DateTime? endDate;
  final bool extensionAvailable;
  final WorkOrderStatus status;
  final String remarks;

  // Extension Contract detail (§8.1)
  final DateTime? extensionStartDate;
  final DateTime? extensionEndDate;
  final String? extensionOrderNumber;
  final String? extensionReason;

  // Department Information (§8.2)
  final String deptOfficeAddress;
  final String deptContactPerson;
  final String deptPhoneNumber;
  final String deptEmail;
  final String deptGSTIN;

  // Financial Details (§8.3)
  final double contractValue;
  final double securityDeposit;
  final double emdAmount;

  // Tender reference (free text, not a foreign key — same choice as
  // Inward/Outward's `department` field)
  final String tenderNumber;
  final String tenderName;

  // Fixed Deposit (§8.4) — all nullable; absent until an FD is recorded
  final String? fdNumber;
  final String? fdBankName;
  final String? fdBranchName;
  final double? fdAmount;
  final DateTime? fdIssueDate;
  final DateTime? fdMaturityDate;
  final double? fdInterestRate;
  final String? fdStoragePath;
  final String? fdFileName;
  final FdStatus? fdStatus;
  final DateTime? fdReleasedAt;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasFd => fdNumber != null && fdNumber!.trim().isNotEmpty;
  bool get hasFdFile => fdStoragePath != null && fdStoragePath!.isNotEmpty;

  /// §8.1 dashboard "Expiring in 60 Days".
  bool get isExpiringSoon {
    if (status != WorkOrderStatus.active || endDate == null) return false;
    final daysLeft = endDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 60;
  }

  /// §8.4 "FD maturity within 30 days".
  bool get isFdMaturingSoon {
    if (!hasFd || fdStatus != FdStatus.active || fdMaturityDate == null) return false;
    final daysLeft = fdMaturityDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 30;
  }

  /// §8.4 "Expired FD".
  bool get isFdExpired =>
      hasFd && fdStatus == FdStatus.active && fdMaturityDate != null && fdMaturityDate!.isBefore(DateTime.now());

  /// §8.4 "FD release pending after project completion".
  bool get isFdReleasePending => hasFd && fdStatus == FdStatus.active && status == WorkOrderStatus.expired;

  factory WorkOrder.fromMap(String id, Map<String, dynamic> data) {
    return WorkOrder(
      id: id,
      workOrderNumber: data['workOrderNumber'] as String? ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      workOrderDate: (data['workOrderDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      departmentName: data['departmentName'] as String? ?? '',
      contractType: ContractType.fromWireValue(data['contractType'] as String?),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      extensionAvailable: data['extensionAvailable'] as bool? ?? false,
      status: WorkOrderStatus.fromWireValue(data['status'] as String?),
      remarks: data['remarks'] as String? ?? '',
      extensionStartDate: (data['extensionStartDate'] as Timestamp?)?.toDate(),
      extensionEndDate: (data['extensionEndDate'] as Timestamp?)?.toDate(),
      extensionOrderNumber: data['extensionOrderNumber'] as String?,
      extensionReason: data['extensionReason'] as String?,
      deptOfficeAddress: data['deptOfficeAddress'] as String? ?? '',
      deptContactPerson: data['deptContactPerson'] as String? ?? '',
      deptPhoneNumber: data['deptPhoneNumber'] as String? ?? '',
      deptEmail: data['deptEmail'] as String? ?? '',
      deptGSTIN: data['deptGSTIN'] as String? ?? '',
      contractValue: (data['contractValue'] as num?)?.toDouble() ?? 0,
      securityDeposit: (data['securityDeposit'] as num?)?.toDouble() ?? 0,
      emdAmount: (data['emdAmount'] as num?)?.toDouble() ?? 0,
      tenderNumber: data['tenderNumber'] as String? ?? '',
      tenderName: data['tenderName'] as String? ?? '',
      fdNumber: data['fdNumber'] as String?,
      fdBankName: data['fdBankName'] as String?,
      fdBranchName: data['fdBranchName'] as String?,
      fdAmount: (data['fdAmount'] as num?)?.toDouble(),
      fdIssueDate: (data['fdIssueDate'] as Timestamp?)?.toDate(),
      fdMaturityDate: (data['fdMaturityDate'] as Timestamp?)?.toDate(),
      fdInterestRate: (data['fdInterestRate'] as num?)?.toDouble(),
      fdStoragePath: data['fdStoragePath'] as String?,
      fdFileName: data['fdFileName'] as String?,
      fdStatus: data['fdStatus'] != null ? FdStatus.fromWireValue(data['fdStatus'] as String?) : null,
      fdReleasedAt: (data['fdReleasedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final searchKeywords = <String>{
      ...workOrderNumber.toLowerCase().split(RegExp(r'[\s/]+')),
      ...departmentName.toLowerCase().split(RegExp(r'\s+')),
      ...tenderNumber.toLowerCase().split(RegExp(r'[\s/]+')),
      if (fdNumber != null) ...fdNumber!.toLowerCase().split(RegExp(r'[\s/]+')),
    }..removeWhere((s) => s.isEmpty);

    return {
      'workOrderNumber': workOrderNumber,
      'year': year,
      'workOrderDate': Timestamp.fromDate(workOrderDate),
      'departmentName': departmentName,
      'contractType': contractType.wireValue,
      'startDate': Timestamp.fromDate(startDate),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'extensionAvailable': extensionAvailable,
      'status': status.wireValue,
      'remarks': remarks,
      if (extensionStartDate != null) 'extensionStartDate': Timestamp.fromDate(extensionStartDate!),
      if (extensionEndDate != null) 'extensionEndDate': Timestamp.fromDate(extensionEndDate!),
      if (extensionOrderNumber != null) 'extensionOrderNumber': extensionOrderNumber,
      if (extensionReason != null) 'extensionReason': extensionReason,
      'deptOfficeAddress': deptOfficeAddress,
      'deptContactPerson': deptContactPerson,
      'deptPhoneNumber': deptPhoneNumber,
      'deptEmail': deptEmail,
      'deptGSTIN': deptGSTIN,
      'contractValue': contractValue,
      'securityDeposit': securityDeposit,
      'emdAmount': emdAmount,
      'tenderNumber': tenderNumber,
      'tenderName': tenderName,
      if (fdNumber != null) 'fdNumber': fdNumber,
      if (fdBankName != null) 'fdBankName': fdBankName,
      if (fdBranchName != null) 'fdBranchName': fdBranchName,
      if (fdAmount != null) 'fdAmount': fdAmount,
      if (fdIssueDate != null) 'fdIssueDate': Timestamp.fromDate(fdIssueDate!),
      if (fdMaturityDate != null) 'fdMaturityDate': Timestamp.fromDate(fdMaturityDate!),
      if (fdInterestRate != null) 'fdInterestRate': fdInterestRate,
      if (fdStoragePath != null) 'fdStoragePath': fdStoragePath,
      if (fdFileName != null) 'fdFileName': fdFileName,
      if (fdStatus != null) 'fdStatus': fdStatus!.wireValue,
      if (fdReleasedAt != null) 'fdReleasedAt': Timestamp.fromDate(fdReleasedAt!),
      'searchKeywords': searchKeywords.toList(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
