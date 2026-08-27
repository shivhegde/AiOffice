import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../../inward_outward/application/io_providers.dart' show storageUploadServiceProvider;
import '../data/epf_case_repository.dart';
import '../domain/epf_case.dart';
import '../domain/epf_enums.dart';

final epfCaseRepositoryProvider = Provider<EpfCaseRepository>((ref) {
  return EpfCaseRepository(
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(storageUploadServiceProvider),
    auditLog: ref.watch(auditLogRepositoryProvider),
  );
});

final epfCaseListProvider = StreamProvider<List<EpfCase>>((ref) {
  return ref.watch(epfCaseRepositoryProvider).watchAll();
});

class EpfCaseFilterState {
  const EpfCaseFilterState({this.search = '', this.stage});

  final String search;
  final CaseStage? stage;

  EpfCaseFilterState copyWith({String? search, Object? stage = _unset}) {
    return EpfCaseFilterState(search: search ?? this.search, stage: stage == _unset ? this.stage : stage as CaseStage?);
  }

  bool matches(EpfCase c) {
    if (search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      final haystack = '${c.name} ${c.mobile} ${c.aadhaarNumber} ${c.panNumber} ${c.uanNumber}'.toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    if (stage != null && c.stage != stage) return false;
    return true;
  }
}

const _unset = Object();

final epfCaseFilterProvider = StateProvider((ref) => const EpfCaseFilterState());

final filteredEpfCaseListProvider = Provider<AsyncValue<List<EpfCase>>>((ref) {
  final filter = ref.watch(epfCaseFilterProvider);
  return ref.watch(epfCaseListProvider).whenData((docs) => docs.where(filter.matches).toList());
});
