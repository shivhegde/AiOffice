import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/doc_types.dart';
import '../../../shared/widgets/document_actions.dart';
import '../../../shared/widgets/slideover_panel.dart';
import '../../users/application/user_providers.dart';
import '../application/io_providers.dart';
import '../domain/io_document.dart';
import '../domain/io_enums.dart';

typedef PrefilledFile = ({Uint8List bytes, String name, String contentType});

/// Create/edit form for one Inward or Outward entry, matching the field
/// sets in REQUIREMENTS.md §6.2/§6.3. [existing] switches the form into
/// edit mode; [prefilledFile] is used by the camera-scan/gallery "Friendly
/// Features" flow (§6.6) to arrive with an image already attached.
class IoFormSlideover {
  IoFormSlideover._();

  static Future<void> show(
    BuildContext context, {
    required IoType type,
    IoDocument? existing,
    PrefilledFile? prefilledFile,
  }) {
    return SlideoverPanel.show(
      context,
      title: existing != null
          ? '${type.label} Entry — ${existing.docNumber}'
          : 'New ${type.label} Entry',
      body: _IoForm(type: type, existing: existing, prefilledFile: prefilledFile),
      // _IoForm renders its own Cancel/Save row inline at the bottom of the
      // scrollable body (it needs its own submit state), so the panel's
      // fixed footer stays empty here.
      actions: const [],
    );
  }
}

class _IoForm extends ConsumerStatefulWidget {
  const _IoForm({required this.type, this.existing, this.prefilledFile});

  final IoType type;
  final IoDocument? existing;
  final PrefilledFile? prefilledFile;

  @override
  ConsumerState<_IoForm> createState() => _IoFormState();
}

class _IoFormState extends ConsumerState<_IoForm> {
  late DateTime _date;
  final _receivedFromController = TextEditingController();
  final _senderCompanyController = TextEditingController();
  final _subjectController = TextEditingController();
  final _departmentController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _remarksController = TextEditingController();
  final _sentToController = TextEditingController();
  final _addressController = TextEditingController();
  final _trackingController = TextEditingController();
  final _sentByController = TextEditingController();

  late String _docType;
  IoPriority _priority = IoPriority.normal;
  DispatchMode _dispatchMode = DispatchMode.courier;

  PrefilledFile? _pendingFile;
  bool _submitting = false;
  bool _dragHover = false;

  static const _allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg'];

  bool get _isInward => widget.type == IoType.inward;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = existing?.date ?? DateTime.now();
    _docType = existing?.docType ?? (_isInward ? kInwardDocTypes.first : kOutwardDocTypes.first);
    _priority = existing?.priority ?? IoPriority.normal;
    _dispatchMode = existing?.dispatchMode ?? DispatchMode.courier;
    _pendingFile = widget.prefilledFile;

