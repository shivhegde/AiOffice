import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/licence_repository.dart';
import '../domain/licence_config.dart';

final licenceRepositoryProvider = Provider<LicenceRepository>((ref) {
  return LicenceRepository(ref.watch(firestoreProvider));
});

final licenceConfigProvider = StreamProvider<LicenceConfig>((ref) {
  return ref.watch(licenceRepositoryProvider).watch();
});

/// How many days ahead of expiry the banner starts showing.
const licenceWarningWindowDays = 10;

enum LicenceStatusKind { noExpiry, ok, expiringSoon, expired }

class LicenceStatus {
  const LicenceStatus({required this.kind, this.daysLeft});

  final LicenceStatusKind kind;

  /// Only set when [kind] is `expiringSoon` — days remaining until (and
  /// including) the expiry date, `0` meaning "expires today".
  final int? daysLeft;
}

/// Combines the admin-configured expiry date with today's date into a
/// status the banner reacts to. Fails open (`noExpiry`) while the config is
/// still loading, so nothing flashes on app start.
final licenceStatusProvider = Provider<LicenceStatus>((ref) {
  final configAsync = ref.watch(licenceConfigProvider);
  final config = configAsync.value;
  final expiryDate = config?.expiryDate;
  if (expiryDate == null) {
    return const LicenceStatus(kind: LicenceStatusKind.noExpiry);
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
  final daysLeft = expiry.difference(today).inDays;

  if (daysLeft < 0) return const LicenceStatus(kind: LicenceStatusKind.expired);
  if (daysLeft <= licenceWarningWindowDays) {
    return LicenceStatus(kind: LicenceStatusKind.expiringSoon, daysLeft: daysLeft);
  }
  return const LicenceStatus(kind: LicenceStatusKind.ok);
});
