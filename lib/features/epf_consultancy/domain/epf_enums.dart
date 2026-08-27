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

/// §9.5.3 Services offered — a fixed selectable list (explicitly not free
/// text, to avoid manual re-typing). One case tracks exactly one service.
enum EpfService {
  pfWithdrawal('pf_withdrawal', 'PF Withdrawal (Form 19)'),
  advance('advance', 'Advance (Form 31)'),
  pension('pension', 'Pension (Form 10C)'),
  transferClaim('transfer_claim', 'Transfer Claim'),
  jointDeclaration('joint_declaration', 'Joint Declaration'),
  kycUpdate('kyc_update', 'KYC Update'),
  uanActivation('uan_activation', 'UAN Activation'),
  pensionCertificate('pension_certificate', 'Pension Certificate'),
  grievance('grievance', 'Grievance'),
  nameCorrection('name_correction', 'Name Correction'),
  dobCorrection('dob_correction', 'DOB Correction'),
  mobileUpdate('mobile_update', 'Mobile Update'),
  employerCorrection('employer_correction', 'Employer Correction'),
  other('other', 'Other Services');

  const EpfService(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static EpfService fromWireValue(String? value) {
    return EpfService.values.firstWhere((s) => s.wireValue == value, orElse: () => EpfService.other);
  }
}

/// §9.5.4 Case Tracking workflow: `New Client → Documents Received →
/// Application Submitted → EPFO Processing → Approved → Payment Credited
/// → Fees Collected → Completed`, plus a `rejected` terminal state the
/// source workflow diagram doesn't show a slot for but the status-color
/// legend (🔴 Rejected) implies exists.
enum CaseStage {
  newClient('new_client', 'New Client'),
  documentsReceived('documents_received', 'Documents Received'),
  applicationSubmitted('application_submitted', 'Application Submitted'),
  epfoProcessing('epfo_processing', 'EPFO Processing'),
  approved('approved', 'Approved'),
  paymentCredited('payment_credited', 'Payment Credited'),
  feesCollected('fees_collected', 'Fees Collected'),
  completed('completed', 'Completed'),
  rejected('rejected', 'Rejected');

  const CaseStage(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CaseStage fromWireValue(String? value) {
    return CaseStage.values.firstWhere((s) => s.wireValue == value, orElse: () => CaseStage.newClient);
  }
}

/// §9.5.5 Document Manager upload slots.
enum EpfDocumentSlot {
  aadhaar('aadhaar', 'Aadhaar'),
  pan('pan', 'PAN'),
  passbook('passbook', 'Passbook'),
  uanScreenshot('uan_screenshot', 'UAN Screenshot'),
  cheque('cheque', 'Cheque'),
  claimPdf('claim_pdf', 'Claim PDF'),
  paymentScreenshot('payment_screenshot', 'Payment Screenshot');

  const EpfDocumentSlot(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static EpfDocumentSlot? fromWireValue(String? value) {
    for (final s in EpfDocumentSlot.values) {
      if (s.wireValue == value) return s;
    }
    return null;
  }
}
