import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/bms_data.dart';

class BatteryInfoScreen extends StatelessWidget {
  final BmsData bmsData;
  final AppLocalizations loc;

  const BatteryInfoScreen({
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
        _buildSocHeader(theme),
        const SizedBox(height: 20),
        _buildSectionTitle(loc.basicInfoSection, Icons.info_outline, theme),
        const SizedBox(height: 10),
        _buildBasicInfoCards(theme),
        const SizedBox(height: 20),
        _buildSectionTitle(loc.voltageSection, Icons.bolt, theme),
        const SizedBox(height: 10),
        _buildVoltageCards(theme),
        const SizedBox(height: 20),
        _buildSectionTitle(loc.temperatureSection, Icons.thermostat, theme),
        const SizedBox(height: 10),
        _buildTemperatureCards(theme),
        const SizedBox(height: 20),
        _buildSectionTitle(loc.capacitySection, Icons.battery_std, theme),
        const SizedBox(height: 10),
        _buildCapacityCards(theme),
        const SizedBox(height: 20),
        _buildSectionTitle(loc.switchStatusSection, Icons.toggle_on_outlined, theme),
        const SizedBox(height: 10),
        _buildMosStatus(theme),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSocHeader(ThemeData theme) {
    final socColor = bmsData.soc > 20
        ? theme.colorScheme.primary
        : Colors.redAccent;

    final stateColor = bmsData.workState == 0x01
        ? Colors.green
        : bmsData.workState == 0x02
            ? Colors.orange
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            socColor.withValues(alpha: 0.12),
            socColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: socColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: bmsData.soc / 100,
                  strokeWidth: 10,
                  backgroundColor: socColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(socColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text(
                    '${bmsData.soc}%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: socColor,
                    ),
                  ),
                  Text(
                    loc.soc,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerInfoRow(
                  loc.totalVoltage,
                  '${bmsData.totalVoltageV.toStringAsFixed(1)} V',
                  theme,
                ),
                const SizedBox(height: 8),
                _headerInfoRow(
                  loc.currentLabel,
                  '${bmsData.currentA.toStringAsFixed(1)} A',
                  theme,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      loc.workState,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        loc.workStateLabel(bmsData.workStateText),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: stateColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (bmsData.deviceSerial.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'SN: ${bmsData.deviceSerial}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerInfoRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
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

  Widget _buildBasicInfoCards(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _infoTile(loc.cellCount, '${bmsData.cellCount} S', Icons.apps, theme),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _infoTile(loc.cycleCount, '${bmsData.cycleCount}', Icons.loop, theme),
        ),
      ],
    );
  }

  Widget _buildVoltageCards(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _infoTile(
                loc.maxCellVoltage,
                '${bmsData.maxCellVoltage} mV',
                Icons.arrow_upward,
                theme,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _infoTile(
                loc.minCellVoltage,
                '${bmsData.minCellVoltage} mV',
                Icons.arrow_downward,
                theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _infoTile(
          loc.cellVoltageDiff,
          '${bmsData.cellVoltageDiffMv} mV',
          Icons.compare_arrows,
          theme,
        ),
      ],
    );
  }

  Widget _buildTemperatureCards(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: _tempCard(loc.maxTemp, bmsData.maxTempC, Colors.orange, theme)),
        const SizedBox(width: 10),
        Expanded(child: _tempCard(loc.minTemp, bmsData.minTempC, Colors.teal, theme)),
        const SizedBox(width: 10),
        Expanded(child: _tempCard(loc.mosTemp, bmsData.mosTempC, Colors.deepOrange, theme)),
      ],
    );
  }

  Widget _tempCard(String label, double value, Color accent, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.thermostat, color: accent, size: 24),
          const SizedBox(height: 8),
          Text(
            '${value.toStringAsFixed(0)}°C',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityCards(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _infoTile(
            loc.remainCapacity,
            '${bmsData.remainCapacity} mAh',
            Icons.battery_charging_full,
            theme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _infoTile(
            loc.ratedCapacity,
            '${bmsData.ratedCapacityAh.toStringAsFixed(1)} Ah',
            Icons.battery_full,
            theme,
          ),
        ),
      ],
    );
  }

  Widget _buildMosStatus(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: _mosCard(loc.chargeMos, bmsData.chargeMosOn, theme)),
        const SizedBox(width: 8),
        Expanded(child: _mosCard(loc.dischargeMos, bmsData.dischargeMosOn, theme)),
        const SizedBox(width: 8),
        Expanded(child: _mosCard(loc.preDischargeMos, bmsData.preDischargeMosOn, theme)),
      ],
    );
  }

  Widget _infoTile(String label, String value, IconData icon, ThemeData theme) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mosCard(String label, bool isOn, ThemeData theme) {
    final color = isOn ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: isOn
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isOn ? loc.mosOn : loc.mosOff,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
