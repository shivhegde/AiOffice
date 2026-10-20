import 'package:cloud_firestore/cloud_firestore.dart';

enum MovementType {
  received('received', 'Received'),
  issueToSite('issue_to_site', 'Issue to site'),
  returnFromSite('return_from_site', 'Return from site'),
  damaged('damaged', 'Damaged'),
  lost('lost', 'Lost');

  const MovementType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  /// Issue/Return always involve a site; Damaged/Lost take one only when
  /// the stock was at a site rather than in store.
  bool get requiresSite => this == issueToSite || this == returnFromSite;

  bool get isWriteOff => this == damaged || this == lost;

  static MovementType fromWireValue(String? value) {
    return MovementType.values.firstWhere((t) => t.wireValue == value, orElse: () => MovementType.received);
  }
}

/// One stock movement in the `inventory_movements` ledger. Linked to its
/// item by [itemId]; [itemLabel] is carried alongside so history still
/// reads sensibly if the item is renamed.
class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.itemId,
    required this.itemLabel,
    required this.date,
    required this.type,
    required this.qty,
    this.site = '',
    this.note = '',
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
  });

  final String id;
  final String itemId;
  final String itemLabel;
  final DateTime date;
  final MovementType type;
  final int qty;

  /// Site / guard name; empty for store-side movements.
  final String site;
  final String note;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;

  factory InventoryMovement.fromMap(String id, Map<String, dynamic> data) {
    return InventoryMovement(
      id: id,
      itemId: data['itemId'] as String? ?? '',
      itemLabel: data['itemLabel'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: MovementType.fromWireValue(data['type'] as String?),
      qty: (data['qty'] as num?)?.toInt() ?? 0,
      site: data['site'] as String? ?? '',
      note: data['note'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemLabel': itemLabel,
      'date': Timestamp.fromDate(date),
      'type': type.wireValue,
      'qty': qty,
      'site': site,
      'note': note,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
