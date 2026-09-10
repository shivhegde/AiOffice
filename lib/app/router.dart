import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/roles.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/candidates/presentation/candidates_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/employees/presentation/employees_screen.dart';
import '../features/epf_consultancy/presentation/epf_consultancy_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/inward_outward/presentation/inward_outward_screen.dart';
import '../features/audit/presentation/audit_log_screen.dart';
import '../features/licence/presentation/licence_settings_screen.dart';
import '../features/tender_emd/presentation/tender_emd_screen.dart';
import '../features/users/application/user_providers.dart';
import '../features/vehicle_insurance/presentation/vehicle_insurance_screen.dart';
import '../features/users/presentation/manage_users_screen.dart';
import '../features/version_gate/presentation/app_version_settings_screen.dart';
import '../features/work_orders/presentation/work_orders_screen.dart';
import '../shared/widgets/app_shell.dart';
import 'go_router_refresh_stream.dart';

/// `authStateChanges`-driven route protection per REQUIREMENTS.md §5:
/// unauthenticated users are redirected to `/login`; authenticated users on
/// `/login` are redirected to `/dashboard`. `/admin/*` routes additionally
/// guard on `role == admin` as defense-in-depth for direct URL entry on
/// Web, on top of the sidebar simply hiding those entries via [RoleGate].
final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges),
    redirect: (context, state) {
      final signedIn = authRepository.currentUser != null;
      final onLogin = state.matchedLocation == '/login';

      if (!signedIn) return onLogin ? null : '/login';
      if (onLogin) return '/dashboard';

      if (state.matchedLocation.startsWith('/admin')) {
        final role = ref.read(currentAppUserProvider).value?.role ?? AppRole.generalUser;
        if (!role.isAtLeast(AppRole.admin)) return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(currentRoute: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/inward-outward', builder: (context, state) => const InwardOutwardScreen()),
          GoRoute(path: '/tender-emd', builder: (context, state) => const TenderEmdScreen()),
          GoRoute(path: '/work-orders', builder: (context, state) => const WorkOrdersScreen()),
          GoRoute(path: '/employees', builder: (context, state) => const EmployeesScreen()),
          GoRoute(path: '/candidates', builder: (context, state) => const CandidatesScreen()),
          GoRoute(path: '/inventory', builder: (context, state) => const InventoryScreen()),
          GoRoute(path: '/vehicle-insurance', builder: (context, state) => const VehicleInsuranceScreen()),
          GoRoute(path: '/epf', builder: (context, state) => const EpfConsultancyScreen()),
          GoRoute(path: '/admin/users', builder: (context, state) => const ManageUsersScreen()),
          GoRoute(path: '/admin/audit-log', builder: (context, state) => const AuditLogScreen()),
          GoRoute(path: '/admin/app-version', builder: (context, state) => const AppVersionSettingsScreen()),
          GoRoute(path: '/admin/licence', builder: (context, state) => const LicenceSettingsScreen()),
        ],
      ),
    ],
  );
});
