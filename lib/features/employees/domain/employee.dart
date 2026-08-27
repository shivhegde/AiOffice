import 'package:cloud_firestore/cloud_firestore.dart';

import 'employee_enums.dart';

/// REQUIREMENTS.md §9.1 — Employee Database (own staff). One Firestore
/// document (`employees/{id}`) per employee; the three document uploads
/// (Aadhaar Card, PAN Card, Passport Photo) are embedded storage-path
/// fields, matching the WorkOrder FD embedding convention (see
/// WorkOrderRepository doc comment for why: the record is always built
/// directly via its constructor, never round-tripped through
/// `toMap()`/`fromMap()`).
class Employee {
  const Employee({
    required this.id,
    required this.employeeId,
    required this.year,
    required this.fullName,
    required this.gender,
    required this.dateOfBirth,
    required this.mobileNumber,
    this.alternateNumber = '',
    this.email = '',
    this.currentAddress = '',
    this.permanentAddress = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.aadhaarNumber = '',
    this.panNumber = '',
    required this.dateOfAppointment,
    required this.joiningDate,
    required this.department,
    required this.designation,
    required this.employeeType,
    this.branchLocation = '',
    this.reportingManager = '',
    required this.workStatus,
    this.photoStoragePath,
    this.photoFileName,
    this.aadhaarStoragePath,
    this.aadhaarFileName,
    this.panStoragePath,
    this.panFileName,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String employeeId;
  final int year;

  // Basic Information
  final String fullName;
  final Gender gender;
  final DateTime dateOfBirth;
  final String mobileNumber;
  final String alternateNumber;
  final String email;
  final String currentAddress;
  final String permanentAddress;
  final String city;
  final String state;
  final String pincode;

  // Identity Details
  final String aadhaarNumber;
  final String panNumber;

  // Appointment / Job Information
  final DateTime dateOfAppointment;
  final DateTime joiningDate;
  final String department;
  final String designation;
  final EmployeeType employeeType;
  final String branchLocation;
  final String reportingManager;
  final WorkStatus workStatus;

  // Document Upload
  final String? photoStoragePath;
  final String? photoFileName;
  final String? aadhaarStoragePath;
  final String? aadhaarFileName;
  final String? panStoragePath;
  final String? panFileName;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasPhoto => photoStoragePath != null && photoStoragePath!.isNotEmpty;
  bool get hasAadhaarFile => aadhaarStoragePath != null && aadhaarStoragePath!.isNotEmpty;
  bool get hasPanFile => panStoragePath != null && panStoragePath!.isNotEmpty;

  /// §9.1 dashboard "New Appointments" — appointed within the current
  /// calendar month.
  bool get isNewAppointment {
    final now = DateTime.now();
    return dateOfAppointment.year == now.year && dateOfAppointment.month == now.month;
  }

  factory Employee.fromMap(String id, Map<String, dynamic> data) {
    return Employee(
      id: id,
      employeeId: data['employeeId'] as String? ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      fullName: data['fullName'] as String? ?? '',
      gender: Gender.fromWireValue(data['gender'] as String?),
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate() ?? DateTime.now(),
      mobileNumber: data['mobileNumber'] as String? ?? '',
      alternateNumber: data['alternateNumber'] as String? ?? '',
      email: data['email'] as String? ?? '',
      currentAddress: data['currentAddress'] as String? ?? '',
      permanentAddress: data['permanentAddress'] as String? ?? '',
      city: data['city'] as String? ?? '',
      state: data['state'] as String? ?? '',
      pincode: data['pincode'] as String? ?? '',
      aadhaarNumber: data['aadhaarNumber'] as String? ?? '',
      panNumber: data['panNumber'] as String? ?? '',
      dateOfAppointment: (data['dateOfAppointment'] as Timestamp?)?.toDate() ?? DateTime.now(),
      joiningDate: (data['joiningDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      department: data['department'] as String? ?? '',
      designation: data['designation'] as String? ?? '',
      employeeType: EmployeeType.fromWireValue(data['employeeType'] as String?),
      branchLocation: data['branchLocation'] as String? ?? '',
      reportingManager: data['reportingManager'] as String? ?? '',
      workStatus: WorkStatus.fromWireValue(data['workStatus'] as String?),
      photoStoragePath: data['photoStoragePath'] as String?,
      photoFileName: data['photoFileName'] as String?,
      aadhaarStoragePath: data['aadhaarStoragePath'] as String?,
      aadhaarFileName: data['aadhaarFileName'] as String?,
      panStoragePath: data['panStoragePath'] as String?,
      panFileName: data['panFileName'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final searchKeywords = <String>{
      ...fullName.toLowerCase().split(RegExp(r'\s+')),
      employeeId.toLowerCase(),
      mobileNumber.toLowerCase(),
      if (aadhaarNumber.isNotEmpty) aadhaarNumber.toLowerCase(),
    }..removeWhere((s) => s.isEmpty);

    return {
      'employeeId': employeeId,
      'year': year,
      'fullName': fullName,
      'gender': gender.wireValue,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'mobileNumber': mobileNumber,
      'alternateNumber': alternateNumber,
      'email': email,
      'currentAddress': currentAddress,
      'permanentAddress': permanentAddress,
      'city': city,
      'state': state,
      'pincode': pincode,
      'aadhaarNumber': aadhaarNumber,
      'panNumber': panNumber,
      'dateOfAppointment': Timestamp.fromDate(dateOfAppointment),
      'joiningDate': Timestamp.fromDate(joiningDate),
      'department': department,
      'designation': designation,
      'employeeType': employeeType.wireValue,
      'branchLocation': branchLocation,
      'reportingManager': reportingManager,
      'workStatus': workStatus.wireValue,
      if (photoStoragePath != null) 'photoStoragePath': photoStoragePath,
      if (photoFileName != null) 'photoFileName': photoFileName,
      if (aadhaarStoragePath != null) 'aadhaarStoragePath': aadhaarStoragePath,
      if (aadhaarFileName != null) 'aadhaarFileName': aadhaarFileName,
      if (panStoragePath != null) 'panStoragePath': panStoragePath,
      if (panFileName != null) 'panFileName': panFileName,
      'searchKeywords': searchKeywords.toList(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
