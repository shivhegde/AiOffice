import 'package:aioffice/app/theme/app_theme.dart';
import 'package:aioffice/core/constants/roles.dart';
import 'package:aioffice/core/providers/firebase_providers.dart';
import 'package:aioffice/features/system_control/application/system_control_providers.dart';
import 'package:aioffice/features/system_control/data/system_control_repository.dart';
import 'package:aioffice/features/system_control/domain/system_control_config.dart';
import 'package:aioffice/features/system_control/presentation/system_control_gate.dart';
import 'package:aioffice/features/users/application/user_providers.dart';
import 'package:aioffice/features/users/domain/app_user.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user(AppRole role) =>
    AppUser(uid: 'u1', email: 'u1@x.com', displayName: 'User One', role: role, status: UserStatus.active);

void main() {
  group('forceRefreshDueProvider', () {
    final startedAt = DateTime(2026, 11, 16, 9);

    ProviderContainer containerFor({required DateTime? refreshAt, required DateTime now}) {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          appStartedAtProvider.overrideWithValue(startedAt),
          systemControlConfigProvider.overrideWith(
            (ref) => Stream.value(SystemControlConfig(forceRefreshAt: refreshAt)),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<bool> due(ProviderContainer c) async {
      await c.read(systemControlConfigProvider.future);
      return c.read(forceRefreshDueProvider);
    }

    test('due once a time after app start has been reached', () async {
      final c = containerFor(refreshAt: DateTime(2026, 11, 16, 10), now: DateTime(2026, 11, 16, 10, 5));
      expect(await due(c), isTrue);
    });

    test('not yet due before the time', () async {
      final c = containerFor(refreshAt: DateTime(2026, 11, 16, 10), now: DateTime(2026, 11, 16, 9, 30));
      expect(await due(c), isFalse);
    });

    test('an app started after the refresh time is not affected', () async {
      final c = containerFor(refreshAt: DateTime(2026, 11, 16, 8), now: DateTime(2026, 11, 16, 10));
      expect(await due(c), isFalse);
    });

    test('nothing scheduled', () async {
      final c = containerFor(refreshAt: null, now: DateTime(2026, 11, 16, 10));
      expect(await due(c), isFalse);
    });
  });

  group('maintenanceAccessProvider', () {
    Future<MaintenanceAccess> accessFor({required bool maintenance, AppRole? role}) async {
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: role != null,
              mockUser: MockUser(uid: 'u1'),
            ),
          ),
          currentAppUserProvider.overrideWith((ref) => Stream.value(role == null ? null : _user(role))),
          systemControlConfigProvider.overrideWith(
            (ref) => Stream.value(SystemControlConfig(maintenanceMode: maintenance)),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(maintenanceAccessProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return container.read(maintenanceAccessProvider);
    }

    test('blocks non-admins and warns admins while on', () async {
      expect(await accessFor(maintenance: true, role: AppRole.manager), MaintenanceAccess.blocked);
      expect(await accessFor(maintenance: true, role: AppRole.generalUser), MaintenanceAccess.blocked);
      expect(await accessFor(maintenance: true, role: AppRole.admin), MaintenanceAccess.adminWarning);
    });

    test('nothing when off or signed out', () async {
      expect(await accessFor(maintenance: false, role: AppRole.generalUser), MaintenanceAccess.none);
      expect(await accessFor(maintenance: true), MaintenanceAccess.none);
    });
  });

  test('repository saves maintenance and refresh without overwriting each other', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = SystemControlRepository(firestore);
    final at = DateTime(2026, 11, 20, 18, 30);
    await repo.saveForceRefresh(at: at, message: 'Restart please', updatedByName: 'Admin');
    await repo.saveMaintenance(enabled: true, message: 'Down for upgrade', updatedByName: 'Admin');

    final config = await repo.watch().first;
    expect(config.maintenanceMode, isTrue);
    expect(config.maintenanceMessage, 'Down for upgrade');
    expect(config.forceRefreshAt, at);
    expect(config.forceRefreshMessage, 'Restart please');
  });

  group('SystemControlGate', () {
    late MockFirebaseAuth auth;
    var exited = false;
    var restarted = false;

    Future<void> pumpGate(WidgetTester tester, {required AppRole role, required SystemControlConfig config}) async {
      exited = false;
      restarted = false;
      auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(auth),
            currentAppUserProvider.overrideWith((ref) => Stream.value(_user(role))),
            systemControlConfigProvider.overrideWith((ref) => Stream.value(config)),
            appStartedAtProvider.overrideWithValue(DateTime(2000)),
            appExitProvider.overrideWithValue(() => exited = true),
            appRestartProvider.overrideWithValue((_) => restarted = true),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => SystemControlGate(child: child!),
            home: const Scaffold(body: Text('HOME')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('non-admin in maintenance is signed out and the app exits on Continue', (tester) async {
      await pumpGate(tester, role: AppRole.manager, config: const SystemControlConfig(maintenanceMode: true));
      expect(find.text('Maintenance in progress'), findsOneWidget);
      expect(find.text('HOME'), findsNothing);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(auth.currentUser, isNull);
      expect(exited, isTrue);
    });

    testWidgets('admin in maintenance is warned and can continue', (tester) async {
      await pumpGate(tester, role: AppRole.admin, config: const SystemControlConfig(maintenanceMode: true));
      expect(find.text('WARNING: Database in maintenance mode'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('WARNING: Database in maintenance mode'), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
      expect(auth.currentUser, isNotNull);
      expect(exited, isFalse);
    });

    testWidgets('a due force refresh restarts the app on Continue, admins included', (tester) async {
      await pumpGate(
        tester,
        role: AppRole.admin,
        config: SystemControlConfig(forceRefreshAt: DateTime(2001)),
      );
      expect(find.text('Refresh required'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(restarted, isTrue);
    });

    testWidgets('nothing shown when no switch is on', (tester) async {
      await pumpGate(tester, role: AppRole.generalUser, config: SystemControlConfig.unset);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });
  });
}