    _receivedFromController.text = existing?.receivedFrom ?? '';
    _senderCompanyController.text = existing?.senderCompany ?? '';
    _subjectController.text = existing?.subject ?? '';
    _departmentController.text = existing?.department ?? '';
    _receiverNameController.text = existing?.receiverName ?? '';
    _remarksController.text = existing?.remarks ?? '';
    _sentToController.text = existing?.sentTo ?? '';
    _addressController.text = existing?.addressOrEmail ?? '';
    _trackingController.text = existing?.trackingNumber ?? '';
    _sentByController.text = existing?.sentBy ?? '';
  }

  @override
  void dispose() {
    _receivedFromController.dispose();
    _senderCompanyController.dispose();
    _subjectController.dispose();
    _departmentController.dispose();
    _receiverNameController.dispose();
    _remarksController.dispose();
    _sentToController.dispose();
    _addressController.dispose();
    _trackingController.dispose();
    _sentByController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );
    if (file == null) return;
    _attachFile(name: file.name, bytesLoader: file.readAsBytes);
  }

  /// Handles a file dropped via [DropTarget.onDragDone]. macOS sandboxed
  /// apps need a security-scoped-resource grant for files dropped from
  /// outside the app container (e.g. Finder) before their bytes can be
  /// read — [DropItem.extraAppleBookmark] carries that grant when needed.
  Future<void> _handleDrop(DropDoneDetails details) async {
    final item = details.files.firstOrNull;
    if (item == null) return;

    final bookmark = item.extraAppleBookmark;
    final scopedAccessStarted = bookmark != null && bookmark.isNotEmpty
        ? await DesktopDrop.instance.startAccessingSecurityScopedResource(bookmark: bookmark)
        : false;
    try {
      await _attachFile(name: item.name, bytesLoader: item.readAsBytes);
    } finally {
      if (scopedAccessStarted) {
        await DesktopDrop.instance.stopAccessingSecurityScopedResource(bookmark: bookmark);
      }
    }
  }

  Future<void> _attachFile({required String name, required Future<Uint8List> Function() bytesLoader}) async {
    final extension = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!_allowedExtensions.contains(extension)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Only PDF or image files are supported (got "$extension").')));
      }
      return;
    }

    final bytes = await bytesLoader();
    if (!mounted) return;
    setState(() {
      _pendingFile = (
        bytes: bytes,
        name: name,
        contentType: extension == 'pdf' ? 'application/pdf' : 'image/$extension',
      );
    });
  }

  Future<void> _submit() async {
    if (_subjectController.text.trim().isEmpty || _departmentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject and Department are required.')),
      );
      return;
    }

    final appUser = ref.read(currentAppUserProvider).value;
    final actorUid = appUser?.uid ?? '';
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _submitting = true);
    try {
      final draft = IoDocument(
        id: widget.existing?.id ?? '',
        type: widget.type,
        docNumber: widget.existing?.docNumber ?? '',
        year: _date.year,
        date: _date,
        docType: _docType,
        department: _departmentController.text.trim(),
        subject: _subjectController.text.trim(),
        remarks: _remarksController.text.trim(),
        receivedFrom: _isInward ? _receivedFromController.text.trim() : null,
        senderCompany: _isInward ? _senderCompanyController.text.trim() : null,
        priority: _isInward ? _priority : null,
        receiverName: _isInward ? _receiverNameController.text.trim() : null,
        sentTo: !_isInward ? _sentToController.text.trim() : null,
        addressOrEmail: !_isInward ? _addressController.text.trim() : null,
        dispatchMode: !_isInward ? _dispatchMode : null,
        trackingNumber: !_isInward ? _trackingController.text.trim() : null,
        sentBy: !_isInward ? _sentByController.text.trim() : null,
        createdBy: widget.existing?.createdBy ?? actorUid,
        createdByName: widget.existing?.createdByName ?? actorName,
        createdAt: widget.existing?.createdAt,
        storagePath: widget.existing?.storagePath,
        fileName: widget.existing?.fileName,
        fileContentType: widget.existing?.fileContentType,
        fileSizeBytes: widget.existing?.fileSizeBytes,
        seen: widget.existing?.seen ?? false,
      );

      final repo = ref.read(ioRepositoryProvider);
      if (_isEditing) {
        await repo.update(document: draft, actorUid: actorUid, actorName: actorName);
      } else {
        await repo.create(
          draft: draft,
          actorUid: actorUid,
          actorName: actorName,
          fileBytes: _pendingFile?.bytes,
          fileName: _pendingFile?.name,
          fileContentType: _pendingFile?.contentType,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.type.label} entry saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docTypes = _isInward ? kInwardDocTypes : kOutwardDocTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isEditing)
          FormRowLabel(
            label: '${widget.type.label} Number',
            child: TextField(
              controller: TextEditingController(text: widget.existing!.docNumber),
              enabled: false,
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Date',
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2015),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
                    }
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Time',
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_date),
                    );
                    if (picked != null) {
                      setState(() => _date = DateTime(_date.year, _date.month, _date.day, picked.hour, picked.minute));
                    }
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(TimeOfDay.fromDateTime(_date).format(context)),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isInward) ...[
          FormRowLabel(label: 'Received From', child: TextField(controller: _receivedFromController)),
          FormRowLabel(label: 'Sender Company / Person', child: TextField(controller: _senderCompanyController)),
        ] else ...[
          FormRowLabel(label: 'Sent To', child: TextField(controller: _sentToController)),
          FormRowLabel(label: 'Address / Email', child: TextField(controller: _addressController)),
        ],
        FormRowLabel(label: 'Subject', child: TextField(controller: _subjectController)),
        FormRowLabel(label: 'Department', child: TextField(controller: _departmentController)),
        FormRowLabel(
          label: 'Document Type',
          child: DropdownButtonFormField<String>(
            initialValue: docTypes.contains(_docType) ? _docType : docTypes.first,
            isExpanded: true,
            items: [for (final t in docTypes) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => setState(() => _docType = v ?? docTypes.first),
          ),
        ),
        if (_isInward) ...[
          FormRowLabel(
            label: 'Priority',
            child: DropdownButtonFormField<IoPriority>(
              initialValue: _priority,
              isExpanded: true,
              items: [for (final p in IoPriority.values) DropdownMenuItem(value: p, child: Text(p.label))],
              onChanged: (v) => setState(() => _priority = v ?? IoPriority.normal),
            ),
          ),
          FormRowLabel(label: 'Receiver Name', child: TextField(controller: _receiverNameController)),
        ] else ...[
          FormRowLabel(
            label: 'Dispatch Mode',
            child: DropdownButtonFormField<DispatchMode>(
              initialValue: _dispatchMode,
              isExpanded: true,
              items: [for (final m in DispatchMode.values) DropdownMenuItem(value: m, child: Text(m.label))],
              onChanged: (v) => setState(() => _dispatchMode = v ?? DispatchMode.courier),
            ),
          ),
          FormRowLabel(label: 'Tracking Number', child: TextField(controller: _trackingController)),
          FormRowLabel(label: 'Sent By', child: TextField(controller: _sentByController)),
        ],
        FormRowLabel(
          label: 'File Upload',
          child: Row(
            children: [
              Expanded(
                child: DropTarget(
                  onDragEntered: (_) => setState(() => _dragHover = true),
                  onDragExited: (_) => setState(() => _dragHover = false),
                  onDragDone: (details) {
                    setState(() => _dragHover = false);
                    _handleDrop(details);
                  },
                  child: InkWell(
                    onTap: _pickFile,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _dragHover ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : null,
                        border: Border.all(
                          color: _dragHover
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: _dragHover ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _pendingFile != null
                            ? 'Attached: ${_pendingFile!.name}'
                            : (widget.existing?.hasFile == true
                                  ? 'On file: ${widget.existing!.fileName}. Tap to replace.'
                                  : 'Drop a PDF or image here, or tap to browse'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              if (_pendingFile == null && widget.existing?.hasFile == true) ...[
                const SizedBox(width: 8),
                DocumentActionIcons(
                  storagePath: widget.existing!.storagePath!,
                  fileName: widget.existing!.fileName!,
                  label: 'attached file',
                ),
              ],
            ],
          ),
        ),
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
                  : const Text('Save Entry'),
            ),
          ],
        ),
      ],
    );
  }
}
