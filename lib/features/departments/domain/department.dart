import 'package:cloud_firestore/cloud_firestore.dart';

/// A shared "Department" master-data entry. Not curated up front — the
/// table is built up as users enter department names on Work Orders (and
/// any other module wired to `DepartmentRepository.ensureExists`).
class Department {
  const Department({required this.id, required this.name, this.createdBy, this.createdAt});

  final String id;
  final String name;
  final String? createdBy;
  final DateTime? createdAt;

  factory Department.fromMap(String id, Map<String, dynamic> data) {
    return Department(
      id: id,
      name: data['name'] as String? ?? '',
      createdBy: data['createdBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
