import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatting.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../application/work_order_providers.dart';
import '../domain/work_order.dart';
import '../domain/work_order_enums.dart';
import 'widgets/fixed_deposit_data_table.dart';
import 'widgets/work_order_data_table.dart';
import 'widgets/work_order_toolbar.dart';

/// REQUIREMENTS.md §8 — Work Orders & Fixed Deposits, matching the
/// prototype's two-tab layout ("Work Orders" / "Fixed Deposits").
class WorkOrdersScreen extends StatefulWidget {
  const WorkOrdersScreen({super.key});

  @override
  State<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

class _WorkOrdersScreenState extends State<WorkOrdersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [Tab(text: 'Work Orders'), Tab(text: 'Fixed Deposits')],
        ),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) => IndexedStack(
            index: _tabController.index,
            children: const [_WorkOrdersTab(), _FixedDepositsTab()],
          ),
        ),
      ],
    );
  }
}

class _WorkOrdersTab extends ConsumerWidget {
  const _WorkOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(workOrderListProvider);
    final filteredAsync = ref.watch(filteredWorkOrderListProvider);

    return allAsync.when(
      data: (all) {
        final active = all.where((wo) => wo.status == WorkOrderStatus.active).length;
        final expiringSoon = all.where((wo) => wo.isExpiringSoon).length;
        final totalValue = all.fold<double>(0, (sum, wo) => sum + wo.contractValue);
        final underExtension = all.where((wo) => wo.contractType == ContractType.extension).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatRow(tiles: [
              StatTile(label: 'Active Work Orders', value: '$active'),
              StatTile(label: 'Expiring in 60 Days', value: '$expiringSoon'),
              StatTile(label: 'Total Contract Value', value: formatCurrencyCompact(totalValue)),
              StatTile(label: 'Under Extension', value: '$underExtension'),
            ]),
            const SizedBox(height: 18),
            const WorkOrderToolbar(),
            const SizedBox(height: 14),
            AppCard(
              child: filteredAsync.when(
                data: (docs) => WorkOrderDataTable(workOrders: docs),
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
      error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load work orders: $err')),
    );
  }
}

class _FixedDepositsTab extends ConsumerWidget {
  const _FixedDepositsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allFdAsync = ref.watch(fixedDepositListProvider);
    final filteredAsync = ref.watch(filteredFdListProvider);

    return allFdAsync.when(
      data: (allFd) {
        final now = DateTime.now();
        final totalSubmitted = allFd.fold<double>(0, (sum, wo) => sum + (wo.fdAmount ?? 0));
        final pendingReturn = allFd
            .where((wo) => wo.fdStatus != FdStatus.released)
            .fold<double>(0, (sum, wo) => sum + (wo.fdAmount ?? 0));
        final expiringThisMonth = allFd
            .where(
              (wo) =>
                  wo.fdStatus == FdStatus.active &&
                  wo.fdMaturityDate != null &&
                  wo.fdMaturityDate!.year == now.year &&
                  wo.fdMaturityDate!.month == now.month,
            )
            .length;
        final releasedThisYear = allFd
            .where((wo) => wo.fdStatus == FdStatus.released && wo.fdReleasedAt?.year == now.year)
            .fold<double>(0, (sum, wo) => sum + (wo.fdAmount ?? 0));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatRow(tiles: [
              StatTile(label: 'Total FD Submitted', value: formatCurrencyCompact(totalSubmitted)),
              StatTile(label: 'Pending FD Return', value: formatCurrencyCompact(pendingReturn)),
              StatTile(label: 'Expiring This Month', value: '$expiringThisMonth'),
              StatTile(label: 'Released This Year', value: formatCurrencyCompact(releasedThisYear)),
            ]),
            const SizedBox(height: 18),
            const FixedDepositToolbar(),
            const SizedBox(height: 14),
            AppCard(
              child: filteredAsync.when(
                data: (List<WorkOrder> docs) => FixedDepositDataTable(workOrders: docs),
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
      error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load fixed deposits: $err')),
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
        final columns = constraints.maxWidth < 460 ? 1 : (constraints.maxWidth < 980 ? 2 : 4);
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
