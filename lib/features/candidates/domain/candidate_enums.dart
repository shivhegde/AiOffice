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

enum MaritalStatus {
  single('single', 'Single'),
  married('married', 'Married'),
  other('other', 'Other');

  const MaritalStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static MaritalStatus fromWireValue(String? value) {
    return MaritalStatus.values.firstWhere((s) => s.wireValue == value, orElse: () => MaritalStatus.single);
  }
}

/// §9.2 Education Details — multi-select (a candidate may have several).
enum EducationLevel {
  sslc('sslc', 'SSLC'),
  puc('puc', 'PUC'),
  iti('iti', 'ITI'),
  diploma('diploma', 'Diploma'),
  degree('degree', 'Degree'),
  beBtech('be_btech', 'BE / BTech'),
  mba('mba', 'MBA'),
  other('other', 'Other');

  const EducationLevel(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static EducationLevel? fromWireValue(String? value) {
    for (final e in EducationLevel.values) {
      if (e.wireValue == value) return e;
    }
    return null;
  }
}

/// §9.2 Category / Post applied for — single select.
enum CandidateCategory {
  security('security', 'Security'),
  computerOperator('computer_operator', 'Computer Operator'),
  receptionist('receptionist', 'Receptionist'),
  officeAssistant('office_assistant', 'Office Assistant'),
  electrician('electrician', 'Electrician'),
  plumber('plumber', 'Plumber'),
  mechanic('mechanic', 'Mechanic'),
  engineer('engineer', 'Engineer'),
  housekeeping('housekeeping', 'Housekeeping'),
  gardener('gardener', 'Gardener'),
  helper('helper', 'Helper'),
  labour('labour', 'Labour');

  const CandidateCategory(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CandidateCategory fromWireValue(String? value) {
    return CandidateCategory.values.firstWhere((c) => c.wireValue == value, orElse: () => CandidateCategory.security);
  }
}

enum ExperienceLevel {
  fresher('fresher', 'Fresher'),
  experienced('experienced', 'Experienced');

  const ExperienceLevel(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ExperienceLevel fromWireValue(String? value) {
    return ExperienceLevel.values.firstWhere((e) => e.wireValue == value, orElse: () => ExperienceLevel.fresher);
  }
}

/// §9.2 Languages known — multi-select.
enum Language {
  kannada('kannada', 'Kannada'),
  english('english', 'English'),
  hindi('hindi', 'Hindi'),
  others('others', 'Others');

  const Language(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static Language? fromWireValue(String? value) {
    for (final l in Language.values) {
      if (l.wireValue == value) return l;
    }
    return null;
  }
}
