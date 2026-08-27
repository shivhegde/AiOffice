import 'package:cloud_firestore/cloud_firestore.dart';

import 'candidate_enums.dart';

/// REQUIREMENTS.md §9.2 — Resume/Candidate Database (manpower pool for
/// placement), a distinct database from Employees (§9.1). One Firestore
/// document (`candidates/{id}`) per candidate; the resume upload is an
/// embedded storage-path field, same convention as Employee documents.
class Candidate {
  const Candidate({
    required this.id,
    required this.candidateId,
    required this.year,
    required this.fullName,
    required this.mobileNumber,
    this.alternateNumber = '',
    this.referredBy = '',
    this.whatsappNumber = '',
    required this.dateOfBirth,
    required this.gender,
    required this.maritalStatus,
    this.village = '',
    this.cityTown = '',
    this.taluk = '',
    this.district = '',
    this.state = '',
    this.pincode = '',
    this.education = const {},
    required this.category,
    required this.experience,
    this.languagesKnown = const {},
    this.height = '',
    this.exServiceman = false,
    this.resumeStoragePath,
    this.resumeFileName,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String candidateId;
  final int year;

  // Personal Information
  final String fullName;
  final String mobileNumber;
  final String alternateNumber;
  final String referredBy;
  final String whatsappNumber;
  final DateTime dateOfBirth;
  final Gender gender;
  final MaritalStatus maritalStatus;

  // Address Information
  final String village;
  final String cityTown;
  final String taluk;
  final String district;
  final String state;
  final String pincode;

  // Education Details (multi-select)
  final Set<EducationLevel> education;

  // Category / Experience
  final CandidateCategory category;
  final ExperienceLevel experience;

  // Languages known (multi-select)
  final Set<Language> languagesKnown;

  // Physical Information — relevant for CandidateCategory.security only
  final String height;
  final bool exServiceman;

  // Document Storage
  final String? resumeStoragePath;
  final String? resumeFileName;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasResume => resumeStoragePath != null && resumeStoragePath!.isNotEmpty;

  /// §9.2 Personal Information "Age (auto-calculated)".
  int get age {
    final now = DateTime.now();
    var years = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      years -= 1;
    }
    return years;
  }

  /// §9.2 dashboard "Added This Month".
  bool get isAddedThisMonth {
    final created = createdAt;
    if (created == null) return false;
    final now = DateTime.now();
    return created.year == now.year && created.month == now.month;
  }

  factory Candidate.fromMap(String id, Map<String, dynamic> data) {
    return Candidate(
      id: id,
      candidateId: data['candidateId'] as String? ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      fullName: data['fullName'] as String? ?? '',
      mobileNumber: data['mobileNumber'] as String? ?? '',
      alternateNumber: data['alternateNumber'] as String? ?? '',
      referredBy: data['referredBy'] as String? ?? '',
      whatsappNumber: data['whatsappNumber'] as String? ?? '',
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gender: Gender.fromWireValue(data['gender'] as String?),
      maritalStatus: MaritalStatus.fromWireValue(data['maritalStatus'] as String?),
      village: data['village'] as String? ?? '',
      cityTown: data['cityTown'] as String? ?? '',
      taluk: data['taluk'] as String? ?? '',
      district: data['district'] as String? ?? '',
      state: data['state'] as String? ?? '',
      pincode: data['pincode'] as String? ?? '',
      education: {
        for (final v in (data['education'] as List?) ?? const [])
          if (EducationLevel.fromWireValue(v as String?) != null) EducationLevel.fromWireValue(v)!,
      },
      category: CandidateCategory.fromWireValue(data['category'] as String?),
      experience: ExperienceLevel.fromWireValue(data['experience'] as String?),
      languagesKnown: {
        for (final v in (data['languagesKnown'] as List?) ?? const [])
          if (Language.fromWireValue(v as String?) != null) Language.fromWireValue(v)!,
      },
      height: data['height'] as String? ?? '',
      exServiceman: data['exServiceman'] as bool? ?? false,
      resumeStoragePath: data['resumeStoragePath'] as String?,
      resumeFileName: data['resumeFileName'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final searchKeywords = <String>{
      ...fullName.toLowerCase().split(RegExp(r'\s+')),
      candidateId.toLowerCase(),
      if (district.isNotEmpty) district.toLowerCase(),
      if (taluk.isNotEmpty) taluk.toLowerCase(),
      for (final e in education) e.label.toLowerCase(),
    }..removeWhere((s) => s.isEmpty);

    return {
      'candidateId': candidateId,
      'year': year,
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'alternateNumber': alternateNumber,
      'referredBy': referredBy,
      'whatsappNumber': whatsappNumber,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'gender': gender.wireValue,
      'maritalStatus': maritalStatus.wireValue,
      'village': village,
      'cityTown': cityTown,
      'taluk': taluk,
      'district': district,
      'state': state,
      'pincode': pincode,
      'education': education.map((e) => e.wireValue).toList(),
      'category': category.wireValue,
      'experience': experience.wireValue,
      'languagesKnown': languagesKnown.map((l) => l.wireValue).toList(),
      'height': height,
      'exServiceman': exServiceman,
      if (resumeStoragePath != null) 'resumeStoragePath': resumeStoragePath,
      if (resumeFileName != null) 'resumeFileName': resumeFileName,
      'searchKeywords': searchKeywords.toList(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
