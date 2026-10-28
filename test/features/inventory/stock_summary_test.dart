import 'package:aioffice/features/inventory/domain/inventory_item.dart';
import 'package:aioffice/features/inventory/domain/inventory_movement.dart';
import 'package:aioffice/features/inventory/domain/stock_summary.dart';
import 'package:flutter_test/flutter_test.dart';

InventoryItem _item(String id, {int opening = 0, int reorder = 5, int target = 20}) => InventoryItem(
  id: id,
  item: 'Shirt',
  size: 'M',
  openingStock: opening,
  reorderLevel: reorder,
  targetStock: target,
  createdBy: 'u',
  createdByName: 'U',
);

InventoryMovement _move(String itemId, MovementType type, int qty, {String site = '', String employee = ''}) =>
    InventoryMovement(
      id: '',
      itemId: itemId,
      itemLabel: 'Shirt (M)',
      date: DateTime(2026, 10, 20),
      type: type,
      qty: qty,
      site: site,
      employeeDocId: employee,
      createdBy: 'u',
      createdByName: 'U',
    );

void main() {
  test('an employee with no site holds and writes off their own stock', () {
    final stock = computeStock(
      [_item('a', opening: 10)],
      [
        _move('a', MovementType.issueToSite, 3, employee: 'ravi'),
        _move('a', MovementType.damaged, 1, employee: 'ravi'),
      ],
    )['a']!;
    expect(stock.inStore, 7);
    expect(stock.withEmployee, {'ravi': 2});
    expect(stock.atSite, {'': 2});
    expect(stock.damaged, 1);
    expect(stock.availableFor(MovementType.lost, '', employeeDocId: 'ravi'), 2);
  });

  test('tracks stock per employee alongside their site', () {
    final stock = computeStock(
      [_item('a', opening: 10)],
      [
        _move('a', MovementType.issueToSite, 2, site: 'Site A', employee: 'ravi'),
        _move('a', MovementType.issueToSite, 3, site: 'Site A', employee: 'mohan'),
        _move('a', MovementType.lost, 1, site: 'Site A', employee: 'mohan'),
        _move('a', MovementType.returnFromSite, 1, site: 'Site A', employee: 'ravi'),
        // Recorded before movements were linked to employees.
        _move('a', MovementType.issueToSite, 4, site: 'Site A'),
      ],
    )['a']!;

    expect(stock.withEmployee, {'ravi': 1, 'mohan': 2});
    expect(stock.atSite, {'Site A': 2 + 3 - 1 - 1 + 4});
    expect(stock.inStore, 10 - 2 - 3 + 1 - 4);
    expect(stock.lost, 1);

    // Damaged / Lost / Return with an employee draw on that employee's own
    // stock, not the site total.
    expect(stock.availableFor(MovementType.damaged, 'Site A', employeeDocId: 'ravi'), 1);
    expect(stock.availableFor(MovementType.lost, 'Site A', employeeDocId: 'mohan'), 2);
    expect(stock.availableFor(MovementType.returnFromSite, 'Site A', employeeDocId: 'nobody'), 0);
    expect(stock.availableFor(MovementType.damaged, '', employeeDocId: ''), 2);
    expect(stock.availableFor(MovementType.issueToSite, 'Site A', employeeDocId: 'ravi'), 2);
  });

  test('replays receipts, issues, returns and write-offs', () {
    final stock = computeStock(
      [_item('a', opening: 10)],
      [
        _move('a', MovementType.received, 30),
        _move('a', MovementType.issueToSite, 12, site: 'Site A'),
        _move('a', MovementType.issueToSite, 5, site: 'Site B'),
        _move('a', MovementType.returnFromSite, 2, site: 'Site A'),
        _move('a', MovementType.damaged, 1, site: 'Site A'),
        _move('a', MovementType.damaged, 3),
        _move('a', MovementType.lost, 1, site: 'Site B'),
      ],
    )['a']!;

    expect(stock.inStore, 10 + 30 - 12 - 5 + 2 - 3);
    expect(stock.atSite, {'Site A': 12 - 2 - 1, 'Site B': 5 - 1});
    expect(stock.atSitesTotal, 13);
    expect(stock.damaged, 4);
    expect(stock.lost, 1);
  });

  test('flags reorder at or below the level and orders up to target', () {
    final stock = computeStock([_item('a', opening: 5), _item('b', opening: 6)], const []);
    expect(stock['a']!.needsReorder, isTrue);
    expect(stock['a']!.orderQty, 15);
    expect(stock['b']!.needsReorder, isFalse);
  });

  test('availableFor reports what each movement can draw on', () {
    final stock = computeStock(
      [_item('a', opening: 10)],
      [_move('a', MovementType.issueToSite, 4, site: 'Site A')],
    )['a']!;
    expect(stock.availableFor(MovementType.received, ''), isNull);
    expect(stock.availableFor(MovementType.issueToSite, 'Site B'), 6);
    expect(stock.availableFor(MovementType.returnFromSite, 'Site A'), 4);
    expect(stock.availableFor(MovementType.returnFromSite, 'Site B'), 0);
    expect(stock.availableFor(MovementType.damaged, ''), 6);
    expect(stock.availableFor(MovementType.lost, 'Site A'), 4);
  });

  test('hasNegative catches store or site below zero', () {
    final ok = computeStock([_item('a', opening: 3)], [_move('a', MovementType.issueToSite, 3, site: 'S')]);
    expect(ok['a']!.hasNegative, isFalse);
    final store = computeStock([_item('a', opening: 3)], [_move('a', MovementType.issueToSite, 4, site: 'S')]);
    expect(store['a']!.hasNegative, isTrue);
    final site = computeStock([_item('a', opening: 3)], [_move('a', MovementType.returnFromSite, 1, site: 'S')]);
    expect(site['a']!.hasNegative, isTrue);
  });

  test('ignores movements for deleted items', () {
    final stock = computeStock([_item('a')], [_move('gone', MovementType.received, 9)]);
    expect(stock.keys, ['a']);
    expect(stock['a']!.inStore, 0);
  });

  test('reads pre-redesign qty as opening stock', () {
    final item = InventoryItem.fromMap('x', {'item': 'Cap', 'size': 'L', 'qty': 7});
    expect(item.openingStock, 7);
    expect(item.displayName, 'Cap (L)');
  });

  test('sitesOf lists each named site once, sorted', () {
    expect(
      sitesOf([
        _move('a', MovementType.issueToSite, 1, site: 'beta'),
        _move('a', MovementType.issueToSite, 1, site: 'Alpha'),
        _move('a', MovementType.returnFromSite, 1, site: 'beta'),
        _move('a', MovementType.received, 1),
      ]),
      ['Alpha', 'beta'],
    );
  });
}
