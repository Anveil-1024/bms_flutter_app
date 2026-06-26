import 'dart:io' show HttpClient, Platform;

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// iOS 上 Dart 原生 Socket 访问 IPv4 服务器可能失败（errno 65），
/// 改用 URLSession（CupertinoClient）与 Safari 行为一致。
http.Client createPlatformHttpClient() {
  if (Platform.isIOS || Platform.isMacOS) {
    return CupertinoClient.defaultSessionConfiguration();
  }
  final io = HttpClient();
  io.connectionTimeout = const Duration(seconds: 20);
  return IOClient(io);
}
