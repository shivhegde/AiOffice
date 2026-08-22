import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/app_version_service.dart';
import '../../../core/utils/semver.dart';
import '../data/version_gate_repository.dart';
import '../domain/version_gate_config.dart';

final versionGateRepositoryProvider = Provider<VersionGateRepository>((ref) {
  return VersionGateRepository(ref.watch(firestoreProvider));
});

final versionGateConfigProvider = StreamProvider<VersionGateConfig>((ref) {
  return ref.watch(versionGateRepositoryProvider).watch();
});

final currentAppVersionProvider = FutureProvider<String>((ref) {
  return const AppVersionService().currentVersion();
});

enum VersionGateStatus { checking, allowed, belowMin, aboveMax }

class VersionGateResult {
  const VersionGateResult({required this.status, this.currentVersion, this.config});

  final VersionGateStatus status;
  final String? currentVersion;
  final VersionGateConfig? config;
}

/// Combines the running build's version with the admin-configured range.
/// While either is still loading, reports `checking` — callers should show
/// nothing blocking during that window rather than flash a false block.
final versionGateResultProvider = Provider<VersionGateResult>((ref) {
  final versionAsync = ref.watch(currentAppVersionProvider);
  final configAsync = ref.watch(versionGateConfigProvider);

  final version = versionAsync.value;
  final config = configAsync.value;
  if (version == null || config == null) {
    return const VersionGateResult(status: VersionGateStatus.checking);
  }

  if (config.minVersion.isNotEmpty && !version.isVersionAtLeast(config.minVersion)) {
    return VersionGateResult(status: VersionGateStatus.belowMin, currentVersion: version, config: config);
  }
  if (config.maxVersion.isNotEmpty && !version.isVersionAtMost(config.maxVersion)) {
    return VersionGateResult(status: VersionGateStatus.aboveMax, currentVersion: version, config: config);
  }
  return VersionGateResult(status: VersionGateStatus.allowed, currentVersion: version, config: config);
});
