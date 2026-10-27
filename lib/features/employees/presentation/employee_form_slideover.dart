import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/document_actions.dart';
import '../../../shared/widgets/slideover_panel.dart';
import '../../users/application/user_providers.dart';
import '../application/employee_providers.dart';
import '../domain/employee.dart';
import '../domain/employee_enums.dart';

/// Create/edit form for an Employee — matches REQUIREMENTS.md §9.1's
/// Basic Information / Identity Details / Appointment Information /
/// Bank Account Details / Document Upload sections.
class EmployeeFormSlideover {
  EmployeeFormSlideover._();

  static Future<void> show(BuildContext context, {Employee? existing}) {
    return SlideoverPanel.show(
      context,
      title: existing != null ? 'Employee — ${existing.employeeId}' : 'New Employee',
      body: _EmployeeForm(existing: existing),
      actions: const [],
      width: 480,
    );
  }
}

class _EmployeeForm extends ConsumerStatefulWidget {
  const _EmployeeForm({this.existing});

  final Employee? existing;

  @override
  ConsumerState<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends ConsumerState<_EmployeeForm> {
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _alternateController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentAddressController = TextEditingController();
  final _permanentAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _departmentController = TextEditingController();
  final _subDepartmentController = TextEditingController();
  final _designationController = TextEditingController();
  final _branchLocationController = TextEditingController();
  final _remarksController = TextEditingController();
  final _epfNumberController = TextEditingController();
  final _esiNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _bankBranchNameController = TextEditingController();

  late DateTime _dateOfBirth;
  late DateTime _dateOfAppointment;
  late DateTime _joiningDate;
  DateTime? _epfJoiningDate;
  DateTime? _esiJoiningDate;
  Gender _gender = Gender.male;
  EmployeeType _employeeType = EmployeeType.permanent;
  WorkStatus _workStatus = WorkStatus.active;

  ({Uint8List bytes, String name, String contentType})? _pendingPhoto;
  ({Uint8List bytes, String name, String contentType})? _pendingAadhaarFile;
  ({Uint8List bytes, String name, String contentType})? _pendingPanFile;
  ({Uint8List bytes, String name, String contentType})? _pendingPassbookFile;

  bool _submitting = false;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _fullNameController.text = e?.fullName ?? '';
    _mobileController.text = e?.mobileNumber ?? '';
    _alternateController.text = e?.alternateNumber ?? '';
    _emailController.text = e?.email ?? '';
    _currentAddressController.text = e?.currentAddress ?? '';
    _permanentAddressController.text = e?.permanentAddress ?? '';
    _cityController.text = e?.city ?? '';
    _stateController.text = e?.state ?? '';
    _pincodeController.text = e?.pincode ?? '';
    _aadhaarController.text = e?.aadhaarNumber ?? '';
    _panController.text = e?.panNumber ?? '';
    _departmentController.text = e?.department ?? '';
    _subDepartmentController.text = e?.subDepartment ?? '';
    _designationController.text = e?.designation ?? '';
    _branchLocationController.text = e?.branchLocation ?? '';
    _remarksController.text = e?.remarks ?? '';
    _epfNumberController.text = e?.epfNumber ?? '';
    _esiNumberController.text = e?.esiNumber ?? '';
    _bankNameController.text = e?.bankName ?? '';
    _accountNumberController.text = e?.accountNumber ?? '';
    _ifscController.text = e?.ifscCode ?? '';
    _bankBranchNameController.text = e?.bankBranchName ?? '';
    _epfJoiningDate = e?.epfJoiningDate;
    _esiJoiningDate = e?.esiJoiningDate;

    _dateOfBirth = e?.dateOfBirth ?? DateTime(1990, 1, 1);
    _dateOfAppointment = e?.dateOfAppointment ?? DateTime.now();
    _joiningDate = e?.joiningDate ?? DateTime.now();
    _gender = e?.gender ?? Gender.male;
    _employeeType = e?.employeeType ?? EmployeeType.permanent;
    _workStatus = e?.workStatus ?? WorkStatus.active;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _alternateController.dispose();
    _emailController.dispose();
    _currentAddressController.dispose();
    _permanentAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _departmentController.dispose();
    _subDepartmentController.dispose();
    _designationController.dispose();
    _branchLocationController.dispose();
    _remarksController.dispose();
    _epfNumberController.dispose();
    _esiNumberController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _bankBranchNameController.dispose();
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

  Future<({Uint8List bytes, String name, String contentType})?> _pickFile() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    return (bytes: bytes, name: file.name, contentType: extension == 'pdf' ? 'application/pdf' : 'image/$extension');
  }

