import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/document_actions.dart';
import '../../../shared/widgets/slideover_panel.dart';
import '../../users/application/user_providers.dart';
import '../application/vehicle_policy_providers.dart';
import '../domain/vehicle_insurance_enums.dart';
import '../domain/vehicle_policy.dart';

/// Create/edit form for a Vehicle Policy — matches REQUIREMENTS.md §9.4's
/// Customer Management / Vehicle Management / Insurance Policy sections.
class VehiclePolicyFormSlideover {
  VehiclePolicyFormSlideover._();

  static Future<void> show(BuildContext context, {VehiclePolicy? existing}) {
    return SlideoverPanel.show(
      context,
      title: existing != null ? 'Policy — ${existing.policyNumber}' : 'New Vehicle Policy',
      body: _VehiclePolicyForm(existing: existing),
      actions: const [],
      width: 480,
    );
  }
}

class _VehiclePolicyForm extends ConsumerStatefulWidget {
  const _VehiclePolicyForm({this.existing});

  final VehiclePolicy? existing;

  @override
  ConsumerState<_VehiclePolicyForm> createState() => _VehiclePolicyFormState();
}

class _VehiclePolicyFormState extends ConsumerState<_VehiclePolicyForm> {
  final _customerNameController = TextEditingController();
  final _customerMobileController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerIdController = TextEditingController();
  final _customerNotesController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _rcDetailsController = TextEditingController();
  final _makeModelController = TextEditingController();
  final _manufacturingYearController = TextEditingController();
  final _engineNumberController = TextEditingController();
  final _chassisNumberController = TextEditingController();
  final _financerDetailsController = TextEditingController();
  final _insuranceCompanyController = TextEditingController();
  final _policyNumberController = TextEditingController();
  final _idvController = TextEditingController();
  final _ncbController = TextEditingController();
  final _premiumController = TextEditingController();
  final _commissionController = TextEditingController();

  VehicleType _vehicleType = VehicleType.car;
  PolicyType _policyType = PolicyType.comprehensive;
  PolicyStatus _status = PolicyStatus.active;
  late DateTime _startDate;
  late DateTime _expiryDate;

  ({Uint8List bytes, String name, String contentType})? _pendingPolicyFile;
  bool _submitting = false;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _customerNameController.text = e?.customerName ?? '';
    _customerMobileController.text = e?.customerMobile ?? '';
    _customerEmailController.text = e?.customerEmail ?? '';
    _customerAddressController.text = e?.customerAddress ?? '';
    _customerIdController.text = e?.customerIdNumber ?? '';
    _customerNotesController.text = e?.customerNotes ?? '';
    _vehicleNumberController.text = e?.vehicleNumber ?? '';
    _rcDetailsController.text = e?.rcDetails ?? '';
    _makeModelController.text = e?.makeModel ?? '';
    _manufacturingYearController.text = e?.manufacturingYear != null ? '${e!.manufacturingYear}' : '';
    _engineNumberController.text = e?.engineNumber ?? '';
    _chassisNumberController.text = e?.chassisNumber ?? '';
    _financerDetailsController.text = e?.financerDetails ?? '';
    _insuranceCompanyController.text = e?.insuranceCompany ?? '';
    _policyNumberController.text = e?.policyNumber ?? '';
    _idvController.text = e != null && e.idv > 0 ? e.idv.toStringAsFixed(0) : '';
    _ncbController.text = e != null && e.ncb > 0 ? e.ncb.toStringAsFixed(0) : '';
    _premiumController.text = e != null && e.premium > 0 ? e.premium.toStringAsFixed(0) : '';
    _commissionController.text = e != null && e.commission > 0 ? e.commission.toStringAsFixed(0) : '';

    _vehicleType = e?.vehicleType ?? VehicleType.car;
    _policyType = e?.policyType ?? PolicyType.comprehensive;
    _status = e?.status ?? PolicyStatus.active;
    _startDate = e?.startDate ?? DateTime.now();
    _expiryDate = e?.expiryDate ?? DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerMobileController.dispose();
    _customerEmailController.dispose();
    _customerAddressController.dispose();
    _customerIdController.dispose();
    _customerNotesController.dispose();
    _vehicleNumberController.dispose();
    _rcDetailsController.dispose();
    _makeModelController.dispose();
    _manufacturingYearController.dispose();
    _engineNumberController.dispose();
    _chassisNumberController.dispose();
    _financerDetailsController.dispose();
    _insuranceCompanyController.dispose();
    _policyNumberController.dispose();
    _idvController.dispose();
    _ncbController.dispose();
    _premiumController.dispose();
    _commissionController.dispose();
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

