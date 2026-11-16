import 'package:aioffice/app/theme/app_theme.dart';
import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/employees/application/employee_providers.dart';
import 'package:aioffice/features/employees/domain/employee.dart';
import 'package:aioffice/features/employees/domain/employee_enums.dart';
import 'package:aioffice/features/inventory/application/inventory_providers.dart';
import 'package:aioffice/features/inventory/data/inventory_repository.dart';
import 'package:aioffice/features/inventory/domain/inventory_item.dart';
import 'package:aioffice/features/inventory/domain/inventory_movement.dart';
import 'package:aioffice/features/inventory/domain/stock_summary.dart';
import 'package:aioffice/features/inventory/presentation/movement_form_slideover.dart';
import 'package:aioffice/features/users/application/user_providers.dart';
import 'package:aioffice/shared/widgets/slideover_panel.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _employee = Employee(
  id: 'emp-1',
  employeeId: 'EMP/2026/0001',
  year: 2026,
  fullName: 'Ravi Kumar',
  gender: Gender.male,
  dateOfBirth: DateTime(1992, 3, 14),
  mobileNumber: '9845066210',
  dateOfAppointment: DateTime(2026, 1, 5),
  joiningDate: DateTime(2026, 1, 5),
  department: 'Operations',
  designation: 'Supervisor',
  employeeType: EmployeeType.permanent,
  workStatus: WorkStatus.active,
  role: 'Guard',
  site: 'Site A',
  createdBy: 'actor-1',
  createdByName: 'Actor One',
);

InventoryItem _item({int openingStock = 10}) => InventoryItem(
  id: 'item-1',
  item: 'Shirt',
  size: 'M',
  openingStock: openingStock,
  reorderLevel: 2,
  targetStock: 10,
  createdBy: 'actor-1',
  createdByName: 'Actor One',
);

/// Opens the movement form on [type] with one item already picked, and
/// returns the Firestore the form saves to.
Future<FakeFirebaseFirestore> _openForm(
  WidgetTester tester,
  MovementType type, {
  int openingStock = 10,
  List<InventoryMovement> movements = const [],
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final firestore = FakeFirebaseFirestore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
        employeeListProvider.overrideWith((ref) => Stream.value([_employee])),
        inventoryListProvider.overrideWith((ref) => Stream.value([_item(openingStock: openingStock)])),
        inventoryMovementsProvider.overrideWith((ref) => Stream.value(movements)),
        inventoryRepositoryProvider.overrideWithValue(
          InventoryRepository(firestore: firestore, auditLog: AuditLogRepository(firestore)),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => MovementFormSlideover.show(context, initialType: type),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Select item'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Shirt (M)').last);
  await tester.pumpAndSettle();
  return firestore;
}

Future<List<Map<String, dynamic>>> _saved(FakeFirebaseFirestore firestore) async =>
    (await firestore.collection('inventory_movements').get()).docs.map((d) => d.data()).toList();

Future<void> _pickEmployee(WidgetTester tester) async {
  final employeeField = find.byType(DropdownMenu<String>);
  await tester.tap(find.descendant(of: employeeField, matching: find.byType(TextField)));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(MenuItemButton, 'Ravi Kumar (EMP/2026/0001)').last);
  await tester.pumpAndSettle();
}

