class MobileVersionInfo {
  const MobileVersionInfo({
    required this.version,
    required this.apkUrl,
    required this.forceUpdate,
    this.updateDescription,
  });

  final String version;
  final String apkUrl;
  final bool forceUpdate;
  final String? updateDescription;

  factory MobileVersionInfo.fromJson(Map<String, dynamic> json) {
    return MobileVersionInfo(
      version: json['version'] as String,
      apkUrl: json['apk_url'] as String,
      forceUpdate: json['force_update'] as bool? ?? false,
      updateDescription: json['update_description'] as String?,
    );
  }
}

class AppVersion {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  final int major;
  final int minor;
  final int patch;

  factory AppVersion.parse(String version) {
    final parts = version.split('.');
    if (parts.length < 3) {
      throw FormatException('Invalid version format: $version');
    }
    return AppVersion(
      major: int.parse(parts[0]),
      minor: int.parse(parts[1]),
      patch: int.parse(parts[2]),
    );
  }

  bool isOlderThan(AppVersion other) {
    if (major != other.major) return major < other.major;
    if (minor != other.minor) return minor < other.minor;
    return patch < other.patch;
  }

  @override
  String toString() => '$major.$minor.$patch';
}
