enum TenderCategory {
  work('work', 'Work'),
  supply('supply', 'Supply'),
  service('service', 'Service');

  const TenderCategory(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static TenderCategory fromWireValue(String? value) {
    return TenderCategory.values.firstWhere((c) => c.wireValue == value, orElse: () => TenderCategory.work);
  }
}

enum EmdType {
  dd('dd', 'DD'),
  online('online', 'Online Payment');

  const EmdType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static EmdType fromWireValue(String? value) {
    return EmdType.values.firstWhere((t) => t.wireValue == value, orElse: () => EmdType.dd);
  }
}

/// "Overdue" (§7.6 — refund pending >30 days) is deliberately NOT a stored
/// value here; it's computed in the UI from `pending` + submission-date
/// age, matching the prototype's `chip-critical "Overdue 34d"` label.
enum RefundStatus {
  pending('pending', 'Pending'),
  refunded('refunded', 'Refunded'),
  forfeited('forfeited', 'Forfeited');

  const RefundStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static RefundStatus fromWireValue(String? value) {
    return RefundStatus.values.firstWhere((s) => s.wireValue == value, orElse: () => RefundStatus.pending);
  }
}
