import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../application/employee_providers.dart';
import '../domain/employee_enums.dart';
import 'widgets/employee_data_table.dart';
import 'widgets/employee_toolbar.dart';

/// REQUIREMENTS.md §9.1 — Employee Database (own staff).
class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(employeeListProvider);
    final filteredAsync = ref.watch(filteredEmployeeListProvider);

    return allAsync.when(
      data: (all) {
        final active = all.where((e) => e.workStatus == WorkStatus.active).length;
        final newAppointments = all.where((e) => e.isNewAppointment).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatRow(
              tiles: [
                StatTile(label: 'Total Employees', value: '${all.length}'),
                StatTile(label: 'Active Employees', value: '$active'),
                StatTile(label: 'New Appointments', value: '$newAppointments'),
              ],
            ),
            const SizedBox(height: 18),
            const EmployeeToolbar(),
            const SizedBox(height: 14),
            AppCard(
              child: filteredAsync.when(
                data: (docs) => EmployeeDataTable(employees: docs),
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Text('Could not load: $err'),
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load employees: $err')),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 460 ? 1 : (constraints.maxWidth < 980 ? 2 : 3);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 3.3,
          children: tiles,
        );
      },
    );
  }
}
