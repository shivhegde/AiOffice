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
import '../domain/stock_summary.dart';

/// "Record movement" form — date, type, item, quantity, employee (whose
/// Site is where the stock is held), note. Pass [existing] to edit a
/// recorded movement instead.
class MovementFormSlideover {
  MovementFormSlideover._();

  static Future<void> show(
    BuildContext context, {
    MovementType initialType = MovementType.received,
    InventoryMovement? existing,
  }) {
    return SlideoverPanel.show(
      context,
      title: existing == null ? 'Record Movement' : 'Edit Movement',
      body: _MovementForm(initialType: existing?.type ?? initialType, existing: existing),
      actions: const [],
      width: 440,
    );
  }
}

class _MovementForm extends ConsumerStatefulWidget {
  const _MovementForm({required this.initialType, this.existing});

  final MovementType initialType;
  final InventoryMovement? existing;

  @override
  ConsumerState<_MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends ConsumerState<_MovementForm> {
  final _qtyController = TextEditingController(text: '1');
  final _employeeController = TextEditingController();
  final _noteController = TextEditingController();

  /// Damaged/Lost only: editable Site and Role, pre-filled from the picked
  /// employee. An empty Site means the stock was in the main store.
  final _siteController = TextEditingController();
  final _roleController = TextEditingController();

  DateTime _date = DateTime.now();
  late MovementType _type = widget.initialType;
  String? _itemId;
  String? _employeeDocId;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    if (m == null) return;
    _date = m.date;
    _itemId = m.itemId;
    _qtyController.text = '${m.qty}';
    _noteController.text = m.note;
    _siteController.text = m.site;
    _roleController.text = m.employeeRole;
    if (m.employeeDocId.isNotEmpty) {
      _employeeDocId = m.employeeDocId;
      _employeeController.text = _originalEmployeeLabel;
    }
  }

