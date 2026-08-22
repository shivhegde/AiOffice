enum ContractType {
  fixed('fixed', 'Fixed Period'),
  extension('extension', 'Extension'),
  tillNextTender('till_next_tender', 'Till Next Tender');

  const ContractType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ContractType fromWireValue(String? value) {
    return ContractType.values.firstWhere((c) => c.wireValue == value, orElse: () => ContractType.fixed);
  }
}

enum WorkOrderStatus {
  active('active', 'Active'),
  expired('expired', 'Expired'),
  extended('extended', 'Extended');

  const WorkOrderStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static WorkOrderStatus fromWireValue(String? value) {
    return WorkOrderStatus.values.firstWhere((s) => s.wireValue == value, orElse: () => WorkOrderStatus.active);
  }
}

enum FdStatus {
  active('active', 'Active'),
  released('released', 'Released'),
  renewed('renewed', 'Renewed');

  const FdStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static FdStatus fromWireValue(String? value) {
    return FdStatus.values.firstWhere((s) => s.wireValue == value, orElse: () => FdStatus.active);
  }
}
