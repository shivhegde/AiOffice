import 'package:aioffice/features/licence/application/licence_providers.dart';
import 'package:aioffice/features/licence/domain/licence_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('licenceStatusProvider', () {
    test('no expiry date set => noExpiry', () async {
      final container = ProviderContainer(
        overrides: [licenceConfigProvider.overrideWith((ref) => Stream.value(LicenceConfig.unset))],
      );
      addTearDown(container.dispose);
      await container.read(licenceConfigProvider.future);
      expect(container.read(licenceStatusProvider).kind, LicenceStatusKind.noExpiry);
    });

    test('expiry far in the future => ok', () async {
      final expiry = DateTime.now().add(const Duration(days: 30));
      final container = ProviderContainer(
        overrides: [
          licenceConfigProvider.overrideWith((ref) => Stream.value(LicenceConfig(expiryDate: expiry))),
        ],
      );
      addTearDown(container.dispose);
      await container.read(licenceConfigProvider.future);
      expect(container.read(licenceStatusProvider).kind, LicenceStatusKind.ok);
    });

    test('exactly 10 days out => expiringSoon with daysLeft 10 (inclusive boundary)', () async {
      final now = DateTime.now();
      final expiry = DateTime(now.year, now.month, now.day).add(const Duration(days: licenceWarningWindowDays));
      final container = ProviderContainer(
        overrides: [
          licenceConfigProvider.overrideWith((ref) => Stream.value(LicenceConfig(expiryDate: expiry))),
        ],
      );
      addTearDown(container.dispose);
      await container.read(licenceConfigProvider.future);
      final status = container.read(licenceStatusProvider);
      expect(status.kind, LicenceStatusKind.expiringSoon);
      expect(status.daysLeft, licenceWarningWindowDays);
    });

    test('11 days out => ok (just outside the warning window)', () async {
      final now = DateTime.now();
      final expiry = DateTime(now.year, now.month, now.day).add(const Duration(days: licenceWarningWindowDays + 1));
      final container = ProviderContainer(
        overrides: [
          licenceConfigProvider.overrideWith((ref) => Stream.value(LicenceConfig(expiryDate: expiry))),
        ],
      );
      addTearDown(container.dispose);
      await container.read(licenceConfigProvider.future);
      expect(container.read(licenceStatusProvider).kind, LicenceStatusKind.ok);
    });

    test('expiry date is today => expiringSoon with daysLeft 0', () async {
      final now = DateTime.now();
      final expiry = DateTime(now.year, now.month, now.day);
      final container = ProviderContainer(
        overrides: [
          licenceConfigProvider.overrideWith((ref) => Stream.value(LicenceConfig(expiryDate: expiry))),
        ],
      );
      addTearDown(container.dispose);
      await container.read(licenceConfigProvider.future);
      final status = container.read(licenceStatusProvider);
      expect(status.kind, LicenceStatusKind.expiringSoon);
      expect(status.daysLeft, 0);
    });

    test('expiry date has passed => expired, not expiringSoon', () async {
      final now = DateTime.now();
      final expiry = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      final container = ProviderContainer(
        overrides: [
          licenceConfigProvider.overrideWith((ref) => Stream.value(LicenceConfig(expiryDate: expiry))),
        ],
      );
      addTearDown(container.dispose);
      await container.read(licenceConfigProvider.future);
      expect(container.read(licenceStatusProvider).kind, LicenceStatusKind.expired);
    });
  });
}
