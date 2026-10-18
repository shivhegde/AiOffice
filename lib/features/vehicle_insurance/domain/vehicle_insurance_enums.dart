enum VehicleType {
  bike('bike', 'Bike'),
  car('car', 'Car'),
  bus('bus', 'Bus'),
  truck('truck', 'Truck'),
  taxi('taxi', 'Taxi'),
  auto('auto', 'Auto'),
  commercialVehicle('commercial_vehicle', 'Commercial Vehicle'),
  goodsCarry('goods_carry', 'Goods Carry'),
  swmVehicle('swm_vehicle', 'SWM Vehicle'),
  // Paired with free text on the policy (`vehicleTypeOther`); keep last.
  other('other', 'Other');

  const VehicleType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static VehicleType fromWireValue(String? value) {
    return VehicleType.values.firstWhere((v) => v.wireValue == value, orElse: () => VehicleType.car);
  }
}

/// A policy can carry several types; [PolicyType.other] pairs with free
/// text on the policy (`policyTypeOther`).
enum PolicyType {
  comprehensive('comprehensive', 'Comprehensive'),
  thirdParty('third_party', 'Third Party'),
  personalAccident('personal_accident', 'Personal Accident Coverage'),
  ownDamage('own_damage', 'Own Damage'),
  other('other', 'Other');

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

/// Supporting-document upload slots on a policy, alongside the policy PDF.
enum VehicleDocumentSlot {
  aadhaar('aadhaar', 'Aadhaar Card'),
  pan('pan', 'PAN Card'),
  previousPolicy('previous_policy', 'Previous Insurance Policy'),
  rc('rc', 'RC');

  const VehicleDocumentSlot(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static VehicleDocumentSlot? fromWireValue(String? value) {
    for (final s in VehicleDocumentSlot.values) {
      if (s.wireValue == value) return s;
    }
    return null;
  }
}
