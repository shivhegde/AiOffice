import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatting.dart';
import '../../../shared/widgets/document_actions.dart';
import '../../../shared/widgets/slideover_panel.dart';
import '../../users/application/user_providers.dart';
import '../application/epf_case_providers.dart';
import '../domain/epf_case.dart';
import '../domain/epf_enums.dart';
import '../domain/epf_followup.dart';
import 'widgets/epf_followup_history_dialog.dart';

/// Create/edit form for an EPF Case — matches REQUIREMENTS.md §9.5.2
/// (Personal/Employment Details) / §9.5.3 (Service) / §9.5.4 (Case
/// Tracking) / §9.5.5 (Document Manager) / §9.5.6 (Follow-up) / §9.5.7
/// (Income) sections.
class EpfCaseFormSlideover {
  EpfCaseFormSlideover._();

  static Future<void> show(BuildContext context, {EpfCase? existing}) {
    return SlideoverPanel.show(
      context,
      title: existing != null ? 'Case — ${existing.clientId}' : 'New EPF Case',
      body: _EpfCaseForm(existing: existing),
      actions: const [],
      width: 500,
    );
  }
}

class _EpfCaseForm extends ConsumerStatefulWidget {
  const _EpfCaseForm({this.existing});

  final EpfCase? existing;

  @override
  ConsumerState<_EpfCaseForm> createState() => _EpfCaseFormState();
}

class _EpfCaseFormState extends ConsumerState<_EpfCaseForm> {
  final _nameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _alternateMobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _uanController = TextEditingController();
  final _passwordController = TextEditingController();
  final _currentCompanyController = TextEditingController();
  final _feeController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _followupRemarkController = TextEditingController();
  final _otherServiceController = TextEditingController();

  late DateTime _dateOfBirth;
  DateTime? _feePaidAt;
  Gender _gender = Gender.male;
  Set<EpfService> _services = {};
  CaseStage _stage = CaseStage.newClient;

  /// Optional first followup captured on a new case; saved to
  /// `epf_followups` after the case is created. Null = no followup.
  DateTime? _followupDate;
  FollowupStatus _followupStatus = FollowupStatus.active;

  final Map<EpfDocumentSlot, ({Uint8List bytes, String name, String contentType})> _pendingDocuments = {};

  bool _submitting = false;
  bool _showPassword = false;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController.text = e?.name ?? '';
    _fatherNameController.text = e?.fatherName ?? '';
    _mobileController.text = e?.mobile ?? '';
    _alternateMobileController.text = e?.alternateMobile ?? '';
    _emailController.text = e?.email ?? '';
    _addressController.text = e?.address ?? '';
    _aadhaarController.text = e?.aadhaarNumber ?? '';
    _panController.text = e?.panNumber ?? '';
    _uanController.text = e?.uanNumber ?? '';
    _passwordController.text = e?.password ?? '';
    _currentCompanyController.text = e?.currentCompany ?? '';
    _feeController.text = e != null && e.fee > 0 ? e.fee.toStringAsFixed(0) : '';
    _amountPaidController.text = e != null && e.amountPaid > 0 ? e.amountPaid.toStringAsFixed(0) : '';

    _dateOfBirth = e?.dateOfBirth ?? DateTime(1990, 1, 1);
    _feePaidAt = e?.feePaidAt;
    _gender = e?.gender ?? Gender.male;
    _services = {...?e?.services};
    _otherServiceController.text = e?.otherService ?? '';
    _stage = e?.stage ?? CaseStage.newClient;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _mobileController.dispose();
    _alternateMobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _uanController.dispose();
    _passwordController.dispose();
    _currentCompanyController.dispose();
    _feeController.dispose();
    _amountPaidController.dispose();
    _followupRemarkController.dispose();
    _otherServiceController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDateInto(DateTime? initial, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1950),
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

