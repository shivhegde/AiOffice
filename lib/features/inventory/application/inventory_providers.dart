import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_item.dart';
import '../domain/inventory_movement.dart';
import '../domain/stock_summary.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(firestore: ref.watch(firestoreProvider), auditLog: ref.watch(auditLogRepositoryProvider));
});

final inventoryListProvider = StreamProvider<List<InventoryItem>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchAll();
});

/// All movements, newest first (by date, then by entry time).
final inventoryMovementsProvider = StreamProvider<List<InventoryMovement>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchMovements().map((list) {
    final sorted = [...list];
    sorted.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now());
    });
    return sorted;
  });
});

/// Stock per item id, recomputed from items + movements.
final inventoryStockProvider = Provider<AsyncValue<Map<String, ItemStock>>>((ref) {
  final items = ref.watch(inventoryListProvider);
  final movements = ref.watch(inventoryMovementsProvider);
  if (items.hasError) return AsyncValue.error(items.error!, items.stackTrace ?? StackTrace.current);
  if (movements.hasError) return AsyncValue.error(movements.error!, movements.stackTrace ?? StackTrace.current);
  if (!items.hasValue || !movements.hasValue) return const AsyncValue.loading();
  return AsyncValue.data(computeStock(items.value!, movements.value!));
});

final inventorySearchProvider = StateProvider((ref) => '');

final filteredInventoryListProvider = Provider<AsyncValue<List<InventoryItem>>>((ref) {
  final search = ref.watch(inventorySearchProvider).trim().toLowerCase();
  return ref.watch(inventoryListProvider).whenData((docs) {
    if (search.isEmpty) return docs;
    return docs.where((i) => '${i.item} ${i.size}'.toLowerCase().contains(search)).toList();
  });
});
