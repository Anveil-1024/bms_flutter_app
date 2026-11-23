enum AppUpdateStatus {
  upToDate,
  optional,
  forced,
  unavailable,
}

class AppUpdateInfo {
  static const String pgyerPlistBase = 'https://www.pgyer.com/app/plist/';

  final String latestVersion;
  final String minSupportedVersion;
  final bool force;
  final String releaseNotesZh;
  final String releaseNotesEn;
  final String androidDownloadUrl;
  final String iosStoreUrl;
  final String iosBuildKey;
  final String installPassword;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.force,
    this.releaseNotesZh = '',
    this.releaseNotesEn = '',
    this.androidDownloadUrl = '',
    this.iosStoreUrl = '',
    this.iosBuildKey = '',
    this.installPassword = '',
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
      iosBuildKey: '${json['ios_build_key'] ?? ''}'.trim(),
      installPassword: '${json['install_password'] ?? ''}'.trim(),
    );
  }

  String releaseNotes({required bool chinese}) {
    final text = chinese ? releaseNotesZh : releaseNotesEn;
    if (text.isNotEmpty) return text;
    return chinese ? releaseNotesEn : releaseNotesZh;
  }

  String? actionUrl({required bool isIOS}) {
    if (isIOS) {
      final installUrl = _iosInstallUrl();
      if (installUrl != null) return installUrl;
      return iosStoreUrl.isEmpty ? null : iosStoreUrl;
    }
    return androidDownloadUrl.isEmpty ? null : androidDownloadUrl;
  }

  /// 蒲公英应用内安装链接；未配置 [iosBuildKey] 时返回 null。
  String? _iosInstallUrl() {
    if (iosBuildKey.isEmpty) return null;
    final plistUrl = '$pgyerPlistBase$iosBuildKey'
        '${installPassword.isEmpty ? '' : '?password=${Uri.encodeQueryComponent(installPassword)}'}';
    return 'itms-services://?action=download-manifest'
        '&url=${Uri.encodeQueryComponent(plistUrl)}';
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
