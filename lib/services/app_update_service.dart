import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update.dart';
import 'platform_http_client.dart';

class AppUpdateService {
  static const String defaultBaseUrl = 'https://grb.asia';
  static const String skippedVersionKey = 'skipped_app_version';

  final String baseUrl;
  final http.Client _client;
  final bool _ownsClient;

  AppUpdateService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? createPlatformHttpClient(),
        _ownsClient = client == null;

  Uri _manifestUri() => Uri.parse('$baseUrl/api/app-version.json');

  Future<AppUpdateInfo> fetchInfo() async {
    try {
      final resp = await _client
          .get(
            _manifestUri(),
            headers: {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) {
        throw AppUpdateException('版本清单请求失败 (${resp.statusCode})');
      }

      final json =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      return AppUpdateInfo.fromJson(json);
    } on AppUpdateException {
      rethrow;
    } on SocketException catch (e) {
      throw AppUpdateException(_networkErrorHint(e.message));
    } on HttpException catch (e) {
      throw AppUpdateException(_networkErrorHint(e.message));
    } on Exception catch (e) {
      throw AppUpdateException(_networkErrorHint('$e'));
    }
  }

  String _networkErrorHint(String detail) {
    if (detail.contains('65') ||
        detail.toLowerCase().contains('no route to host')) {
      return '无法连接升级服务器（$detail）。请确认已开启 WiFi 或蜂窝数据，'
          '并关闭 VPN 后重试。';
    }
    return '网络请求失败：$detail';
  }

  /// 比较版本：按 `.` 分段数字比较（`1.0.10 > 1.0.2`）。
  static int compareSemver(String a, String b) {
    final pa = _semverParts(a);
    final pb = _semverParts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  static List<int> _semverParts(String version) {
    final core = version.split('+').first.split('-').first.trim();
    if (core.isEmpty) return const [0];
    return core.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }

  AppUpdateCheckResult check(AppUpdateInfo info, String localVersion) {
    if (info.latestVersion.isEmpty) {
      return AppUpdateCheckResult(
        status: AppUpdateStatus.unavailable,
        localVersion: localVersion,
        info: info,
      );
    }

    final vsLatest = compareSemver(localVersion, info.latestVersion);
    if (vsLatest >= 0) {
      return AppUpdateCheckResult(
        status: AppUpdateStatus.upToDate,
        localVersion: localVersion,
        info: info,
      );
    }

    final belowMin = info.minSupportedVersion.isNotEmpty &&
        compareSemver(localVersion, info.minSupportedVersion) < 0;
    if (belowMin || info.force) {
      return AppUpdateCheckResult(
        status: AppUpdateStatus.forced,
        localVersion: localVersion,
        info: info,
      );
    }

    return AppUpdateCheckResult(
      status: AppUpdateStatus.optional,
      localVersion: localVersion,
      info: info,
    );
  }

  bool shouldPrompt(
    AppUpdateCheckResult result, {
    String? skippedVersion,
    bool ignoreSkip = false,
  }) {
    if (result.status == AppUpdateStatus.forced) return true;
    if (result.status != AppUpdateStatus.optional) return false;
    if (ignoreSkip) return true;
    final latest = result.latestVersion;
    if (latest == null || latest.isEmpty) return true;
    return skippedVersion != latest;
  }

  Future<String?> loadSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(skippedVersionKey);
  }

  Future<void> saveSkippedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(skippedVersionKey, version);
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
