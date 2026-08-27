import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../../inward_outward/application/io_providers.dart' show storageUploadServiceProvider;
import '../data/candidate_repository.dart';
import '../domain/candidate.dart';
import '../domain/candidate_enums.dart';

final candidateRepositoryProvider = Provider<CandidateRepository>((ref) {
  return CandidateRepository(
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(storageUploadServiceProvider),
    auditLog: ref.watch(auditLogRepositoryProvider),
  );
});

final candidateListProvider = StreamProvider<List<Candidate>>((ref) {
  return ref.watch(candidateRepositoryProvider).watchAll();
});

class CandidateFilterState {
  const CandidateFilterState({this.search = '', this.category});

  final String search;
  final CandidateCategory? category;

  CandidateFilterState copyWith({String? search, Object? category = _unset}) {
    return CandidateFilterState(
      search: search ?? this.search,
      category: category == _unset ? this.category : category as CandidateCategory?,
    );
  }

  bool matches(Candidate c) {
    if (search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      final haystack = '${c.fullName} ${c.candidateId} ${c.district} ${c.taluk}'.toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    if (category != null && c.category != category) return false;
    return true;
  }
}

const _unset = Object();

final candidateFilterProvider = StateProvider((ref) => const CandidateFilterState());

final filteredCandidateListProvider = Provider<AsyncValue<List<Candidate>>>((ref) {
  final filter = ref.watch(candidateFilterProvider);
  return ref.watch(candidateListProvider).whenData((docs) => docs.where(filter.matches).toList());
});
