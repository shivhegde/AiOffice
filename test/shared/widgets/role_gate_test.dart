import 'package:aioffice/core/constants/roles.dart';
import 'package:aioffice/features/users/application/user_providers.dart';
import 'package:aioffice/shared/widgets/role_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap({required AppRole role, required Widget child}) {
    return ProviderScope(
      overrides: [effectiveRoleProvider.overrideWithValue(role)],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('shows child when the effective role meets minRole', (tester) async {
    await tester.pumpWidget(
      wrap(
        role: AppRole.admin,
        child: const RoleGate(minRole: AppRole.powerUser, child: Text('Visible')),
      ),
    );
    expect(find.text('Visible'), findsOneWidget);
  });

  testWidgets('hides child when the effective role is below minRole', (tester) async {
    await tester.pumpWidget(
      wrap(
        role: AppRole.generalUser,
        child: const RoleGate(minRole: AppRole.powerUser, child: Text('Hidden')),
      ),
    );
    expect(find.text('Hidden'), findsNothing);
  });

  testWidgets('renders fallback when provided and gated', (tester) async {
    await tester.pumpWidget(
      wrap(
        role: AppRole.generalUser,
        child: const RoleGate(
          minRole: AppRole.admin,
          fallback: Text('No access'),
          child: Text('Admin only'),
        ),
      ),
    );
    expect(find.text('No access'), findsOneWidget);
    expect(find.text('Admin only'), findsNothing);
  });
}
