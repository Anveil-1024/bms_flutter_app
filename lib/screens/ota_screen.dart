import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/history_record.dart';
import '../services/bms_ble_service.dart';

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
  Uint8List? _firmware;
  String? _fileName;
  double _progress = 0;
  bool _busy = false;
  String? _status;

  AppLocalizations get loc => widget.loc;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (!mounted) return;
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.single;
      final bytes = f.bytes;
      setState(() {
        _fileName = f.name;
        _firmware = bytes != null ? Uint8List.fromList(bytes) : null;
        _status = null;
        _progress = 0;
      });
    }
  }

  Future<void> _startOta() async {
    final fw = _firmware;
    if (fw == null || fw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.otaSelectFileFirst)),
      );
      return;
    }
    if (!widget.bleService.isConnected) return;

    setState(() {
      _busy = true;
      _progress = 0;
      _status = loc.otaInProgress;
    });

    try {
      await widget.bleService.runOta(
        fw,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        setState(() {
          _status = loc.otaSuccess;
          _progress = 1;
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

    return Scaffold(
      appBar: AppBar(title: Text(loc.otaTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _fileName ?? loc.otaPickFile,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: Text(loc.otaPickFile),
            ),
            const SizedBox(height: 24),
            if (_busy || _progress > 0)
              LinearProgressIndicator(value: _busy ? _progress : (_progress >= 1 ? 1 : null)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (_busy || !widget.bleService.isConnected) ? null : _startOta,
              icon: const Icon(Icons.upload),
              label: Text(loc.otaStart),
            ),
            if (_status != null) ...[
              const SizedBox(height: 24),
              Text(
                _status!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _status == loc.otaSuccess
                      ? Colors.green
                      : _busy
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
}
