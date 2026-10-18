import 'package:cloud_firestore/cloud_firestore.dart';

import 'vehicle_insurance_enums.dart';

/// REQUIREMENTS.md §9.4 — Vehicle Insurance (agency/sales module): the
/// organization's own book of insurance customers and policies sold, not
/// company-owned vehicles. Customer, Vehicle, and Policy fields are unified
/// onto one Firestore document (`vehicle_policies/{id}`) — one customer's
/// single vehicle+policy per row, same embedding convention as WorkOrder's
/// Fixed Deposit fields (a customer with multiple vehicles simply gets
/// multiple documents, matching how every other module in this app avoids
/// a separate customers collection until there's a proven need for one).
class VehiclePolicy {
  const VehiclePolicy({
    required this.id,
    required this.customerName,
    required this.customerMobile,
    this.customerEmail = '',
    this.customerAddress = '',
    this.customerIdNumber = '',
    this.customerNotes = '',
    required this.vehicleNumber,
    required this.vehicleType,
    this.vehicleTypeOther = '',
    this.makeModel = '',
    this.manufacturingYear,
    this.engineNumber = '',
    this.chassisNumber = '',
    this.financerDetails = '',
    required this.insuranceCompany,
    required this.policyNumber,
    required this.policyTypes,
    this.policyTypeOther = '',
    this.idv = 0,
    this.ncb = 0,
    this.premium = 0,
    this.commission = 0,
    required this.startDate,
    required this.expiryDate,
    this.policyStoragePath,
    this.policyFileName,
    this.documentPaths = const {},
    this.documentFileNames = const {},
    required this.status,
    this.renewedAt,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  // Customer Management
  final String customerName;
  final String customerMobile;
  final String customerEmail;
  final String customerAddress;
  final String customerIdNumber;
  final String customerNotes;

  // Vehicle Management
  final String vehicleNumber;
  final VehicleType vehicleType;

  /// What "Other" means for this vehicle, when [vehicleType] is
  /// [VehicleType.other].
  final String vehicleTypeOther;

  /// Display text: the typed text for "Other" (or "Other" if left blank),
  /// otherwise the type's label.
  String get vehicleTypeLabel {
    if (vehicleType == VehicleType.other && vehicleTypeOther.trim().isNotEmpty) return vehicleTypeOther.trim();
    return vehicleType.label;
  }
  final String makeModel;
  final int? manufacturingYear;
  final String engineNumber;
  final String chassisNumber;
  final String financerDetails;

  // Insurance Policy
  final String insuranceCompany;
  final String policyNumber;
  /// One or more policy types, in [PolicyType] declaration order.
  final List<PolicyType> policyTypes;

  /// What "Other" means for this policy, when it is selected.
  final String policyTypeOther;

  /// Display text for the selected types, e.g. "Comprehensive, Own
  /// Damage" — "Other" is replaced by its typed text when given.
  String get policyTypesLabel {
    if (policyTypes.isEmpty) return '—';
    return [
      for (final t in policyTypes)
        if (t == PolicyType.other && policyTypeOther.trim().isNotEmpty) policyTypeOther.trim() else t.label,
    ].join(', ');
  }
  final double idv;
  final double ncb;
  final double premium;
  final double commission;
  final DateTime startDate;
  final DateTime expiryDate;
  final String? policyStoragePath;
  final String? policyFileName;

  // Supporting documents (Aadhaar, PAN, previous policy, RC)
  final Map<VehicleDocumentSlot, String> documentPaths;
  final Map<VehicleDocumentSlot, String> documentFileNames;

  final PolicyStatus status;
  final DateTime? renewedAt;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasPolicyFile => policyStoragePath != null && policyStoragePath!.isNotEmpty;

  int get daysToExpiry => expiryDate.difference(DateTime.now()).inDays;

  /// §9.4 "Automatic Renewal System" — Show policies due in next
  /// 60/30/15/7 days.
  bool isExpiringWithin(int days) {
    if (status != PolicyStatus.active) return false;
    return daysToExpiry >= 0 && daysToExpiry <= days;
  }

  /// True if the policy is active and expires within `[minDays, maxDays]`
  /// (inclusive) — used for the dashboard's non-overlapping expiry bands.
  bool isExpiringBetween(int minDays, int maxDays) {
    if (status != PolicyStatus.active) return false;
    return daysToExpiry >= minDays && daysToExpiry <= maxDays;
  }

  bool get isOverdue => status == PolicyStatus.active && daysToExpiry < 0;

  /// §9.4 dashboard "Renewals completed this month".
  bool get isRenewedThisMonth {
    final renewed = renewedAt;
    if (status != PolicyStatus.renewed || renewed == null) return false;
    final now = DateTime.now();
    return renewed.year == now.year && renewed.month == now.month;
  }

  factory VehiclePolicy.fromMap(String id, Map<String, dynamic> data) {
    return VehiclePolicy(
      id: id,
      customerName: data['customerName'] as String? ?? '',
      customerMobile: data['customerMobile'] as String? ?? '',
      customerEmail: data['customerEmail'] as String? ?? '',
      customerAddress: data['customerAddress'] as String? ?? '',
      customerIdNumber: data['customerIdNumber'] as String? ?? '',
      customerNotes: data['customerNotes'] as String? ?? '',
      vehicleNumber: data['vehicleNumber'] as String? ?? '',
      vehicleType: VehicleType.fromWireValue(data['vehicleType'] as String?),
      vehicleTypeOther: data['vehicleTypeOther'] as String? ?? '',
      makeModel: data['makeModel'] as String? ?? '',
      manufacturingYear: (data['manufacturingYear'] as num?)?.toInt(),
      engineNumber: data['engineNumber'] as String? ?? '',
      chassisNumber: data['chassisNumber'] as String? ?? '',
      financerDetails: data['financerDetails'] as String? ?? '',
      insuranceCompany: data['insuranceCompany'] as String? ?? '',
      policyNumber: data['policyNumber'] as String? ?? '',
      policyTypes: _policyTypesFromMap(data),
      policyTypeOther: data['policyTypeOther'] as String? ?? '',
      idv: (data['idv'] as num?)?.toDouble() ?? 0,
      ncb: (data['ncb'] as num?)?.toDouble() ?? 0,
      premium: (data['premium'] as num?)?.toDouble() ?? 0,
      commission: (data['commission'] as num?)?.toDouble() ?? 0,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      policyStoragePath: data['policyStoragePath'] as String?,
      policyFileName: data['policyFileName'] as String?,
      documentPaths: _slotMap(data['documentPaths']),
      documentFileNames: _slotMap(data['documentFileNames']),
      status: PolicyStatus.fromWireValue(data['status'] as String?),
      renewedAt: (data['renewedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// `policyTypes` (list) since multi-select; older policies have only
  /// the single `policyType` string.
  static Map<VehicleDocumentSlot, String> _slotMap(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (VehicleDocumentSlot.fromWireValue(e.key as String?) != null && e.value is String)
          VehicleDocumentSlot.fromWireValue(e.key as String?)!: e.value as String,
    };
  }

  static List<PolicyType> _policyTypesFromMap(Map<String, dynamic> data) {
    final raw = data['policyTypes'];
    if (raw is List && raw.isNotEmpty) {
      final wire = raw.whereType<String>().toSet();
      return [for (final t in PolicyType.values) if (wire.contains(t.wireValue)) t];
    }
    final legacy = data['policyType'];
    if (legacy is String && legacy.isNotEmpty) return [PolicyType.fromWireValue(legacy)];
    return const [];
  }

  Map<String, dynamic> toMap() {
    final searchKeywords = <String>{
      ...customerName.toLowerCase().split(RegExp(r'\s+')),
      vehicleNumber.toLowerCase(),
      customerMobile.toLowerCase(),
      policyNumber.toLowerCase(),
    }..removeWhere((s) => s.isEmpty);

    return {
      'customerName': customerName,
      'customerMobile': customerMobile,
      'customerEmail': customerEmail,
      'customerAddress': customerAddress,
      'customerIdNumber': customerIdNumber,
      'customerNotes': customerNotes,
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType.wireValue,
      'vehicleTypeOther': vehicleType == VehicleType.other ? vehicleTypeOther : '',
      'makeModel': makeModel,
      if (manufacturingYear != null) 'manufacturingYear': manufacturingYear,
      'engineNumber': engineNumber,
      'chassisNumber': chassisNumber,
      'financerDetails': financerDetails,
      'insuranceCompany': insuranceCompany,
      'policyNumber': policyNumber,
      'policyTypes': [for (final t in policyTypes) t.wireValue],
      'policyTypeOther': policyTypes.contains(PolicyType.other) ? policyTypeOther : '',
      // Single-type field kept so builds from before multi-select still
      // show something sensible for new policies.
      if (policyTypes.isNotEmpty) 'policyType': policyTypes.first.wireValue,
      'idv': idv,
      'ncb': ncb,
      'premium': premium,
      'commission': commission,
      'startDate': Timestamp.fromDate(startDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      if (policyStoragePath != null) 'policyStoragePath': policyStoragePath,
      if (policyFileName != null) 'policyFileName': policyFileName,
      'documentPaths': {for (final e in documentPaths.entries) e.key.wireValue: e.value},
      'documentFileNames': {for (final e in documentFileNames.entries) e.key.wireValue: e.value},
      'status': status.wireValue,
      if (renewedAt != null) 'renewedAt': Timestamp.fromDate(renewedAt!),
      'searchKeywords': searchKeywords.toList(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
