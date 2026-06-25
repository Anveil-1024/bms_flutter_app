import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/firmware_update.dart';

class FirmwareUpdateService {
  static const String defaultBaseUrl = 'http://39.96.159.115';

  final String baseUrl;
  final http.Client _client;

  FirmwareUpdateService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? http.Client();

  Uri _manifestUri() => Uri.parse('$baseUrl/api/version.json');

  Future<FirmwareManifest> fetchManifest() async {
    final resp = await _client.get(
      _manifestUri(),
      headers: {'Cache-Control': 'no-cache'},
    );
    if (resp.statusCode != 200) {
      throw FirmwareUpdateException(
        '版本清单请求失败 (${resp.statusCode})',
      );
    }

    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final resolvedBase =
        (json['base_url'] as String?)?.trim().replaceAll(RegExp(r'/+$'), '') ??
            baseUrl;

    final batteryRaw = json['battery_update'];
    final batteryUpdate = <String, ProductFirmwareInfo>{};
    if (batteryRaw is Map<String, dynamic>) {
      for (final entry in batteryRaw.entries) {
        if (entry.value is Map<String, dynamic>) {
          batteryUpdate[entry.key] = _parseProductInfo(
            entry.key,
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    return FirmwareManifest(
      baseUrl: resolvedBase,
      batteryUpdate: batteryUpdate,
    );
  }

  ProductFirmwareInfo _parseProductInfo(
    String key,
    Map<String, dynamic> block,
  ) {
    final filesRaw = block['files'];
    final files = <FirmwareFileEntry>[];
    if (filesRaw is List) {
      for (final item in filesRaw) {
        if (item is Map<String, dynamic>) {
          files.add(FirmwareFileEntry(
            version: '${item['version'] ?? ''}',
            filename: '${item['filename'] ?? ''}',
            size: (item['size'] as num?)?.toInt() ?? 0,
            sha256: '${item['sha256'] ?? ''}'.toLowerCase(),
            downloadUrl: '${item['download_url'] ?? ''}',
          ));
        }
      }
    }

    return ProductFirmwareInfo(
      productId: '${block['product_id'] ?? key}',
      name: '${block['name'] ?? key}',
      latestVersion: block['latest_version']?.toString(),
      latestDownloadUrl: block['latest_download_url']?.toString(),
      files: files,
    );
  }

  /// 比较版本：纯数字按整数，否则按字符串
  static int compareVersion(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) {
      return na.compareTo(nb);
    }
    return a.compareTo(b);
  }

  FirmwareCheckResult checkUpdate(
    FirmwareManifest manifest,
    String productId,
    String localVersion,
  ) {
    final block = manifest.batteryUpdate[productId];
    if (block == null) {
      return FirmwareCheckResult(
        status: FirmwareUpdateStatus.unsupportedProduct,
        productId: productId,
        localVersion: localVersion,
      );
    }

    final latest = block.latestVersion;
    if (latest == null || latest.isEmpty) {
      return FirmwareCheckResult(
        status: FirmwareUpdateStatus.noFirmwareOnServer,
        productId: productId,
        localVersion: localVersion,
        productDisplayName: block.name,
      );
    }

    final target = block.latestFile;
    final downloadUrl = block.latestDownloadUrl ?? target?.downloadUrl;

    if (compareVersion(localVersion, latest) >= 0) {
      return FirmwareCheckResult(
        status: FirmwareUpdateStatus.upToDate,
        productId: productId,
        localVersion: localVersion,
        latestVersion: latest,
        productDisplayName: block.name,
        targetFile: target,
        downloadUrl: downloadUrl,
      );
    }

    return FirmwareCheckResult(
      status: FirmwareUpdateStatus.updateAvailable,
      productId: productId,
      localVersion: localVersion,
      latestVersion: latest,
      productDisplayName: block.name,
      targetFile: target,
      downloadUrl: downloadUrl,
    );
  }

  Future<Uint8List> downloadFirmware({
    required String downloadUrl,
    required int expectedSize,
    required String expectedSha256,
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.parse(downloadUrl);
    final request = http.Request('GET', uri);
    final streamed = await _client.send(request);
    if (streamed.statusCode != 200) {
      throw FirmwareUpdateException(
        '固件下载失败 (${streamed.statusCode})',
      );
    }

    final contentLength = streamed.contentLength;
    final bytes = <int>[];
    await for (final chunk in streamed.stream) {
      bytes.addAll(chunk);
      if (contentLength != null && contentLength > 0 && onProgress != null) {
        onProgress(bytes.length / contentLength);
      }
    }

    if (bytes.length != expectedSize) {
      throw FirmwareUpdateException(
        '固件大小校验失败（期望 $expectedSize 字节，实际 ${bytes.length} 字节）',
      );
    }

    final digest = sha256.convert(bytes).toString();
    final expected = expectedSha256.toLowerCase();
    if (digest != expected) {
      throw FirmwareUpdateException('固件 SHA-256 校验失败');
    }

    onProgress?.call(1.0);
    return Uint8List.fromList(bytes);
  }

  void dispose() {
    _client.close();
  }
}
