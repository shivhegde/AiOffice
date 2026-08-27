import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../../inward_outward/application/io_providers.dart' show storageUploadServiceProvider;
import '../data/vehicle_policy_repository.dart';
import '../domain/vehicle_insurance_enums.dart';
import '../domain/vehicle_policy.dart';

final vehiclePolicyRepositoryProvider = Provider<VehiclePolicyRepository>((ref) {
  return VehiclePolicyRepository(
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(storageUploadServiceProvider),
    auditLog: ref.watch(auditLogRepositoryProvider),
  );
});

final vehiclePolicyListProvider = StreamProvider<List<VehiclePolicy>>((ref) {
  return ref.watch(vehiclePolicyRepositoryProvider).watchAll();
});

/// Backs the "Renewals" tab — policies due within 60 days, i.e. the
/// §9.4 "generate a daily follow-up list" requirement.
final renewalsDueListProvider = Provider<AsyncValue<List<VehiclePolicy>>>((ref) {
  return ref.watch(vehiclePolicyListProvider).whenData((all) => all.where((p) => p.isExpiringWithin(60)).toList());
});

class PolicyFilterState {
  const PolicyFilterState({this.search = '', this.status});

  final String search;
  final PolicyStatus? status;

  PolicyFilterState copyWith({String? search, Object? status = _unset}) {
    return PolicyFilterState(
      search: search ?? this.search,
      status: status == _unset ? this.status : status as PolicyStatus?,
    );
  }

  bool matches(VehiclePolicy p) {
    if (search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      final haystack = '${p.vehicleNumber} ${p.customerName} ${p.customerMobile} ${p.policyNumber}'.toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    if (status != null && p.status != status) return false;
    return true;
  }
}

const _unset = Object();

final policyFilterProvider = StateProvider((ref) => const PolicyFilterState());

final filteredPolicyListProvider = Provider<AsyncValue<List<VehiclePolicy>>>((ref) {
  final filter = ref.watch(policyFilterProvider);
  return ref.watch(vehiclePolicyListProvider).whenData((docs) => docs.where(filter.matches).toList());
});
