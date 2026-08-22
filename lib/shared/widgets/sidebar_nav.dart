import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_theme.dart';
import '../../core/constants/roles.dart';
import '../../features/users/application/user_providers.dart';
import '../models/nav_entry.dart';

/// Prototype's `.sidebar` — grouped nav matching the IA in
/// REQUIREMENTS.md §3: Overview / Documents / Task Groups / People /
/// Operations / Client Services / Admin.
final List<NavGroup> appNavGroups = [
  const NavGroup(
    label: 'Overview',
    entries: [NavEntry(route: '/dashboard', label: 'Dashboard', icon: Icons.grid_view_rounded)],
  ),
  const NavGroup(
    label: 'Documents',
    entries: [NavEntry(route: '/inward-outward', label: 'Inward / Outward', icon: Icons.mail_outline_rounded)],
  ),
  const NavGroup(
    label: 'Task Groups',
    entries: [
      NavEntry(route: '/tender-emd', label: 'Tender-EMD', icon: Icons.diamond_outlined),
      NavEntry(route: '/work-orders', label: 'Work Orders & FD', icon: Icons.description_outlined),
    ],
  ),
  const NavGroup(
    label: 'People',
    entries: [
      NavEntry(route: '/employees', label: 'Employees', icon: Icons.person_outline_rounded),
      NavEntry(route: '/candidates', label: 'Candidate Bank', icon: Icons.badge_outlined),
    ],
  ),
  const NavGroup(
    label: 'Operations',
    entries: [NavEntry(route: '/inventory', label: 'Inventory', icon: Icons.inventory_2_outlined)],
  ),
  const NavGroup(
    label: 'Client Services',
    entries: [
      NavEntry(route: '/vehicle-insurance', label: 'Vehicle Insurance', icon: Icons.shield_outlined),
      NavEntry(route: '/epf', label: 'EPF Consultancy', icon: Icons.work_outline_rounded),
    ],
  ),
  const NavGroup(
    label: 'Admin',
    entries: [
      NavEntry(route: '/admin/users', label: 'Manage Users', icon: Icons.people_outline_rounded, minRole: AppRole.admin),
      NavEntry(route: '/admin/audit-log', label: 'Audit Log', icon: Icons.assignment_outlined, minRole: AppRole.admin),
      NavEntry(route: '/admin/app-version', label: 'App Version', icon: Icons.system_update_outlined, minRole: AppRole.admin),
    ],
  ),
];

class SidebarNav extends ConsumerWidget {
  const SidebarNav({super.key, required this.currentRoute, required this.onNavigate});

  final String currentRoute;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final role = ref.watch(effectiveRoleProvider);

    return Container(
      width: 240,
      color: colors.ink900,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFB8791E), borderRadius: BorderRadius.circular(7)),
                    child: Text('O', style: AppFonts.serif(fontWeight: FontWeight.w700, color: colors.onAccent)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OfficeAI',
                          style: AppFonts.serif(fontWeight: FontWeight.w700, fontSize: 16.5, color: const Color(0xFFEDE7D6)),
                        ),
                        Text(
                          'REGISTRY & TASK CONSOLE',
                          style: const TextStyle(fontSize: 10.5, letterSpacing: 0.7, color: Color(0xFFB9B096)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0x24EDE7D6), height: 1),
            const SizedBox(height: 8),
            for (final group in appNavGroups) _NavGroupSection(group: group, currentRoute: currentRoute, onNavigate: onNavigate, role: role),
          ],
        ),
      ),
    );
  }
}

class _NavGroupSection extends StatelessWidget {
  const _NavGroupSection({required this.group, required this.currentRoute, required this.onNavigate, required this.role});

  final NavGroup group;
  final String currentRoute;
  final ValueChanged<String> onNavigate;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(
              group.label.toUpperCase(),
              style: const TextStyle(fontSize: 10.5, letterSpacing: 0.7, color: Color(0xFF9E9578)),
            ),
          ),
          for (final entry in group.entries) _NavItem(entry: entry, active: entry.route == currentRoute, locked: !role.isAtLeast(entry.minRole), onTap: () => onNavigate(entry.route)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.entry, required this.active, required this.locked, required this.onTap});

  final NavEntry entry;
  final bool active;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (locked) return const SizedBox.shrink();

    return Material(
      color: active ? const Color(0xFFB8791E) : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(entry.icon, size: 17, color: active ? const Color(0xFF1B1200) : const Color(0xFFD8D2BE)),
              const SizedBox(width: 10),
              Text(
                entry.label,
                style: TextStyle(
                  fontSize: 13.3,
                  color: active ? const Color(0xFF1B1200) : const Color(0xFFD8D2BE),
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
