import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/slideover_panel.dart';
import '../../users/application/user_providers.dart';
import '../application/candidate_providers.dart';
import '../domain/candidate.dart';
import '../domain/candidate_enums.dart';

/// Create/edit form for a Candidate — matches REQUIREMENTS.md §9.2's
/// Personal Information / Address Information / Education Details /
/// Category / Experience / Languages / Physical Information (security
/// roles only) / Document Storage sections.
class CandidateFormSlideover {
  CandidateFormSlideover._();

  static Future<void> show(BuildContext context, {Candidate? existing}) {
    return SlideoverPanel.show(
      context,
      title: existing != null ? 'Candidate — ${existing.candidateId}' : 'New Candidate',
      body: _CandidateForm(existing: existing),
      actions: const [],
      width: 480,
    );
  }
}

class _CandidateForm extends ConsumerStatefulWidget {
  const _CandidateForm({this.existing});

  final Candidate? existing;

  @override
  ConsumerState<_CandidateForm> createState() => _CandidateFormState();
}

class _CandidateFormState extends ConsumerState<_CandidateForm> {
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _alternateController = TextEditingController();
  final _referredByController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _villageController = TextEditingController();
  final _cityTownController = TextEditingController();
  final _talukController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _heightController = TextEditingController();

  late DateTime _dateOfBirth;
  Gender _gender = Gender.male;
  MaritalStatus _maritalStatus = MaritalStatus.single;
  CandidateCategory _category = CandidateCategory.security;
  ExperienceLevel _experience = ExperienceLevel.fresher;
  bool _exServiceman = false;
  final Set<EducationLevel> _education = {};
  final Set<Language> _languages = {};

  ({Uint8List bytes, String name, String contentType})? _pendingResume;
  bool _submitting = false;
  bool get _isEditing => widget.existing != null;
  bool get _isSecurityCategory => _category == CandidateCategory.security;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _fullNameController.text = e?.fullName ?? '';
    _mobileController.text = e?.mobileNumber ?? '';
    _alternateController.text = e?.alternateNumber ?? '';
    _referredByController.text = e?.referredBy ?? '';
    _whatsappController.text = e?.whatsappNumber ?? '';
    _villageController.text = e?.village ?? '';
    _cityTownController.text = e?.cityTown ?? '';
    _talukController.text = e?.taluk ?? '';
    _districtController.text = e?.district ?? '';
    _stateController.text = e?.state ?? '';
    _pincodeController.text = e?.pincode ?? '';
    _heightController.text = e?.height ?? '';

    _dateOfBirth = e?.dateOfBirth ?? DateTime(1995, 1, 1);
    _gender = e?.gender ?? Gender.male;
    _maritalStatus = e?.maritalStatus ?? MaritalStatus.single;
    _category = e?.category ?? CandidateCategory.security;
    _experience = e?.experience ?? ExperienceLevel.fresher;
    _exServiceman = e?.exServiceman ?? false;
    if (e != null) {
      _education.addAll(e.education);
      _languages.addAll(e.languagesKnown);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _alternateController.dispose();
    _referredByController.dispose();
    _whatsappController.dispose();
    _villageController.dispose();
    _cityTownController.dispose();
    _talukController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _heightController.dispose();
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

  Future<void> _pickResume() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    final contentType = switch (extension) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
    if (!mounted) return;
    setState(() => _pendingResume = (bytes: bytes, name: file.name, contentType: contentType));
  }

  Future<void> _submit() async {
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Full name is required.')));
      return;
    }
    if (_mobileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mobile number is required.')));
      return;
    }

