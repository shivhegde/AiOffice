enum Gender {
  male('male', 'Male'),
  female('female', 'Female'),
  other('other', 'Other');

  const Gender(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static Gender fromWireValue(String? value) {
    return Gender.values.firstWhere((g) => g.wireValue == value, orElse: () => Gender.male);
  }
}

enum EmployeeType {
  permanent('permanent', 'Permanent'),
  temporary('temporary', 'Temporary'),
  contract('contract', 'Contract');

  const EmployeeType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static EmployeeType fromWireValue(String? value) {
    return EmployeeType.values.firstWhere((t) => t.wireValue == value, orElse: () => EmployeeType.permanent);
  }
}

enum WorkStatus {
  active('active', 'Active'),
  inactive('inactive', 'Inactive'),
  resigned('resigned', 'Resigned'),
  retired('retired', 'Retired'),
  contractClosed('contract_closed', 'Contract Closed');

  const WorkStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static WorkStatus fromWireValue(String? value) {
    return WorkStatus.values.firstWhere((s) => s.wireValue == value, orElse: () => WorkStatus.active);
  }
}
