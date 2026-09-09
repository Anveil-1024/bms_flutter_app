enum AppUpdateStatus {
  upToDate,
  optional,
  forced,
  unavailable,
}

class AppUpdateInfo {
  final String latestVersion;
  final String minSupportedVersion;
  final bool force;
  final String releaseNotesZh;
  final String releaseNotesEn;
  final String androidDownloadUrl;
  final String iosStoreUrl;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.force,
    this.releaseNotesZh = '',
    this.releaseNotesEn = '',
    this.androidDownloadUrl = '',
    this.iosStoreUrl = '',
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: '${json['latest_version'] ?? ''}'.trim(),
      minSupportedVersion: '${json['min_supported_version'] ?? ''}'.trim(),
      force: json['force'] == true,
      releaseNotesZh: '${json['release_notes_zh'] ?? ''}'.trim(),
      releaseNotesEn: '${json['release_notes_en'] ?? ''}'.trim(),
      androidDownloadUrl: '${json['android_download_url'] ?? ''}'.trim(),
      iosStoreUrl: '${json['ios_store_url'] ?? ''}'.trim(),
    );
  }

  String releaseNotes({required bool chinese}) {
    final text = chinese ? releaseNotesZh : releaseNotesEn;
    if (text.isNotEmpty) return text;
    return chinese ? releaseNotesEn : releaseNotesZh;
  }

  String? actionUrl({required bool isIOS}) {
    final url = isIOS ? iosStoreUrl : androidDownloadUrl;
    return url.isEmpty ? null : url;
  }
}

class AppUpdateCheckResult {
  final AppUpdateStatus status;
  final String localVersion;
  final AppUpdateInfo? info;

  const AppUpdateCheckResult({
    required this.status,
    required this.localVersion,
    this.info,
  });

  String? get latestVersion => info?.latestVersion;

  bool get hasUpdate =>
      status == AppUpdateStatus.optional || status == AppUpdateStatus.forced;
}

class AppUpdateException implements Exception {
  final String message;

  AppUpdateException(this.message);

  @override
  String toString() => message;
}
