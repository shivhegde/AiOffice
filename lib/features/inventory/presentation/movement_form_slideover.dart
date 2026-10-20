import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatting.dart';
import '../../../shared/widgets/slideover_panel.dart';
import '../../users/application/user_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_item.dart';
import '../domain/inventory_movement.dart';
import '../domain/stock_summary.dart';

/// "Record movement" form — date, type, item, quantity, site/guard, note.
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
  final _siteController = TextEditingController();
  final _siteFocus = FocusNode();
  final _noteController = TextEditingController();

  DateTime _date = DateTime.now();
  late MovementType _type = widget.initialType;
  String? _itemId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // The availability hint depends on the site typed.
    _siteController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _siteController.dispose();
    _siteFocus.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _submit(List<InventoryItem> items) async {
    final item = items.where((i) => i.id == _itemId).firstOrNull;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    final site = _siteController.text.trim();
    if (item == null) return _toast('Select an item.');
    if (qty < 1) return _toast('Quantity must be at least 1.');
    if (_type.requiresSite && site.isEmpty) return _toast('Enter the site name.');

    // Stock can't go negative: the quantity must be on hand where it's
    // taken from.
    final stock = ref.read(inventoryStockProvider).value?[item.id];
    final available = stock?.availableFor(_type, site);
    if (available != null && qty > available) {
      final where = (_type == MovementType.issueToSite || site.isEmpty) ? 'in store' : 'at $site';
      return _toast('Only ${available < 0 ? 0 : available} ${item.displayName} available $where.');
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
    final sites = sitesOf(ref.watch(inventoryMovementsProvider).value ?? const []);
    final site = _siteController.text.trim();
    final available = _itemId == null
        ? null
        : ref.watch(inventoryStockProvider).value?[_itemId]?.availableFor(_type, site);
    final availableHint = available == null
        ? null
        : 'Available ${(_type == MovementType.issueToSite || site.isEmpty) ? 'in store' : 'at $site'}: '
              '${available < 0 ? 0 : available}';

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Add uniform items in the Items tab first.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: Align(alignment: Alignment.centerLeft, child: Text(formatDisplayDate(_date))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Type',
                child: DropdownButtonFormField<MovementType>(
                  initialValue: _type,
                  isExpanded: true,
                  items: [for (final t in MovementType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                  onChanged: (v) => setState(() => _type = v ?? MovementType.received),
                ),
              ),
            ),
          ],
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
        FormRowLabel(
          label: _type.requiresSite ? 'Site / Guard' : 'Site / Guard (if any)',
          child: RawAutocomplete<String>(
            textEditingController: _siteController,
            focusNode: _siteFocus,
            optionsBuilder: (value) {
              final needle = value.text.trim().toLowerCase();
              return sites.where((s) => s.toLowerCase().contains(needle));
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(hintText: 'Site name'),
            ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 380),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final o in options) ListTile(dense: true, title: Text(o), onTap: () => onSelected(o)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        FormRowLabel(
          label: 'Note',
          child: TextField(
            controller: _noteController,
            decoration: const InputDecoration(hintText: 'Reason / supplier'),
          ),
        ),
        Text(
          'Issue/Return need a site. For Damaged/Lost, leave site empty if it was in store.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submitting ? null : () => _submit(items),
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
