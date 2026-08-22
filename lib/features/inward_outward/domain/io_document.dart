import 'package:cloud_firestore/cloud_firestore.dart';

import 'io_enums.dart';

/// REQUIREMENTS.md §6.2 (Inward) / §6.3 (Outward) fields, unified into one
/// Firestore document shape (`inward_outward_documents/{docId}`) with
/// direction-specific fields left null on the other type.
class IoDocument {
  const IoDocument({
    required this.id,
    required this.type,
    required this.docNumber,
    required this.year,
    required this.date,
    required this.docType,
    required this.department,
    required this.subject,
    required this.remarks,
    this.receivedFrom,
    this.senderCompany,
    this.priority,
    this.receiverName,
    this.sentTo,
    this.addressOrEmail,
    this.dispatchMode,
    this.trackingNumber,
    this.sentBy,
    this.storagePath,
    this.fileName,
    this.fileContentType,
    this.fileSizeBytes,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
    this.seen = false,
  });

  final String id;
  final IoType type;
  final String docNumber;
  final int year;
  final DateTime date;
  final String docType;
  final String department;
  final String subject;
  final String remarks;

  // Inward-only
  final String? receivedFrom;
  final String? senderCompany;
  final IoPriority? priority;
  final String? receiverName;

  // Outward-only
  final String? sentTo;
  final String? addressOrEmail;
  final DispatchMode? dispatchMode;
  final String? trackingNumber;
  final String? sentBy;

  // File
  final String? storagePath;
  final String? fileName;
  final String? fileContentType;
  final int? fileSizeBytes;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Acknowledgement flag toggled by `power_user`/`manager`/`admin` (see
  /// [AppRole]) so other users can confirm the document has been
  /// reviewed. General Users see it read-only — see `IoRepository.setSeen`
  /// and `canManageDocuments()` in firestore.rules.
  final bool seen;

  bool get hasFile => storagePath != null && storagePath!.isNotEmpty;

  factory IoDocument.fromMap(String id, Map<String, dynamic> data) {
    return IoDocument(
      id: id,
      type: IoType.fromWireValue(data['type'] as String?),
      docNumber: data['docNumber'] as String? ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      docType: data['docType'] as String? ?? '',
      department: data['department'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      remarks: data['remarks'] as String? ?? '',
      receivedFrom: data['receivedFrom'] as String?,
      senderCompany: data['senderCompany'] as String?,
      priority: data['priority'] != null ? IoPriority.fromWireValue(data['priority'] as String?) : null,
      receiverName: data['receiverName'] as String?,
      sentTo: data['sentTo'] as String?,
      addressOrEmail: data['addressOrEmail'] as String?,
      dispatchMode: data['dispatchMode'] != null ? DispatchMode.fromWireValue(data['dispatchMode'] as String?) : null,
      trackingNumber: data['trackingNumber'] as String?,
      sentBy: data['sentBy'] as String?,
      storagePath: data['storagePath'] as String?,
      fileName: data['fileName'] as String?,
      fileContentType: data['fileContentType'] as String?,
      fileSizeBytes: (data['fileSizeBytes'] as num?)?.toInt(),
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      seen: data['seen'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    final searchKeywords = <String>{
      ...docNumber.toLowerCase().split(RegExp(r'[\s/]+')),
      ...subject.toLowerCase().split(RegExp(r'\s+')),
      ...department.toLowerCase().split(RegExp(r'\s+')),
      if (receivedFrom != null) ...receivedFrom!.toLowerCase().split(RegExp(r'\s+')),
      if (senderCompany != null) ...senderCompany!.toLowerCase().split(RegExp(r'\s+')),
      if (sentTo != null) ...sentTo!.toLowerCase().split(RegExp(r'\s+')),
    }..removeWhere((s) => s.isEmpty);

    return {
      'type': type.wireValue,
      'docNumber': docNumber,
      'year': year,
      'date': Timestamp.fromDate(date),
      'docType': docType,
      'department': department,
      'subject': subject,
      'remarks': remarks,
      if (receivedFrom != null) 'receivedFrom': receivedFrom,
      if (senderCompany != null) 'senderCompany': senderCompany,
      if (priority != null) 'priority': priority!.wireValue,
      if (receiverName != null) 'receiverName': receiverName,
      if (sentTo != null) 'sentTo': sentTo,
      if (addressOrEmail != null) 'addressOrEmail': addressOrEmail,
      if (dispatchMode != null) 'dispatchMode': dispatchMode!.wireValue,
      if (trackingNumber != null) 'trackingNumber': trackingNumber,
      if (sentBy != null) 'sentBy': sentBy,
      if (storagePath != null) 'storagePath': storagePath,
      if (fileName != null) 'fileName': fileName,
      if (fileContentType != null) 'fileContentType': fileContentType,
      if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
      'searchKeywords': searchKeywords.toList(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'seen': seen,
    };
  }
}
