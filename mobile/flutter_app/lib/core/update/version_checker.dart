import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'models.dart';
import 'update_repository.dart';

final versionCheckerProvider = FutureProvider<VersionCheckResult>((ref) async {
  final repository = ref.watch(updateRepositoryProvider);
  return VersionChecker.check(repository);
});

class VersionCheckResult {
  const VersionCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    this.latestVersion,
  });

  final bool hasUpdate;
  final String currentVersion;
  final MobileVersionInfo? latestVersion;
}

class VersionChecker {
  static Future<VersionCheckResult> check(UpdateRepository repository) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionStr = packageInfo.version;

      final latestInfo = await repository.getLatestVersion();

      final currentVersion = AppVersion.parse(currentVersionStr);
      final latestVersion = AppVersion.parse(latestInfo.version);

      final hasUpdate = currentVersion.isOlderThan(latestVersion);

      return VersionCheckResult(
        hasUpdate: hasUpdate,
        currentVersion: currentVersionStr,
        latestVersion: hasUpdate ? latestInfo : null,
      );
    } catch (e) {
      return const VersionCheckResult(
        hasUpdate: false,
        currentVersion: 'unknown',
      );
    }
  }
}
