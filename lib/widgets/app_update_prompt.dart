import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/app_update.dart';
import '../services/app_update_service.dart';

class AppUpdatePrompt {
  AppUpdatePrompt._();

  static Future<void> checkAndPrompt({
    required BuildContext context,
    required AppLocalizations loc,
    bool manual = false,
  }) async {
    final service = AppUpdateService();
    try {
      final package = await PackageInfo.fromPlatform();
      final info = await service.fetchInfo();
      if (!context.mounted) return;

      final result = service.check(info, package.version);
      if (result.status == AppUpdateStatus.upToDate) {
        if (manual) _snack(context, loc.appUpdateUpToDate);
        return;
      }
      if (result.status == AppUpdateStatus.unavailable) {
        if (manual) _snack(context, loc.appUpdateUnavailable);
        return;
      }

      final skipped = manual ? null : await service.loadSkippedVersion();
      if (!context.mounted) return;
      if (!service.shouldPrompt(
        result,
        skippedVersion: skipped,
        ignoreSkip: manual,
      )) {
        return;
      }

      await show(
        context: context,
        loc: loc,
        service: service,
        result: result,
      );
    } catch (e) {
      if (manual && context.mounted) {
        final message = e is AppUpdateException ? e.message : '$e';
        _snack(context, loc.appUpdateCheckFailed(message));
      }
    } finally {
      service.dispose();
    }
  }

  static Future<void> show({
    required BuildContext context,
    required AppLocalizations loc,
    required AppUpdateService service,
    required AppUpdateCheckResult result,
  }) {
    final info = result.info;
    if (info == null) return Future.value();

    final forced = result.status == AppUpdateStatus.forced;
    final notes = info.releaseNotes(chinese: loc.language == AppLanguage.zh);
    final latest = info.latestVersion;

    return showDialog<void>(
      context: context,
      barrierDismissible: !forced,
      builder: (dialogContext) {
        return PopScope(
          canPop: !forced,
          child: AlertDialog(
            title: Text(
              forced ? loc.appUpdateRequiredTitle : loc.appUpdateAvailableTitle,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${loc.otaCurrentVersion}: ${result.localVersion}'),
                Text('${loc.otaLatestVersion}: $latest'),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(notes),
                ],
              ],
            ),
            actions: [
              if (!forced)
                TextButton(
                  onPressed: () async {
                    await service.saveSkippedVersion(latest);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(loc.appUpdateLater),
                ),
              FilledButton(
                onPressed: () async {
                  final opened = await _openUpdateUrl(info);
                  if (!opened) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(loc.appUpdateOpenFailed)),
                      );
                    }
                    return;
                  }
                  if (!forced && dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: Text(loc.appUpdateNow),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<bool> _openUpdateUrl(AppUpdateInfo info) async {
    final url = info.actionUrl(
      isIOS: defaultTargetPlatform == TargetPlatform.iOS,
    );
    if (url == null) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
