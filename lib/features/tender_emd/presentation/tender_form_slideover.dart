import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/document_actions.dart';
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
  final _tenderNumberController = TextEditingController();
  final _tenderNameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _subDepartmentController = TextEditingController();
  final _bidValidityDaysController = TextEditingController();
  final _emdAmountController = TextEditingController();
  final _emdPaymentBankController = TextEditingController();
  final _utrController = TextEditingController();
  final _refundToAccountController = TextEditingController();
  final _refundUtrController = TextEditingController();
  final _deptContactPersonController = TextEditingController();
  final _deptContactMobileController = TextEditingController();
  final _deptContactEmailController = TextEditingController();
  final _deptOfficeAddressController = TextEditingController();
  final _remarksController = TextEditingController();

  late DateTime _publishDate;
  late DateTime _submissionDate;
  DateTime? _emdPaymentDate;
  DateTime? _emdValidUntil;
  DateTime? _refundedAt;
  TenderCategory _category = TenderCategory.work;
  TenderStatus _status = TenderStatus.active;
  EmdType _emdType = EmdType.dd;
  RefundStatus _refundStatus = RefundStatus.pending;

  ({Uint8List bytes, String name, String contentType})? _pendingPaymentProof;
  ({Uint8List bytes, String name, String contentType})? _pendingRefundProof;

  bool _submitting = false;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _tenderNumberController.text = existing?.tenderNumber ?? '';
    _tenderNameController.text = existing?.tenderName ?? '';
    _departmentController.text = existing?.departmentName ?? '';
    _subDepartmentController.text = existing?.subDepartmentName ?? '';
    _bidValidityDaysController.text = existing?.bidValidityDays?.toString() ?? '';
    _emdAmountController.text = existing != null ? existing.emdAmount.toStringAsFixed(0) : '';
    _emdPaymentBankController.text = existing?.emdPaymentBank ?? '';
    _utrController.text = existing?.utrNumber ?? '';
    _refundToAccountController.text = existing?.refundToAccount ?? '';
    _refundUtrController.text = existing?.refundUtrNumber ?? '';
    _deptContactPersonController.text = existing?.deptContactPerson ?? '';
    _deptContactMobileController.text = existing?.deptContactMobile ?? '';
    _deptContactEmailController.text = existing?.deptContactEmail ?? '';
    _deptOfficeAddressController.text = existing?.deptOfficeAddress ?? '';
    _remarksController.text = existing?.remarks ?? '';
    _publishDate = existing?.publishDate ?? DateTime.now();
    _submissionDate = existing?.submissionDate ?? DateTime.now();
    _emdPaymentDate = existing?.emdPaymentDate;
    _emdValidUntil = existing?.emdValidUntil;
    _refundedAt = existing?.refundedAt;
    _category = existing?.category ?? TenderCategory.work;
    _status = existing?.status ?? TenderStatus.active;
    _emdType = existing?.emdType ?? EmdType.dd;
    _refundStatus = existing?.refundStatus ?? RefundStatus.pending;
  }

  @override
  void dispose() {
    _tenderNumberController.dispose();
    _tenderNameController.dispose();
    _departmentController.dispose();
    _subDepartmentController.dispose();
    _bidValidityDaysController.dispose();
    _emdAmountController.dispose();
    _emdPaymentBankController.dispose();
    _utrController.dispose();
    _refundToAccountController.dispose();
    _refundUtrController.dispose();
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
    final tenderNumber = _tenderNumberController.text.trim();
    if (tenderNumber.isEmpty ||
        _tenderNameController.text.trim().isEmpty ||
        _departmentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tender Number, Tender Description and Department are required.')));
      return;
    }
    final allTenders = ref.read(tenderListProvider).value ?? const <Tender>[];
    final duplicate = allTenders.any(
      (t) => t.id != widget.existing?.id && t.tenderNumber.trim().toLowerCase() == tenderNumber.toLowerCase(),
    );
    if (duplicate) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tender Number $tenderNumber is already used by another tender.')));
      return;
    }

    final appUser = ref.read(currentAppUserProvider).value;
    final actorUid = appUser?.uid ?? '';
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _submitting = true);
    try {
      final draft = Tender(
        id: widget.existing?.id ?? '',
        tenderNumber: tenderNumber,
        year: widget.existing?.year ?? _submissionDate.year,
        tenderName: _tenderNameController.text.trim(),
        departmentName: _departmentController.text.trim(),
        subDepartmentName: _subDepartmentController.text.trim(),
        category: _category,
        status: _status,
        publishDate: _publishDate,
        submissionDate: _submissionDate,
        bidValidityDays: int.tryParse(_bidValidityDaysController.text.trim()),
        emdAmount: double.tryParse(_emdAmountController.text.trim()) ?? 0,
        emdType: _emdType,
        emdPaymentDate: _emdPaymentDate,
        emdPaymentBank: _emdPaymentBankController.text.trim(),
        utrNumber: _utrController.text.trim(),
        paymentProofStoragePath: widget.existing?.paymentProofStoragePath,
        paymentProofFileName: widget.existing?.paymentProofFileName,
        refundProofStoragePath: widget.existing?.refundProofStoragePath,
        refundProofFileName: widget.existing?.refundProofFileName,
        emdValidUntil: _emdValidUntil,
        refundStatus: _refundStatus,
        refundedAt: _refundedAt ?? (_refundStatus == RefundStatus.refunded ? DateTime.now() : null),
        refundToAccount: _refundToAccountController.text.trim(),
        refundUtrNumber: _refundUtrController.text.trim(),
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
        await repo.update(
          tender: draft,
          actorUid: actorUid,
          actorName: actorName,
          paymentProofFile: _pendingPaymentProof,
          refundProofFile: _pendingRefundProof,
        );
      } else {
        await repo.create(
          draft: draft,
          actorUid: actorUid,
          actorName: actorName,
          paymentProofFile: _pendingPaymentProof,
          refundProofFile: _pendingRefundProof,
        );
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

  /// Distinct non-empty values already entered on other tenders, for the
  /// Department / Sub-Department pulldowns.
  List<String> _previousValues(String Function(Tender t) pick) {
    final all = ref.watch(tenderListProvider).value ?? const <Tender>[];
    final values = {
      for (final t in all)
        if (pick(t).trim().isNotEmpty) pick(t).trim(),
    }.toList();
    return values..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Pulldown of previously entered values that still accepts free text —
  /// same pattern as the Work Order Department field.
  Widget _pickOrTypeField(TextEditingController controller, List<String> options) {
    return DropdownMenu<String>(
      controller: controller,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      dropdownMenuEntries: [for (final o in options) DropdownMenuEntry(value: o, label: o)],
      onSelected: (value) {
        if (value != null) controller.text = value;
      },
    );
  }

  Future<({Uint8List bytes, String name, String contentType})?> _pickFile() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    return (bytes: bytes, name: file.name, contentType: extension == 'pdf' ? 'application/pdf' : 'image/$extension');
  }

  Widget _proofField({
    required String label,
    required ({Uint8List bytes, String name, String contentType})? pending,
    required String? existingName,
    required String? existingPath,
    required ValueChanged<({Uint8List bytes, String name, String contentType})> onPicked,
  }) {
    return FormRowLabel(
      label: label,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final file = await _pickFile();
                if (file != null && mounted) setState(() => onPicked(file));
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pending != null
                      ? 'Attached: ${pending.name}'
                      : (existingName != null ? 'On file: $existingName. Tap to replace.' : 'Tap to upload'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (pending == null && existingPath != null && existingName != null) ...[
            const SizedBox(width: 8),
            DocumentActionIcons(storagePath: existingPath, fileName: existingName, label: label),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormRowLabel(
          label: 'Tender Number',
          child: TextField(controller: _tenderNumberController),
        ),
        FormRowLabel(
          label: 'Tender Description',
          child: TextField(controller: _tenderNameController),
        ),
        FormRowLabel(
          label: 'Tender Status',
          child: DropdownButtonFormField<TenderStatus>(
            initialValue: _status,
            isExpanded: true,
            items: [for (final s in TenderStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
            onChanged: (v) => setState(() => _status = v ?? TenderStatus.active),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Department',
                child: _pickOrTypeField(_departmentController, _previousValues((t) => t.departmentName)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Sub-Department',
                child: _pickOrTypeField(_subDepartmentController, _previousValues((t) => t.subDepartmentName)),
              ),
            ),
          ],
        ),
        FormRowLabel(
          label: 'Category',
          child: DropdownButtonFormField<TenderCategory>(
            initialValue: _category,
            isExpanded: true,
            items: [for (final c in TenderCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
            onChanged: (v) => setState(() => _category = v ?? TenderCategory.work),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _dateField('Publish Date', _publishDate, (d) => setState(() => _publishDate = d))),
            const SizedBox(width: 10),
            Expanded(
              child: _dateField('Bid Submission Date', _submissionDate, (d) => setState(() => _submissionDate = d)),
            ),
          ],
        ),
        FormRowLabel(
          label: 'Bid Validity (Days)',
          child: TextField(controller: _bidValidityDaysController, keyboardType: TextInputType.number),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text('EMD Payment Details', style: Theme.of(context).textTheme.titleMedium),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'EMD Payment Date',
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await _pickDate(_emdPaymentDate ?? DateTime.now());
                    if (picked != null) setState(() => _emdPaymentDate = picked);
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_emdPaymentDate != null ? _fmt(_emdPaymentDate!) : 'Not set'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'EMD Payment Bank',
                child: TextField(controller: _emdPaymentBankController),
              ),
            ),
          ],
        ),
        FormRowLabel(
          label: 'UTR / Reference Number',
          child: TextField(controller: _utrController),
        ),
        _proofField(
          label: 'Payment Proof',
          pending: _pendingPaymentProof,
          existingName: widget.existing?.paymentProofFileName,
          existingPath: widget.existing?.paymentProofStoragePath,
          onPicked: (f) => _pendingPaymentProof = f,
        ),
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
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text('EMD Refund Details', style: Theme.of(context).textTheme.titleMedium),
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
        FormRowLabel(
          label: 'EMD Refund To (Account)',
          child: _pickOrTypeField(_refundToAccountController, _previousValues((t) => t.refundToAccount)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'EMD Refund Date',
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await _pickDate(_refundedAt ?? DateTime.now());
                    if (picked != null) setState(() => _refundedAt = picked);
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_refundedAt != null ? _fmt(_refundedAt!) : 'Not set'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Refund Bank UTR Number',
                child: TextField(controller: _refundUtrController),
              ),
            ),
          ],
        ),
        _proofField(
          label: 'Refund Proof',
          pending: _pendingRefundProof,
          existingName: widget.existing?.refundProofFileName,
          existingPath: widget.existing?.refundProofStoragePath,
          onPicked: (f) => _pendingRefundProof = f,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text('Department Contact', style: Theme.of(context).textTheme.titleMedium),
        ),
        FormRowLabel(
          label: 'Contact Person',
          child: TextField(controller: _deptContactPersonController),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Mobile Number',
                child: TextField(controller: _deptContactMobileController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Email ID',
                child: TextField(controller: _deptContactEmailController),
              ),
            ),
          ],
        ),
        FormRowLabel(
          label: 'Office Address',
          child: TextField(controller: _deptOfficeAddressController, maxLines: 2),
        ),
        FormRowLabel(
          label: 'Remarks',
          child: TextField(controller: _remarksController, maxLines: 3),
        ),
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
