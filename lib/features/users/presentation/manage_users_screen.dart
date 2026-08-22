import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/roles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_data_table.dart';
import '../../../shared/widgets/status_chip.dart';
import '../application/user_providers.dart';
import '../domain/app_user.dart';

/// REQUIREMENTS.md §4 "Manage users (roles, status)" — Admin-only (the
/// route itself double-guards on role, see `app/router.dart`). Note: the
/// very first admin must be promoted manually via the Firestore console
/// (Phase 1 plan decision #2) — this screen can only promote/demote
/// *subsequent* users once at least one admin exists.
class ManageUsersScreen extends ConsumerWidget {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_allUsersStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: usersAsync.when(
        data: (users) => _UsersTable(users: users),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load users: $err')),
      ),
    );
  }
}

final _allUsersStreamProvider = StreamProvider((ref) {
  return ref.watch(userRepositoryProvider).watchAllUsers();
});

class _UsersTable extends ConsumerWidget {
  const _UsersTable({required this.users});

  final List<AppUser> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final pendingCount = users.where((u) => u.isPending).length;
    // Pending accounts surface first — they're the ones needing action.
    final sorted = [...users]..sort((a, b) {
      if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
      return a.email.compareTo(b.email);
    });

    return AppCard(
      title: 'All users',
      trailing: Text(
        pendingCount > 0 ? '${users.length} total • $pendingCount pending approval' : '${users.length} total',
        style: TextStyle(
          fontSize: 11.5,
          color: pendingCount > 0 ? colors.warning : colors.textMuted,
          fontWeight: pendingCount > 0 ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      child: AppDataTable(
        columns: const [
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final user in sorted)
            DataRow(
              cells: [
                DataCell(Text(user.email)),
                DataCell(Text(user.displayName)),
                DataCell(_RoleDropdown(user: user)),
                DataCell(_StatusChipForUser(user: user)),
                DataCell(_StatusAction(user: user)),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusChipForUser extends StatelessWidget {
  const _StatusChipForUser({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return switch (user.status) {
      UserStatus.pending => const StatusChip(label: 'Pending approval', variant: StatusChipVariant.warn),
      UserStatus.active => const StatusChip(label: 'Active', variant: StatusChipVariant.good),
      UserStatus.disabled => const StatusChip(label: 'Disabled', variant: StatusChipVariant.critical),
    };
  }
}

class _StatusAction extends ConsumerWidget {
  const _StatusAction({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> setStatus(UserStatus status) {
      return ref.read(userRepositoryProvider).updateRoleAndStatus(uid: user.uid, role: user.role, status: status);
    }

    return switch (user.status) {
      UserStatus.pending => TextButton(
        onPressed: () => setStatus(UserStatus.active),
        child: const Text('Approve'),
      ),
      UserStatus.active => TextButton(onPressed: () => setStatus(UserStatus.disabled), child: const Text('Disable')),
      UserStatus.disabled => TextButton(onPressed: () => setStatus(UserStatus.active), child: const Text('Enable')),
    };
  }
}

class _RoleDropdown extends ConsumerWidget {
  const _RoleDropdown({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButton<AppRole>(
      value: user.role,
      underline: const SizedBox.shrink(),
      style: const TextStyle(fontSize: 12.8),
      items: [for (final role in AppRole.values) DropdownMenuItem(value: role, child: Text(role.label))],
      onChanged: (role) async {
        if (role == null) return;
        await ref.read(userRepositoryProvider).updateRoleAndStatus(uid: user.uid, role: role, status: user.status);
      },
    );
  }
}
