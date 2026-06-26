import 'package:http/http.dart' as http;

import 'platform_http_client_stub.dart'
    if (dart.library.io) 'platform_http_client_io.dart' as impl;

http.Client createPlatformHttpClient() => impl.createPlatformHttpClient();
