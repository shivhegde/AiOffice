import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/slideover_panel.dart';
import '../../users/application/user_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_item.dart';

/// Create/edit form for a uniform item — name, size, opening stock,
/// reorder level and target stock (docs/inventory_redesign.html "Add
/// uniform item").
class InventoryFormSlideover {
  InventoryFormSlideover._();

  static Future<void> show(BuildContext context, {InventoryItem? existing}) {
    return SlideoverPanel.show(
      context,
      title: existing != null ? 'Inventory — ${existing.displayName}' : 'New Uniform Item',
      body: _InventoryForm(existing: existing),
      actions: const [],
      width: 420,
    );
  }
}

class _InventoryForm extends ConsumerStatefulWidget {
  const _InventoryForm({this.existing});

  final InventoryItem? existing;

  @override
  ConsumerState<_InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends ConsumerState<_InventoryForm> {
  final _itemController = TextEditingController();
  final _sizeController = TextEditingController();
  final _openingController = TextEditingController();
  final _reorderController = TextEditingController();
  final _targetController = TextEditingController();

  bool _submitting = false;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _itemController.text = e?.item ?? '';
    _sizeController.text = e?.size ?? '';
    _openingController.text = '${e?.openingStock ?? 0}';
    _reorderController.text = '${e?.reorderLevel ?? 5}';
    _targetController.text = '${e?.targetStock ?? 20}';
  }

  @override
  void dispose() {
    _itemController.dispose();
    _sizeController.dispose();
    _openingController.dispose();
    _reorderController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  int _intOf(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Future<void> _submit() async {
    if (_itemController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item name is required.')));
      return;
    }
    if ([_openingController, _reorderController, _targetController].any((c) => _intOf(c) < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock values cannot be negative.')));
      return;
    }

    // Lowering opening stock below what has already been issued out of the
    // store would leave store stock negative.
    final existing = widget.existing;
    if (existing != null) {
      final inStore = ref.read(inventoryStockProvider).value?[existing.id]?.inStore;
      if (inStore != null && inStore - existing.openingStock + _intOf(_openingController) < 0) {
        final minimum = existing.openingStock - inStore;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening stock must be at least $minimum — store stock would go negative.')),
        );
        return;
      }
    }

    final appUser = ref.read(currentAppUserProvider).value;
    final actorUid = appUser?.uid ?? '';
    final actorName = appUser?.displayName.isNotEmpty == true ? appUser!.displayName : (appUser?.email ?? 'Unknown');

    setState(() => _submitting = true);
    try {
      final draft = InventoryItem(
        id: widget.existing?.id ?? '',
        item: _itemController.text.trim(),
        size: _sizeController.text.trim(),
        openingStock: _intOf(_openingController),
        reorderLevel: _intOf(_reorderController),
        targetStock: _intOf(_targetController),
        createdBy: widget.existing?.createdBy ?? actorUid,
        createdByName: widget.existing?.createdByName ?? actorName,
        createdAt: widget.existing?.createdAt,
      );

      final repo = ref.read(inventoryRepositoryProvider);
      if (_isEditing) {
        await repo.update(item: draft, actorUid: actorUid, actorName: actorName);
      } else {
        await repo.create(draft: draft, actorUid: actorUid, actorName: actorName);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventory item saved.')));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormRowLabel(
          label: 'Item Name',
          child: TextField(
            controller: _itemController,
            decoration: const InputDecoration(hintText: 'Shirt, Trouser, Cap, Shoes…'),
          ),
        ),
        FormRowLabel(
          label: 'Size',
          child: TextField(
            controller: _sizeController,
            decoration: const InputDecoration(hintText: 'M / 40 / 9'),
          ),
        ),
        FormRowLabel(
          label: 'Opening Stock',
          child: TextField(controller: _openingController, keyboardType: TextInputType.number),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormRowLabel(
                label: 'Reorder when ≤',
                child: TextField(controller: _reorderController, keyboardType: TextInputType.number),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormRowLabel(
                label: 'Target Stock',
                child: TextField(controller: _targetController, keyboardType: TextInputType.number),
              ),
            ),
          ],
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
                  : const Text('Save Item'),
            ),
          ],
        ),
      ],
    );
  }
}
