import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import '../services/bms_ble_service.dart';
import '../models/bms_data.dart';
import 'qr_scan_screen.dart';

enum _BtStatus {
  init,
  turnOn,
  ready,
  scanning,
  lookingForDevice,
  noDevice,
  qrNotFound,
  selectDevice,
  connecting,
  connected,
  disconnected,
  scanError,
  connectError,
  unavailable,
  cameraDenied,
}

/// iOS 扫描时 platformName 常为空，须优先用广播名 advName。
String _bleDisplayName(ScanResult r) {
  final adv = r.advertisementData.advName.trim();
  if (adv.isNotEmpty) return adv;
  final platform = r.device.platformName.trim();
  if (platform.isNotEmpty) return platform;
  return r.device.remoteId.str;
}

bool _isGrtDevice(ScanResult r) {
  return _bleDisplayName(r).toUpperCase().startsWith('GRT');
}

bool _sameBleName(String a, String b) {
  return a.trim().toUpperCase() == b.trim().toUpperCase();
}

List<ScanResult> _dedupeScanResults(List<ScanResult> results) {
  final map = <String, ScanResult>{};
  for (final r in results) {
    map[r.device.remoteId.str] = r;
  }
  return map.values.toList();
}

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
  static const _scanTimeout = Duration(seconds: 12);

  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BmsData>? _dataSub;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  _BtStatus _btStatus = _BtStatus.init;
  String _statusArg = '';
  bool _isScanning = false;
  String? _connectingDeviceId;
  String? _lookupName;
  int _scanGen = 0;

  BmsBleService get _bleService => widget.bleService;
  AppLocalizations get loc => widget.loc;

  bool get _busy => _isScanning || _connectingDeviceId != null;

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
      case _BtStatus.lookingForDevice:
        return loc.btLookingFor(_statusArg);
      case _BtStatus.noDevice:
        return loc.btNoDevice;
      case _BtStatus.qrNotFound:
        return loc.btQrNotFound(_statusArg);
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
      case _BtStatus.cameraDenied:
        return loc.btCameraPermissionRequired;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkBluetooth();
  }

  static const List<Permission> _androidBlePermissions = [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
  ];

  bool _isGranted(PermissionStatus? status) {
    return status != null && (status.isGranted || status.isLimited);
  }

  Future<bool> _hasBlePermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await Future.wait(
      _androidBlePermissions.map((p) => p.status),
    );
    return statuses.every((s) => _isGranted(s));
  }

  Future<bool> _ensureBlePermissions() async {
    if (!Platform.isAndroid) return true;
    if (await _hasBlePermissions()) return true;

    final statusMap = await _androidBlePermissions.request();
    final granted = _androidBlePermissions.every(
      (p) => _isGranted(statusMap[p]),
    );

    if (!granted && mounted) {
      setState(() {
        _btStatus = _BtStatus.unavailable;
        _statusArg = loc.btPermissionRequired;
      });
    }
    return granted;
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (_isGranted(status)) return true;
    final requested = await Permission.camera.request();
    if (_isGranted(requested)) return true;
    if (mounted) {
      setState(() {
        _btStatus = _BtStatus.cameraDenied;
      });
    }
    return false;
  }

  Future<bool> _prepareBle() async {
    final granted = await _ensureBlePermissions();
    if (!granted) return false;

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      if (mounted) setState(() => _btStatus = _BtStatus.turnOn);
      return false;
    }
    return true;
  }

  Future<void> _checkBluetooth() async {
    try {
      final hasPermissions = await _hasBlePermissions();
      if (!hasPermissions) {
        setState(() {
          _btStatus = _BtStatus.unavailable;
          _statusArg = loc.btPermissionRequired;
        });
        return;
      }
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

  void _cancelScanListeners() {
    _scanSub?.cancel();
    _scanSub = null;
    _bleService.stopScan();
  }

  Future<void> _openQrScan() async {
    if (_busy || _bleService.isConnected) return;
    if (!await _prepareBle()) return;
    if (!await _ensureCameraPermission()) return;
    if (!mounted) return;

    final name = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => QrScanScreen(loc: loc)));
    if (!mounted || name == null || name.isEmpty) return;
    await _findAndConnectByName(name);
  }

  Future<void> _findAndConnectByName(String targetName) async {
    if (_busy) return;
    final gen = ++_scanGen;
    try {
      if (!await _prepareBle()) return;

      setState(() {
        _isScanning = true;
        _lookupName = targetName;
        _scanResults = [];
        _btStatus = _BtStatus.lookingForDevice;
        _statusArg = targetName;
      });

      _cancelScanListeners();
      await _bleService.startScan(timeout: _scanTimeout);
      _scanSub = _bleService.scanResults.listen((results) {
        if (!mounted || gen != _scanGen) return;
        if (_connectingDeviceId != null || _bleService.isConnected) return;

        final matches = _dedupeScanResults(
          results
              .where((r) => _sameBleName(_bleDisplayName(r), targetName))
              .toList(),
        );
        if (matches.isEmpty) return;

        if (matches.length == 1) {
          _cancelScanListeners();
          setState(() => _scanResults = matches);
          _connect(
            matches.first.device,
            displayName: _bleDisplayName(matches.first),
          );
          return;
        }

        _cancelScanListeners();
        setState(() {
          _isScanning = false;
          _scanResults = matches;
          _btStatus = _BtStatus.selectDevice;
        });
      });

      await Future.delayed(_scanTimeout);
      if (!mounted || gen != _scanGen) return;
      if (_connectingDeviceId != null || _bleService.isConnected) return;

      _cancelScanListeners();
      setState(() {
        _isScanning = false;
        if (_scanResults.length > 1) {
          _btStatus = _BtStatus.selectDevice;
        } else {
          _btStatus = _BtStatus.qrNotFound;
          _statusArg = targetName;
        }
      });
    } catch (e) {
      if (mounted && gen == _scanGen) {
        _cancelScanListeners();
        setState(() {
          _isScanning = false;
          _btStatus = _BtStatus.scanError;
          _statusArg = '$e';
        });
      }
    }
  }

  void _startScan() async {
    if (_busy) return;
    final gen = ++_scanGen;
    try {
      if (!await _prepareBle()) return;

      setState(() {
        _isScanning = true;
        _lookupName = null;
        _scanResults = [];
        _btStatus = _BtStatus.scanning;
      });
      _cancelScanListeners();
      await _bleService.startScan(timeout: _scanTimeout);
      _scanSub = _bleService.scanResults.listen((results) {
        if (mounted && gen == _scanGen) {
          setState(() {
            _scanResults = _dedupeScanResults(
              results.where(_isGrtDevice).toList(),
            );
          });
        }
      });
      await Future.delayed(_scanTimeout);
      if (mounted && gen == _scanGen) {
        _cancelScanListeners();
        setState(() {
          _isScanning = false;
          _btStatus = _scanResults.isEmpty
              ? _BtStatus.noDevice
              : _BtStatus.selectDevice;
        });
      }
    } catch (e) {
      if (mounted && gen == _scanGen) {
        _cancelScanListeners();
        setState(() {
          _isScanning = false;
          _btStatus = _BtStatus.scanError;
          _statusArg = '$e';
        });
      }
    }
  }

  void _connect(BluetoothDevice device, {String? displayName}) async {
    if (_connectingDeviceId != null || _bleService.isConnected) return;
    _connectingDeviceId = device.remoteId.str;
    _scanGen++;

    final granted = await _ensureBlePermissions();
    if (!granted) {
      if (mounted) setState(() => _connectingDeviceId = null);
      return;
    }

    final name =
        displayName ??
        (device.platformName.trim().isNotEmpty
            ? device.platformName.trim()
            : device.remoteId.str);
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _btStatus = _BtStatus.connecting;
      _statusArg = name;
    });
    _cancelScanListeners();
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
          _lookupName = null;
          _scanResults = [];
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
        if (_bleService.isConnected)
          OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off),
            label: Text(loc.btDisconnect),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )
        else ...[
          _buildQrButton(),
          const SizedBox(height: 4),
          _buildManualScanButton(),
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
    final statusIcon = isConnected
        ? Icons.bluetooth_connected
        : (_btStatus == _BtStatus.lookingForDevice ||
              _btStatus == _BtStatus.scanning)
        ? Icons.bluetooth_searching
        : Icons.bluetooth;

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
        border: Border.all(color: statusColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
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

  Widget _buildQrButton() {
    final lookingByQr = _lookupName != null && _isScanning;
    final label = _connectingDeviceId != null
        ? loc.btConnectingTo(_statusArg)
        : lookingByQr
        ? loc.btLookingFor(_lookupName!)
        : loc.btQrScanBtn;
    return FilledButton.icon(
      onPressed: _busy ? null : _openQrScan,
      icon: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.qr_code_scanner),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildManualScanButton() {
    return TextButton(
      onPressed: _busy ? null : _startScan,
      child: Text(
        _isScanning && _lookupName == null
            ? loc.btScanningBtn
            : loc.btManualScan,
      ),
    );
  }

  Widget _deviceTile(ScanResult result, ThemeData theme) {
    final device = result.device;
    final name = _bleDisplayName(result);
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
            ...List.generate(
              3,
              (i) => Icon(
                Icons.signal_cellular_alt,
                size: 14,
                color: i < signalStrength
                    ? theme.colorScheme.primary
                    : Colors.grey[300],
              ),
            ),
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
                onPressed: _connectingDeviceId != null
                    ? null
                    : () => _connect(device, displayName: name),
                tooltip: loc.btConnect,
              ),
      ),
    );
  }
}
