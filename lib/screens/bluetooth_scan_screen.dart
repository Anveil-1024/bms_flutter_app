import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../l10n/app_localizations.dart';
import '../services/bms_ble_service.dart';
import '../models/bms_data.dart';

enum _BtStatus { init, turnOn, ready, scanning, noDevice, selectDevice, connecting, connected, disconnected, scanError, connectError, unavailable }

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
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  _BtStatus _btStatus = _BtStatus.init;
  String _statusArg = '';
  bool _isScanning = false;
  String? _connectingDeviceId;

  BmsBleService get _bleService => widget.bleService;
  AppLocalizations get loc => widget.loc;

  String get _statusText {
    switch (_btStatus) {
      case _BtStatus.init:
        return loc.btStatusInit;
      case _BtStatus.turnOn:
        return loc.btTurnOn;
      case _BtStatus.ready:
        return loc.btReady;
      case _BtStatus.scanning:
        return loc.btScanning;
      case _BtStatus.noDevice:
        return loc.btNoDevice;
      case _BtStatus.selectDevice:
        return loc.btSelectDevice;
      case _BtStatus.connecting:
        return loc.btConnectingTo(_statusArg);
      case _BtStatus.connected:
        return loc.btConnected;
      case _BtStatus.disconnected:
        return loc.btDisconnected;
      case _BtStatus.scanError:
        return loc.btScanError(_statusArg);
      case _BtStatus.connectError:
        return loc.btConnectError(_statusArg);
      case _BtStatus.unavailable:
        return loc.btUnavailable(_statusArg);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkBluetooth();
  }

  Future<void> _checkBluetooth() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        setState(() => _btStatus = _BtStatus.turnOn);
        return;
      }
      setState(() => _btStatus = _BtStatus.ready);
    } catch (e) {
      setState(() {
        _btStatus = _BtStatus.unavailable;
        _statusArg = '$e';
      });
    }
  }

  void _startScan() async {
    if (_isScanning) return;
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        setState(() => _btStatus = _BtStatus.turnOn);
        return;
      }
      setState(() {
        _isScanning = true;
        _scanResults = [];
        _btStatus = _BtStatus.scanning;
      });
      await _bleService.startScan(timeout: const Duration(seconds: 12));
      _scanSub?.cancel();
      _scanSub = _bleService.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _scanResults = results
                .where((r) => r.device.platformName.isNotEmpty)
                .toList();
          });
        }
      });
      await Future.delayed(const Duration(seconds: 12));
      if (mounted) {
        _scanSub?.cancel();
        _bleService.stopScan();
        setState(() {
          _isScanning = false;
          _btStatus = _scanResults.isEmpty ? _BtStatus.noDevice : _BtStatus.selectDevice;
        });
      }
    } catch (e) {
      if (mounted) {
        _bleService.stopScan();
        setState(() {
          _isScanning = false;
          _btStatus = _BtStatus.scanError;
          _statusArg = '$e';
        });
      }
    }
  }

  void _connect(BluetoothDevice device) async {
    if (_connectingDeviceId != null || _bleService.isConnected) return;
    final name = device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString();
    setState(() {
      _connectingDeviceId = device.remoteId.str;
      _btStatus = _BtStatus.connecting;
      _statusArg = name;
    });
    _scanSub?.cancel();
    _bleService.stopScan();
    try {
      await _bleService.connect(device);
      _dataSub?.cancel();
      _dataSub = _bleService.bmsDataStream.listen((data) {
        widget.onDataUpdate(data);
      });
      _connectionStateSub?.cancel();
      _connectionStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          _dataSub?.cancel();
          _connectionStateSub?.cancel();
          setState(() {
            _btStatus = _BtStatus.disconnected;
          });
        }
      });
      if (mounted) {
        setState(() {
          _connectingDeviceId = null;
          _isScanning = false;
          _btStatus = _BtStatus.connected;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectingDeviceId = null;
          _btStatus = _BtStatus.connectError;
          _statusArg = '$e';
        });
      }
    }
  }

  void _disconnect() async {
    _connectionStateSub?.cancel();
    await _bleService.disconnect();
    _dataSub?.cancel();
    if (mounted) {
      setState(() {
        _btStatus = _BtStatus.disconnected;
      });
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _dataSub?.cancel();
    _connectionStateSub?.cancel();
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
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
        if (_scanResults.isNotEmpty && !_bleService.isConnected) ...[
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
    final isConnected = _bleService.isConnected;
    final statusColor = isConnected ? Colors.green : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.08),
            statusColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: statusColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusText,
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
    if (_bleService.isConnected) return const SizedBox.shrink();
    return FilledButton.icon(
      onPressed: (_isScanning || _connectingDeviceId != null) ? null : _startScan,
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
        trailing: _connectingDeviceId == device.remoteId.str
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: Icon(Icons.link, color: theme.colorScheme.primary),
                onPressed: _connectingDeviceId != null ? null : () => _connect(device),
                tooltip: loc.btConnect,
              ),
      ),
    );
  }
}