  String get _originalEmployeeLabel {
    final m = widget.existing!;
    return m.employeeId.isEmpty ? m.employeeName : '${m.employeeName} (${m.employeeId})';
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _employeeController.dispose();
    _noteController.dispose();
    _siteController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  static String _employeeLabel(Employee e) => e.employeeId.isEmpty ? e.fullName : '${e.fullName} (${e.employeeId})';

  /// The employee on this movement, or null if none is picked (or the text
  /// has since been edited away from the picked name). When editing and
  /// the original employee is left as is, their details as saved on the
  /// movement are kept — even if the employee has since moved site or been
  /// deleted — so a correction doesn't silently move stock elsewhere.
  _Who? _who(List<Employee> employees) {
    final m = widget.existing;
    if (m != null &&
        m.employeeDocId.isNotEmpty &&
        _employeeDocId == m.employeeDocId &&
        _employeeController.text.trim() == _originalEmployeeLabel) {
      return (
        docId: m.employeeDocId,
        employeeId: m.employeeId,
        name: m.employeeName,
        site: m.site,
        role: m.employeeRole,
      );
    }
    final e = employees.where((e) => e.id == _employeeDocId).firstOrNull;
    if (e == null || _employeeController.text.trim() != _employeeLabel(e)) return null;
    return (docId: e.id, employeeId: e.employeeId, name: e.fullName, site: e.site.trim(), role: e.role);
  }

  /// Stock to check this movement against: the current position, minus
  /// the movement being edited.
  ItemStock? _stockFor(String? itemId) {
    if (itemId == null) return null;
    if (!_isEditing) return ref.read(inventoryStockProvider).value?[itemId];
    final items = ref.read(inventoryListProvider).value ?? const <InventoryItem>[];
    final others = (ref.read(inventoryMovementsProvider).value ?? const <InventoryMovement>[])
        .where((m) => m.id != widget.existing!.id)
        .toList();
    return computeStock(items, others)[itemId];
  }

  /// Every type but Received can involve an employee.
  bool get _takesEmployee => _type != MovementType.received;

  /// Site this movement is held at: typed in for Damaged/Lost, otherwise
  /// the picked employee's Site.
  String _siteFor(_Who? employee) => _type.isWriteOff ? _siteController.text.trim() : (employee?.site ?? '');

  /// Where the limiting stock for this movement is: the store for Issue,
  /// the employee for Return; for Damaged/Lost whichever of store / site /
  /// employee has the least (they all come down together).
  String _availableWhere(ItemStock? stock, _Who? employee, String site) {
    if (_type == MovementType.issueToSite) return 'in store';
    if (!_type.isWriteOff) return employee == null ? 'in store' : 'with ${employee.name}';
    final candidates = <(int, String)>[
      (stock?.inStore ?? 0, 'in store'),
      if (site.isNotEmpty) (stock?.atSite[site] ?? 0, 'at $site'),
      if (employee != null) (stock?.withEmployee[employee.docId] ?? 0, 'with ${employee.name}'),
    ];
    return candidates.reduce((a, b) => b.$1 <= a.$1 ? b : a).$2;
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _submit(List<InventoryItem> items, List<Employee> employees) async {
    final item = items.where((i) => i.id == _itemId).firstOrNull;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    // Received only adds to store, so any employee left picked from
    // another type is ignored.
    final employee = _takesEmployee ? _who(employees) : null;
    final site = _siteFor(employee);
    if (item == null) return _toast('Select an item.');
    if (qty < 1) return _toast('Quantity must be at least 1.');
    if (_takesEmployee && employee == null && _employeeController.text.trim().isNotEmpty) {
      return _toast('Pick the employee from the list.');
    }
    if (_type.requiresSite && employee == null) return _toast('Select the employee.');

    // Stock can't go negative: the quantity must be on hand where it's
    // taken from.
    final stock = _stockFor(item.id);
    final available = stock?.availableFor(_type, site, employeeDocId: employee?.docId ?? '');
    if (available != null && qty > available) {
      return _toast(
        'Only ${available < 0 ? 0 : available} ${item.displayName} available ${_availableWhere(stock, employee, site)}.',
      );
    }

    final appUser = ref.read(currentAppUserProvider).value;
    final actorUid = appUser?.uid ?? '';
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    final existing = widget.existing;
    final draft = InventoryMovement(
      id: existing?.id ?? '',
      itemId: item.id,
      itemLabel: item.displayName,
      date: DateTime(_date.year, _date.month, _date.day),
      type: _type,
      qty: qty,
      site: site,
      employeeDocId: employee?.docId ?? '',
      employeeId: employee?.employeeId ?? '',
      employeeName: employee?.name ?? '',
      employeeRole: _type.isWriteOff ? _roleController.text.trim() : (employee?.role ?? ''),
      note: _noteController.text.trim(),
      // A write-off recorded before the store rule keeps its original
      // effect when corrected; every other write-off uses the store rule.
      writeOffFromStore:
          _type.isWriteOff && (existing == null || !existing.type.isWriteOff || existing.writeOffFromStore),
      createdBy: existing?.createdBy ?? actorUid,
      createdByName: existing?.createdByName ?? actorName,
      createdAt: existing?.createdAt,
    );

    if (existing != null) {
      // Later movements may rely on the stock this one provided (e.g. a
      // receipt that issues were made from) — refuse an edit that would
      // leave any affected item negative.
      final items = ref.read(inventoryListProvider).value ?? const <InventoryItem>[];
      final all = ref.read(inventoryMovementsProvider).value ?? const <InventoryMovement>[];
      final before = computeStock(items, all);
      final after = computeStock(items, [
        for (final m in all)
          if (m.id != existing.id) m,
        draft,
      ]);
      for (final id in {existing.itemId, item.id}) {
        if ((after[id]?.hasNegative ?? false) && !(before[id]?.hasNegative ?? false)) {
          return _toast(
            'Cannot save: other movements depend on this stock and it would go negative. Correct those first.',
          );
        }
      }
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      if (existing == null) {
        await repo.addMovement(draft: draft, actorUid: actorUid, actorName: actorName);
      } else {
        await repo.updateMovement(movement: draft, actorUid: actorUid, actorName: actorName);
      }
      if (mounted) {
        Navigator.of(context).pop();
        _toast(existing == null ? 'Movement recorded.' : 'Movement updated.');
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
    final employee = _takesEmployee ? _who(employees) : null;
    final site = _siteFor(employee);
    // Watched so the hint stays live; [_stockFor] reads the same data.
    ref.watch(inventoryStockProvider);
    final stock = _stockFor(_itemId);
    final available = stock?.availableFor(_type, site, employeeDocId: employee?.docId ?? '');
    final availableHint = available == null
        ? null
        : 'Available ${_availableWhere(stock, employee, site)}: ${available < 0 ? 0 : available}';

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
              onSelected: (id) => setState(() {
                _employeeDocId = id;
                final picked = employees.where((e) => e.id == id).firstOrNull;
                if (picked != null) {
                  _siteController.text = picked.site.trim();
                  _roleController.text = picked.role.trim();
                }
              }),
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
                  child: _type.isWriteOff
                      ? TextField(
                          controller: _siteController,
                          decoration: const InputDecoration(hintText: 'Blank = main store'),
                          onChanged: (_) => setState(() {}),
                        )
                      : InputDecorator(
                          decoration: const InputDecoration(enabled: false),
                          child: Text(employee?.site ?? '', overflow: TextOverflow.ellipsis),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FormRowLabel(
                  label: 'Role',
                  child: _type.isWriteOff
                      ? TextField(controller: _roleController)
                      : InputDecorator(
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
          'Issue/Return need an employee. Damaged/Lost always reduce the main store; '
          'when a Site is entered they also reduce that site\'s stock.',
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

/// The employee on a movement, as saved on it.
typedef _Who = ({String docId, String employeeId, String name, String site, String role});
