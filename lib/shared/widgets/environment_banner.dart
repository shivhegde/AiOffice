import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_environment.dart';
import '../../core/providers/firebase_providers.dart';

/// Red strip across the top of every authenticated screen while an admin
/// is working in a test environment (see [AppEnvironment]), so test and
/// production data can't be confused. Hidden in production.
class EnvironmentBanner extends ConsumerWidget {
  const EnvironmentBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(activeEnvironmentProvider).value ?? AppEnvironment.production;
    if (env.isProduction) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.error,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 17, color: theme.colorScheme.onError),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'TEST ENVIRONMENT: ${env.name} — changes here do not affect production data.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onError),
            ),
          ),
        ],
      ),
    );
  }
}
