import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/document_viewer_dialog.dart';
import '../../../shared/widgets/slideover_panel.dart';
import '../../departments/application/department_providers.dart';
import '../../inward_outward/application/io_providers.dart' show storageUploadServiceProvider;
import '../../users/application/user_providers.dart';
import '../application/work_order_providers.dart';
import '../domain/work_order.dart';
import '../domain/work_order_enums.dart';

/// Create/edit form for a Work Order, including its embedded Fixed
/// Deposit section — matches REQUIREMENTS.md §8.1–§8.4.
class WorkOrderFormSlideover {
  WorkOrderFormSlideover._();

  static Future<void> show(BuildContext context, {WorkOrder? existing}) {
    return SlideoverPanel.show(
      context,
      title: existing != null ? 'Work Order — ${existing.workOrderNumber}' : 'New Work Order',
      body: _WorkOrderForm(existing: existing),
      actions: const [],
      width: 480,
    );
  }
}

class _WorkOrderForm extends ConsumerStatefulWidget {
  const _WorkOrderForm({this.existing});

  final WorkOrder? existing;

  @override
  ConsumerState<_WorkOrderForm> createState() => _WorkOrderFormState();
}

class _WorkOrderFormState extends ConsumerState<_WorkOrderForm> {
  final _departmentController = TextEditingController();
  final _remarksController = TextEditingController();
  final _extensionOrderNumberController = TextEditingController();
  final _extensionReasonController = TextEditingController();
  final _deptOfficeAddressController = TextEditingController();
  final _deptContactPersonController = TextEditingController();
  final _deptPhoneController = TextEditingController();
  final _deptEmailController = TextEditingController();
  final _deptGSTINController = TextEditingController();
  final _contractValueController = TextEditingController();
  final _securityDepositController = TextEditingController();
  final _emdAmountController = TextEditingController();
  final _tenderNumberController = TextEditingController();
  final _tenderNameController = TextEditingController();
  final _fdNumberController = TextEditingController();
  final _fdBankNameController = TextEditingController();
  final _fdBranchNameController = TextEditingController();
  final _fdAmountController = TextEditingController();
  final _fdInterestRateController = TextEditingController();

  late DateTime _workOrderDate;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _extensionAvailable = false;
  WorkOrderStatus _status = WorkOrderStatus.active;
  ContractType _contractType = ContractType.fixed;
  DateTime? _extensionStartDate;
  DateTime? _extensionEndDate;
  DateTime? _fdIssueDate;
  DateTime? _fdMaturityDate;
  FdStatus? _fdStatus;

  ({Uint8List bytes, String name, String contentType})? _pendingFdFile;
  bool _submitting = false;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _departmentController.text = e?.departmentName ?? '';
    _remarksController.text = e?.remarks ?? '';
    _extensionOrderNumberController.text = e?.extensionOrderNumber ?? '';
    _extensionReasonController.text = e?.extensionReason ?? '';
    _deptOfficeAddressController.text = e?.deptOfficeAddress ?? '';
    _deptContactPersonController.text = e?.deptContactPerson ?? '';
    _deptPhoneController.text = e?.deptPhoneNumber ?? '';
    _deptEmailController.text = e?.deptEmail ?? '';
    _deptGSTINController.text = e?.deptGSTIN ?? '';
    _contractValueController.text = e != null ? e.contractValue.toStringAsFixed(0) : '';
    _securityDepositController.text = e != null ? e.securityDeposit.toStringAsFixed(0) : '';
    _emdAmountController.text = e != null ? e.emdAmount.toStringAsFixed(0) : '';
    _tenderNumberController.text = e?.tenderNumber ?? '';
    _tenderNameController.text = e?.tenderName ?? '';
    _fdNumberController.text = e?.fdNumber ?? '';
    _fdBankNameController.text = e?.fdBankName ?? '';
    _fdBranchNameController.text = e?.fdBranchName ?? '';
    _fdAmountController.text = e?.fdAmount != null ? e!.fdAmount!.toStringAsFixed(0) : '';
    _fdInterestRateController.text = e?.fdInterestRate != null ? e!.fdInterestRate!.toStringAsFixed(2) : '';

