import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../application/inventory_providers.dart';
import '../inventory_form_slideover.dart';

class InventoryToolbar extends ConsumerWidget {
  const InventoryToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppToolbar(
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search item'),
            onChanged: (v) => ref.read(inventorySearchProvider.notifier).state = v,
          ),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: FilledButton.icon(
            onPressed: () => InventoryFormSlideover.show(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Item'),
          ),
        ),
      ],
    );
  }
}