    final appUser = ref.read(currentAppUserProvider).value;
    final actorUid = appUser?.uid ?? '';
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _submitting = true);
    try {
      final draft = Candidate(
        id: widget.existing?.id ?? '',
        candidateId: widget.existing?.candidateId ?? '',
        year: widget.existing?.year ?? DateTime.now().year,
        fullName: _fullNameController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        alternateNumber: _alternateController.text.trim(),
        referredBy: _referredByController.text.trim(),
        whatsappNumber: _whatsappController.text.trim(),
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        maritalStatus: _maritalStatus,
        village: _villageController.text.trim(),
        cityTown: _cityTownController.text.trim(),
        taluk: _talukController.text.trim(),
        district: _districtController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        education: _education,
        category: _category,
        experience: _experience,
        languagesKnown: _languages,
        height: _isSecurityCategory ? _heightController.text.trim() : '',
        exServiceman: _isSecurityCategory ? _exServiceman : false,
        resumeStoragePath: widget.existing?.resumeStoragePath,
        resumeFileName: widget.existing?.resumeFileName,
        createdBy: widget.existing?.createdBy ?? actorUid,
        createdByName: widget.existing?.createdByName ?? actorName,
        createdAt: widget.existing?.createdAt,
      );

      final repo = ref.read(candidateRepositoryProvider);
      if (_isEditing) {
        await repo.update(candidate: draft, actorUid: actorUid, actorName: actorName, resumeFile: _pendingResume);
      } else {
        await repo.create(draft: draft, actorUid: actorUid, actorName: actorName, resumeFile: _pendingResume);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidate saved.')));
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

  Widget _multiSelectChips<T>({
    required String label,
    required List<T> options,
    required Set<T> selected,
    required String Function(T) labelOf,
  }) {
    return FormRowLabel(
      label: label,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            FilterChip(
              label: Text(labelOf(option)),
              selected: selected.contains(option),
              onSelected: (v) => setState(() => v ? selected.add(option) : selected.remove(option)),
            ),
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
            label: 'Candidate ID',
            child: TextField(controller: TextEditingController(text: widget.existing!.candidateId), enabled: false),
          ),
        FormRowLabel(
          label: 'Full Name',
          child: TextField(controller: _fullNameController),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Mobile Number',
                child: TextField(controller: _mobileController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Alternate Number',
                child: TextField(controller: _alternateController),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'WhatsApp Number',
                child: TextField(controller: _whatsappController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Referred By',
                child: TextField(controller: _referredByController),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _dateButton('Date of Birth', _dateOfBirth, (d) => setState(() => _dateOfBirth = d))),
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
        FormRowLabel(
          label: 'Marital Status',
          child: DropdownButtonFormField<MaritalStatus>(
            initialValue: _maritalStatus,
            isExpanded: true,
            items: [for (final m in MaritalStatus.values) DropdownMenuItem(value: m, child: Text(m.label))],
            onChanged: (v) => setState(() => _maritalStatus = v ?? MaritalStatus.single),
          ),
        ),

        _sectionHeader('Address Information'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Village',
                child: TextField(controller: _villageController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'City / Town',
                child: TextField(controller: _cityTownController),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Taluk',
                child: TextField(controller: _talukController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'District',
                child: TextField(controller: _districtController),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'State',
                child: TextField(controller: _stateController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Pincode',
                child: TextField(controller: _pincodeController),
              ),
            ),
          ],
        ),

        _sectionHeader('Education Details'),
        _multiSelectChips(
          label: 'Qualifications',
          options: EducationLevel.values,
          selected: _education,
          labelOf: (e) => e.label,
        ),

        _sectionHeader('Category & Experience'),
        FormRowLabel(
          label: 'Category / Post Applied For',
          child: DropdownButtonFormField<CandidateCategory>(
            initialValue: _category,
            isExpanded: true,
            items: [for (final c in CandidateCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
            onChanged: (v) => setState(() => _category = v ?? CandidateCategory.security),
          ),
        ),
        FormRowLabel(
          label: 'Experience',
          child: DropdownButtonFormField<ExperienceLevel>(
            initialValue: _experience,
            isExpanded: true,
            items: [for (final e in ExperienceLevel.values) DropdownMenuItem(value: e, child: Text(e.label))],
            onChanged: (v) => setState(() => _experience = v ?? ExperienceLevel.fresher),
          ),
        ),
        _multiSelectChips(
          label: 'Languages Known',
          options: Language.values,
          selected: _languages,
          labelOf: (l) => l.label,
        ),

        if (_isSecurityCategory) ...[
          _sectionHeader('Physical Information (Security roles)'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FormRowLabel(
                  label: 'Height',
                  child: TextField(controller: _heightController),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FormRowLabel(
                  label: 'Ex-Serviceman',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _exServiceman,
                    title: Text(_exServiceman ? 'Yes' : 'No'),
                    onChanged: (v) => setState(() => _exServiceman = v),
                  ),
                ),
              ),
            ],
          ),
        ],

        _sectionHeader('Document Storage'),
        FormRowLabel(
          label: 'Resume',
          child: InkWell(
            onTap: _pickResume,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _pendingResume != null
                    ? 'Attached: ${_pendingResume!.name}'
                    : (widget.existing?.hasResume == true
                          ? 'On file: ${widget.existing!.resumeFileName}. Tap to replace.'
                          : 'Tap to upload resume (PDF or Word)'),
                textAlign: TextAlign.center,
              ),
            ),
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
                  : const Text('Save Candidate'),
            ),
          ],
        ),
      ],
    );
  }
}