  Widget _fileUploadRow({
    required String label,
    required ({Uint8List bytes, String name, String contentType})? pending,
    required String? existingFileName,
    required String? existingStoragePath,
    required ValueChanged<({Uint8List bytes, String name, String contentType})?> onPicked,
  }) {
    return FormRowLabel(
      label: label,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final file = await _pickFile();
                if (file != null) setState(() => onPicked(file));
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pending != null
                      ? 'Attached: ${pending.name}'
                      : (existingFileName != null ? 'On file: $existingFileName. Tap to replace.' : 'Tap to upload'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (pending == null && existingStoragePath != null && existingFileName != null) ...[
            const SizedBox(width: 8),
            DocumentActionIcons(storagePath: existingStoragePath, fileName: existingFileName, label: label),
          ],
        ],
      ),
    );
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
      final draft = Employee(
        id: widget.existing?.id ?? '',
        employeeId: widget.existing?.employeeId ?? '',
        year: _dateOfAppointment.year,
        fullName: _fullNameController.text.trim(),
        gender: _gender,
        dateOfBirth: _dateOfBirth,
        mobileNumber: _mobileController.text.trim(),
        alternateNumber: _alternateController.text.trim(),
        email: _emailController.text.trim(),
        currentAddress: _currentAddressController.text.trim(),
        permanentAddress: _permanentAddressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        aadhaarNumber: _aadhaarController.text.trim(),
        panNumber: _panController.text.trim(),
        dateOfAppointment: _dateOfAppointment,
        joiningDate: _joiningDate,
        department: _departmentController.text.trim(),
        subDepartment: _subDepartmentController.text.trim(),
        designation: _designationController.text.trim(),
        employeeType: _employeeType,
        branchLocation: _branchLocationController.text.trim(),
        remarks: _remarksController.text.trim(),
        workStatus: _workStatus,
        epfNumber: _epfNumberController.text.trim(),
        epfJoiningDate: _epfJoiningDate,
        esiNumber: _esiNumberController.text.trim(),
        esiJoiningDate: _esiJoiningDate,
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        ifscCode: _ifscController.text.trim().toUpperCase(),
        bankBranchName: _bankBranchNameController.text.trim(),
        photoStoragePath: widget.existing?.photoStoragePath,
        photoFileName: widget.existing?.photoFileName,
        aadhaarStoragePath: widget.existing?.aadhaarStoragePath,
        aadhaarFileName: widget.existing?.aadhaarFileName,
        panStoragePath: widget.existing?.panStoragePath,
        panFileName: widget.existing?.panFileName,
        passbookStoragePath: widget.existing?.passbookStoragePath,
        passbookFileName: widget.existing?.passbookFileName,
        createdBy: widget.existing?.createdBy ?? actorUid,
        createdByName: widget.existing?.createdByName ?? actorName,
        createdAt: widget.existing?.createdAt,
      );

