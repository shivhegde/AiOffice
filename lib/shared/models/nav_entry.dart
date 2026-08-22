import 'package:flutter/widgets.dart';

import '../../core/constants/roles.dart';

class NavEntry {
  const NavEntry({
    required this.route,
    required this.label,
    required this.icon,
    this.minRole = AppRole.generalUser,
  });

  final String route;
  final String label;
  final IconData icon;
  final AppRole minRole;
}

class NavGroup {
  const NavGroup({required this.label, required this.entries});

  final String label;
  final List<NavEntry> entries;
}
