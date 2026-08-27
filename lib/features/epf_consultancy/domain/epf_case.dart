import 'package:cloud_firestore/cloud_firestore.dart';

import 'epf_enums.dart';
import 'epf_follow_up.dart';

/// REQUIREMENTS.md §9.5 — EPF Consultancy ("Classic Consultancy"): a
/// client-facing case-management module, functionally a small CRM. §9.5.2
/// (Client Management) and §9.5.4 (Case Tracking) are unified onto one
/// Firestore document (`epf_cases/{id}`) — one document per service case,
/// with client personal/employment details embedded rather than kept in a
/// separate clients collection. A client returning for a second service
/// (e.g. UAN Activation after a completed PF Withdrawal) gets a second
/// case document with the same personal details re-entered; this trades
/// off normalization for consistency with every other module in this app
/// (Vehicle Insurance's Customer+Vehicle+Policy is the same shape), and
/// can be revisited if repeat clients turn out to be common.
class EpfCase {
  const EpfCase({
    required this.id,
    required this.clientId,
    required this.year,
    required this.name,
    this.fatherName = '',
    required this.mobile,
    this.alternateMobile = '',
    this.email = '',
    this.address = '',
    this.aadhaarNumber = '',
    this.panNumber = '',
    required this.dateOfBirth,
    required this.gender,
    this.uanNumber = '',
    this.previousCompany = '',
    this.currentCompany = '',
    this.dateOfJoining,
    this.exitDate,
    this.memberId = '',
    required this.service,
    required this.stage,
    this.documentPaths = const {},
    this.documentFileNames = const {},
    this.fee = 0,
    this.amountPaid = 0,
    this.feePaidAt,
    this.followUps = const [],
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String clientId;
  final int year;

  // Personal Details
  final String name;
  final String fatherName;
  final String mobile;
  final String alternateMobile;
  final String email;
  final String address;
  final String aadhaarNumber;
  final String panNumber;
  final DateTime dateOfBirth;
  final Gender gender;

  // Employment Details
  final String uanNumber;
  final String previousCompany;
  final String currentCompany;
  final DateTime? dateOfJoining;
  final DateTime? exitDate;
  final String memberId;

  // Service + Case Tracking
  final EpfService service;
  final CaseStage stage;

  // Document Manager
  final Map<EpfDocumentSlot, String> documentPaths;
  final Map<EpfDocumentSlot, String> documentFileNames;

  // Income
  final double fee;
  final double amountPaid;
  final DateTime? feePaidAt;

  // Follow-up log
  final List<EpfFollowUp> followUps;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get pendingAmount => fee - amountPaid;
  bool get isFullyPaid => pendingAmount <= 0;
  bool get isPending => stage != CaseStage.completed && stage != CaseStage.rejected;
  bool get isCompleted => stage == CaseStage.completed;

  bool get isCreatedToday {
    final created = createdAt;
    if (created == null) return false;
    final now = DateTime.now();
    return created.year == now.year && created.month == now.month && created.day == now.day;
  }

  bool get isPaidToday {
    final paidAt = feePaidAt;
    if (paidAt == null) return false;
    final now = DateTime.now();
    return paidAt.year == now.year && paidAt.month == now.month && paidAt.day == now.day;
  }

  EpfFollowUp? get latestFollowUp => followUps.isEmpty ? null : followUps.last;

  bool get hasFollowUpToday {
    final latest = latestFollowUp;
    if (latest == null) return false;
    final now = DateTime.now();
    return latest.date.year == now.year && latest.date.month == now.month && latest.date.day == now.day;
  }

  /// §9.5.1 dashboard "Renewal Alerts" — the source spec doesn't define
  /// what "renewal" means for an EPF case-management workflow (unlike
  /// Work Orders/Vehicle Insurance, EPF cases don't literally renew); read
  /// here as a stale-case alert: still open, but untouched for 30+ days.
  bool get needsRenewalAlert {
    if (!isPending) return false;
    final updated = updatedAt;
    if (updated == null) return false;
    return DateTime.now().difference(updated).inDays >= 30;
  }

  factory EpfCase.fromMap(String id, Map<String, dynamic> data) {
    final rawDocPaths = (data['documentPaths'] as Map?) ?? const {};
    final rawDocNames = (data['documentFileNames'] as Map?) ?? const {};
    final rawFollowUps = (data['followUps'] as List?) ?? const [];

    return EpfCase(
      id: id,
      clientId: data['clientId'] as String? ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      name: data['name'] as String? ?? '',
      fatherName: data['fatherName'] as String? ?? '',
      mobile: data['mobile'] as String? ?? '',
      alternateMobile: data['alternateMobile'] as String? ?? '',
      email: data['email'] as String? ?? '',
      address: data['address'] as String? ?? '',
      aadhaarNumber: data['aadhaarNumber'] as String? ?? '',
      panNumber: data['panNumber'] as String? ?? '',
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gender: Gender.fromWireValue(data['gender'] as String?),
      uanNumber: data['uanNumber'] as String? ?? '',
      previousCompany: data['previousCompany'] as String? ?? '',
      currentCompany: data['currentCompany'] as String? ?? '',
      dateOfJoining: (data['dateOfJoining'] as Timestamp?)?.toDate(),
      exitDate: (data['exitDate'] as Timestamp?)?.toDate(),
      memberId: data['memberId'] as String? ?? '',
      service: EpfService.fromWireValue(data['service'] as String?),
      stage: CaseStage.fromWireValue(data['stage'] as String?),
      documentPaths: {
        for (final entry in rawDocPaths.entries)
          if (EpfDocumentSlot.fromWireValue(entry.key as String?) != null)
            EpfDocumentSlot.fromWireValue(entry.key as String?)!: entry.value as String,
      },
      documentFileNames: {
        for (final entry in rawDocNames.entries)
          if (EpfDocumentSlot.fromWireValue(entry.key as String?) != null)
            EpfDocumentSlot.fromWireValue(entry.key as String?)!: entry.value as String,
      },
      fee: (data['fee'] as num?)?.toDouble() ?? 0,
      amountPaid: (data['amountPaid'] as num?)?.toDouble() ?? 0,
      feePaidAt: (data['feePaidAt'] as Timestamp?)?.toDate(),
      followUps: [for (final f in rawFollowUps) EpfFollowUp.fromMap(f as Map<String, dynamic>)],
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final searchKeywords = <String>{
      ...name.toLowerCase().split(RegExp(r'\s+')),
      clientId.toLowerCase(),
      mobile.toLowerCase(),
      if (aadhaarNumber.isNotEmpty) aadhaarNumber.toLowerCase(),
      if (panNumber.isNotEmpty) panNumber.toLowerCase(),
      if (uanNumber.isNotEmpty) uanNumber.toLowerCase(),
    }..removeWhere((s) => s.isEmpty);

    return {
      'clientId': clientId,
      'year': year,
      'name': name,
      'fatherName': fatherName,
      'mobile': mobile,
      'alternateMobile': alternateMobile,
      'email': email,
      'address': address,
      'aadhaarNumber': aadhaarNumber,
      'panNumber': panNumber,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'gender': gender.wireValue,
      'uanNumber': uanNumber,
      'previousCompany': previousCompany,
      'currentCompany': currentCompany,
      if (dateOfJoining != null) 'dateOfJoining': Timestamp.fromDate(dateOfJoining!),
      if (exitDate != null) 'exitDate': Timestamp.fromDate(exitDate!),
      'memberId': memberId,
      'service': service.wireValue,
      'stage': stage.wireValue,
      'documentPaths': {for (final entry in documentPaths.entries) entry.key.wireValue: entry.value},
      'documentFileNames': {for (final entry in documentFileNames.entries) entry.key.wireValue: entry.value},
      'fee': fee,
      'amountPaid': amountPaid,
      if (feePaidAt != null) 'feePaidAt': Timestamp.fromDate(feePaidAt!),
      'followUps': [for (final f in followUps) f.toMap()],
      'searchKeywords': searchKeywords.toList(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
