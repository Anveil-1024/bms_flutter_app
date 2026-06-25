// 升级服务器版本清单与检查结果

class FirmwareManifest {
  final String baseUrl;
  final Map<String, ProductFirmwareInfo> batteryUpdate;

  const FirmwareManifest({
    required this.baseUrl,
    required this.batteryUpdate,
  });
}

class ProductFirmwareInfo {
  final String productId;
  final String name;
  final String? latestVersion;
  final String? latestDownloadUrl;
  final List<FirmwareFileEntry> files;

  const ProductFirmwareInfo({
    required this.productId,
    required this.name,
    this.latestVersion,
    this.latestDownloadUrl,
    this.files = const [],
  });

  FirmwareFileEntry? get latestFile {
    final v = latestVersion;
    if (v == null) return null;
    for (final f in files) {
      if (f.version == v) return f;
    }
    return files.isNotEmpty ? files.last : null;
  }
}

class FirmwareFileEntry {
  final String version;
  final String filename;
  final int size;
  final String sha256;
  final String downloadUrl;

  const FirmwareFileEntry({
    required this.version,
    required this.filename,
    required this.size,
    required this.sha256,
    required this.downloadUrl,
  });
}

enum FirmwareUpdateStatus {
  /// 本地版本低于服务器最新版
  updateAvailable,
  /// 已是最新
  upToDate,
  /// product_id 不在清单中
  unsupportedProduct,
  /// 产品线存在但 latest_version 为 null / 无文件
  noFirmwareOnServer,
}

class FirmwareCheckResult {
  final FirmwareUpdateStatus status;
  final String productId;
  final String localVersion;
  final String? latestVersion;
  final String? productDisplayName;
  final FirmwareFileEntry? targetFile;
  final String? downloadUrl;

  const FirmwareCheckResult({
    required this.status,
    required this.productId,
    required this.localVersion,
    this.latestVersion,
    this.productDisplayName,
    this.targetFile,
    this.downloadUrl,
  });

  bool get canUpgrade => status == FirmwareUpdateStatus.updateAvailable;
}

class FirmwareUpdateException implements Exception {
  final String message;

  FirmwareUpdateException(this.message);

  @override
  String toString() => message;
}
