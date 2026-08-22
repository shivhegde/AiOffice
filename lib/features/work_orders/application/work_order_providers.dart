import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../../inward_outward/application/io_providers.dart' show storageUploadServiceProvider;
import '../data/work_order_repository.dart';
import '../domain/work_order.dart';
import '../domain/work_order_enums.dart';

final workOrderRepositoryProvider = Provider<WorkOrderRepository>((ref) {
  return WorkOrderRepository(
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(storageUploadServiceProvider),
    auditLog: ref.watch(auditLogRepositoryProvider),
  );
});

final workOrderListProvider = StreamProvider<List<WorkOrder>>((ref) {
  return ref.watch(workOrderRepositoryProvider).watchAll();
});

/// Only work orders that have an FD recorded — backs the prototype's
/// "Fixed Deposits" tab, which is a filtered view over Work Orders rather
/// than a separate collection (see Phase 2 plan decision #1).
final fixedDepositListProvider = Provider<AsyncValue<List<WorkOrder>>>((ref) {
  return ref.watch(workOrderListProvider).whenData((all) => all.where((wo) => wo.hasFd).toList());
});

class WorkOrderFilterState {
  const WorkOrderFilterState({this.search = '', this.status});

  final String search;
  final WorkOrderStatus? status;

  WorkOrderFilterState copyWith({String? search, Object? status = _unset}) {
    return WorkOrderFilterState(
      search: search ?? this.search,
      status: status == _unset ? this.status : status as WorkOrderStatus?,
    );
  }

  bool matches(WorkOrder wo) {
    if (search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      if (!wo.workOrderNumber.toLowerCase().contains(needle)) return false;
    }
    if (status != null && wo.status != status) return false;
    return true;
  }
}

class FdFilterState {
  const FdFilterState({this.search = '', this.status});

  final String search;
  final FdStatus? status;

  FdFilterState copyWith({String? search, Object? status = _unset}) {
    return FdFilterState(search: search ?? this.search, status: status == _unset ? this.status : status as FdStatus?);
  }

  bool matches(WorkOrder wo) {
    if (search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      if (!(wo.fdNumber ?? '').toLowerCase().contains(needle)) return false;
    }
    if (status != null && wo.fdStatus != status) return false;
    return true;
  }
}

const _unset = Object();

final workOrderFilterProvider = StateProvider((ref) => const WorkOrderFilterState());
final fdFilterProvider = StateProvider((ref) => const FdFilterState());

final filteredWorkOrderListProvider = Provider<AsyncValue<List<WorkOrder>>>((ref) {
  final filter = ref.watch(workOrderFilterProvider);
  return ref.watch(workOrderListProvider).whenData((docs) => docs.where(filter.matches).toList());
});

final filteredFdListProvider = Provider<AsyncValue<List<WorkOrder>>>((ref) {
  final filter = ref.watch(fdFilterProvider);
  return ref.watch(fixedDepositListProvider).whenData((docs) => docs.where(filter.matches).toList());
});
