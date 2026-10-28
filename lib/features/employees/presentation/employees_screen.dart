import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/roles.dart';
import '../../../core/utils/currency_formatting.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/role_gate.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../application/employee_providers.dart';
import '../application/salary_providers.dart';
import '../domain/employee_enums.dart';
import '../domain/salary_payment.dart';
import 'widgets/employee_data_table.dart';
import 'widgets/employee_toolbar.dart';
import 'widgets/salary_register.dart';

/// REQUIREMENTS.md §9.1 — Employee Database (own staff), with a second
/// "Salary Details" tab holding the Salary Payment Register
/// (docs/Salary Payment Register.html). The tab is driven by
/// [employeesTabProvider] so an employee row's "Salary details" action
/// can switch to it.
class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
    initialIndex: ref.read(employeesTabProvider),
  );

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() {
      if (ref.read(employeesTabProvider) != _tabController.index) {
        ref.read(employeesTabProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(employeesTabProvider, (_, index) {
      if (_tabController.index != index) _tabController.animateTo(index);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Employee Details'),
            Tab(text: 'Salary Details'),
          ],
        ),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) =>
              IndexedStack(index: _tabController.index, children: const [_EmployeeDetailsTab(), _SalaryDetailsTab()]),
        ),
      ],
    );
  }
}

class _EmployeeDetailsTab extends ConsumerWidget {
  const _EmployeeDetailsTab();

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

class _SalaryDetailsTab extends StatelessWidget {
  const _SalaryDetailsTab();

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      minRole: AppRole.powerUser,
      fallback: const AppCard(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Salary details are available to Power Users, Managers and Admins.')),
        ),
      ),
      child: const _SalaryRegister(),
    );
  }
}

class _SalaryRegister extends ConsumerWidget {
  const _SalaryRegister();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredSalaryPaymentListProvider);
    final allPayments = ref.watch(salaryPaymentListProvider).value ?? const <SalaryPayment>[];
    final activeEmployees = (ref.watch(employeeListProvider).value ?? const [])
        .where((e) => e.workStatus == WorkStatus.active)
        .length;
    // Unfiltered — the tiles always cover the whole register.
    final summary = SalarySummary.of(allPayments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SalaryStatRow(
          tiles: [
            StatTile(label: 'Active Employees', value: '$activeEmployees'),
            StatTile(label: 'Employees Paid This Salary Month', value: '${summary.employeesPaidThisMonth}'),
            StatTile(label: 'Amount Paid This Salary Month', value: formatCurrencyFull(summary.amountPaidThisMonth)),
            StatTile(label: 'Employees Paid Last Salary Month', value: '${summary.employeesPaidLastMonth}'),
            StatTile(label: 'Amount Paid Last Salary Month', value: formatCurrencyFull(summary.amountPaidLastMonth)),
          ],
        ),
        const SizedBox(height: 18),
        const SalaryToolbar(),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SalaryHistoryPanel(),
              filteredAsync.when(
                data: (payments) => SalaryRegisterTable(payments: payments),
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Text('Could not load salary payments: $err'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Five-tile variant of [_StatRow]: the longer labels need ~300px a tile
/// to stay on one line, so it goes 5 across only when there's room and
/// otherwise 3 (then 3 + 2), 2 or 1 — never 4, which would leave one
/// tile alone on a second row.
class _SalaryStatRow extends StatelessWidget {
  const _SalaryStatRow({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final fit = ((constraints.maxWidth + spacing) / (300 + spacing)).floor();
        final columns = fit >= 5 ? 5 : (fit >= 3 ? 3 : fit.clamp(1, 2));
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: 3.3,
          children: tiles,
        );
      },
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
