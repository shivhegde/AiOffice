/// Firestore collection name constants — single source of truth so
/// repositories and security-rule-adjacent code never hand-type strings.
class FirestorePaths {
  FirestorePaths._();

  static const users = 'users';
  static const counters = 'counters';
  static const inwardOutwardDocuments = 'inward_outward_documents';
  static const auditLog = 'audit_log';
  static const tenders = 'tenders';
  static const workOrders = 'work_orders';
  static const employees = 'employees';
  static const candidates = 'candidates';
  static const inventoryItems = 'inventory_items';
  static const vehiclePolicies = 'vehicle_policies';
  static const epfCases = 'epf_cases';
  static const appConfig = 'app_config';
  static const versionGateDocId = 'version_gate';
}

/// Cloud Storage path convention for Inward/Outward file uploads:
/// `inward_outward/{type}/{year}/{docId}/{fileName}`.
class StoragePaths {
  StoragePaths._();

  static String inwardOutwardFile({
    required String type,
    required int year,
    required String docId,
    required String fileName,
  }) {
    return 'inward_outward/$type/$year/$docId/$fileName';
  }
}
