import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/slideover_panel.dart';
import '../../users/application/user_providers.dart';
import '../application/tender_providers.dart';
import '../domain/tender.dart';
import '../domain/tender_enums.dart';

/// Create/edit form for a Tender-EMD record, matching REQUIREMENTS.md
/// §7.1–§7.3 field sets.
class TenderFormSlideover {
  TenderFormSlideover._();

  static Future<void> show(BuildContext context, {Tender? existing}) {
    return SlideoverPanel.show(
      context,
      title: existing != null ? 'Tender / EMD — ${existing.tenderNumber}' : 'New Tender / EMD',
      body: _TenderForm(existing: existing),
      actions: const [],
    );
  }
}

class _TenderForm extends ConsumerStatefulWidget {
  const _TenderForm({this.existing});

  final Tender? existing;

  @override
  ConsumerState<_TenderForm> createState() => _TenderFormState();
}

class _TenderFormState extends ConsumerState<_TenderForm> {
  final _tenderNameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _emdAmountController = TextEditingController();
  final _utrController = TextEditingController();
  final _deptContactPersonController = TextEditingController();
  final _deptContactMobileController = TextEditingController();
  final _deptContactEmailController = TextEditingController();
  final _deptOfficeAddressController = TextEditingController();
  final _remarksController = TextEditingController();

  late DateTime _publishDate;
  late DateTime _submissionDate;
  DateTime? _emdValidUntil;
  TenderCategory _category = TenderCategory.work;
  EmdType _emdType = EmdType.dd;
  RefundStatus _refundStatus = RefundStatus.pending;

