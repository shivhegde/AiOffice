enum VehicleType {
  bike('bike', 'Bike'),
  car('car', 'Car'),
  bus('bus', 'Bus'),
  truck('truck', 'Truck'),
  taxi('taxi', 'Taxi'),
  auto('auto', 'Auto');

  const VehicleType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static VehicleType fromWireValue(String? value) {
    return VehicleType.values.firstWhere((v) => v.wireValue == value, orElse: () => VehicleType.car);
  }
}

enum PolicyType {
  thirdParty('third_party', 'Third Party'),
  comprehensive('comprehensive', 'Comprehensive');

  const PolicyType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static PolicyType fromWireValue(String? value) {
    return PolicyType.values.firstWhere((p) => p.wireValue == value, orElse: () => PolicyType.comprehensive);
  }
}

enum PolicyStatus {
  active('active', 'Active'),
  expired('expired', 'Expired'),
  renewed('renewed', 'Renewed'),
  cancelled('cancelled', 'Cancelled');

  const PolicyStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static PolicyStatus fromWireValue(String? value) {
    return PolicyStatus.values.firstWhere((s) => s.wireValue == value, orElse: () => PolicyStatus.active);
  }
}
