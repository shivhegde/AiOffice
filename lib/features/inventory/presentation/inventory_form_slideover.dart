import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/slideover_panel.dart';
import '../../users/application/user_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_item.dart';

/// Create/edit form for an Inventory item — REQUIREMENTS.md §9.3's
/// minimal Item / Size / Qty fields.
class InventoryFormSlideover {
  InventoryFormSlideover._();

  static Future<void> show(BuildContext context, {InventoryItem? existing}) {
    return SlideoverPanel.show(
      context,
      title: existing != null ? 'Inventory — ${existing.item}' : 'New Inventory Item',
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
  final _qtyController = TextEditingController();

  bool _submitting = false;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _itemController.text = e?.item ?? '';
    _sizeController.text = e?.size ?? '';
    _qtyController.text = e != null ? '${e.qty}' : '';
  }

  @override
  void dispose() {
    _itemController.dispose();
    _sizeController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_itemController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item name is required.')));
      return;
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
        qty: int.tryParse(_qtyController.text.trim()) ?? 0,
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
          label: 'Item',
          child: TextField(controller: _itemController),
        ),
        FormRowLabel(
          label: 'Size',
          child: TextField(controller: _sizeController),
        ),
        FormRowLabel(
          label: 'Qty',
          child: TextField(controller: _qtyController, keyboardType: TextInputType.number),
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
