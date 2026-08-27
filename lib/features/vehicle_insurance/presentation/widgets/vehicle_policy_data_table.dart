import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/services/whatsapp_launcher.dart';
import '../../../../core/utils/currency_formatting.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../users/application/user_providers.dart';
import '../../application/vehicle_policy_providers.dart';
import '../../domain/vehicle_insurance_enums.dart';
import '../../domain/vehicle_policy.dart';
import '../vehicle_policy_form_slideover.dart';

class VehiclePolicyDataTable extends ConsumerWidget {
  const VehiclePolicyDataTable({super.key, required this.policies});

  final List<VehiclePolicy> policies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDataTable(
      columns: const [
        DataColumn(label: Text('Vehicle No.')),
        DataColumn(label: Text('Customer')),
        DataColumn(label: Text('Insurer')),
        DataColumn(label: Text('Policy No.')),
        DataColumn(label: Text('Premium')),
        DataColumn(label: Text('Expiry')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final p in policies)
          DataRow(
            cells: [
              DataCell(Text(p.vehicleNumber)),
              DataCell(Text(p.customerName)),
              DataCell(Text(p.insuranceCompany)),
              DataCell(Text(p.policyNumber)),
              DataCell(Text(formatCurrencyCompact(p.premium))),
              DataCell(Text(formatDisplayDate(p.expiryDate))),
              DataCell(_StatusChipForPolicy(policy: p)),
              DataCell(_RowActions(policy: p)),
            ],
          ),
      ],
    );
  }
}

class _StatusChipForPolicy extends StatelessWidget {
  const _StatusChipForPolicy({required this.policy});

  final VehiclePolicy policy;

  @override
  Widget build(BuildContext context) {
    if (policy.status == PolicyStatus.renewed) {
      return const StatusChip(label: 'Renewed', variant: StatusChipVariant.accent);
    }
    if (policy.status == PolicyStatus.cancelled) {
      return const StatusChip(label: 'Cancelled', variant: StatusChipVariant.neutral);
    }
    if (policy.isOverdue) {
      return const StatusChip(label: 'Expired', variant: StatusChipVariant.critical);
    }
    if (policy.isExpiringWithin(7)) {
      return StatusChip(label: 'Due in ${policy.daysToExpiry}d', variant: StatusChipVariant.critical);
    }
    if (policy.isExpiringWithin(30)) {
      return StatusChip(label: 'Due in ${policy.daysToExpiry}d', variant: StatusChipVariant.warn);
    }
    return const StatusChip(label: 'Active', variant: StatusChipVariant.good);
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.policy});

  final VehiclePolicy policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chat_outlined, size: 17),
          tooltip: 'WhatsApp reminder',
          onPressed: () => WhatsappLauncher.open(
            phone: policy.customerMobile,
            message:
                'Hello ${policy.customerName}, your ${policy.vehicleType.label} insurance '
                '(${policy.vehicleNumber}, Policy ${policy.policyNumber}) expires on '
                '${formatDisplayDate(policy.expiryDate)}. Please contact us to renew.',
          ),
        ),
        IconButton(
          icon: const Icon(Icons.call_outlined, size: 17),
          tooltip: 'Call customer',
          onPressed: () => launchUrl(Uri.parse('tel:${policy.customerMobile}')),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17),
                tooltip: 'Edit',
                onPressed: () => VehiclePolicyFormSlideover.show(context, existing: policy),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 17),
                tooltip: 'Delete',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete policy?'),
                      content: Text('This removes ${policy.vehicleNumber} — ${policy.customerName}.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  final appUser = ref.read(currentAppUserProvider).value;
                  await ref
                      .read(vehiclePolicyRepositoryProvider)
                      .delete(
                        policy: policy,
                        actorUid: appUser?.uid ?? '',
                        actorName: appUser?.displayName ?? appUser?.email ?? 'Unknown',
                      );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
