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
        _buildSectionTitle(loc.temperatureSection, Icons.thermostat, theme),
        const SizedBox(height: 10),
        _buildTemperatureCards(theme),
        const SizedBox(height: 20),
        _buildSectionTitle(loc.electricalSection, Icons.electric_bolt, theme),
        const SizedBox(height: 10),
        _buildElectricalGrid(theme),
        const SizedBox(height: 16),
        _buildMosStatus(theme),
      ],
    );
  }

  Widget _buildSocHeader(ThemeData theme) {
    final socColor = bmsData.socPercent > 20
        ? theme.colorScheme.primary
        : Colors.redAccent;

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
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: bmsData.socPercent / 100,
                  strokeWidth: 10,
                  backgroundColor: socColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(socColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text(
                    '${bmsData.socPercent}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: socColor,
                    ),
                  ),
                  Text(
                    loc.soc,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildTemperatureCards(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: _tempCard(loc.cellTemp, bmsData.cellTemperature, Colors.orange, theme)),
        const SizedBox(width: 10),
        Expanded(child: _tempCard(loc.ambientTemp, bmsData.ambientTemperature, Colors.teal, theme)),
        const SizedBox(width: 10),
        Expanded(child: _tempCard(loc.mosTemp, bmsData.mosTemperature, Colors.deepOrange, theme)),
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
            '${value.toStringAsFixed(1)}°C',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildElectricalGrid(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _infoTile(loc.current, '${bmsData.currentA.toStringAsFixed(2)} A', Icons.electric_bolt, theme)),
            const SizedBox(width: 10),
            Expanded(child: _infoTile(loc.voltage, '${bmsData.voltageV.toStringAsFixed(2)} V', Icons.bolt, theme)),
          ],
        ),
        const SizedBox(height: 10),
        _infoTile(loc.cycleCount, '${bmsData.cycleCount}', Icons.loop, theme),
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
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMosStatus(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: _mosCard(loc.chargeMos, bmsData.chargeMosOn, theme)),
        const SizedBox(width: 10),
        Expanded(child: _mosCard(loc.dischargeMos, bmsData.dischargeMosOn, theme)),
      ],
    );
  }

  Widget _mosCard(String label, bool isOn, ThemeData theme) {
    final color = isOn ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
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
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                isOn ? loc.mosOn : loc.mosOff,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
