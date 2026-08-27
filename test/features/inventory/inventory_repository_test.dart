import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/inventory/data/inventory_repository.dart';
import 'package:aioffice/features/inventory/domain/inventory_item.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

InventoryItem _draft({String item = 'Uniform', String size = 'M', int qty = 20}) {
  return InventoryItem(id: '', item: item, size: size, qty: qty, createdBy: 'actor-1', createdByName: 'Actor One');
}

void main() {
  late FakeFirebaseFirestore firestore;
  late InventoryRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = InventoryRepository(firestore: firestore, auditLog: AuditLogRepository(firestore));
  });

  test('create saves item, size and qty', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(saved.item, 'Uniform');
    expect(saved.size, 'M');
    expect(saved.qty, 20);

    final stored = await repository.watchAll().first;
    expect(stored.single.qty, 20);
  });

  test('update changes qty', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    final updated = InventoryItem(
      id: saved.id,
      item: saved.item,
      size: saved.size,
      qty: 5,
      createdBy: saved.createdBy,
      createdByName: saved.createdByName,
      createdAt: saved.createdAt,
    );
    await repository.update(item: updated, actorUid: 'actor-1', actorName: 'Actor One');

    final stored = await repository.watchAll().first;
    expect(stored.single.qty, 5);
  });

  test('delete removes the document and logs create+delete audit entries', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    await repository.delete(item: saved, actorUid: 'actor-1', actorName: 'Actor One');

    final remaining = await firestore.collection('inventory_items').get();
    expect(remaining.docs, isEmpty);
    final auditDocs = await firestore.collection('audit_log').get();
    expect(auditDocs.docs.map((d) => d.data()['action']), containsAll(['create', 'delete']));
  });
}
