enum IoType {
  inward('inward', 'Inward', 'INW'),
  outward('outward', 'Outward', 'OUT');

  const IoType(this.wireValue, this.label, this.docPrefix);

  final String wireValue;
  final String label;
  final String docPrefix;

  static IoType fromWireValue(String? value) {
    return IoType.values.firstWhere((t) => t.wireValue == value, orElse: () => IoType.inward);
  }
}

enum IoPriority {
  normal('normal', 'Normal'),
  urgent('urgent', 'Urgent');

  const IoPriority(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static IoPriority fromWireValue(String? value) {
    return IoPriority.values.firstWhere((p) => p.wireValue == value, orElse: () => IoPriority.normal);
  }
}

enum DispatchMode {
  courier('courier', 'Courier'),
  post('post', 'Post'),
  handDelivery('hand_delivery', 'Hand Delivery'),
  email('email', 'Email');

  const DispatchMode(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static DispatchMode fromWireValue(String? value) {
    return DispatchMode.values.firstWhere((d) => d.wireValue == value, orElse: () => DispatchMode.courier);
  }
}
