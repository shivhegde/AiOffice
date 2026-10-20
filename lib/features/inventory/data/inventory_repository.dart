import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/date_formatting.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
import '../domain/inventory_item.dart';
import '../domain/inventory_movement.dart';

/// Inventory items + their stock-movement ledger. No document numbering or
/// file uploads. Same "always build the final record directly via its
/// constructor" convention as every other repository in this app.
class InventoryRepository {
  InventoryRepository({required FirebaseFirestore firestore, required AuditLogRepository auditLog})
    : _firestore = firestore,
      _auditLog = auditLog;

  final FirebaseFirestore _firestore;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.inventoryItems);
  CollectionReference<Map<String, dynamic>> get _movements => _firestore.collection(FirestorePaths.inventoryMovements);

  Stream<List<InventoryItem>> watchAll() {
    return _collection
        .orderBy('item')
        .snapshots()
        .map((snap) => snap.docs.map((d) => InventoryItem.fromMap(d.id, d.data())).toList());
  }

  Future<InventoryItem> create({
    required InventoryItem draft,
    required String actorUid,
    required String actorName,
  }) async {
    final docRef = _collection.doc();
    final toSave = InventoryItem(
      id: docRef.id,
      item: draft.item,
      size: draft.size,
      openingStock: draft.openingStock,
      reorderLevel: draft.reorderLevel,
      targetStock: draft.targetStock,
      createdBy: actorUid,
      createdByName: actorName,
    );

    await docRef.set(toSave.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.create,
      module: 'inventory',
      targetId: docRef.id,
      targetLabel: draft.displayName,
    );

    return toSave;
  }

  Future<void> update({required InventoryItem item, required String actorUid, required String actorName}) async {
    await _collection.doc(item.id).update(item.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.update,
      module: 'inventory',
      targetId: item.id,
      targetLabel: item.displayName,
    );
  }

  /// Deletes the item and its whole movement history.
  Future<void> delete({required InventoryItem item, required String actorUid, required String actorName}) async {
    final movements = await _movements.where('itemId', isEqualTo: item.id).get();
    if (movements.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final m in movements.docs) {
        batch.delete(m.reference);
      }
      await batch.commit();
    }
    await _collection.doc(item.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'inventory',
      targetId: item.id,
      targetLabel: item.displayName,
    );
  }

  // ---- Movements ----

  /// Every movement; callers sort and group client-side.
  Stream<List<InventoryMovement>> watchMovements() {
    return _movements.snapshots().map(
      (snap) => snap.docs.map((d) => InventoryMovement.fromMap(d.id, d.data())).toList(),
    );
  }

  Future<void> addMovement({
    required InventoryMovement draft,
    required String actorUid,
    required String actorName,
  }) async {
    final ref = _movements.doc();
    final movement = InventoryMovement(
      id: ref.id,
      itemId: draft.itemId,
      itemLabel: draft.itemLabel,
      date: draft.date,
      type: draft.type,
      qty: draft.qty,
      site: draft.site,
      note: draft.note,
      createdBy: actorUid,
      createdByName: actorName,
    );
    await ref.set(movement.toMap());
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.create,
      module: 'inventory',
      targetId: draft.itemId,
      targetLabel: '${draft.itemLabel} — ${draft.type.label} ${draft.qty} (${formatDisplayDate(draft.date)})',
    );
  }

  Future<void> deleteMovement({
    required InventoryMovement movement,
    required String actorUid,
    required String actorName,
  }) async {
    await _movements.doc(movement.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'inventory',
      targetId: movement.itemId,
      targetLabel:
          '${movement.itemLabel} — ${movement.type.label} ${movement.qty} (${formatDisplayDate(movement.date)}) removed',
    );
  }
}
