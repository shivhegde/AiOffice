import 'package:aioffice/core/utils/semver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('equal versions compare to 0', () {
      expect(compareVersions('1.2.3', '1.2.3'), 0);
    });

    test('major/minor/patch ordering, not lexicographic', () {
      expect(compareVersions('1.9.0', '1.10.0'), lessThan(0));
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
      expect(compareVersions('1.2.3', '1.2.4'), lessThan(0));
    });

    test('build metadata after + is ignored', () {
      expect(compareVersions('1.0.0+5', '1.0.0+1'), 0);
    });

    test('missing segments default to 0', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1', '1.0.0'), 0);
    });
  });

  group('VersionComparison extension', () {
    test('isVersionAtLeast', () {
      expect('1.5.0'.isVersionAtLeast('1.0.0'), isTrue);
      expect('1.0.0'.isVersionAtLeast('1.5.0'), isFalse);
      expect('1.0.0'.isVersionAtLeast('1.0.0'), isTrue);
    });

    test('isVersionAtMost', () {
      expect('1.0.0'.isVersionAtMost('1.5.0'), isTrue);
      expect('1.5.0'.isVersionAtMost('1.0.0'), isFalse);
    });
  });
}
