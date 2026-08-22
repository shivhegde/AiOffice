import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/users/application/user_providers.dart';
import '../../features/users/domain/app_user.dart';
import 'sidebar_nav.dart';
import 'top_bar.dart';

const Map<String, (String, String)> _titles = {
  '/dashboard': ('Dashboard', 'Overview across all task groups'),
  '/inward-outward': ('Inward / Outward', 'Correspondence register'),
  '/tender-emd': ('Tender-EMD', 'Tender bids and Earnest Money Deposit tracking'),
  '/work-orders': ('Work Orders & Fixed Deposits', 'Contract lifecycle and linked deposits'),
  '/employees': ('Employees', 'Organization staff directory'),
  '/candidates': ('Candidate Bank', 'Manpower pool for placement roles'),
  '/inventory': ('Inventory', 'Uniform & apparel stock'),
  '/vehicle-insurance': ('Vehicle Insurance', 'Customer policies, renewals & commission'),
  '/epf': ('EPF Consultancy', 'Client case management for EPF services'),
  '/admin/users': ('Manage Users', 'Roles & account status — Admin only'),
  '/admin/audit-log': ('Audit Log', 'System activity trail — Admin only'),
  '/admin/app-version': ('App Version', 'Allowed app-version range — Admin only'),
};

/// Persistent sidebar + top bar shell wrapping every authenticated route,
/// matching `docs/prototype.html`'s app shell. Collapses the sidebar into a
/// `Drawer` below the prototype's 760px breakpoint.
///
/// Route content only mounts once `users/{uid}` is confirmed to exist —
/// otherwise Firestore reads gated by `isKnownUser()` in firestore.rules
/// (e.g. Inward/Outward, Dashboard) can fire before
/// `UserRepository.ensureUserDocument()` finishes creating that doc (a
/// real race on first sign-in, or after the doc is wiped while still
/// signed in), get a terminal `permission-denied`, and — since Firestore
/// listeners don't auto-retry after that — stay stuck showing an error
/// until the app is restarted.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.currentRoute, required this.child});

  final String currentRoute;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNarrow = MediaQuery.sizeOf(context).width < 760;
    final (title, crumb) = _titles[currentRoute] ?? (currentRoute, '');
    final appUserAsync = ref.watch(currentAppUserProvider);

    void navigate(String route) {
      if (isNarrow) Navigator.of(context).maybePop();
      context.go(route);
    }

    return Scaffold(
      drawer: isNarrow
          ? Drawer(child: SidebarNav(currentRoute: currentRoute, onNavigate: navigate))
          : null,
      body: Row(
        children: [
          if (!isNarrow) SidebarNav(currentRoute: currentRoute, onNavigate: navigate),
          Expanded(
            child: Column(
              children: [
                Builder(
                  builder: (innerContext) => TopBar(
                    title: title,
                    crumb: crumb,
                    onMenuTap: isNarrow ? () => Scaffold.of(innerContext).openDrawer() : null,
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: appUserAsync.when(
                      data: (appUser) => appUser == null
                          ? const _PreparingAccount()
                          : !appUser.isActive
                          ? _AccountNotActiveScreen(appUser: appUser)
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(22, 22, 22, 60),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1180),
                                child: child,
                              ),
                            ),
                      loading: () => const _PreparingAccount(),
                      error: (err, _) => _PreparingAccountError(
                        error: err,
                        onRetry: () => ref.invalidate(currentAppUserProvider),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparingAccount extends StatelessWidget {
  const _PreparingAccount();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Setting up your account…'),
        ],
      ),
    );
  }
}

/// Shown instead of the app for a signed-in user whose account isn't
/// `active` — either a brand-new self-registration awaiting Admin
/// approval (`pending`), or an account an Admin has explicitly disabled.
/// Without this, such a user would instead hit a confusing raw
/// `permission-denied` from Firestore the moment any route tried to read
/// data, since `isKnownUser()` in firestore.rules requires `active`.
class _AccountNotActiveScreen extends ConsumerWidget {
  const _AccountNotActiveScreen({required this.appUser});

  final AppUser appUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final isPending = appUser.isPending;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isPending ? Icons.hourglass_top_outlined : Icons.block_outlined, size: 32, color: colors.textMuted),
            const SizedBox(height: 14),
            Text(
              isPending ? 'Awaiting admin approval' : 'Account disabled',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              isPending
                  ? 'Your account (${appUser.email}) has been created but needs an admin to approve it before you can sign in.'
                  : 'Your account (${appUser.email}) has been disabled. Contact an admin if you believe this is a mistake.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreparingAccountError extends StatelessWidget {
  const _PreparingAccountError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32),
            const SizedBox(height: 12),
            const Text('Could not load your account.'),
            const SizedBox(height: 4),
            Text('$error', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