  bool _submitting = false;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _tenderNameController.text = existing?.tenderName ?? '';
    _departmentController.text = existing?.departmentName ?? '';
    _emdAmountController.text = existing != null ? existing.emdAmount.toStringAsFixed(0) : '';
    _utrController.text = existing?.utrNumber ?? '';
    _deptContactPersonController.text = existing?.deptContactPerson ?? '';
    _deptContactMobileController.text = existing?.deptContactMobile ?? '';
    _deptContactEmailController.text = existing?.deptContactEmail ?? '';
    _deptOfficeAddressController.text = existing?.deptOfficeAddress ?? '';
    _remarksController.text = existing?.remarks ?? '';
    _publishDate = existing?.publishDate ?? DateTime.now();
    _submissionDate = existing?.submissionDate ?? DateTime.now();
    _emdValidUntil = existing?.emdValidUntil;
    _category = existing?.category ?? TenderCategory.work;
    _emdType = existing?.emdType ?? EmdType.dd;
    _refundStatus = existing?.refundStatus ?? RefundStatus.pending;
  }

  @override
  void dispose() {
    _tenderNameController.dispose();
    _departmentController.dispose();
    _emdAmountController.dispose();
    _utrController.dispose();
    _deptContactPersonController.dispose();
    _deptContactMobileController.dispose();
    _deptContactEmailController.dispose();
    _deptOfficeAddressController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2015), lastDate: DateTime(2100));
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _submit() async {
    if (_tenderNameController.text.trim().isEmpty || _departmentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tender Name and Department are required.')),
      );
      return;
    }

    final appUser = ref.read(currentAppUserProvider).value;
    final actorUid = appUser?.uid ?? '';
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _submitting = true);
    try {
      final draft = Tender(
        id: widget.existing?.id ?? '',
        tenderNumber: widget.existing?.tenderNumber ?? '',
        year: _submissionDate.year,
        tenderName: _tenderNameController.text.trim(),
        departmentName: _departmentController.text.trim(),
        category: _category,
        publishDate: _publishDate,
        submissionDate: _submissionDate,
        emdAmount: double.tryParse(_emdAmountController.text.trim()) ?? 0,
        emdType: _emdType,
        utrNumber: _utrController.text.trim(),
        emdValidUntil: _emdValidUntil,
        refundStatus: _refundStatus,
        refundedAt: _refundStatus == RefundStatus.refunded ? (widget.existing?.refundedAt ?? DateTime.now()) : null,
        deptContactPerson: _deptContactPersonController.text.trim(),
        deptContactMobile: _deptContactMobileController.text.trim(),
        deptContactEmail: _deptContactEmailController.text.trim(),
        deptOfficeAddress: _deptOfficeAddressController.text.trim(),
        remarks: _remarksController.text.trim(),
        createdBy: widget.existing?.createdBy ?? actorUid,
        createdByName: widget.existing?.createdByName ?? actorName,
        createdAt: widget.existing?.createdAt,
      );

      final repo = ref.read(tenderRepositoryProvider);
      if (_isEditing) {
        await repo.update(tender: draft, actorUid: actorUid, actorName: actorName);
      } else {
        await repo.create(draft: draft, actorUid: actorUid, actorName: actorName);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tender / EMD record saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime> onPicked) {
    return FormRowLabel(
      label: label,
      child: OutlinedButton(
        onPressed: () async {
          final picked = await _pickDate(value);
          if (picked != null) onPicked(picked);
        },
        child: Align(alignment: Alignment.centerLeft, child: Text(_fmt(value))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isEditing)
          FormRowLabel(
            label: 'Tender Indent Number',
            child: TextField(
              controller: TextEditingController(text: widget.existing!.tenderNumber),
              enabled: false,
            ),
          ),
        FormRowLabel(label: 'Tender Name', child: TextField(controller: _tenderNameController)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: FormRowLabel(label: 'Department', child: TextField(controller: _departmentController))),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Category',
                child: DropdownButtonFormField<TenderCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  items: [for (final c in TenderCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
                  onChanged: (v) => setState(() => _category = v ?? TenderCategory.work),
                ),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _dateField('Publish Date', _publishDate, (d) => setState(() => _publishDate = d)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dateField('Submission Date', _submissionDate, (d) => setState(() => _submissionDate = d)),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'EMD Amount (Rs.)',
                child: TextField(controller: _emdAmountController, keyboardType: TextInputType.number),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'EMD Type',
                child: DropdownButtonFormField<EmdType>(
                  initialValue: _emdType,
                  isExpanded: true,
                  items: [for (final t in EmdType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                  onChanged: (v) => setState(() => _emdType = v ?? EmdType.dd),
                ),
              ),
            ),
          ],
        ),
        FormRowLabel(label: 'UTR / URN Number', child: TextField(controller: _utrController)),
        FormRowLabel(
          label: 'EMD Valid Until (optional)',
          child: OutlinedButton(
            onPressed: () async {
              final picked = await _pickDate(_emdValidUntil ?? DateTime.now());
              if (picked != null) setState(() => _emdValidUntil = picked);
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_emdValidUntil != null ? _fmt(_emdValidUntil!) : 'Not set — validity alert won\'t fire'),
            ),
          ),
        ),
        FormRowLabel(
          label: 'Refund Status',
          child: DropdownButtonFormField<RefundStatus>(
            initialValue: _refundStatus,
            isExpanded: true,
            items: [for (final s in RefundStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
            onChanged: (v) => setState(() => _refundStatus = v ?? RefundStatus.pending),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text('Department Contact', style: Theme.of(context).textTheme.titleMedium),
        ),
        FormRowLabel(label: 'Contact Person', child: TextField(controller: _deptContactPersonController)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(label: 'Mobile Number', child: TextField(controller: _deptContactMobileController)),
            ),
            const SizedBox(width: 10),
            Expanded(child: FormRowLabel(label: 'Email ID', child: TextField(controller: _deptContactEmailController))),
          ],
        ),
        FormRowLabel(label: 'Office Address', child: TextField(controller: _deptOfficeAddressController, maxLines: 2)),
        FormRowLabel(label: 'Remarks', child: TextField(controller: _remarksController, maxLines: 3)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}
