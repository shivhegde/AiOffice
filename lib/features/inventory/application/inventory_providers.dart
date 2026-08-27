import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(firestore: ref.watch(firestoreProvider), auditLog: ref.watch(auditLogRepositoryProvider));
});

final inventoryListProvider = StreamProvider<List<InventoryItem>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchAll();
});

final inventorySearchProvider = StateProvider((ref) => '');

final filteredInventoryListProvider = Provider<AsyncValue<List<InventoryItem>>>((ref) {
  final search = ref.watch(inventorySearchProvider).trim().toLowerCase();
  return ref.watch(inventoryListProvider).whenData((docs) {
    if (search.isEmpty) return docs;
    return docs.where((i) => i.item.toLowerCase().contains(search)).toList();
  });
});
