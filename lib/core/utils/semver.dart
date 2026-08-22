/// Minimal semantic-version comparator for `major.minor.patch` strings
/// (build metadata after a `+`, e.g. pubspec's `1.0.0+1`, is ignored —
/// standard semver precedence rules). Missing/non-numeric segments are
/// treated as `0`, so `"1.2"` compares as `"1.2.0"`.
int compareVersions(String a, String b) {
  final partsA = _parse(a);
  final partsB = _parse(b);
  for (var i = 0; i < 3; i++) {
    final cmp = partsA[i].compareTo(partsB[i]);
    if (cmp != 0) return cmp;
  }
  return 0;
}

List<int> _parse(String version) {
  final withoutBuild = version.split('+').first;
  final segments = withoutBuild.split('.');
  return List.generate(3, (i) => i < segments.length ? (int.tryParse(segments[i]) ?? 0) : 0);
}

extension VersionComparison on String {
  bool isVersionAtLeast(String other) => compareVersions(this, other) >= 0;
  bool isVersionAtMost(String other) => compareVersions(this, other) <= 0;
}
