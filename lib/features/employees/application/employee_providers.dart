import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../../inward_outward/application/io_providers.dart' show storageUploadServiceProvider;
import '../data/employee_repository.dart';
import '../domain/employee.dart';
import '../domain/employee_enums.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(storageUploadServiceProvider),
    auditLog: ref.watch(auditLogRepositoryProvider),
  );
});

final employeeListProvider = StreamProvider<List<Employee>>((ref) {
  return ref.watch(employeeRepositoryProvider).watchAll();
});

class EmployeeFilterState {
  const EmployeeFilterState({this.search = '', this.workStatus, this.department});

  final String search;
  final WorkStatus? workStatus;
  final String? department;

  EmployeeFilterState copyWith({String? search, Object? workStatus = _unset, Object? department = _unset}) {
    return EmployeeFilterState(
      search: search ?? this.search,
      workStatus: workStatus == _unset ? this.workStatus : workStatus as WorkStatus?,
      department: department == _unset ? this.department : department as String?,
    );
  }

  bool matches(Employee e) {
    if (search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      final haystack = '${e.fullName} ${e.employeeId} ${e.mobileNumber} ${e.aadhaarNumber}'.toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    if (workStatus != null && e.workStatus != workStatus) return false;
    if (department != null && department!.isNotEmpty && e.department != department) return false;
    return true;
  }
}

const _unset = Object();

final employeeFilterProvider = StateProvider((ref) => const EmployeeFilterState());

final filteredEmployeeListProvider = Provider<AsyncValue<List<Employee>>>((ref) {
  final filter = ref.watch(employeeFilterProvider);
  return ref.watch(employeeListProvider).whenData((docs) => docs.where(filter.matches).toList());
});
