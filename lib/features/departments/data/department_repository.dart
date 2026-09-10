import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/department.dart';

/// Shared Department master list backing the "select existing or add new"
/// picker on Work Orders & FD (and any future module that adopts it).
class DepartmentRepository {
  DepartmentRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.departments);

  Stream<List<Department>> watchAll() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Department.fromMap(d.id, d.data())).toList());
  }

  /// Adds [name] to the department table unless an entry already matches
  /// it case-insensitively. No-op for a blank name.
  Future<void> ensureExists({required String name, required String actorUid}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final normalized = trimmed.toLowerCase();
    final existing = await _collection.where('nameLower', isEqualTo: normalized).limit(1).get();
    if (existing.docs.isNotEmpty) return;
    await _collection.add({
      'name': trimmed,
      'nameLower': normalized,
      'createdBy': actorUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
