import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/department_repository.dart';
import '../domain/department.dart';

final departmentRepositoryProvider = Provider<DepartmentRepository>((ref) {
  return DepartmentRepository(firestore: ref.watch(firestoreProvider));
});

final departmentListProvider = StreamProvider<List<Department>>((ref) {
  return ref.watch(departmentRepositoryProvider).watchAll();
});
