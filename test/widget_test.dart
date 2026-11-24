import 'package:flutter_test/flutter_test.dart';

import 'package:bms_flutter_app/l10n/app_localizations.dart';

void main() {
  test('ICP filing number is displayed in the about page', () {
    final loc = AppLocalizations();
    expect(loc.icpInfo, 'ICP 备案号：沪ICP备2026033910号-2A');
  });
}