    _workOrderDate = e?.workOrderDate ?? DateTime.now();
    _startDate = e?.startDate ?? DateTime.now();
    _endDate = e?.endDate;
    _extensionAvailable = e?.extensionAvailable ?? false;
    _status = e?.status ?? WorkOrderStatus.active;
    _contractType = e?.contractType ?? ContractType.fixed;
    _extensionStartDate = e?.extensionStartDate;
    _extensionEndDate = e?.extensionEndDate;
    _fdIssueDate = e?.fdIssueDate;
    _fdMaturityDate = e?.fdMaturityDate;
    _fdStatus = e?.fdStatus;
  }

  @override
  void dispose() {
    _departmentController.dispose();
    _remarksController.dispose();
    _extensionOrderNumberController.dispose();
    _extensionReasonController.dispose();
    _deptOfficeAddressController.dispose();
    _deptContactPersonController.dispose();
    _deptPhoneController.dispose();
    _deptEmailController.dispose();
    _deptGSTINController.dispose();
    _contractValueController.dispose();
    _securityDepositController.dispose();
    _emdAmountController.dispose();
    _tenderNumberController.dispose();
    _tenderNameController.dispose();
    _fdNumberController.dispose();
    _fdBankNameController.dispose();
    _fdBranchNameController.dispose();
    _fdAmountController.dispose();
    _fdInterestRateController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDateInto(DateTime? initial, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Widget _dateButton(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return FormRowLabel(
      label: label,
      child: OutlinedButton(
        onPressed: () => _pickDateInto(value, onPicked),
        child: Align(alignment: Alignment.centerLeft, child: Text(value != null ? _fmt(value) : 'Not set')),
      ),
    );
  }

  Future<void> _pickFdFile() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    if (!mounted) return;
    setState(() {
      _pendingFdFile = (
        bytes: bytes,
        name: file.name,
        contentType: extension == 'pdf' ? 'application/pdf' : 'image/$extension',
      );
    });
  }

  Future<Uint8List> _fetchFdFileBytes(WorkOrder existing) async {
    final bytes = await ref.read(storageUploadServiceProvider).fetchBytes(existing.fdStoragePath!);
    if (bytes == null) throw Exception('File not found in storage.');
    return bytes;
  }

  String _fdMimeType(String fileName) {
    final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return extension == 'pdf' ? 'application/pdf' : 'image/$extension';
  }

  Future<void> _viewFdFile() async {
    final existing = widget.existing;
    if (existing == null || !existing.hasFdFile) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _fetchFdFileBytes(existing);
      final fileName = existing.fdFileName ?? '${existing.workOrderNumber}-fd';
      if (!mounted) return;
      await DocumentViewerDialog.show(context, bytes: bytes, fileName: fileName, contentType: _fdMimeType(fileName));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open FD document: $e')));
    }
  }

  Future<void> _downloadFdFile() async {
    final existing = widget.existing;
    if (existing == null || !existing.hasFdFile) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _fetchFdFileBytes(existing);
      final fileName = existing.fdFileName ?? '${existing.workOrderNumber}-fd';
      await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: _fdMimeType(fileName));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not download FD document: $e')));
    }
  }

  Future<void> _submit() async {
    final departmentName = _departmentController.text.trim();
    if (departmentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department is required.')));
      return;
    }

    final appUser = ref.read(currentAppUserProvider).value;
    final actorUid = appUser?.uid ?? '';
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _submitting = true);
    try {
      final fdNumber = _fdNumberController.text.trim();
      final hasFd = fdNumber.isNotEmpty;

      final draft = WorkOrder(
        id: widget.existing?.id ?? '',
        workOrderNumber: widget.existing?.workOrderNumber ?? '',
        year: _workOrderDate.year,
        workOrderDate: _workOrderDate,
        departmentName: departmentName,
        contractType: _contractType,
        startDate: _startDate,
        endDate: _contractType == ContractType.tillNextTender ? null : _endDate,
        extensionAvailable: _extensionAvailable,
        status: _status,
        remarks: _remarksController.text.trim(),
        extensionStartDate: _contractType == ContractType.extension ? _extensionStartDate : null,
        extensionEndDate: _contractType == ContractType.extension ? _extensionEndDate : null,
        extensionOrderNumber: _contractType == ContractType.extension
            ? _extensionOrderNumberController.text.trim()
            : null,
        extensionReason: _contractType == ContractType.extension ? _extensionReasonController.text.trim() : null,
        deptOfficeAddress: _deptOfficeAddressController.text.trim(),
        deptContactPerson: _deptContactPersonController.text.trim(),
        deptPhoneNumber: _deptPhoneController.text.trim(),
        deptEmail: _deptEmailController.text.trim(),
        deptGSTIN: _deptGSTINController.text.trim(),
        contractValue: double.tryParse(_contractValueController.text.trim()) ?? 0,
        securityDeposit: double.tryParse(_securityDepositController.text.trim()) ?? 0,
        emdAmount: double.tryParse(_emdAmountController.text.trim()) ?? 0,
        tenderNumber: _tenderNumberController.text.trim(),
        tenderName: _tenderNameController.text.trim(),
        fdNumber: hasFd ? fdNumber : null,
        fdBankName: hasFd ? _fdBankNameController.text.trim() : null,
        fdBranchName: hasFd ? _fdBranchNameController.text.trim() : null,
        fdAmount: hasFd ? (double.tryParse(_fdAmountController.text.trim()) ?? 0) : null,
        fdIssueDate: hasFd ? _fdIssueDate : null,
        fdMaturityDate: hasFd ? _fdMaturityDate : null,
        fdInterestRate: hasFd ? double.tryParse(_fdInterestRateController.text.trim()) : null,
        fdStoragePath: widget.existing?.fdStoragePath,
        fdFileName: widget.existing?.fdFileName,
        fdStatus: hasFd ? (_fdStatus ?? FdStatus.active) : null,
        fdReleasedAt: hasFd && _fdStatus == FdStatus.released
            ? (widget.existing?.fdReleasedAt ?? DateTime.now())
            : null,
        createdBy: widget.existing?.createdBy ?? actorUid,
        createdByName: widget.existing?.createdByName ?? actorName,
        createdAt: widget.existing?.createdAt,
      );

      final repo = ref.read(workOrderRepositoryProvider);
      if (_isEditing) {
        await repo.update(
          workOrder: draft,
          actorUid: actorUid,
          actorName: actorName,
          fdFileBytes: _pendingFdFile?.bytes,
          fdFileName: _pendingFdFile?.name,
          fdFileContentType: _pendingFdFile?.contentType,
        );
      } else {
        await repo.create(
          draft: draft,
          actorUid: actorUid,
          actorName: actorName,
          fdFileBytes: _pendingFdFile?.bytes,
          fdFileName: _pendingFdFile?.name,
          fdFileContentType: _pendingFdFile?.contentType,
        );
      }
      await ref.read(departmentRepositoryProvider).ensureExists(name: departmentName, actorUid: actorUid);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work Order saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Pulldown over the shared Department table (`departmentListProvider`)
  /// that still accepts free text — tapping the field lists every existing
  /// department (typing filters it), and picking one or typing a new name
  /// both work; `_submit` adds any new name to the table.
  Widget _departmentField() {
    final names = ref
        .watch(departmentListProvider)
        .maybeWhen(data: (list) => list.map((d) => d.name).toList(), orElse: () => const <String>[]);

    return DropdownMenu<String>(
      controller: _departmentController,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      dropdownMenuEntries: [for (final n in names) DropdownMenuEntry(value: n, label: n)],
      onSelected: (value) {
        if (value != null) _departmentController.text = value;
      },
    );
  }

  Widget _sectionHeader(String title, {bool withDivider = true}) {
    return Padding(
      padding: EdgeInsets.only(top: withDivider ? 18 : 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (withDivider) Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ],
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
            label: 'Work Order Number',
            child: TextField(
              controller: TextEditingController(text: widget.existing!.workOrderNumber),
              enabled: false,
            ),
          ),
        _dateButton('Work Order Date', _workOrderDate, (d) => setState(() => _workOrderDate = d)),
        FormRowLabel(label: 'Department', child: _departmentField()),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Contract Type',
                child: DropdownButtonFormField<ContractType>(
                  initialValue: _contractType,
                  isExpanded: true,
                  items: [for (final c in ContractType.values) DropdownMenuItem(value: c, child: Text(c.label))],
                  onChanged: (v) => setState(() => _contractType = v ?? ContractType.fixed),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Status',
                child: DropdownButtonFormField<WorkOrderStatus>(
                  initialValue: _status,
                  isExpanded: true,
                  items: [
                    for (final s in WorkOrderStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? WorkOrderStatus.active),
                ),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _dateButton('Start Date', _startDate, (d) => setState(() => _startDate = d))),
            const SizedBox(width: 10),
            if (_contractType != ContractType.tillNextTender)
              Expanded(child: _dateButton('End Date', _endDate, (d) => setState(() => _endDate = d)))
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
        FormRowLabel(
          label: 'Extension Available',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _extensionAvailable,
            title: Text(_extensionAvailable ? 'Yes' : 'No'),
            onChanged: (v) => setState(() => _extensionAvailable = v),
          ),
        ),
        if (_contractType == ContractType.extension) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _dateButton(
                  'Extension Start Date',
                  _extensionStartDate,
                  (d) => setState(() => _extensionStartDate = d),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateButton('Extension End Date', _extensionEndDate, (d) => setState(() => _extensionEndDate = d)),
              ),
            ],
          ),
          FormRowLabel(label: 'Extension Order Number', child: TextField(controller: _extensionOrderNumberController)),
          FormRowLabel(label: 'Extension Reason', child: TextField(controller: _extensionReasonController, maxLines: 2)),
        ],
        FormRowLabel(label: 'Remarks', child: TextField(controller: _remarksController, maxLines: 2)),

        _sectionHeader('Department Information'),
        FormRowLabel(label: 'Office Address', child: TextField(controller: _deptOfficeAddressController, maxLines: 2)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(label: 'Contact Person', child: TextField(controller: _deptContactPersonController)),
            ),
            const SizedBox(width: 10),
            Expanded(child: FormRowLabel(label: 'Phone Number', child: TextField(controller: _deptPhoneController))),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: FormRowLabel(label: 'Email', child: TextField(controller: _deptEmailController))),
            const SizedBox(width: 10),
            Expanded(child: FormRowLabel(label: 'GSTIN No.', child: TextField(controller: _deptGSTINController))),
          ],
        ),

        _sectionHeader('Financial Details'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Contract Value (Rs.)',
                child: TextField(controller: _contractValueController, keyboardType: TextInputType.number),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Security Deposit (Rs.)',
                child: TextField(controller: _securityDepositController, keyboardType: TextInputType.number),
              ),
            ),
          ],
        ),
        FormRowLabel(
          label: 'EMD Amount (Rs.)',
          child: TextField(controller: _emdAmountController, keyboardType: TextInputType.number),
        ),

        _sectionHeader('Tender Reference'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: FormRowLabel(label: 'Tender Number', child: TextField(controller: _tenderNumberController))),
            const SizedBox(width: 10),
            Expanded(child: FormRowLabel(label: 'Tender Name', child: TextField(controller: _tenderNameController))),
          ],
        ),

        _sectionHeader('Fixed Deposit Details (optional)'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: FormRowLabel(label: 'FD Number', child: TextField(controller: _fdNumberController))),
            const SizedBox(width: 10),
            Expanded(child: FormRowLabel(label: 'Bank Name', child: TextField(controller: _fdBankNameController))),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: FormRowLabel(label: 'Branch Name', child: TextField(controller: _fdBranchNameController))),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'FD Amount (Rs.)',
                child: TextField(controller: _fdAmountController, keyboardType: TextInputType.number),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _dateButton('FD Issue Date', _fdIssueDate, (d) => setState(() => _fdIssueDate = d))),
            const SizedBox(width: 10),
            Expanded(child: _dateButton('FD Maturity Date', _fdMaturityDate, (d) => setState(() => _fdMaturityDate = d))),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Interest Rate (%)',
                child: TextField(controller: _fdInterestRateController, keyboardType: TextInputType.number),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'FD Status',
                child: DropdownButtonFormField<FdStatus?>(
                  initialValue: _fdStatus,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— None —')),
                    for (final s in FdStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) => setState(() => _fdStatus = v),
                ),
              ),
            ),
          ],
        ),
        FormRowLabel(
          label: 'FD Scan Copy',
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickFdFile,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _pendingFdFile != null
                          ? 'Attached: ${_pendingFdFile!.name}'
                          : (widget.existing?.hasFdFile == true
                                ? 'On file: ${widget.existing!.fdFileName}. Tap to replace.'
                                : 'Tap to upload FD scan (PDF or image)'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              if (_pendingFdFile == null && widget.existing?.hasFdFile == true) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: 'View FD document',
                  onPressed: _viewFdFile,
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download FD document',
                  onPressed: _downloadFdFile,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),
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
                  : const Text('Save Work Order'),
            ),
          ],
        ),
      ],
    );
  }
}
