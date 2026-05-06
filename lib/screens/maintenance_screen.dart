import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/bms_ble_service.dart';
import 'history_screen.dart';
import 'ota_screen.dart';

class MaintenanceScreen extends StatefulWidget {
  final BmsBleService bleService;
  final AppLocalizations loc;

  const MaintenanceScreen({
    super.key,
    required this.bleService,
    required this.loc,
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  int? _soh;
  bool _sohLoading = false;

  AppLocalizations get loc => widget.loc;

  Future<void> _readSoh() async {
    if (!widget.bleService.isConnected) return;
    setState(() => _sohLoading = true);
    try {
      final v = await widget.bleService.readSoh();
      if (mounted) setState(() => _soh = v);
    } catch (_) {
      if (mounted) setState(() => _soh = null);
    } finally {
      if (mounted) setState(() => _sohLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = widget.bleService.isConnected;

    if (!connected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            loc.maintenanceNeedConnect,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      loc.sohLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_sohLoading)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        _soh != null ? '$_soh%' : loc.sohUnknown,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _sohLoading ? null : _readSoh,
                  icon: const Icon(Icons.refresh),
                  label: Text(loc.sohRefresh),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.history, color: theme.colorScheme.primary),
                title: Text(loc.historyTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (ctx) => HistoryScreen(
                        bleService: widget.bleService,
                        loc: loc,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.system_update_alt, color: theme.colorScheme.primary),
                title: Text(loc.otaTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (ctx) => OtaScreen(
                        bleService: widget.bleService,
                        loc: loc,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
