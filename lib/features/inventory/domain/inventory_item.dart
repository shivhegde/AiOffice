import 'package:cloud_firestore/cloud_firestore.dart';

/// REQUIREMENTS.md §9.3 — Inventory. As specified, this is minimal: a flat
/// list of Item, Size, Qty (e.g., Uniform — S/M/L, Cap — S/M/L). No
/// issue/return tracking, no assignment to employee, no reorder threshold,
/// no stock-in/stock-out transaction log — the source sheet is a 3-row
/// stub with none of the Dashboard/Search/Alerts sections every other
/// module has (flagged in REQUIREMENTS.md §9.3 as likely still unplanned,
/// confirm before adding more). One Firestore document
/// (`inventory_items/{id}`) per item+size row.
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.item,
    required this.size,
    required this.qty,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String item;
  final String size;
  final int qty;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory InventoryItem.fromMap(String id, Map<String, dynamic> data) {
    return InventoryItem(
      id: id,
      item: data['item'] as String? ?? '',
      size: data['size'] as String? ?? '',
      qty: (data['qty'] as num?)?.toInt() ?? 0,
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
      'qty': qty,
      'searchKeywords': item.toLowerCase().split(RegExp(r'\s+'))..removeWhere((s) => s.isEmpty),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
