import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../l10n/app_localizations.dart';
import '../services/bms_ble_service.dart';
import '../models/bms_data.dart';

class BluetoothScanScreen extends StatefulWidget {
  final BmsBleService bleService;
  final AppLocalizations loc;
  final ValueChanged<BmsData> onDataUpdate;

  const BluetoothScanScreen({
    super.key,
    required this.bleService,
    required this.loc,
    required this.onDataUpdate,
  });

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen> {
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BmsData>? _dataSub;
  String _status = '';
  bool _isScanning = false;
  bool _isConnecting = false;

  BmsBleService get _bleService => widget.bleService;
  AppLocalizations get loc => widget.loc;

  @override
  void initState() {
    super.initState();
    _status = loc.btStatusInit;
    _checkBluetooth();
  }

  Future<void> _checkBluetooth() async {
    try {
      if (await FlutterBluePlus.isOn == false) {
        setState(() => _status = loc.btTurnOn);
        return;
      }
      setState(() => _status = loc.btReady);
    } catch (e) {
      setState(() => _status = loc.btUnavailable('$e'));
    }
  }

  void _startScan() async {
    if (_isScanning) return;
    try {
      if (await FlutterBluePlus.isOn == false) {
        setState(() => _status = loc.btTurnOn);
        return;
      }
      setState(() {
        _isScanning = true;
        _scanResults = [];
        _status = loc.btScanning;
      });
      await _bleService.startScan(timeout: const Duration(seconds: 12));
      _scanSub?.cancel();
      _scanSub = _bleService.scanResults.listen((results) {
        if (mounted) setState(() => _scanResults = results);
      });
      await Future.delayed(const Duration(seconds: 12));
      if (mounted) {
        _scanSub?.cancel();
        _bleService.stopScan();
        setState(() {
          _isScanning = false;
          _status = _scanResults.isEmpty ? loc.btNoDevice : loc.btSelectDevice;
        });
      }
    } catch (e) {
      if (mounted) {
        _bleService.stopScan();
        setState(() {
          _isScanning = false;
          _status = loc.btScanError('$e');
        });
      }
    }
  }

  void _connect(BluetoothDevice device) async {
    if (_isConnecting || _bleService.isConnected) return;
    final name = device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString();
    setState(() {
      _isConnecting = true;
      _status = loc.btConnectingTo(name);
    });
    _scanSub?.cancel();
    _bleService.stopScan();
    try {
      await _bleService.connect(device);
      _dataSub?.cancel();
      _dataSub = _bleService.bmsDataStream.listen((data) {
        widget.onDataUpdate(data);
      });
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _status = loc.btConnected;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _status = loc.btConnectError('$e');
        });
      }
    }
  }

  void _disconnect() async {
    await _bleService.disconnect();
    _dataSub?.cancel();
    if (mounted) {
      setState(() {
        _status = loc.btDisconnected;
      });
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(theme),
        const SizedBox(height: 16),
        _buildScanButton(theme),
        if (_bleService.isConnected) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off),
            label: Text(loc.btDisconnect),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ],
        if (_scanResults.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            loc.btDeviceList,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          ..._scanResults.map((r) => _deviceTile(r, theme)),
        ],
      ],
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _bleService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (_bleService.device != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${loc.btDevice}: ${_bleService.device!.platformName.isNotEmpty ? _bleService.device!.platformName : _bleService.device!.remoteId}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton(ThemeData theme) {
    return FilledButton.icon(
      onPressed: (_isScanning || _isConnecting) ? null : _startScan,
      icon: _isScanning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.radar),
      label: Text(_isScanning ? loc.btScanningBtn : loc.btScanBtn),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _deviceTile(ScanResult result, ThemeData theme) {
    final device = result.device;
    final name = device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString();
    final rssi = result.rssi;
    final signalStrength = rssi > -60 ? 3 : (rssi > -80 ? 2 : 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.bluetooth, color: theme.colorScheme.primary),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Text('${loc.btSignal}: $rssi dBm  '),
            ...List.generate(3, (i) => Icon(
              Icons.signal_cellular_alt,
              size: 14,
              color: i < signalStrength
                  ? theme.colorScheme.primary
                  : Colors.grey[300],
            )),
          ],
        ),
        trailing: _isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: Icon(Icons.link, color: theme.colorScheme.primary),
                onPressed: () => _connect(device),
                tooltip: loc.btConnect,
              ),
      ),
    );
  }
}
