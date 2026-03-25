import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/bms_data.dart';

class BatteryDetailScreen extends StatelessWidget {
  final BmsData bmsData;
  final AppLocalizations loc;

  const BatteryDetailScreen({
    super.key,
    required this.bmsData,
    required this.loc,
  });

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '--:--:--';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle(loc.voltageSection, Icons.bolt, theme),
        const SizedBox(height: 12),
        _buildVoltageCards(theme),
        const SizedBox(height: 24),
        _buildSectionTitle(loc.timeSection, Icons.timer, theme),
        const SizedBox(height: 12),
        _buildTimeCards(theme),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildVoltageCards(ThemeData theme) {
    final items = [
      _DetailItem(loc.totalCellVoltage, '${bmsData.totalCellVoltage.toStringAsFixed(3)} V', Icons.battery_full),
      _DetailItem(loc.cellVoltageDiff, '${bmsData.cellVoltageDiff.toStringAsFixed(3)} V', Icons.compare_arrows),
      _DetailItem(loc.maxCellVoltage, '${bmsData.maxCellVoltage.toStringAsFixed(3)} V', Icons.arrow_upward),
      _DetailItem(loc.minCellVoltage, '${bmsData.minCellVoltage.toStringAsFixed(3)} V', Icons.arrow_downward),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _detailCard(items[0], theme)),
            const SizedBox(width: 10),
            Expanded(child: _detailCard(items[1], theme)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _detailCard(items[2], theme)),
            const SizedBox(width: 10),
            Expanded(child: _detailCard(items[3], theme)),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeCards(ThemeData theme) {
    final items = [
      _DetailItem(loc.currentChargeInterval, _formatDuration(bmsData.currentChargeInterval), Icons.hourglass_top),
      _DetailItem(loc.maxChargeInterval, _formatDuration(bmsData.maxChargeInterval), Icons.hourglass_full),
      _DetailItem(loc.chargeRemaining, _formatDuration(bmsData.chargeRemainingTime), Icons.battery_charging_full),
      _DetailItem(loc.dischargeRemaining, _formatDuration(bmsData.dischargeRemainingTime), Icons.battery_alert),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _detailCard(items[0], theme)),
            const SizedBox(width: 10),
            Expanded(child: _detailCard(items[1], theme)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _detailCard(items[2], theme)),
            const SizedBox(width: 10),
            Expanded(child: _detailCard(items[3], theme)),
          ],
        ),
      ],
    );
  }

  Widget _detailCard(_DetailItem item, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 16, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem {
  final String label;
  final String value;
  final IconData icon;
  const _DetailItem(this.label, this.value, this.icon);
}
