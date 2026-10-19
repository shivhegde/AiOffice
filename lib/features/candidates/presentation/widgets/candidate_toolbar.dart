import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../shared/widgets/app_toolbar.dart';
import '../../../../shared/widgets/role_gate.dart';
import '../../application/candidate_providers.dart';
import '../../domain/candidate.dart';
import '../../domain/candidate_enums.dart';
import '../candidate_form_slideover.dart';

class CandidateToolbar extends ConsumerWidget {
  const CandidateToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(candidateFilterProvider);

    return AppToolbar(
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search name, district, taluk'),
            onChanged: (v) => ref.read(candidateFilterProvider.notifier).state = filter.copyWith(search: v),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<CandidateCategory?>(
            initialValue: filter.category,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Categories')),
              for (final c in CandidateCategory.values) DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (v) => ref.read(candidateFilterProvider.notifier).state = filter.copyWith(category: v),
          ),
        ),
        PopupMenuButton<ReportFormat>(
          tooltip: 'Export table',
          onSelected: (format) async {
            final messenger = ScaffoldMessenger.of(context);
            final candidates = ref.read(filteredCandidateListProvider).value ?? const <Candidate>[];
            try {
              await ReportExportService.save(
                format: format,
                title: 'Candidate Bank',
                subtitle:
                    'Generated on ${formatDisplayDateTime(DateTime.now())} • '
                    '${candidates.length} candidate${candidates.length == 1 ? '' : 's'}',
                headers: _exportHeaders,
                rows: _exportRows(candidates),
                // Every form field is a column — too wide for A4.
                pdfPageFormat: PdfPageFormat.a3.landscape,
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
            onPressed: () => CandidateFormSlideover.show(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Candidate'),
          ),
        ),
      ],
    );
  }
}

const _exportHeaders = [
  'S.No.',
  'Candidate ID',
  'Full Name',
  'Mobile',
  'Alternate No.',
  'WhatsApp No.',
  'Referred By',
  'Date of Birth',
  'Age',
  'Gender',
  'Marital Status',
  'Village',
  'City / Town',
  'Taluk',
  'District',
  'State',
  'Pincode',
  'Qualification',
  'Category / Post',
  'Experience',
  'Languages Known',
  'Height',
  'Ex-Serviceman',
  'Resume',
  'Added By',
  'Added On',
];

/// Every field captured on the candidate form, in form order.
List<List<String>> _exportRows(List<Candidate> candidates) {
  String orDash(String v) => v.isEmpty ? '—' : v;
  bool isSecurity(Candidate c) => c.categories.contains(CandidateCategory.security);
  return [
    for (final (index, c) in candidates.indexed)
      [
        '${index + 1}',
        c.candidateId,
        c.fullName,
        orDash(c.mobileNumber),
        orDash(c.alternateNumber),
        orDash(c.whatsappNumber),
        orDash(c.referredBy),
        formatDisplayDate(c.dateOfBirth),
        '${c.age}',
        c.genderDisplay,
        c.maritalStatusDisplay,
        orDash(c.village),
        orDash(c.cityTown),
        orDash(c.taluk),
        orDash(c.district),
        orDash(c.state),
        orDash(c.pincode),
        orDash(c.educationDisplay),
        orDash(c.categoryDisplay),
        c.experience.label,
        orDash(c.languagesDisplay),
        isSecurity(c) ? orDash(c.height) : '—',
        isSecurity(c) ? (c.exServiceman ? 'Yes' : 'No') : '—',
        c.hasResume ? (c.resumeFileName ?? 'Yes') : 'No',
        orDash(c.createdByName),
        c.createdAt != null ? formatDisplayDate(c.createdAt!) : '—',
      ],
  ];
}
