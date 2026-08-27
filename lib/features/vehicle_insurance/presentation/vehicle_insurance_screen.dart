import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatting.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../application/vehicle_policy_providers.dart';
import '../domain/vehicle_insurance_enums.dart';
import 'widgets/vehicle_policy_data_table.dart';
import 'widgets/vehicle_policy_toolbar.dart';

/// REQUIREMENTS.md §9.4 — Vehicle Insurance, matching the spec's two
/// concerns: the main policy register and the "Automatic Renewal System"
/// follow-up list, laid out as a two-tab screen (same convention as
/// Work Orders / Fixed Deposits).
class VehicleInsuranceScreen extends StatefulWidget {
  const VehicleInsuranceScreen({super.key});

  @override
  State<VehicleInsuranceScreen> createState() => _VehicleInsuranceScreenState();
}

class _VehicleInsuranceScreenState extends State<VehicleInsuranceScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [
            Tab(text: 'Policies'),
            Tab(text: 'Renewals'),
          ],
        ),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) =>
              IndexedStack(index: _tabController.index, children: const [_PoliciesTab(), _RenewalsTab()]),
        ),
      ],
    );
  }
}

class _PoliciesTab extends ConsumerWidget {
  const _PoliciesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(vehiclePolicyListProvider);
    final filteredAsync = ref.watch(filteredPolicyListProvider);

    return allAsync.when(
      data: (all) {
        final active = all.where((p) => p.status == PolicyStatus.active).length;
        final expiring7 = all.where((p) => p.isExpiringWithin(7)).length;
        final expiring30 = all.where((p) => p.isExpiringWithin(30)).length;
        final premiumCollected = all.fold<double>(0, (sum, p) => sum + p.premium);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatRow(
              tiles: [
                StatTile(label: 'Active Policies', value: '$active'),
                StatTile(label: 'Expiring in 7 Days', value: '$expiring7'),
                StatTile(label: 'Expiring in 30 Days', value: '$expiring30'),
                StatTile(label: 'Premium Collected', value: formatCurrencyCompact(premiumCollected)),
              ],
            ),
            const SizedBox(height: 18),
            const VehiclePolicyToolbar(),
            const SizedBox(height: 14),
            AppCard(
              child: filteredAsync.when(
                data: (docs) => VehiclePolicyDataTable(policies: docs),
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
      error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load policies: $err')),
    );
  }
}

class _RenewalsTab extends ConsumerWidget {
  const _RenewalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueAsync = ref.watch(renewalsDueListProvider);
    final allAsync = ref.watch(vehiclePolicyListProvider);

    return allAsync.when(
      data: (all) {
        final renewedThisMonth = all.where((p) => p.isRenewedThisMonth).length;
        final due60 = all.where((p) => p.isExpiringWithin(60)).length;
        final due15 = all.where((p) => p.isExpiringWithin(15)).length;
        final overdue = all.where((p) => p.isOverdue).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatRow(
              tiles: [
                StatTile(label: 'Due in 60 Days', value: '$due60'),
                StatTile(label: 'Due in 15 Days', value: '$due15'),
                StatTile(label: 'Overdue', value: '$overdue'),
                StatTile(label: 'Renewed This Month', value: '$renewedThisMonth'),
              ],
            ),
            const SizedBox(height: 18),
            AppCard(
              title: 'Daily Follow-up List',
              child: dueAsync.when(
                data: (due) {
                  final sorted = [...due]..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
                  if (sorted.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No renewals due in the next 60 days.')),
                    );
                  }
                  return VehiclePolicyDataTable(policies: sorted);
                },
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
      error: (err, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Could not load renewals: $err')),
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
          childAspectRatio: 2.3,
          children: tiles,
        );
      },
    );
  }
}
