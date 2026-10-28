import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../employees/application/employee_providers.dart';
import '../../../employees/domain/employee.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_movement.dart';
import 'inventory_export_button.dart';

/// "Employee Holdings" — employee × item matrix of the stock each employee
/// currently holds, with a Total column. Only employees holding something
/// are listed.
class InventoryHoldingsTab extends ConsumerWidget {
  const InventoryHoldingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = {for (final e in ref.watch(employeeListProvider).value ?? const <Employee>[]) e.id: e};
    final movements = ref.watch(inventoryMovementsProvider).value ?? const <InventoryMovement>[];

    return ref
        .watch(inventoryStockProvider)
        .when(
          data: (stockById) {
            final stock = stockById.values.toList();
            final holderIds = {
              for (final s in stock)
                for (final entry in s.withEmployee.entries)
                  if (entry.value != 0) entry.key,
            };

            // Employee details come from the Employees module; an employee
            // since deleted falls back to the details saved on their
            // latest movement.
            final latestMovement = <String, InventoryMovement>{};
            for (final m in movements) {
              if (m.employeeDocId.isEmpty) continue;
              final seen = latestMovement[m.employeeDocId];
              if (seen == null || m.date.isAfter(seen.date)) latestMovement[m.employeeDocId] = m;
            }
            ({String id, String name, String site, String role}) detailsOf(String docId) {
              final e = employees[docId];
              if (e != null) return (id: e.employeeId, name: e.fullName, site: e.site, role: e.role);
              final m = latestMovement[docId];
              return (
                id: m?.employeeId ?? '',
                name: m?.employeeName ?? '',
                site: m?.site ?? '',
                role: m?.employeeRole ?? '',
              );
            }

            final holders = [for (final id in holderIds) (docId: id, details: detailsOf(id))]
              ..sort((a, b) => a.details.name.toLowerCase().compareTo(b.details.name.toLowerCase()));

            final headers = [
              'S.No.',
              'Employee ID',
              'Employee Name',
              'Site',
              'Role',
              for (final s in stock) s.item.displayName,
              'Total',
            ];
            String orDash(String value) => value.isEmpty ? '—' : value;
            List<String> rowOf(
              int index,
              ({String docId, ({String id, String name, String site, String role}) details}) h,
            ) {
              final quantities = [for (final s in stock) s.withEmployee[h.docId] ?? 0];
              return [
                '${index + 1}',
                orDash(h.details.id),
                orDash(h.details.name),
                orDash(h.details.site),
                orDash(h.details.role),
                for (final q in quantities) '$q',
                '${quantities.fold(0, (total, q) => total + q)}',
              ];
            }

            return AppCard(
              title: 'Employee Holdings',
              trailing: InventoryExportButton(
                title: 'Employee Holdings',
                headers: headers,
                rows: () => [for (final (index, h) in holders.indexed) rowOf(index, h)],
              ),
              child: holders.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('Issue items to an employee in Movements and they will show here.')),
                    )
                  : AppDataTable(
                      columns: [for (final h in headers) DataColumn(label: Text(h))],
                      rows: [
                        for (final (index, h) in holders.indexed)
                          DataRow(
                            cells: [
                              for (final (col, value) in rowOf(index, h).indexed)
                                DataCell(
                                  Text(
                                    value,
                                    style: col == headers.length - 1
                                        ? const TextStyle(fontWeight: FontWeight.w700)
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load inventory: $err')),
        );
  }
}
