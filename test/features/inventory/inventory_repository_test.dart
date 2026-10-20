import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/inventory/data/inventory_repository.dart';
import 'package:aioffice/features/inventory/domain/inventory_item.dart';
import 'package:aioffice/features/inventory/domain/inventory_movement.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

InventoryItem _draft({String item = 'Uniform', String size = 'M', int opening = 20}) {
  return InventoryItem(
    id: '',
    item: item,
    size: size,
    openingStock: opening,
    reorderLevel: 5,
    targetStock: 30,
    createdBy: 'actor-1',
    createdByName: 'Actor One',
  );
}

InventoryMovement _movement(String itemId) {
  return InventoryMovement(
    id: '',
    itemId: itemId,
    itemLabel: 'Uniform (M)',
    date: DateTime(2026, 10, 20),
    type: MovementType.issueToSite,
    qty: 4,
    site: 'Site A',
    createdBy: 'actor-1',
    createdByName: 'Actor One',
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late InventoryRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = InventoryRepository(firestore: firestore, auditLog: AuditLogRepository(firestore));
  });

  test('create saves item, size and stock levels', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    expect(saved.item, 'Uniform');
    expect(saved.size, 'M');
    expect(saved.openingStock, 20);

    final stored = (await repository.watchAll().first).single;
    expect(stored.openingStock, 20);
    expect(stored.reorderLevel, 5);
    expect(stored.targetStock, 30);
  });

  test('update changes opening stock', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    final updated = InventoryItem(
      id: saved.id,
      item: saved.item,
      size: saved.size,
      openingStock: 5,
      reorderLevel: saved.reorderLevel,
      targetStock: saved.targetStock,
      createdBy: saved.createdBy,
      createdByName: saved.createdByName,
      createdAt: saved.createdAt,
    );
    await repository.update(item: updated, actorUid: 'actor-1', actorName: 'Actor One');

    final stored = await repository.watchAll().first;
    expect(stored.single.openingStock, 5);
  });

  test('addMovement and deleteMovement round-trip', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    await repository.addMovement(draft: _movement(saved.id), actorUid: 'actor-1', actorName: 'Actor One');

    final movements = await repository.watchMovements().first;
    expect(movements.single.itemId, saved.id);
    expect(movements.single.type, MovementType.issueToSite);
    expect(movements.single.site, 'Site A');

    await repository.deleteMovement(movement: movements.single, actorUid: 'actor-1', actorName: 'Actor One');
    expect(await repository.watchMovements().first, isEmpty);
  });

  test('delete removes the item with its movements and logs create+delete audit entries', () async {
    final saved = await repository.create(draft: _draft(), actorUid: 'actor-1', actorName: 'Actor One');
    await repository.addMovement(draft: _movement(saved.id), actorUid: 'actor-1', actorName: 'Actor One');
    await repository.delete(item: saved, actorUid: 'actor-1', actorName: 'Actor One');

    expect((await firestore.collection('inventory_items').get()).docs, isEmpty);
    expect((await firestore.collection('inventory_movements').get()).docs, isEmpty);
    final auditDocs = await firestore.collection('audit_log').get();
    expect(auditDocs.docs.map((d) => d.data()['action']), containsAll(['create', 'delete']));
  });
}
