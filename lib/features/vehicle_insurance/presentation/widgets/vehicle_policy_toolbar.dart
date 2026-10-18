import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../application/vehicle_policy_providers.dart';
import '../../domain/vehicle_followup.dart';
import '../../domain/vehicle_insurance_enums.dart';
import '../../domain/vehicle_policy.dart';
import '../vehicle_policy_form_slideover.dart';

class VehiclePolicyToolbar extends ConsumerWidget {
  const VehiclePolicyToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(policyFilterProvider);

    return AppToolbar(
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search vehicle no., name, policy no.'),
            onChanged: (v) => ref.read(policyFilterProvider.notifier).state = filter.copyWith(search: v),
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<PolicyStatus?>(
            initialValue: filter.status,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Status')),
              for (final s in PolicyStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => ref.read(policyFilterProvider.notifier).state = filter.copyWith(status: v),
          ),
        ),
        PopupMenuButton<ReportFormat>(
          tooltip: 'Export table',
          onSelected: (format) async {
            final messenger = ScaffoldMessenger.of(context);
            final policies = ref.read(filteredPolicyListProvider).value ?? const <VehiclePolicy>[];
            final followups = ref.read(vehicleFollowupsByPolicyProvider).value ?? const {};
            try {
              await ReportExportService.save(
                format: format,
                title: 'Vehicle Insurance Policies',
                subtitle:
                    'Generated on ${formatDisplayDateTime(DateTime.now())} • '
                    '${policies.length} polic${policies.length == 1 ? 'y' : 'ies'}',
                headers: _exportHeaders,
                rows: _exportRows(policies, followups),
              );
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text('Could not export: $e')));
            }
          },
          itemBuilder: (_) => [
            for (final f in ReportFormat.values)
              PopupMenuItem(
                value: f,
                child: Row(
                  children: [
                    Icon(f == ReportFormat.pdf ? Icons.picture_as_pdf_outlined : Icons.table_chart_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text('Export as ${f.label}'),
                  ],
                ),
              ),
          ],
          child: IgnorePointer(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Export'),
            ),
          ),
        ),
        RoleGate(
          minRole: AppRole.powerUser,
          child: FilledButton.icon(
            onPressed: () => VehiclePolicyFormSlideover.show(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Policy'),
          ),
        ),
      ],
    );
  }
}

const _exportHeaders = [
  'S.No.',
  'Vehicle No.',
  'Vehicle Type',
  'Customer',
  'Mobile',
  'Insurer',
  'Policy No.',
  'Policy Type',
  'Premium',
  'Start Date',
  'Expiry Date',
  'Status',
  'Followup Date',
  'Followup Remark',
  'Followup Status',
];

/// Same rows and followup summary as the on-screen table.
List<List<String>> _exportRows(List<VehiclePolicy> policies, Map<String, List<VehicleFollowup>> followups) {
  return [
    for (final (index, p) in policies.indexed)
      () {
        final current = currentVehicleFollowup(followups[p.id] ?? const []);
        return [
          '${index + 1}',
          p.vehicleNumber,
          p.vehicleTypeLabel,
          p.customerName,
          p.customerMobile,
          p.insuranceCompany,
          p.policyNumber,
          p.policyTypesLabel,
          p.premium.toStringAsFixed(0),
          formatDisplayDate(p.startDate),
          formatDisplayDate(p.expiryDate),
          p.status.label,
          current != null ? formatDisplayDate(current.followupDate) : '—',
          current?.remark ?? '—',
          current?.status.label ?? '—',
        ];
      }(),
  ];
}
