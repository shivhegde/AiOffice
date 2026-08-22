import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../data/tender_repository.dart';
import '../domain/tender.dart';
import '../domain/tender_enums.dart';

final tenderRepositoryProvider = Provider<TenderRepository>((ref) {
  return TenderRepository(firestore: ref.watch(firestoreProvider), auditLog: ref.watch(auditLogRepositoryProvider));
});

final tenderListProvider = StreamProvider<List<Tender>>((ref) {
  return ref.watch(tenderRepositoryProvider).watchAll();
});

/// Client-side filter state for the Tender-EMD toolbar (§7.7: Tender
/// Number, Refund Status, Department), same pattern as `IoFilterState`.
class TenderFilterState {
  const TenderFilterState({this.search = '', this.refundStatus, this.department});

  final String search;
  final RefundStatus? refundStatus;
  final String? department;

  TenderFilterState copyWith({String? search, Object? refundStatus = _unset, Object? department = _unset}) {
    return TenderFilterState(
      search: search ?? this.search,
      refundStatus: refundStatus == _unset ? this.refundStatus : refundStatus as RefundStatus?,
      department: department == _unset ? this.department : department as String?,
    );
  }

  bool matches(Tender tender) {
    if (search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      final haystack = '${tender.tenderNumber} ${tender.tenderName}'.toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    if (refundStatus != null && tender.refundStatus != refundStatus) return false;
    if (department != null && department!.isNotEmpty && tender.departmentName != department) return false;
    return true;
  }
}

const _unset = Object();

final tenderFilterProvider = StateProvider((ref) => const TenderFilterState());

final filteredTenderListProvider = Provider<AsyncValue<List<Tender>>>((ref) {
  final filter = ref.watch(tenderFilterProvider);
  return ref.watch(tenderListProvider).whenData((docs) => docs.where(filter.matches).toList());
});
