import 'package:aioffice/app/theme/app_theme.dart';
import 'package:aioffice/features/employees/application/employee_providers.dart';
import 'package:aioffice/features/employees/domain/employee.dart';
import 'package:aioffice/features/employees/domain/employee_enums.dart';
import 'package:aioffice/features/inventory/application/inventory_providers.dart';
import 'package:aioffice/features/inventory/domain/inventory_item.dart';
import 'package:aioffice/features/inventory/domain/inventory_movement.dart';
import 'package:aioffice/features/inventory/presentation/widgets/inventory_holdings_tab.dart';
import 'package:aioffice/features/inventory/presentation/widgets/inventory_sites_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _ravi = Employee(
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

InventoryItem _item(String id, String name) => InventoryItem(
  id: id,
  item: name,
  size: '',
  openingStock: 20,
  reorderLevel: 2,
  targetStock: 20,
  createdBy: 'actor-1',
  createdByName: 'Actor One',
);

InventoryMovement _move(
  String itemId,
  MovementType type,
  int qty, {
  required String employeeDocId,
  String site = 'Site A',
  String employeeId = '',
  String employeeName = '',
}) => InventoryMovement(
  id: '',
  itemId: itemId,
  itemLabel: itemId,
  date: DateTime(2026, 10, 1),
  type: type,
  qty: qty,
  site: site,
  employeeDocId: employeeDocId,
  employeeId: employeeId,
  employeeName: employeeName,
  createdBy: 'actor-1',
  createdByName: 'Actor One',
);

void main() {
  testWidgets('lists each employee holding stock, with a column per item', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeListProvider.overrideWith((ref) => Stream.value([_ravi])),
          inventoryListProvider.overrideWith((ref) => Stream.value([_item('shirt', 'Shirt'), _item('cap', 'Cap')])),
          inventoryMovementsProvider.overrideWith(
            (ref) => Stream.value([
              _move('shirt', MovementType.issueToSite, 3, employeeDocId: 'emp-1'),
              _move('shirt', MovementType.lost, 1, employeeDocId: 'emp-1'),
              _move('cap', MovementType.issueToSite, 1, employeeDocId: 'emp-1'),
              // Deleted employee: details come from their movement.
              _move(
                'cap',
                MovementType.issueToSite,
                2,
                employeeDocId: 'gone',
                employeeId: 'EMP/2025/0009',
                employeeName: 'Old Hand',
              ),
              // Returned everything: not listed.
              _move('shirt', MovementType.issueToSite, 1, employeeDocId: 'emp-3', employeeName: 'Zero'),
              _move('shirt', MovementType.returnFromSite, 1, employeeDocId: 'emp-3', employeeName: 'Zero'),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SingleChildScrollView(child: InventoryHoldingsTab())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final header in ['Employee ID', 'Employee Name', 'Site', 'Role', 'Shirt', 'Cap', 'Total']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    final table = tester.widget<DataTable>(find.byType(DataTable));
    List<String> cells(DataRow row) => [for (final c in row.cells) (c.child as Text).data!];
    expect(table.rows.map(cells).toList(), [
      ['1', 'EMP/2025/0009', 'Old Hand', 'Site A', '—', '0', '2', '2'],
      ['2', 'EMP/2026/0001', 'Ravi Kumar', 'Site A', 'Guard', '2', '1', '3'],
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Site Holdings lists each site with a column per item, blank site last', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryListProvider.overrideWith((ref) => Stream.value([_item('shirt', 'Shirt'), _item('cap', 'Cap')])),
          inventoryMovementsProvider.overrideWith(
            (ref) => Stream.value([
              _move('shirt', MovementType.issueToSite, 3, employeeDocId: 'a', site: 'Site B'),
              _move('cap', MovementType.issueToSite, 1, employeeDocId: 'b', site: 'Site A'),
              // Two employees with no Site: grouped on one blank row.
              _move('shirt', MovementType.issueToSite, 2, employeeDocId: 'c', site: ''),
              _move('cap', MovementType.issueToSite, 4, employeeDocId: 'd', site: ''),
              // Fully returned: not listed.
              _move('shirt', MovementType.issueToSite, 1, employeeDocId: 'e', site: 'Site C'),
              _move('shirt', MovementType.returnFromSite, 1, employeeDocId: 'e', site: 'Site C'),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SingleChildScrollView(child: InventorySitesTab())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Site Holdings'), findsOneWidget);
    final table = tester.widget<DataTable>(find.byType(DataTable));
    List<String> cells(DataRow row) => [for (final c in row.cells) (c.child as Text).data!];
    expect([for (final c in table.columns) (c.label as Text).data], ['S.No.', 'Site', 'Shirt', 'Cap', 'Total']);
    expect(table.rows.map(cells).toList(), [
      ['1', 'Site A', '0', '1', '1'],
      ['2', 'Site B', '3', '0', '3'],
      ['3', '', '2', '4', '6'],
    ]);
    expect(tester.takeException(), isNull);
  });
}
