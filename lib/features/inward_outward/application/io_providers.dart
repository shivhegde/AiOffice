import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/storage_upload_service.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../data/io_repository.dart';
import '../domain/io_document.dart';
import '../domain/io_enums.dart';

final storageUploadServiceProvider = Provider((ref) => StorageUploadService(ref.watch(firebaseStorageProvider)));

final ioRepositoryProvider = Provider<IoRepository>((ref) {
  return IoRepository(
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(storageUploadServiceProvider),
    auditLog: ref.watch(auditLogRepositoryProvider),
  );
});

final inwardListProvider = StreamProvider<List<IoDocument>>((ref) {
  return ref.watch(ioRepositoryProvider).watchByType(IoType.inward);
});

final outwardListProvider = StreamProvider<List<IoDocument>>((ref) {
  return ref.watch(ioRepositoryProvider).watchByType(IoType.outward);
});

/// Client-side filter state for the Inward/Outward toolbars — mirrors the
/// prototype's search/department/priority/dispatch filters plus a date
/// *range* (an enhancement over the prototype's single-date filter),
/// applied over the live list providers (matches the prototype's
/// `generateIoReport` client-side filtering approach).
class IoFilterState {
  const IoFilterState({
    this.search = '',
    this.department,
    this.priority,
    this.dispatchMode,
    this.dateFrom,
    this.dateTo,
  });

  final String search;
  final String? department;
  final IoPriority? priority;
  final DispatchMode? dispatchMode;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  bool get hasDateRange => dateFrom != null || dateTo != null;

  IoFilterState copyWith({
    String? search,
    Object? department = _unset,
    Object? priority = _unset,
    Object? dispatchMode = _unset,
    Object? dateFrom = _unset,
    Object? dateTo = _unset,
  }) {
    return IoFilterState(
      search: search ?? this.search,
      department: department == _unset ? this.department : department as String?,
      priority: priority == _unset ? this.priority : priority as IoPriority?,
      dispatchMode: dispatchMode == _unset ? this.dispatchMode : dispatchMode as DispatchMode?,
      dateFrom: dateFrom == _unset ? this.dateFrom : dateFrom as DateTime?,
      dateTo: dateTo == _unset ? this.dateTo : dateTo as DateTime?,
    );
  }

  bool matches(IoDocument doc) {
    if (search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      final haystack = [
        doc.docNumber,
        doc.subject,
        doc.department,
        doc.receivedFrom,
        doc.senderCompany,
        doc.sentTo,
      ].whereType<String>().join(' ').toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    if (department != null && department!.isNotEmpty && doc.department != department) return false;
    if (priority != null && doc.priority != priority) return false;
    if (dispatchMode != null && doc.dispatchMode != dispatchMode) return false;
    if (dateFrom != null) {
      final from = DateTime(dateFrom!.year, dateFrom!.month, dateFrom!.day);
      if (doc.date.isBefore(from)) return false;
    }
    if (dateTo != null) {
      final to = DateTime(dateTo!.year, dateTo!.month, dateTo!.day, 23, 59, 59);
      if (doc.date.isAfter(to)) return false;
    }
    return true;
  }
}

const _unset = Object();

final inwardFilterProvider = StateProvider((ref) => const IoFilterState());
final outwardFilterProvider = StateProvider((ref) => const IoFilterState());

final filteredInwardListProvider = Provider<AsyncValue<List<IoDocument>>>((ref) {
  final filter = ref.watch(inwardFilterProvider);
  return ref.watch(inwardListProvider).whenData((docs) => docs.where(filter.matches).toList());
});

final filteredOutwardListProvider = Provider<AsyncValue<List<IoDocument>>>((ref) {
  final filter = ref.watch(outwardFilterProvider);
  return ref.watch(outwardListProvider).whenData((docs) => docs.where(filter.matches).toList());
});
