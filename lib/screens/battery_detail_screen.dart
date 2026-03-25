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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle(loc.protectionSection, Icons.shield_outlined, theme),
        const SizedBox(height: 12),
        _buildProtectionCards(theme),
        const SizedBox(height: 24),
        _buildSectionTitle(loc.faultSection, Icons.warning_amber_rounded, theme),
        const SizedBox(height: 12),
        _buildFaultCard(theme),
        const SizedBox(height: 24),
        _buildSectionTitle(loc.versionSection, Icons.memory, theme),
        const SizedBox(height: 12),
        _buildVersionCard(theme),
        const SizedBox(height: 16),
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

  Widget _buildProtectionCards(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _paramCard(loc.dischargeOcp, '${bmsData.dischargeOcpA.toStringAsFixed(1)} A', Icons.flash_on, Colors.orange, theme)),
            const SizedBox(width: 10),
            Expanded(child: _paramCard(loc.chargeOcp, '${bmsData.chargeOcpA.toStringAsFixed(1)} A', Icons.flash_on, Colors.blue, theme)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _paramCard(loc.cellOvp, '${bmsData.cellOvp} mV', Icons.arrow_upward, Colors.red, theme)),
            const SizedBox(width: 10),
            Expanded(child: _paramCard(loc.cellUvp, '${bmsData.cellUvp} mV', Icons.arrow_downward, Colors.purple, theme)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _paramCard(loc.chargeOtp, '${bmsData.chargeOtpC.toStringAsFixed(1)} °C', Icons.thermostat, Colors.deepOrange, theme)),
            const SizedBox(width: 10),
            Expanded(child: _paramCard(loc.dischargeOtp, '${bmsData.dischargeOtpC.toStringAsFixed(1)} °C', Icons.thermostat, Colors.red, theme)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _paramCard(loc.maxChargeCurrent, '${bmsData.maxChargeCurrentA.toStringAsFixed(1)} A', Icons.bolt, Colors.green, theme)),
            const SizedBox(width: 10),
            Expanded(child: _paramCard(loc.maxDischargeCurrent, '${bmsData.maxDischargeCurrentA.toStringAsFixed(1)} A', Icons.bolt, Colors.amber, theme)),
          ],
        ),
      ],
    );
  }

  Widget _paramCard(String label, String value, IconData icon, Color accent, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
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
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaultCard(ThemeData theme) {
    final faults = bmsData.activeFaults;
    if (faults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 10),
            Text(
              loc.noFault,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: faults.map((key) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.faultName(key),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVersionCard(ThemeData theme) {
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
        children: [
          _versionRow(loc.hardwareVersion, bmsData.hardwareVersionStr, theme),
          const Divider(height: 24),
          _versionRow(loc.softwareVersion, bmsData.softwareVersionStr, theme),
          if (bmsData.deviceSerial.isNotEmpty) ...[
            const Divider(height: 24),
            _versionRow(loc.deviceSerial, bmsData.deviceSerial, theme),
          ],
        ],
      ),
    );
  }

  Widget _versionRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
