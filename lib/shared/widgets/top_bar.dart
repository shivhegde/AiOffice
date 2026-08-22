import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/roles.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/users/application/user_providers.dart';

/// Prototype's `.topbar` — title/crumb, global search (§3.1), a
/// debug-only role picker (§5.1 plan decision #10), and a user chip with
/// sign-out.
class TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const TopBar({
    super.key,
    required this.title,
    required this.crumb,
    this.onMenuTap,
    this.onSearch,
  });

  final String title;
  final String crumb;
  final VoidCallback? onMenuTap;
  final ValueChanged<String>? onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final appUser = ref.watch(currentAppUserProvider).value;
    final effectiveRole = ref.watch(effectiveRoleProvider);
    final isNarrow = MediaQuery.sizeOf(context).width < 760;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (isNarrow && onMenuTap != null) ...[
            IconButton(icon: const Icon(Icons.menu), onPressed: onMenuTap),
            const SizedBox(width: 6),
          ],
          if (!isNarrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
                Text(crumb, style: TextStyle(fontSize: 12, color: colors.textMuted)),
              ],
            ),
          const SizedBox(width: 16),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: TextField(
                onSubmitted: onSearch,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search documents, tenders, people…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (kDebugMode) _DebugRolePicker(activeRole: effectiveRole),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(5, 5, 10, 5),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: colors.ink800,
                  child: Text(
                    _initials(appUser?.displayName ?? appUser?.email ?? '?'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFFEDE7D6), fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isNarrow)
                  Text(
                    '${appUser?.displayName ?? appUser?.email ?? '...'} • ${effectiveRole.label}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 16),
                  tooltip: 'Sign out',
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    final letters = parts.take(2).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
    return letters.isEmpty ? trimmed[0].toUpperCase() : letters;
  }
}

class _DebugRolePicker extends ConsumerWidget {
  const _DebugRolePicker({required this.activeRole});

  final AppRole activeRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Viewing as (debug)', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        DropdownButton<AppRole>(
          value: activeRole,
          underline: const SizedBox.shrink(),
          style: const TextStyle(fontSize: 12.5),
          items: [for (final role in AppRole.values) DropdownMenuItem(value: role, child: Text(role.label))],
          onChanged: (role) => ref.read(debugRoleOverrideProvider.notifier).state = role,
        ),
      ],
    );
  }
}
