import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatting.dart';
import '../../../shared/widgets/slideover_panel.dart';
import '../../employees/application/employee_providers.dart';
import '../../employees/domain/employee.dart';
import '../../users/application/user_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_item.dart';
import '../domain/inventory_movement.dart';

/// "Record movement" form — date, type, item, quantity, employee (whose
/// Site is where the stock is held), note.
class MovementFormSlideover {
  MovementFormSlideover._();

  static Future<void> show(BuildContext context, {MovementType initialType = MovementType.received}) {
    return SlideoverPanel.show(
      context,
      title: 'Record Movement',
      body: _MovementForm(initialType: initialType),
      actions: const [],
      width: 440,
    );
  }
}

class _MovementForm extends ConsumerStatefulWidget {
  const _MovementForm({required this.initialType});

  final MovementType initialType;

  @override
  ConsumerState<_MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends ConsumerState<_MovementForm> {
  final _qtyController = TextEditingController(text: '1');
  final _employeeController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _date = DateTime.now();
  late MovementType _type = widget.initialType;
  String? _itemId;
  String? _employeeDocId;
  bool _submitting = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _employeeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static String _employeeLabel(Employee e) => e.employeeId.isEmpty ? e.fullName : '${e.fullName} (${e.employeeId})';

  /// The employee picked from the list, or null if none is picked (or the
  /// text has since been edited away from the picked name).
  Employee? _selectedEmployee(List<Employee> employees) {
    final e = employees.where((e) => e.id == _employeeDocId).firstOrNull;
    return e != null && _employeeController.text.trim() == _employeeLabel(e) ? e : null;
  }

  /// Every type but Received can involve an employee.
  bool get _takesEmployee => _type != MovementType.received;

  /// Where the stock for this movement comes from: the store for Issue
  /// (and Damaged/Lost with no employee), otherwise the employee's own.
  String _availableWhere(Employee? employee) =>
      _type == MovementType.issueToSite || employee == null ? 'in store' : 'with ${employee.fullName}';

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _submit(List<InventoryItem> items, List<Employee> employees) async {
    final item = items.where((i) => i.id == _itemId).firstOrNull;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    // Received only adds to store, so any employee left picked from
    // another type is ignored.
    final employee = _takesEmployee ? _selectedEmployee(employees) : null;
    final site = employee?.site.trim() ?? '';
    if (item == null) return _toast('Select an item.');
    if (qty < 1) return _toast('Quantity must be at least 1.');
    if (_takesEmployee && employee == null && _employeeController.text.trim().isNotEmpty) {
      return _toast('Pick the employee from the list.');
    }
    if (_type.requiresSite && employee == null) return _toast('Select the employee.');

    // Stock can't go negative: the quantity must be on hand where it's
    // taken from.
    final stock = ref.read(inventoryStockProvider).value?[item.id];
    final available = stock?.availableFor(_type, site, employeeDocId: employee?.id ?? '');
    if (available != null && qty > available) {
      return _toast(
        'Only ${available < 0 ? 0 : available} ${item.displayName} available ${_availableWhere(employee)}.',
      );
    }

    final appUser = ref.read(currentAppUserProvider).value;
    final actorUid = appUser?.uid ?? '';
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _submitting = true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .addMovement(
            draft: InventoryMovement(
              id: '',
              itemId: item.id,
              itemLabel: item.displayName,
              date: DateTime(_date.year, _date.month, _date.day),
              type: _type,
              qty: qty,
              site: site,
              employeeDocId: employee?.id ?? '',
              employeeId: employee?.employeeId ?? '',
              employeeName: employee?.fullName ?? '',
              employeeRole: employee?.role ?? '',
              note: _noteController.text.trim(),
              createdBy: actorUid,
              createdByName: actorName,
            ),
            actorUid: actorUid,
            actorName: actorName,
          );
      if (mounted) {
        Navigator.of(context).pop();
        _toast('Movement recorded.');
      }
    } catch (e) {
      if (mounted) _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(inventoryListProvider).value ?? const <InventoryItem>[];
    final employees = [...ref.watch(employeeListProvider).value ?? const <Employee>[]]
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    final employee = _takesEmployee ? _selectedEmployee(employees) : null;
    final site = employee?.site.trim() ?? '';
    final available = _itemId == null
        ? null
        : ref
              .watch(inventoryStockProvider)
              .value?[_itemId]
              ?.availableFor(_type, site, employeeDocId: employee?.id ?? '');
    final availableHint = available == null
        ? null
        : 'Available ${_availableWhere(employee)}: ${available < 0 ? 0 : available}';

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Add uniform items in the Items tab first.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormRowLabel(
          label: 'Date',
          child: OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Align(alignment: Alignment.centerLeft, child: Text(formatDisplayDate(_date))),
          ),
        ),
        FormRowLabel(
          label: 'Type',
          child: DropdownButtonFormField<MovementType>(
            initialValue: _type,
            isExpanded: true,
            items: [for (final t in MovementType.values) DropdownMenuItem(value: t, child: Text(t.label))],
            onChanged: (v) => setState(() => _type = v ?? MovementType.received),
          ),
        ),
        FormRowLabel(
          label: 'Item',
          child: DropdownButtonFormField<String>(
            initialValue: _itemId,
            isExpanded: true,
            hint: const Text('Select item'),
            items: [
              for (final i in items)
                DropdownMenuItem(
                  value: i.id,
                  child: Text(i.displayName, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _itemId = v),
          ),
        ),
        FormRowLabel(
          label: 'Quantity',
          child: TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(helperText: availableHint),
          ),
        ),
        if (_takesEmployee) ...[
          FormRowLabel(
            label: _type.requiresSite ? 'Employee Name' : 'Employee Name (if any)',
            child: DropdownMenu<String>(
              controller: _employeeController,
              expandedInsets: EdgeInsets.zero,
              enableFilter: true,
              requestFocusOnTap: true,
              hintText: 'Search employee',
              dropdownMenuEntries: [
                for (final e in employees) DropdownMenuEntry(value: e.id, label: _employeeLabel(e)),
              ],
              onSelected: (id) => setState(() => _employeeDocId = id),
            ),
          ),
          FormRowLabel(
            label: 'Employee ID',
            child: InputDecorator(
              decoration: const InputDecoration(enabled: false),
              child: Text(employee?.employeeId ?? '', overflow: TextOverflow.ellipsis),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FormRowLabel(
                  label: 'Site',
                  child: InputDecorator(
                    decoration: const InputDecoration(enabled: false),
                    child: Text(employee?.site ?? '', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FormRowLabel(
                  label: 'Role',
                  child: InputDecorator(
                    decoration: const InputDecoration(enabled: false),
                    child: Text(employee?.role ?? '', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            ],
          ),
        ],
        FormRowLabel(
          label: 'Note',
          child: TextField(
            controller: _noteController,
            decoration: const InputDecoration(hintText: 'Reason / supplier'),
          ),
        ),
        Text(
          'Issue/Return need an employee. For Damaged/Lost, leave the employee empty if it was in store.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submitting ? null : () => _submit(items, employees),
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
