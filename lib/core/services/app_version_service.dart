import 'package:package_info_plus/package_info_plus.dart';

/// Reads the running build's own version (from pubspec.yaml's `version:`
/// at build time — e.g. `1.0.0+1`) so it can be compared against the
/// admin-configured allowed range. See `VersionGateConfig`.
class AppVersionService {
  const AppVersionService();

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }
}
