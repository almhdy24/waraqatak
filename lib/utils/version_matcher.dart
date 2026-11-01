/// Framework-independent SemVer matcher matching docs/version_targeting.md.
class ParsedVersion {
  final int major;
  final int minor;
  final int patch;
  final int? build;

  const ParsedVersion({
    required this.major,
    this.minor = 0,
    this.patch = 0,
    this.build,
  });

  static ParsedVersion? tryParse(String? raw, {int? appBuild}) {
    if (raw == null) return null;
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    int? build = (appBuild != null && appBuild >= 0) ? appBuild : null;

    // Split build metadata (+16)
    final plusPos = trimmed.indexOf('+');
    if (plusPos != -1) {
      final buildStr = trimmed.substring(plusPos + 1);
      if (build == null && int.tryParse(buildStr) != null) {
        build = int.parse(buildStr);
      }
      trimmed = trimmed.substring(0, plusPos);
    }

    // Split pre-release metadata (-alpha)
    final dashPos = trimmed.indexOf('-');
    if (dashPos != -1) {
      trimmed = trimmed.substring(0, dashPos);
    }

    final parts = trimmed.split('.');
    if (parts.isEmpty || int.tryParse(parts[0]) == null) {
      return null;
    }

    final major = int.parse(parts[0]);
    final minor = (parts.length > 1 && int.tryParse(parts[1]) != null)
        ? int.parse(parts[1])
        : 0;
    final patch = (parts.length > 2 && int.tryParse(parts[2]) != null)
        ? int.parse(parts[2])
        : 0;

    return ParsedVersion(
      major: major,
      minor: minor,
      patch: patch,
      build: build,
    );
  }

  int compareTo(ParsedVersion other, {bool compareBuild = false}) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    if (compareBuild && other.build != null) {
      final effectiveBuild = build ?? 0;
      return effectiveBuild.compareTo(other.build!);
    }

    return 0;
  }
}

class VersionMatcher {
  VersionMatcher._();

  /// Evaluates whether an app version/build falls within inclusive bounds [minVersion, maxVersion].
  static bool matches({
    String? appVersion,
    int? appBuild,
    String? minVersion,
    String? maxVersion,
  }) {
    final cleanMin = (minVersion != null && minVersion.trim().isNotEmpty)
        ? minVersion.trim()
        : null;
    final cleanMax = (maxVersion != null && maxVersion.trim().isNotEmpty)
        ? maxVersion.trim()
        : null;

    if (cleanMin == null && cleanMax == null) {
      return true;
    }

    final parsedApp = ParsedVersion.tryParse(appVersion, appBuild: appBuild);
    if (parsedApp == null) {
      return false;
    }

    if (cleanMin != null) {
      final parsedMin = ParsedVersion.tryParse(cleanMin);
      if (parsedMin != null) {
        final compareBuild = (parsedMin.build != null);
        if (parsedApp.compareTo(parsedMin, compareBuild: compareBuild) < 0) {
          return false;
        }
      }
    }

    if (cleanMax != null) {
      final parsedMax = ParsedVersion.tryParse(cleanMax);
      if (parsedMax != null) {
        final compareBuild = (parsedMax.build != null);
        if (parsedApp.compareTo(parsedMax, compareBuild: compareBuild) > 0) {
          return false;
        }
      }
    }

    return true;
  }

  /// Validates that min bound is not strictly greater than max bound.
  static bool isRangeValid({String? minVersion, String? maxVersion}) {
    final cleanMin = (minVersion != null && minVersion.trim().isNotEmpty)
        ? minVersion.trim()
        : null;
    final cleanMax = (maxVersion != null && maxVersion.trim().isNotEmpty)
        ? maxVersion.trim()
        : null;

    if (cleanMin == null || cleanMax == null) {
      return true;
    }

    final parsedMin = ParsedVersion.tryParse(cleanMin);
    final parsedMax = ParsedVersion.tryParse(cleanMax);

    if (parsedMin == null || parsedMax == null) {
      return false;
    }

    final compareBuild = (parsedMin.build != null || parsedMax.build != null);
    return parsedMin.compareTo(parsedMax, compareBuild: compareBuild) <= 0;
  }
}
