import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/bms_data.dart';
import '../models/firmware_update.dart';
import '../models/history_record.dart';
import '../services/bms_ble_service.dart';
import '../services/firmware_update_service.dart';

class OtaScreen extends StatefulWidget {
  final BmsBleService bleService;
  final AppLocalizations loc;

  const OtaScreen({
    super.key,
    required this.bleService,
    required this.loc,
  });

  @override
  State<OtaScreen> createState() => _OtaScreenState();
}

class _OtaScreenState extends State<OtaScreen> {
  final _firmwareService = FirmwareUpdateService();

  BmsData? _deviceInfo;
  FirmwareCheckResult? _checkResult;
  bool _checking = false;
  bool _busy = false;
  double _progress = 0;
  String? _status;
  String? _phase;

  AppLocalizations get loc => widget.loc;

  @override
  void dispose() {
    _firmwareService.dispose();
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    if (!widget.bleService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.otaNeedConnect)),
      );
      return;
    }

    setState(() {
      _checking = true;
      _checkResult = null;
      _status = null;
      _progress = 0;
      _phase = null;
    });

    try {
      final info = await widget.bleService.queryBatteryInfo();
      if (!mounted) return;

      if (info == null || !info.hasOtaIdentity) {
        setState(() {
          _deviceInfo = info;
          _status = loc.otaNoProductLine;
        });
        return;
      }

      final manifest = await _firmwareService.fetchManifest();
      final result = _firmwareService.checkUpdate(
        manifest,
        info.productLineId,
        info.firmwareVersion,
      );

      if (!mounted) return;
      setState(() {
        _deviceInfo = info;
        _checkResult = result;
        _status = _statusTextFor(result);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = loc.otaErrorMsg(
            e is FirmwareUpdateException ? e.message : '$e',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String? _statusTextFor(FirmwareCheckResult result) {
    switch (result.status) {
      case FirmwareUpdateStatus.upToDate:
        return loc.otaUpToDate;
      case FirmwareUpdateStatus.updateAvailable:
        return loc.otaUpdateAvailable;
      case FirmwareUpdateStatus.unsupportedProduct:
        return loc.otaUnsupportedProduct;
      case FirmwareUpdateStatus.noFirmwareOnServer:
        return loc.otaNoFirmwareOnServer;
    }
  }

  Future<void> _downloadAndUpgrade() async {
    final check = _checkResult;
    final file = check?.targetFile;
    final url = check?.downloadUrl ?? file?.downloadUrl;

    if (check == null ||
        !check.canUpgrade ||
        file == null ||
        url == null ||
        url.isEmpty) {
      return;
    }
    if (!widget.bleService.isConnected) return;

    setState(() {
      _busy = true;
      _progress = 0;
      _phase = loc.otaDownloading;
      _status = loc.otaDownloading;
    });

    Uint8List? firmware;
    try {
      firmware = await _firmwareService.downloadFirmware(
        downloadUrl: url,
        expectedSize: file.size,
        expectedSha256: file.sha256,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _progress = p * 0.1;
              _phase = loc.otaDownloading;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = loc.otaErrorMsg(
            e is FirmwareUpdateException ? e.message : '$e',
          );
          _busy = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _phase = loc.otaInProgress;
      _status = loc.otaInProgress;
    });

    try {
      await widget.bleService.runOta(
        firmware,
        onProgress: (p) {
          if (mounted) {
            setState(() => _progress = 0.1 + p * 0.9);
          }
        },
      );
      if (mounted) {
        setState(() {
          _status = loc.otaSuccess;
          _progress = 1;
          _phase = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = loc.otaErrorMsg(e is OtaException ? e.message : '$e');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickLocalFileAndUpgrade() async {
    if (!widget.bleService.isConnected || _busy || _checking) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['bin', 'hex'],
    );
    if (result == null || result.files.isEmpty) return;

    final firmware = result.files.first.bytes;
    if (firmware == null || firmware.isEmpty) {
      if (mounted) {
        setState(() => _status = loc.otaPickFirmwareFailed);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _phase = loc.otaInProgress;
      _status = loc.otaInProgress;
    });

    try {
      await widget.bleService.runOta(
        firmware,
        onProgress: (p) {
          if (mounted) {
            setState(() => _progress = p);
          }
        },
      );
      if (mounted) {
        setState(() {
          _status = loc.otaSuccess;
          _progress = 1;
          _phase = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = loc.otaErrorMsg(e is OtaException ? e.message : '$e');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = widget.bleService.isConnected;
    final check = _checkResult;
    final canUpgrade = check?.canUpgrade == true && !_busy && !_checking;
    final showProgressBlock = _busy || _progress > 0;
    final showStatusText =
        _status != null && !(_busy && _phase != null && _status == _phase);

    return Scaffold(
      appBar: AppBar(title: Text(loc.otaTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_deviceInfo != null) ...[
              _infoCard(theme, _deviceInfo!),
              const SizedBox(height: 16),
            ],
            if (check != null) ...[
              _checkCard(theme, check),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              onPressed: (_busy || _checking || !connected) ? null : _checkUpdate,
              icon: _checking
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.cloud_download_outlined),
              label: Text(_checking ? loc.otaChecking : loc.otaCheckUpdate),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canUpgrade ? _downloadAndUpgrade : null,
              icon: const Icon(Icons.system_update_alt),
              label: Text(loc.otaDownloadAndUpgrade),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_busy || _checking || !connected)
                  ? null
                  : _pickLocalFileAndUpgrade,
              icon: const Icon(Icons.upload_file),
              label: Text(loc.otaLocalUpgrade),
            ),
            const Spacer(),
            if (showProgressBlock) ...[
              LinearProgressIndicator(
                value: _busy ? _progress.clamp(0.0, 1.0) : (_progress >= 1 ? 1 : null),
              ),
              if (_phase != null) ...[
                const SizedBox(height: 8),
                Text(
                  _phase!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
            if (showStatusText) ...[
              const SizedBox(height: 24),
              Text(
                _status!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _status == loc.otaSuccess
                      ? Colors.green
                      : (_status == loc.otaUpToDate ||
                              _status == loc.otaUpdateAvailable)
                          ? theme.colorScheme.onSurface
                          : (_busy || _checking)
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoCard(ThemeData theme, BmsData info) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.productLineId, style: theme.textTheme.labelMedium),
            Text(info.productLineId, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(loc.otaCurrentVersion, style: theme.textTheme.labelMedium),
            Text(info.firmwareVersion, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _checkCard(ThemeData theme, FirmwareCheckResult check) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (check.productDisplayName != null) ...[
              Text(loc.otaProductName, style: theme.textTheme.labelMedium),
              Text(check.productDisplayName!, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
            ],
            Text(loc.otaCurrentVersion, style: theme.textTheme.labelMedium),
            Text(check.localVersion, style: theme.textTheme.bodyLarge),
            if (check.latestVersion != null) ...[
              const SizedBox(height: 8),
              Text(loc.otaLatestVersion, style: theme.textTheme.labelMedium),
              Text(check.latestVersion!, style: theme.textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}
