import 'package:bms_flutter_app/models/app_update.dart';
import 'package:bms_flutter_app/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppUpdateService service;

  setUp(() {
    service = AppUpdateService();
  });

  tearDown(() => service.dispose());

  group('compareSemver', () {
    test('numeric dotted versions', () {
      expect(AppUpdateService.compareSemver('1.0.10', '1.0.2'), greaterThan(0));
      expect(AppUpdateService.compareSemver('1.0.2', '1.0.10'), lessThan(0));
      expect(AppUpdateService.compareSemver('1.0.3', '1.0.3'), 0);
      expect(AppUpdateService.compareSemver('1.0', '1.0.0'), 0);
      expect(AppUpdateService.compareSemver('1.0.3+1', '1.0.3'), 0);
    });
  });

  group('check', () {
    test('forced when below min supported', () {
      final result = service.check(
        const AppUpdateInfo(
          latestVersion: '1.0.5',
          minSupportedVersion: '1.0.3',
          force: false,
        ),
        '1.0.2',
      );
      expect(result.status, AppUpdateStatus.forced);
    });

    test('optional when below latest and not forced', () {
      final result = service.check(
        const AppUpdateInfo(
          latestVersion: '1.0.5',
          minSupportedVersion: '1.0.2',
          force: false,
        ),
        '1.0.3',
      );
      expect(result.status, AppUpdateStatus.optional);
    });

    test('forced when force flag is true', () {
      final result = service.check(
        const AppUpdateInfo(
          latestVersion: '1.0.5',
          minSupportedVersion: '1.0.2',
          force: true,
        ),
        '1.0.3',
      );
      expect(result.status, AppUpdateStatus.forced);
    });

    test('up to date', () {
      final result = service.check(
        const AppUpdateInfo(
          latestVersion: '1.0.3',
          minSupportedVersion: '1.0.2',
          force: false,
        ),
        '1.0.3',
      );
      expect(result.status, AppUpdateStatus.upToDate);
    });
  });

  group('shouldPrompt', () {
    test('skips optional for the same latest version', () {
      const result = AppUpdateCheckResult(
        status: AppUpdateStatus.optional,
        localVersion: '1.0.2',
        info: AppUpdateInfo(
          latestVersion: '1.0.3',
          minSupportedVersion: '1.0.2',
          force: false,
        ),
      );
      expect(service.shouldPrompt(result, skippedVersion: '1.0.3'), isFalse);
      expect(
        service.shouldPrompt(result, skippedVersion: '1.0.3', ignoreSkip: true),
        isTrue,
      );
      expect(service.shouldPrompt(result), isTrue);
    });

    test('forced always prompts', () {
      const result = AppUpdateCheckResult(
        status: AppUpdateStatus.forced,
        localVersion: '1.0.1',
        info: AppUpdateInfo(
          latestVersion: '1.0.3',
          minSupportedVersion: '1.0.2',
          force: false,
        ),
      );
      expect(service.shouldPrompt(result, skippedVersion: '1.0.3'), isTrue);
    });
  });
}