InventoryMovement _issued({required String employeeDocId, required int qty}) => InventoryMovement(
  id: 'm-$employeeDocId',
  itemId: 'item-1',
  itemLabel: 'Shirt (M)',
  date: DateTime(2026, 10, 1),
  type: MovementType.issueToSite,
  qty: qty,
  site: 'Site A',
  employeeDocId: employeeDocId,
  createdBy: 'actor-1',
  createdByName: 'Actor One',
);

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Issue to Employee shows the picked employee read-only and saves them with their site', (tester) async {
    final firestore = await _openForm(tester, MovementType.issueToSite);

    expect(find.text('Employee Name'), findsOneWidget);
    expect(find.text('Site / Guard'), findsNothing);

    final employeeField = find.byType(DropdownMenu<String>);
    await tester.tap(find.descendant(of: employeeField, matching: find.byType(TextField)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Ravi Kumar (EMP/2026/0001)').last);
    await tester.pumpAndSettle();

    // Employee ID, Site and Role fill in, read-only.
    expect(find.widgetWithText(InputDecorator, 'EMP/2026/0001'), findsOneWidget);
    expect(find.widgetWithText(InputDecorator, 'Site A'), findsOneWidget);
    expect(find.widgetWithText(InputDecorator, 'Guard'), findsOneWidget);

    await _save(tester);
    final saved = (await _saved(firestore)).single;
    expect(saved['type'], 'issue_to_site');
    expect(saved['site'], 'Site A');
    expect(saved['employeeDocId'], 'emp-1');
    expect(saved['employeeId'], 'EMP/2026/0001');
    expect(saved['employeeName'], 'Ravi Kumar');
    expect(saved['employeeRole'], 'Guard');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Received in Store hides the employee fields', (tester) async {
    final firestore = await _openForm(tester, MovementType.received);
    expect(find.text('Employee Name'), findsNothing);
    expect(find.text('Employee Name (if any)'), findsNothing);
    expect(find.text('Employee ID'), findsNothing);
    expect(find.text('Site'), findsNothing);
    expect(find.text('Role'), findsNothing);

    await _save(tester);
    final saved = (await _saved(firestore)).single;
    expect(saved['type'], 'received');
    expect(saved['employeeDocId'], '');
    expect(saved['site'], '');
  });

  for (final type in [MovementType.issueToSite, MovementType.returnFromSite]) {
    testWidgets('${type.label} cannot be saved without an employee', (tester) async {
      final firestore = await _openForm(tester, type);
      await _save(tester);
      expect(find.text('Select the employee.'), findsOneWidget);
      expect(await _saved(firestore), isEmpty);
    });
  }

  testWidgets('Damaged with no employee comes off store stock', (tester) async {
    final firestore = await _openForm(tester, MovementType.damaged);
    expect(find.text('Employee Name (if any)'), findsOneWidget);

    await _save(tester);
    final saved = (await _saved(firestore)).single;
    expect(saved['site'], '');
    final stock = computeStock([_item()], [InventoryMovement.fromMap('m1', saved)])['item-1']!;
    expect(stock.inStore, 9);
    expect(stock.damaged, 1);
  });

  testWidgets('Lost with no employee is refused when the store has no stock', (tester) async {
    final firestore = await _openForm(tester, MovementType.lost, openingStock: 0);
    await _save(tester);
    expect(find.text('Only 0 Shirt (M) available in store.'), findsOneWidget);
    expect(await _saved(firestore), isEmpty);
  });

  testWidgets('Damaged with an employee comes off that employee\'s own stock', (tester) async {
    // Site A holds 5, but only 2 of them are with Ravi.
    final firestore = await _openForm(
      tester,
      MovementType.damaged,
      movements: [
        _issued(employeeDocId: 'emp-1', qty: 2),
        _issued(employeeDocId: 'emp-2', qty: 3),
      ],
    );
    await _pickEmployee(tester);
    expect(find.text('Available with Ravi Kumar: 2'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '1'), '3');
    await _save(tester);
    expect(find.text('Only 2 Shirt (M) available with Ravi Kumar.'), findsOneWidget);
    expect(await _saved(firestore), isEmpty);

    await tester.enterText(find.widgetWithText(TextField, '3'), '2');
    await _save(tester);
    final saved = (await _saved(firestore)).single;
    expect(saved['employeeDocId'], 'emp-1');
    expect(saved['site'], 'Site A');
  });

  testWidgets('Damaged with a typed Site comes off that site and the main store', (tester) async {
    // Site A holds 5 (from store's 10), none of it with a linked employee.
    final firestore = await _openForm(tester, MovementType.damaged, movements: [_issued(employeeDocId: '', qty: 5)]);
    await tester.enterText(find.widgetWithText(TextField, 'Blank = main store'), 'Site A');
    await tester.pumpAndSettle();
    final roleField = find.descendant(of: find.widgetWithText(FormRowLabel, 'Role'), matching: find.byType(TextField));
    await tester.enterText(roleField, 'Guard');
    await _save(tester);

    final saved = (await _saved(firestore)).single;
    expect(saved['site'], 'Site A');
    expect(saved['employeeRole'], 'Guard');
    expect(saved['writeOffFromStore'], true);
    final stock = computeStock(
      [_item()],
      [_issued(employeeDocId: '', qty: 5), InventoryMovement.fromMap('m1', saved)],
    )['item-1']!;
    expect(stock.atSite['Site A'], 4);
    expect(stock.inStore, 4);
    expect(stock.damaged, 1);
  });

  testWidgets('Picking an employee pre-fills the editable Site and Role on Damaged', (tester) async {
    await _openForm(tester, MovementType.damaged, movements: [_issued(employeeDocId: 'emp-1', qty: 2)]);
    await _pickEmployee(tester);
    expect(find.widgetWithText(TextField, 'Site A'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Guard'), findsOneWidget);
  });

  group('editing', () {
    InventoryMovement received(int qty) => InventoryMovement(
      id: 'r1',
      itemId: 'item-1',
      itemLabel: 'Shirt (M)',
      date: DateTime(2026, 10, 1),
      type: MovementType.received,
      qty: qty,
      note: 'Supplier X',
      createdBy: 'actor-1',
      createdByName: 'Actor One',
    );

    Future<FakeFirebaseFirestore> openEdit(
      WidgetTester tester,
      InventoryMovement existing, {
      List<InventoryMovement> others = const [],
      int openingStock = 0,
    }) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('inventory_movements').doc(existing.id).set(existing.toMap());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
            employeeListProvider.overrideWith((ref) => Stream.value([_employee])),
            inventoryListProvider.overrideWith((ref) => Stream.value([_item(openingStock: openingStock)])),
            inventoryMovementsProvider.overrideWith((ref) => Stream.value([existing, ...others])),
            inventoryRepositoryProvider.overrideWithValue(
              InventoryRepository(firestore: firestore, auditLog: AuditLogRepository(firestore)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => MovementFormSlideover.show(context, existing: existing),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return firestore;
    }

    testWidgets('opens pre-filled and saves the correction over the same record', (tester) async {
      final firestore = await openEdit(tester, received(5));
      expect(find.text('Edit Movement'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Supplier X'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '5'), '8');
      await _save(tester);

      final saved = await _saved(firestore);
      expect(saved, hasLength(1));
      expect(saved.single['qty'], 8);
      expect(saved.single['createdBy'], 'actor-1');
      expect(find.text('Movement updated.'), findsOneWidget);
    });

    testWidgets('keeps the original employee and site when only the quantity changes', (tester) async {
      final issued = _issued(employeeDocId: 'emp-1', qty: 2);
      final firestore = await openEdit(
        tester,
        InventoryMovement(
          id: issued.id,
          itemId: issued.itemId,
          itemLabel: issued.itemLabel,
          date: issued.date,
          type: issued.type,
          qty: 2,
          site: 'Old Site',
          employeeDocId: 'emp-1',
          employeeId: 'EMP/2026/0001',
          employeeName: 'Ravi Kumar',
          employeeRole: 'Guard',
          createdBy: 'actor-1',
          createdByName: 'Actor One',
        ),
        openingStock: 10,
      );
      await tester.enterText(find.widgetWithText(TextField, '2'), '3');
      await _save(tester);

      final saved = (await _saved(firestore)).single;
      expect(saved['qty'], 3);
      expect(saved['employeeDocId'], 'emp-1');
      expect(saved['site'], 'Old Site');
    });

    testWidgets('refuses an edit that would leave later movements without stock', (tester) async {
      // 5 received, 4 of them issued afterwards: the receipt can't drop to 3.
      final firestore = await openEdit(tester, received(5), others: [_issued(employeeDocId: 'emp-1', qty: 4)]);
      await tester.enterText(find.widgetWithText(TextField, '5'), '3');
      await _save(tester);

      expect(find.textContaining('Cannot save'), findsOneWidget);
      expect((await _saved(firestore)).single['qty'], 5);
    });
  });
}