  Future<void> _pickDocument(EpfDocumentSlot slot) async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    if (!mounted) return;
    setState(() {
      _pendingDocuments[slot] = (
        bytes: bytes,
        name: file.name,
        contentType: extension == 'pdf' ? 'application/pdf' : 'image/$extension',
      );
    });
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required.')));
      return;
    }
    if (_mobileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mobile number is required.')));
      return;
    }
    if (_services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one service.')));
      return;
    }
    final followupRemark = _followupRemarkController.text.trim();
    if (!_isEditing && _followupDate == null && followupRemark.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a Followup Date for the followup remark, or clear the remark.')),
      );
      return;
    }

    final appUser = ref.read(currentAppUserProvider).value;
    final actorUid = appUser?.uid ?? '';
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _submitting = true);
    try {
      final amountPaid = double.tryParse(_amountPaidController.text.trim()) ?? 0;
      final draft = EpfCase(
        id: widget.existing?.id ?? '',
        clientId: widget.existing?.clientId ?? '',
        year: widget.existing?.year ?? DateTime.now().year,
        name: _nameController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        mobile: _mobileController.text.trim(),
        alternateMobile: _alternateMobileController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        aadhaarNumber: _aadhaarController.text.trim(),
        panNumber: _panController.text.trim(),
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        uanNumber: _uanController.text.trim(),
        password: _passwordController.text,
        currentCompany: _currentCompanyController.text.trim(),
        services: [for (final s in EpfService.values) if (_services.contains(s)) s],
        otherService: _services.contains(EpfService.other) ? _otherServiceController.text.trim() : '',
        stage: _stage,
        documentPaths: widget.existing?.documentPaths ?? const {},
        documentFileNames: widget.existing?.documentFileNames ?? const {},
        fee: double.tryParse(_feeController.text.trim()) ?? 0,
        amountPaid: amountPaid,
        feePaidAt: amountPaid > 0 ? (_feePaidAt ?? DateTime.now()) : null,
        followUps: widget.existing?.followUps ?? const [],
        createdBy: widget.existing?.createdBy ?? actorUid,
        createdByName: widget.existing?.createdByName ?? actorName,
        createdAt: widget.existing?.createdAt,
      );

      final repo = ref.read(epfCaseRepositoryProvider);
      if (_isEditing) {
        await repo.update(epfCase: draft, actorUid: actorUid, actorName: actorName, documentFiles: _pendingDocuments);
      } else {
        final created = await repo.create(
          draft: draft,
          actorUid: actorUid,
          actorName: actorName,
          documentFiles: _pendingDocuments,
        );
        if (_followupDate != null) {
          await repo.addFollowup(
            epfCase: created,
            followupDate: _followupDate!,
            remark: followupRemark,
            status: _followupStatus,
            actorUid: actorUid,
            actorName: actorName,
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

  Widget _documentSlotRow(EpfDocumentSlot slot) {
    final pending = _pendingDocuments[slot];
    final existingName = widget.existing?.documentFileNames[slot];
    final existingPath = widget.existing?.documentPaths[slot];
    return FormRowLabel(
      label: slot.label,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _pickDocument(slot),
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
            DocumentActionIcons(storagePath: existingPath, fileName: existingName, label: slot.label),
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
        if (_isEditing)
          FormRowLabel(
            label: 'Client ID',
            child: TextField(controller: TextEditingController(text: widget.existing!.clientId), enabled: false),
          ),
        FormRowLabel(
          label: 'Name',
          child: TextField(controller: _nameController),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: "Father's Name",
                child: TextField(controller: _fatherNameController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Gender',
                child: DropdownButtonFormField<Gender>(
                  initialValue: _gender,
                  isExpanded: true,
                  items: [for (final g in Gender.values) DropdownMenuItem(value: g, child: Text(g.label))],
                  onChanged: (v) => setState(() => _gender = v ?? Gender.male),
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
                label: 'Mobile No.',
                child: TextField(controller: _mobileController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Alternate Mobile',
                child: TextField(controller: _alternateMobileController),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Email',
                child: TextField(controller: _emailController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _dateButton('Date of Birth', _dateOfBirth, (d) => setState(() => _dateOfBirth = d))),
          ],
        ),
        FormRowLabel(
          label: 'Address',
          child: TextField(controller: _addressController, maxLines: 2),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Aadhaar Number',
                child: TextField(controller: _aadhaarController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'PAN Number',
                child: TextField(controller: _panController),
              ),
            ),
          ],
        ),

        _sectionHeader('Employment Details'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'UAN Number',
                child: TextField(controller: _uanController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Password',
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        FormRowLabel(
          label: 'Current Company',
          child: TextField(controller: _currentCompanyController),
        ),

        _sectionHeader('Service & Case Tracking'),
        FormRowLabel(
          label: 'Services (select one or more)',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in EpfService.values)
                FilterChip(
                  label: Text(s.label),
                  selected: _services.contains(s),
                  visualDensity: VisualDensity.compact,
                  onSelected: (selected) => setState(() {
                    _services = selected ? {..._services, s} : ({..._services}..remove(s));
                  }),
                ),
            ],
          ),
        ),
        if (_services.contains(EpfService.other))
          FormRowLabel(
            label: 'Other Service',
            child: TextField(
              controller: _otherServiceController,
              decoration: const InputDecoration(hintText: 'Describe the other service'),
            ),
          ),
        FormRowLabel(
          label: 'Stage',
          child: DropdownButtonFormField<CaseStage>(
            initialValue: _stage,
            isExpanded: true,
            items: [for (final s in CaseStage.values) DropdownMenuItem(value: s, child: Text(s.label))],
            onChanged: (v) => setState(() => _stage = v ?? CaseStage.newClient),
          ),
        ),

        _sectionHeader('Document Manager'),
        for (final slot in EpfDocumentSlot.values) _documentSlotRow(slot),

        _sectionHeader('Income'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Fee (Rs.)',
                child: TextField(controller: _feeController, keyboardType: TextInputType.number),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Amount Paid (Rs.)',
                child: TextField(controller: _amountPaidController, keyboardType: TextInputType.number),
              ),
            ),
          ],
        ),
        _dateButton('Payment Date', _feePaidAt, (d) => setState(() => _feePaidAt = d)),

        _sectionHeader('Followup'),
        if (_isEditing)
          FormRowLabel(
            label: 'Followups',
            child: OutlinedButton.icon(
              icon: const Icon(Icons.history, size: 16),
              label: const Text('Open Followup History to add or update followups'),
              onPressed: () => EpfFollowupHistoryDialog.show(context, widget.existing!),
            ),
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FormRowLabel(
                  label: 'Followup Date',
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _followupDate ?? DateTime.now(),
                              firstDate: DateTime(2015),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _followupDate = picked);
                          },
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_followupDate == null ? 'No followup' : formatDisplayDate(_followupDate!)),
                          ),
                        ),
                      ),
                      if (_followupDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          tooltip: 'Clear followup date',
                          onPressed: () => setState(() => _followupDate = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FormRowLabel(
                  label: 'Followup Status',
                  child: DropdownButtonFormField<FollowupStatus>(
                    initialValue: _followupStatus,
                    isExpanded: true,
                    items: [for (final st in FollowupStatus.values) DropdownMenuItem(value: st, child: Text(st.label))],
                    onChanged: (v) => setState(() => _followupStatus = v ?? FollowupStatus.active),
                  ),
                ),
              ),
            ],
          ),
          FormRowLabel(
            label: 'Followup Remarks',
            child: TextField(controller: _followupRemarkController, maxLines: 2),
          ),
        ],

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
                  : const Text('Save Case'),
            ),
          ],
        ),
      ],
    );
  }
}
