import 'package:aioffice/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _user({String role = 'admin', String status = 'active', Object? environment}) => {
  'role': role,
  'status': status,
  'environment': ?environment,
};

void main() {
  group('AppEnvironment.fromProductionUserData', () {
    test('active admin with a test environment is routed there', () {
      final env = AppEnvironment.fromProductionUserData(_user(environment: 'test1'));
      expect(env.name, 'test1');
      expect(env.isProduction, isFalse);
      expect(env.databaseId, 'test1');
      expect(env.storagePrefix, 'env/test1/');
    });

    test('value is trimmed and lower-cased', () {
      expect(AppEnvironment.fromProductionUserData(_user(environment: ' Test2 ')).name, 'test2');
    });

    test('non-admin roles always get production', () {
      for (final role in ['general_user', 'power_user', 'manager']) {
        expect(AppEnvironment.fromProductionUserData(_user(role: role, environment: 'test1')), AppEnvironment.production);
      }
    });

    test('inactive admin gets production', () {
      expect(
        AppEnvironment.fromProductionUserData(_user(status: 'disabled', environment: 'test1')),
        AppEnvironment.production,
      );
    });

    test('missing, blank, "production", "(default)" or invalid values fall back to production', () {
      for (final value in [null, '', 'production', 'PRODUCTION', '(default)', 'ab', '1test', 'test_1', 42]) {
        expect(AppEnvironment.fromProductionUserData(_user(environment: value)), AppEnvironment.production);
      }
      expect(AppEnvironment.fromProductionUserData(null), AppEnvironment.production);
    });

    test('production has no database id or storage prefix', () {
      expect(AppEnvironment.production.databaseId, isNull);
      expect(AppEnvironment.production.storagePrefix, '');
    });
  });
}
