import 'package:flutter/material.dart';

import 'inward_list_view.dart';
import 'outward_list_view.dart';

/// REQUIREMENTS.md §6 — matches the prototype's Inward/Outward folder tabs.
class InwardOutwardScreen extends StatefulWidget {
  const InwardOutwardScreen({super.key});

  @override
  State<InwardOutwardScreen> createState() => _InwardOutwardScreenState();
}

class _InwardOutwardScreenState extends State<InwardOutwardScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'Inward'), Tab(text: 'Outward')],
        ),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) => IndexedStack(
            index: _tabController.index,
            children: const [InwardListView(), OutwardListView()],
          ),
        ),
      ],
    );
  }
}
