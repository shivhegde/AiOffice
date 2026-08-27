import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../audit/data/audit_log_repository.dart';
import '../../audit/domain/audit_entry.dart';
import '../domain/inventory_item.dart';

/// Inventory CRUD (REQUIREMENTS.md §9.3) — no document numbering or file
/// uploads, unlike the other modules, since the source spec defines no
/// Item ID or document upload for this module (see [InventoryItem] doc
/// comment). Same "always build the final record directly via its
/// constructor" convention as every other repository in this app.
class InventoryRepository {
  InventoryRepository({required FirebaseFirestore firestore, required AuditLogRepository auditLog})
    : _firestore = firestore,
      _auditLog = auditLog;

  final FirebaseFirestore _firestore;
  final AuditLogRepository _auditLog;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.inventoryItems);

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
      qty: draft.qty,
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
      targetLabel: '${draft.item} (${draft.size})',
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
      targetLabel: '${item.item} (${item.size})',
    );
  }

  Future<void> delete({required InventoryItem item, required String actorUid, required String actorName}) async {
    await _collection.doc(item.id).delete();
    await _auditLog.log(
      actorUid: actorUid,
      actorName: actorName,
      action: AuditAction.delete,
      module: 'inventory',
      targetId: item.id,
      targetLabel: '${item.item} (${item.size})',
    );
  }
}
