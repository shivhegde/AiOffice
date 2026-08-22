import 'package:aioffice/core/constants/roles.dart';
import 'package:aioffice/features/users/domain/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUser.toCreateMap', () {
    test('new accounts default to pending, not active', () {
      final user = AppUser(
        uid: 'uid-1',
        email: 'someone@example.com',
        displayName: 'Someone',
        role: AppRole.admin, // deliberately wrong — toCreateMap must ignore this
        status: UserStatus.active, // deliberately wrong — toCreateMap must ignore this
      );

      final map = user.toCreateMap();

      expect(map['status'], 'pending');
      expect(map['role'], 'general_user');
    });
  });

  group('UserStatus.fromWireValue', () {
    test('recognizes all three states', () {
      expect(UserStatus.fromWireValue('pending'), UserStatus.pending);
      expect(UserStatus.fromWireValue('active'), UserStatus.active);
      expect(UserStatus.fromWireValue('disabled'), UserStatus.disabled);
    });

    test('unrecognized/malformed values fail closed to pending, not active', () {
      expect(UserStatus.fromWireValue('garbage'), UserStatus.pending);
      expect(UserStatus.fromWireValue(null), UserStatus.pending);
    });
  });

  group('AppUser status getters', () {
    test('isActive / isPending reflect status', () {
      AppUser withStatus(UserStatus status) {
        return AppUser(uid: 'u', email: 'e', displayName: 'd', role: AppRole.generalUser, status: status);
      }

      expect(withStatus(UserStatus.active).isActive, isTrue);
      expect(withStatus(UserStatus.active).isPending, isFalse);
      expect(withStatus(UserStatus.pending).isPending, isTrue);
      expect(withStatus(UserStatus.pending).isActive, isFalse);
      expect(withStatus(UserStatus.disabled).isActive, isFalse);
      expect(withStatus(UserStatus.disabled).isPending, isFalse);
    });
  });
}
