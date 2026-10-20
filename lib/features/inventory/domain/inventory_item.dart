import 'package:cloud_firestore/cloud_firestore.dart';

/// Inventory — uniform stock tracker (docs/inventory_redesign.html). One
/// Firestore document (`inventory_items/{id}`) per item+size. Current
/// stock is never stored: it's [openingStock] plus the item's
/// `inventory_movements` ledger (see `stock_summary.dart`).
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.item,
    required this.size,
    required this.openingStock,
    required this.reorderLevel,
    required this.targetStock,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String item;
  final String size;
  final int openingStock;

  /// "Reorder when ≤" — the item needs ordering once store stock falls to
  /// this level or below.
  final int reorderLevel;

  /// Stock level to order back up to.
  final int targetStock;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => size.isEmpty ? item : '$item ($size)';

  factory InventoryItem.fromMap(String id, Map<String, dynamic> data) {
    return InventoryItem(
      id: id,
      item: data['item'] as String? ?? '',
      size: data['size'] as String? ?? '',
      // Items saved before the redesign stored a flat 'qty'; treat it as
      // the opening stock.
      openingStock: (data['openingStock'] as num? ?? data['qty'] as num?)?.toInt() ?? 0,
      reorderLevel: (data['reorderLevel'] as num?)?.toInt() ?? 0,
      targetStock: (data['targetStock'] as num?)?.toInt() ?? 0,
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'item': item,
      'size': size,
      'openingStock': openingStock,
      'reorderLevel': reorderLevel,
      'targetStock': targetStock,
      'searchKeywords': item.toLowerCase().split(RegExp(r'\s+'))..removeWhere((s) => s.isEmpty),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