      final repo = ref.read(employeeRepositoryProvider);
      if (_isEditing) {
        await repo.update(
          employee: draft,
          actorUid: actorUid,
          actorName: actorName,
          photoFile: _pendingPhoto,
          aadhaarFile: _pendingAadhaarFile,
          panFile: _pendingPanFile,
          passbookFile: _pendingPassbookFile,
        );
      } else {
        await repo.create(
          draft: draft,
          actorUid: actorUid,
          actorName: actorName,
          photoFile: _pendingPhoto,
          aadhaarFile: _pendingAadhaarFile,
          panFile: _pendingPanFile,
          passbookFile: _pendingPassbookFile,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Distinct non-empty values already entered on other employees, for
  /// the Department / Sub-Department pulldowns.
  List<String> _previousValues(String Function(Employee e) pick) {
    final all = ref.watch(employeeListProvider).value ?? const <Employee>[];
    final values = {
      for (final e in all)
        if (pick(e).trim().isNotEmpty) pick(e).trim(),
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
            label: 'Employee ID',
            child: TextField(controller: TextEditingController(text: widget.existing!.employeeId), enabled: false),
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
                label: 'Gender',
                child: DropdownButtonFormField<Gender>(
                  initialValue: _gender,
                  isExpanded: true,
                  items: [for (final g in Gender.values) DropdownMenuItem(value: g, child: Text(g.label))],
                  onChanged: (v) => setState(() => _gender = v ?? Gender.male),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _dateButton('Date of Birth', _dateOfBirth, (d) => setState(() => _dateOfBirth = d))),
          ],
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
        FormRowLabel(
          label: 'Email ID',
          child: TextField(controller: _emailController),
        ),
        FormRowLabel(
          label: 'Current Address',
          child: TextField(controller: _currentAddressController, maxLines: 2),
        ),
        FormRowLabel(
          label: 'Permanent Address',
          child: TextField(controller: _permanentAddressController, maxLines: 2),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'City',
                child: TextField(controller: _cityController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'State',
                child: TextField(controller: _stateController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'PIN Code',
                child: TextField(controller: _pincodeController),
              ),
            ),
          ],
        ),

        _sectionHeader('Identity Details'),
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

        _sectionHeader('Appointment / Job Information'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _dateButton(
                'Date of Appointment',
                _dateOfAppointment,
                (d) => setState(() => _dateOfAppointment = d),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _dateButton('Joining Date', _joiningDate, (d) => setState(() => _joiningDate = d))),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Department',
                child: _pickOrTypeField(_departmentController, _previousValues((e) => e.department)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Sub-Department',
                child: _pickOrTypeField(_subDepartmentController, _previousValues((e) => e.subDepartment)),
              ),
            ),
          ],
        ),
        FormRowLabel(
          label: 'Designation',
          child: TextField(controller: _designationController),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Employee Type',
                child: DropdownButtonFormField<EmployeeType>(
                  initialValue: _employeeType,
                  isExpanded: true,
                  items: [for (final t in EmployeeType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                  onChanged: (v) => setState(() => _employeeType = v ?? EmployeeType.permanent),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Work Status',
                child: DropdownButtonFormField<WorkStatus>(
                  initialValue: _workStatus,
                  isExpanded: true,
                  items: [for (final s in WorkStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
                  onChanged: (v) => setState(() => _workStatus = v ?? WorkStatus.active),
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
                label: 'Branch / Office Location',
                child: TextField(controller: _branchLocationController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Remarks',
                child: TextField(controller: _remarksController),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'EPF Number',
                child: TextField(controller: _epfNumberController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dateButton('EPF Joining Date', _epfJoiningDate, (d) => setState(() => _epfJoiningDate = d)),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'ESI Number',
                child: TextField(controller: _esiNumberController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dateButton('ESI Joining Date', _esiJoiningDate, (d) => setState(() => _esiJoiningDate = d)),
            ),
          ],
        ),

        _sectionHeader('Bank Account Details'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Bank Name',
                child: TextField(controller: _bankNameController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Account Number',
                child: TextField(controller: _accountNumberController),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'IFSC Code',
                child: TextField(controller: _ifscController, textCapitalization: TextCapitalization.characters),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Branch Name',
                child: TextField(controller: _bankBranchNameController),
              ),
            ),
          ],
        ),

        _sectionHeader('Document Upload'),
        _fileUploadRow(
          label: 'Passport Photo',
          pending: _pendingPhoto,
          existingFileName: widget.existing?.photoFileName,
          existingStoragePath: widget.existing?.photoStoragePath,
          onPicked: (f) => _pendingPhoto = f,
        ),
        _fileUploadRow(
          label: 'Aadhaar Card',
          pending: _pendingAadhaarFile,
          existingFileName: widget.existing?.aadhaarFileName,
          existingStoragePath: widget.existing?.aadhaarStoragePath,
          onPicked: (f) => _pendingAadhaarFile = f,
        ),
        _fileUploadRow(
          label: 'PAN Card',
          pending: _pendingPanFile,
          existingFileName: widget.existing?.panFileName,
          existingStoragePath: widget.existing?.panStoragePath,
          onPicked: (f) => _pendingPanFile = f,
        ),
        _fileUploadRow(
          label: 'Bank Passbook',
          pending: _pendingPassbookFile,
          existingFileName: widget.existing?.passbookFileName,
          existingStoragePath: widget.existing?.passbookStoragePath,
          onPicked: (f) => _pendingPassbookFile = f,
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
                  : const Text('Save Employee'),
            ),
          ],
        ),
      ],
    );
  }
}
