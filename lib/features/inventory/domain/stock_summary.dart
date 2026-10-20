import 'dart:math' as math;

import 'inventory_item.dart';
import 'inventory_movement.dart';

/// Derived stock position of one item, replayed from its opening stock and
/// movement ledger.
class ItemStock {
  ItemStock(this.item) : inStore = item.openingStock;

  final InventoryItem item;
  int inStore;
  final Map<String, int> atSite = {};
  int damaged = 0;
  int lost = 0;

  int get atSitesTotal => atSite.values.fold(0, (sum, q) => sum + q);

  bool get needsReorder => inStore <= item.reorderLevel;

  int get orderQty => math.max(0, item.targetStock - inStore);

  /// True when store or any site has gone below zero.
  bool get hasNegative => inStore < 0 || atSite.values.any((q) => q < 0);

  /// Most a movement of [type] can take out of the stock it draws from —
  /// store for Issue (and Damaged/Lost with no site), the named site for
  /// Return (and Damaged/Lost at a site). Null for Received, which only
  /// adds stock.
  int? availableFor(MovementType type, String site) {
    return switch (type) {
      MovementType.received => null,
      MovementType.issueToSite => inStore,
      MovementType.returnFromSite => atSite[site] ?? 0,
      MovementType.damaged || MovementType.lost => site.isEmpty ? inStore : (atSite[site] ?? 0),
    };
  }
}

/// Stock per item id, following the movement rules of the redesign:
/// Received adds to store; Issue moves store → site; Return moves site →
/// store; Damaged/Lost come off the named site, or off store when no site
/// is given.
Map<String, ItemStock> computeStock(List<InventoryItem> items, List<InventoryMovement> movements) {
  final stock = {for (final i in items) i.id: ItemStock(i)};
  for (final m in movements) {
    final s = stock[m.itemId];
    if (s == null) continue;
    switch (m.type) {
      case MovementType.received:
        s.inStore += m.qty;
      case MovementType.issueToSite:
        s.inStore -= m.qty;
        s.atSite[m.site] = (s.atSite[m.site] ?? 0) + m.qty;
      case MovementType.returnFromSite:
        s.inStore += m.qty;
        s.atSite[m.site] = (s.atSite[m.site] ?? 0) - m.qty;
      case MovementType.damaged:
      case MovementType.lost:
        if (m.type == MovementType.damaged) {
          s.damaged += m.qty;
        } else {
          s.lost += m.qty;
        }
        if (m.site.isNotEmpty) {
          s.atSite[m.site] = (s.atSite[m.site] ?? 0) - m.qty;
        } else {
          s.inStore -= m.qty;
        }
    }
  }
  return stock;
}

/// Every site named in the ledger, sorted.
List<String> sitesOf(List<InventoryMovement> movements) {
  return {
    for (final m in movements)
      if (m.site.isNotEmpty) m.site,
  }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}