  Future<void> _pickPolicyFile() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    if (!mounted) return;
    setState(() {
      _pendingPolicyFile = (
        bytes: bytes,
        name: file.name,
        contentType: extension == 'pdf' ? 'application/pdf' : 'image/$extension',
      );
    });
  }

  Future<void> _submit() async {
    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer name is required.')));
      return;
    }
    if (_vehicleNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehicle number is required.')));
      return;
    }
    if (_policyNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Policy number is required.')));
      return;
    }

    final appUser = ref.read(currentAppUserProvider).value;
    final actorUid = appUser?.uid ?? '';
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _submitting = true);
    try {
      final draft = VehiclePolicy(
        id: widget.existing?.id ?? '',
        customerName: _customerNameController.text.trim(),
        customerMobile: _customerMobileController.text.trim(),
        customerEmail: _customerEmailController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        customerIdNumber: _customerIdController.text.trim(),
        customerNotes: _customerNotesController.text.trim(),
        vehicleNumber: _vehicleNumberController.text.trim(),
        rcDetails: _rcDetailsController.text.trim(),
        vehicleType: _vehicleType,
        makeModel: _makeModelController.text.trim(),
        manufacturingYear: int.tryParse(_manufacturingYearController.text.trim()),
        engineNumber: _engineNumberController.text.trim(),
        chassisNumber: _chassisNumberController.text.trim(),
        financerDetails: _financerDetailsController.text.trim(),
        insuranceCompany: _insuranceCompanyController.text.trim(),
        policyNumber: _policyNumberController.text.trim(),
        policyType: _policyType,
        idv: double.tryParse(_idvController.text.trim()) ?? 0,
        ncb: double.tryParse(_ncbController.text.trim()) ?? 0,
        premium: double.tryParse(_premiumController.text.trim()) ?? 0,
        commission: double.tryParse(_commissionController.text.trim()) ?? 0,
        startDate: _startDate,
        expiryDate: _expiryDate,
        policyStoragePath: widget.existing?.policyStoragePath,
        policyFileName: widget.existing?.policyFileName,
        status: _status,
        renewedAt: _status == PolicyStatus.renewed ? (widget.existing?.renewedAt ?? DateTime.now()) : null,
        createdBy: widget.existing?.createdBy ?? actorUid,
        createdByName: widget.existing?.createdByName ?? actorName,
        createdAt: widget.existing?.createdAt,
      );

      final repo = ref.read(vehiclePolicyRepositoryProvider);
      if (_isEditing) {
        await repo.update(policy: draft, actorUid: actorUid, actorName: actorName, policyFile: _pendingPolicyFile);
      } else {
        await repo.create(draft: draft, actorUid: actorUid, actorName: actorName, policyFile: _pendingPolicyFile);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Policy saved.')));
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormRowLabel(
          label: 'Customer Name',
          child: TextField(controller: _customerNameController),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Mobile Number',
                child: TextField(controller: _customerMobileController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Email',
                child: TextField(controller: _customerEmailController),
              ),
            ),
          ],
        ),
        FormRowLabel(
          label: 'Address',
          child: TextField(controller: _customerAddressController, maxLines: 2),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Aadhaar / PAN (optional)',
                child: TextField(controller: _customerIdController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Notes',
                child: TextField(controller: _customerNotesController),
              ),
            ),
          ],
        ),

        _sectionHeader('Vehicle Management'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Vehicle Number',
                child: TextField(controller: _vehicleNumberController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Vehicle Type',
                child: DropdownButtonFormField<VehicleType>(
                  initialValue: _vehicleType,
                  isExpanded: true,
                  items: [for (final t in VehicleType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                  onChanged: (v) => setState(() => _vehicleType = v ?? VehicleType.car),
                ),
              ),
            ),
          ],
        ),
        FormRowLabel(
          label: 'RC Details',
          child: TextField(controller: _rcDetailsController),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Make & Model',
                child: TextField(controller: _makeModelController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Manufacturing Year',
                child: TextField(controller: _manufacturingYearController, keyboardType: TextInputType.number),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Engine Number',
                child: TextField(controller: _engineNumberController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Chassis Number',
                child: TextField(controller: _chassisNumberController),
              ),
            ),
          ],
        ),
        FormRowLabel(
          label: 'Financer Details',
          child: TextField(controller: _financerDetailsController),
        ),

        _sectionHeader('Insurance Policy'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Insurance Company',
                child: TextField(controller: _insuranceCompanyController),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Policy Number',
                child: TextField(controller: _policyNumberController),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Policy Type',
                child: DropdownButtonFormField<PolicyType>(
                  initialValue: _policyType,
                  isExpanded: true,
                  items: [for (final t in PolicyType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                  onChanged: (v) => setState(() => _policyType = v ?? PolicyType.comprehensive),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Status',
                child: DropdownButtonFormField<PolicyStatus>(
                  initialValue: _status,
                  isExpanded: true,
                  items: [for (final s in PolicyStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
                  onChanged: (v) => setState(() => _status = v ?? PolicyStatus.active),
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
                label: 'IDV (Rs.)',
                child: TextField(controller: _idvController, keyboardType: TextInputType.number),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'NCB (%)',
                child: TextField(controller: _ncbController, keyboardType: TextInputType.number),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Premium (Rs.)',
                child: TextField(controller: _premiumController, keyboardType: TextInputType.number),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Commission (Rs.)',
                child: TextField(controller: _commissionController, keyboardType: TextInputType.number),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _dateButton('Start Date', _startDate, (d) => setState(() => _startDate = d))),
            const SizedBox(width: 10),
            Expanded(child: _dateButton('Expiry Date', _expiryDate, (d) => setState(() => _expiryDate = d))),
          ],
        ),
        FormRowLabel(
          label: 'Policy PDF',
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickPolicyFile,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _pendingPolicyFile != null
                          ? 'Attached: ${_pendingPolicyFile!.name}'
                          : (widget.existing?.hasPolicyFile == true
                                ? 'On file: ${widget.existing!.policyFileName}. Tap to replace.'
                                : 'Tap to upload policy PDF or scan'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              if (_pendingPolicyFile == null && widget.existing?.hasPolicyFile == true) ...[
                const SizedBox(width: 8),
                DocumentActionIcons(
                  storagePath: widget.existing!.policyStoragePath!,
                  fileName: widget.existing!.policyFileName!,
                  label: 'policy document',
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
                  : const Text('Save Policy'),
            ),
          ],
        ),
      ],
    );
  }
}
