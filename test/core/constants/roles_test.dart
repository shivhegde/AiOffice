import 'package:aioffice/core/constants/roles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRole', () {
    test('rank ordering is generalUser < powerUser < manager < admin', () {
      expect(AppRole.generalUser.rank, lessThan(AppRole.powerUser.rank));
      expect(AppRole.powerUser.rank, lessThan(AppRole.manager.rank));
      expect(AppRole.manager.rank, lessThan(AppRole.admin.rank));
    });

    test('isAtLeast(powerUser) admits powerUser, manager and admin, not generalUser', () {
      expect(AppRole.generalUser.isAtLeast(AppRole.powerUser), isFalse);
      expect(AppRole.powerUser.isAtLeast(AppRole.powerUser), isTrue);
      expect(AppRole.manager.isAtLeast(AppRole.powerUser), isTrue);
      expect(AppRole.admin.isAtLeast(AppRole.powerUser), isTrue);
    });

    test('isAtLeast(manager) admits manager and admin, not powerUser or generalUser', () {
      expect(AppRole.powerUser.isAtLeast(AppRole.manager), isFalse);
      expect(AppRole.manager.isAtLeast(AppRole.manager), isTrue);
      expect(AppRole.admin.isAtLeast(AppRole.manager), isTrue);
    });

    test('fromWireValue round-trips "manager"', () {
      expect(AppRole.fromWireValue('manager'), AppRole.manager);
      expect(AppRole.manager.wireValue, 'manager');
    });

    test('fromWireValue falls back to generalUser for unknown values', () {
      expect(AppRole.fromWireValue('not_a_role'), AppRole.generalUser);
      expect(AppRole.fromWireValue(null), AppRole.generalUser);
    });
  });
}
