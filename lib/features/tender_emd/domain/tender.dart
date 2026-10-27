import 'package:cloud_firestore/cloud_firestore.dart';

import 'tender_enums.dart';

/// REQUIREMENTS.md §7.1 (Tender Details) + §7.2 (EMD Details) + §7.3
/// (Department Contact) unified onto one Firestore document
/// (`tenders/{id}`), matching the prototype's single-row-per-tender table.
class Tender {
  const Tender({
    required this.id,
    required this.tenderNumber,
    required this.year,
    required this.tenderName,
    required this.departmentName,
    this.subDepartmentName = '',
    required this.category,
    this.status = TenderStatus.active,
    required this.publishDate,
    required this.submissionDate,
    this.bidValidityDays,
    required this.emdAmount,
    this.emdPaymentDate,
    this.emdPaymentBank = '',
    required this.emdType,
    required this.utrNumber,
    this.paymentProofStoragePath,
    this.paymentProofFileName,
    this.emdValidUntil,
    required this.refundStatus,
    this.refundedAt,
    this.refundToAccount = '',
    this.refundUtrNumber = '',
    this.refundProofStoragePath,
    this.refundProofFileName,
    required this.deptContactPerson,
    required this.deptContactMobile,
    required this.deptContactEmail,
    required this.deptOfficeAddress,
    required this.remarks,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// Entered by the user (the department's own tender number) — not
  /// auto-generated.
  final String tenderNumber;
  final int year;

  /// Shown as "Tender Description"; the field keeps its original name so
  /// existing documents don't need migrating.
  final String tenderName;
  final String departmentName;
  final String subDepartmentName;
  final TenderCategory category;
  final TenderStatus status;
  final DateTime publishDate;
  final DateTime submissionDate;
  final int? bidValidityDays;

  final double emdAmount;
  final EmdType emdType;
  final DateTime? emdPaymentDate;
  final String emdPaymentBank;
  final String utrNumber;
  final String? paymentProofStoragePath;
  final String? paymentProofFileName;

  /// Optional — see §7.6 build-time note: the source spreadsheet never
  /// defines what "EMD validity" date the 15-day alert should measure
  /// against. Left blank, that alert just doesn't fire for this tender.
  final DateTime? emdValidUntil;

  final RefundStatus refundStatus;

  /// Shown as "EMD Refund Date". Defaults to the day the refund status
  /// was first set to Refunded, and can be changed in the form.
  final DateTime? refundedAt;
  final String refundToAccount;
  final String refundUtrNumber;
  final String? refundProofStoragePath;
  final String? refundProofFileName;

  final String deptContactPerson;
  final String deptContactMobile;
  final String deptContactEmail;
  final String deptOfficeAddress;

  final String remarks;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasPaymentProof => paymentProofStoragePath != null && paymentProofStoragePath!.isNotEmpty;
  bool get hasRefundProof => refundProofStoragePath != null && refundProofStoragePath!.isNotEmpty;

  /// §7.6 "Refund pending for more than 30 days" — computed, not stored.
  bool get isRefundOverdue =>
      refundStatus == RefundStatus.pending && DateTime.now().difference(submissionDate).inDays > 30;

  int get refundOverdueDays => DateTime.now().difference(submissionDate).inDays;

  /// §7.6 "EMD validity expiring in 15 days".
  bool get isEmdValidityExpiringSoon {
    final validUntil = emdValidUntil;
    if (validUntil == null) return false;
    final daysLeft = validUntil.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 15;
  }

  factory Tender.fromMap(String id, Map<String, dynamic> data) {
    return Tender(
      id: id,
      tenderNumber: data['tenderNumber'] as String? ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      tenderName: data['tenderName'] as String? ?? '',
      departmentName: data['departmentName'] as String? ?? '',
      subDepartmentName: data['subDepartmentName'] as String? ?? '',
      category: TenderCategory.fromWireValue(data['category'] as String?),
      status: TenderStatus.fromWireValue(data['status'] as String?),
      publishDate: (data['publishDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      submissionDate: (data['submissionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bidValidityDays: (data['bidValidityDays'] as num?)?.toInt(),
      emdAmount: (data['emdAmount'] as num?)?.toDouble() ?? 0,
      emdType: EmdType.fromWireValue(data['emdType'] as String?),
      emdPaymentDate: (data['emdPaymentDate'] as Timestamp?)?.toDate(),
      emdPaymentBank: data['emdPaymentBank'] as String? ?? '',
      utrNumber: data['utrNumber'] as String? ?? '',
      paymentProofStoragePath: data['paymentProofStoragePath'] as String?,
      paymentProofFileName: data['paymentProofFileName'] as String?,
      emdValidUntil: (data['emdValidUntil'] as Timestamp?)?.toDate(),
      refundStatus: RefundStatus.fromWireValue(data['refundStatus'] as String?),
      refundedAt: (data['refundedAt'] as Timestamp?)?.toDate(),
      refundToAccount: data['refundToAccount'] as String? ?? '',
      refundUtrNumber: data['refundUtrNumber'] as String? ?? '',
      refundProofStoragePath: data['refundProofStoragePath'] as String?,
      refundProofFileName: data['refundProofFileName'] as String?,
      deptContactPerson: data['deptContactPerson'] as String? ?? '',
      deptContactMobile: data['deptContactMobile'] as String? ?? '',
      deptContactEmail: data['deptContactEmail'] as String? ?? '',
      deptOfficeAddress: data['deptOfficeAddress'] as String? ?? '',
      remarks: data['remarks'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final searchKeywords = <String>{
      ...tenderNumber.toLowerCase().split(RegExp(r'[\s/]+')),
      ...tenderName.toLowerCase().split(RegExp(r'\s+')),
      ...departmentName.toLowerCase().split(RegExp(r'\s+')),
    }..removeWhere((s) => s.isEmpty);

    return {
      'tenderNumber': tenderNumber,
      'year': year,
      'tenderName': tenderName,
      'departmentName': departmentName,
      'subDepartmentName': subDepartmentName,
      'category': category.wireValue,
      'status': status.wireValue,
      'publishDate': Timestamp.fromDate(publishDate),
      'submissionDate': Timestamp.fromDate(submissionDate),
      'bidValidityDays': bidValidityDays,
      'emdAmount': emdAmount,
      'emdType': emdType.wireValue,
      'emdPaymentDate': emdPaymentDate != null ? Timestamp.fromDate(emdPaymentDate!) : null,
      'emdPaymentBank': emdPaymentBank,
      'utrNumber': utrNumber,
      if (paymentProofStoragePath != null) 'paymentProofStoragePath': paymentProofStoragePath,
      if (paymentProofFileName != null) 'paymentProofFileName': paymentProofFileName,
      if (emdValidUntil != null) 'emdValidUntil': Timestamp.fromDate(emdValidUntil!),
      'refundStatus': refundStatus.wireValue,
      if (refundedAt != null) 'refundedAt': Timestamp.fromDate(refundedAt!),
      'refundToAccount': refundToAccount,
      'refundUtrNumber': refundUtrNumber,
      if (refundProofStoragePath != null) 'refundProofStoragePath': refundProofStoragePath,
      if (refundProofFileName != null) 'refundProofFileName': refundProofFileName,
      'deptContactPerson': deptContactPerson,
      'deptContactMobile': deptContactMobile,
      'deptContactEmail': deptContactEmail,
      'deptOfficeAddress': deptOfficeAddress,
      'remarks': remarks,
      'searchKeywords': searchKeywords.toList(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
