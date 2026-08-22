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
    required this.category,
    required this.publishDate,
    required this.submissionDate,
    required this.emdAmount,
    required this.emdType,
    required this.utrNumber,
    this.emdValidUntil,
    required this.refundStatus,
    this.refundedAt,
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
  final String tenderNumber;
  final int year;
  final String tenderName;
  final String departmentName;
  final TenderCategory category;
  final DateTime publishDate;
  final DateTime submissionDate;

  final double emdAmount;
  final EmdType emdType;
  final String utrNumber;

  /// Optional — see §7.6 build-time note: the source spreadsheet never
  /// defines what "EMD validity" date the 15-day alert should measure
  /// against. Left blank, that alert just doesn't fire for this tender.
  final DateTime? emdValidUntil;

  final RefundStatus refundStatus;
  final DateTime? refundedAt;

  final String deptContactPerson;
  final String deptContactMobile;
  final String deptContactEmail;
  final String deptOfficeAddress;

  final String remarks;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
      category: TenderCategory.fromWireValue(data['category'] as String?),
      publishDate: (data['publishDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      submissionDate: (data['submissionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      emdAmount: (data['emdAmount'] as num?)?.toDouble() ?? 0,
      emdType: EmdType.fromWireValue(data['emdType'] as String?),
      utrNumber: data['utrNumber'] as String? ?? '',
      emdValidUntil: (data['emdValidUntil'] as Timestamp?)?.toDate(),
      refundStatus: RefundStatus.fromWireValue(data['refundStatus'] as String?),
      refundedAt: (data['refundedAt'] as Timestamp?)?.toDate(),
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
      'category': category.wireValue,
      'publishDate': Timestamp.fromDate(publishDate),
      'submissionDate': Timestamp.fromDate(submissionDate),
      'emdAmount': emdAmount,
      'emdType': emdType.wireValue,
      'utrNumber': utrNumber,
      if (emdValidUntil != null) 'emdValidUntil': Timestamp.fromDate(emdValidUntil!),
      'refundStatus': refundStatus.wireValue,
      if (refundedAt != null) 'refundedAt': Timestamp.fromDate(refundedAt!),
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
