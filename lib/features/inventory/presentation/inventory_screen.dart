import 'package:flutter/material.dart';

import 'widgets/inventory_dashboard_tab.dart';
import 'widgets/inventory_items_tab.dart';
import 'widgets/inventory_movements_tab.dart';
import 'widgets/inventory_next_order_tab.dart';
import 'widgets/inventory_sites_tab.dart';

/// Inventory — uniform stock tracker, laid out per
/// docs/inventory_redesign.html: Dashboard, Items, Movements, Sites,
/// Damaged and Next Order tabs over one item list + movement ledger.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 6, vsync: this);

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
            Tab(text: 'Dashboard'),
            Tab(text: 'Items'),
            Tab(text: 'Movements'),
            Tab(text: 'Sites'),
            Tab(text: 'Damaged'),
            Tab(text: 'Next Order'),
          ],
        ),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) => IndexedStack(
            index: _tabController.index,
            children: const [
              InventoryDashboardTab(),
              InventoryItemsTab(),
              InventoryMovementsTab(),
              InventorySitesTab(),
              InventoryMovementsTab(damagedOnly: true),
              InventoryNextOrderTab(),
            ],
          ),
        ),
      ],
    );
  }
}
