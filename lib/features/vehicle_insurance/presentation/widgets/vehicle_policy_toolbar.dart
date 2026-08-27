import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../application/vehicle_policy_providers.dart';
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
        OutlinedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final all = ref.read(filteredPolicyListProvider).value ?? const <VehiclePolicy>[];
            final csv = _toCsv(all);
            try {
              await FilePicker.saveFile(
                fileName: 'vehicle_policies.csv',
                bytes: Uint8List.fromList(utf8.encode(csv)),
                mimeType: 'text/csv',
              );
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text('Could not export: $e')));
            }
          },
          icon: const Icon(Icons.file_download_outlined, size: 16),
          label: const Text('Export'),
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

String _toCsv(List<VehiclePolicy> policies) {
  final buffer = StringBuffer()
    ..writeln(
      'Vehicle Number,Customer Name,Mobile,Insurance Company,Policy Number,Policy Type,Premium,Start Date,Expiry Date,Status',
    );
  for (final p in policies) {
    buffer.writeln(
      [
        p.vehicleNumber,
        p.customerName,
        p.customerMobile,
        p.insuranceCompany,
        p.policyNumber,
        p.policyType.label,
        p.premium.toStringAsFixed(0),
        formatDisplayDate(p.startDate),
        formatDisplayDate(p.expiryDate),
        p.status.label,
      ].map((f) => '"${f.replaceAll('"', '""')}"').join(','),
    );
  }
  return buffer.toString();
}
