import 'package:aioffice/features/version_gate/application/version_gate_providers.dart';
import 'package:aioffice/features/version_gate/domain/version_gate_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('versionGateResultProvider', () {
    test('no bounds configured => allowed', () async {
      final container = ProviderContainer(
        overrides: [
          currentAppVersionProvider.overrideWith((ref) => Future.value('1.0.0')),
          versionGateConfigProvider.overrideWith((ref) => Stream.value(VersionGateConfig.unset)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentAppVersionProvider.future);
      await container.read(versionGateConfigProvider.future);
      expect(container.read(versionGateResultProvider).status, VersionGateStatus.allowed);
    });

    test('version below minVersion => belowMin', () async {
      final container = ProviderContainer(
        overrides: [
          currentAppVersionProvider.overrideWith((ref) => Future.value('0.9.0')),
          versionGateConfigProvider.overrideWith(
            (ref) => Stream.value(const VersionGateConfig(minVersion: '1.0.0', maxVersion: '', blockMessage: '')),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentAppVersionProvider.future);
      await container.read(versionGateConfigProvider.future);
      expect(container.read(versionGateResultProvider).status, VersionGateStatus.belowMin);
    });

    test('version above maxVersion => aboveMax', () async {
      final container = ProviderContainer(
        overrides: [
          currentAppVersionProvider.overrideWith((ref) => Future.value('2.0.0')),
          versionGateConfigProvider.overrideWith(
            (ref) => Stream.value(const VersionGateConfig(minVersion: '', maxVersion: '1.5.0', blockMessage: '')),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentAppVersionProvider.future);
      await container.read(versionGateConfigProvider.future);
      expect(container.read(versionGateResultProvider).status, VersionGateStatus.aboveMax);
    });

    test('version within range => allowed', () async {
      final container = ProviderContainer(
        overrides: [
          currentAppVersionProvider.overrideWith((ref) => Future.value('1.2.0')),
          versionGateConfigProvider.overrideWith(
            (ref) => Stream.value(const VersionGateConfig(minVersion: '1.0.0', maxVersion: '1.5.0', blockMessage: '')),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentAppVersionProvider.future);
      await container.read(versionGateConfigProvider.future);
      expect(container.read(versionGateResultProvider).status, VersionGateStatus.allowed);
    });

    test('exact boundary versions are allowed (inclusive range)', () async {
      final container = ProviderContainer(
        overrides: [
          currentAppVersionProvider.overrideWith((ref) => Future.value('1.0.0')),
          versionGateConfigProvider.overrideWith(
            (ref) => Stream.value(const VersionGateConfig(minVersion: '1.0.0', maxVersion: '1.0.0', blockMessage: '')),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentAppVersionProvider.future);
      await container.read(versionGateConfigProvider.future);
      expect(container.read(versionGateResultProvider).status, VersionGateStatus.allowed);
    });
  });
}
