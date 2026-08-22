import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/roles.dart';
import '../../features/users/application/user_providers.dart';

/// Flutter equivalent of the prototype's `data-min-role` attribute: hides
/// [child] unless the effective role (see [effectiveRoleProvider]) meets
/// [minRole]. Real enforcement always happens server-side via security
/// rules — this only controls what's rendered.
class RoleGate extends ConsumerWidget {
  const RoleGate({super.key, required this.minRole, required this.child, this.fallback});

  final AppRole minRole;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(effectiveRoleProvider);
    if (role.isAtLeast(minRole)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
