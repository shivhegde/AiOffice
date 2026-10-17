/// Opt-in local development against the Firebase Local Emulator Suite:
/// `--dart-define=USE_FIREBASE_EMULATOR=true`. Off by default, so debug
/// runs hit the live project and are routed by [AppEnvironment] like any
/// other sign-in.
const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Which data environment the signed-in user works in.
///
/// Everyone authenticates against the one `officeai-registry` project.
/// Production data lives in the `(default)` Firestore database. A test
/// environment is a named Firestore database in the same project (e.g.
/// `test1`), and its Storage files sit under `env/<name>/`.
///
/// The environment is chosen per user by the `environment` field on that
/// user's production `users/{uid}` document. Only an active Admin is ever
/// routed away from production; for everyone else the field is ignored.
/// Admins set it in the Firebase console before signing in.
class AppEnvironment {
  const AppEnvironment._(this.name);

  static const production = AppEnvironment._(productionName);
  static const productionName = 'production';

  /// Firestore database ids: lowercase letters, digits and hyphens,
  /// starting with a letter, 4–63 chars.
  static final _databaseIdPattern = RegExp(r'^[a-z][a-z0-9-]{2,61}[a-z0-9]$');

  /// `production`, or the Firestore database id of a test environment.
  final String name;

  bool get isProduction => name == productionName;

  /// Null for production, meaning the `(default)` database.
  String? get databaseId => isProduction ? null : name;

  /// Prefix applied to every Storage path so test files never mix with
  /// production files in the shared bucket.
  String get storagePrefix => isProduction ? '' : 'env/$name/';

  /// Resolves the environment from a production `users/{uid}` document.
  /// Anything unexpected falls back to production.
  static AppEnvironment fromProductionUserData(Map<String, dynamic>? data) {
    if (data == null) return production;
    if (data['role'] != 'admin' || data['status'] != 'active') return production;
    final raw = data['environment'];
    if (raw is! String) return production;
    final requested = raw.trim().toLowerCase();
    if (requested.isEmpty || requested == productionName) return production;
    if (requested == '(default)' || !_databaseIdPattern.hasMatch(requested)) return production;
    return AppEnvironment._(requested);
  }

  @override
  bool operator ==(Object other) => other is AppEnvironment && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'AppEnvironment($name)';
}
