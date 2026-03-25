import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bms_data.dart';

/// BMS 蓝牙服务：扫描、连接、订阅/解析数据
/// 若你的 BMS 使用不同 UUID 或数据格式，请在 bms_ble_service.dart 中修改
class BmsBleService {
  static const String bmsServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String bmsDataCharUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

  StreamSubscription<List<int>>? _valueSub;
  Timer? _pollTimer;
  final _bmsDataController = StreamController<BmsData>.broadcast();
  Stream<BmsData> get bmsDataStream => _bmsDataController.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _dataChar;

  BluetoothDevice? get device => _device;
  bool get isConnected => _device?.isConnected ?? false;

  /// 开始扫描，结果通过 FlutterBluePlus.scanResults 获取
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    await FlutterBluePlus.startScan(timeout: timeout);
  }

  /// 扫描结果流（每次收到更新会收到当前完整列表）
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  void stopScan() {
    FlutterBluePlus.stopScan();
  }

  /// 连接设备并发现服务/特征，订阅数据
  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    _device = device;
    await device.connect();
    await _discoverAndSubscribe(device);
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    final dataCharGuid = Guid(bmsDataCharUuid);

    for (BluetoothService svc in services) {
      for (BluetoothCharacteristic c in svc.characteristics) {
        if (c.characteristicUuid == dataCharGuid) {
          _dataChar = c;
          break;
        }
      }
      if (_dataChar != null) break;
    }

    // 若未找到固定 UUID，尝试使用第一个可读/可通知的特征（便于兼容不同 BMS）
    if (_dataChar == null) {
      for (BluetoothService svc in services) {
        for (BluetoothCharacteristic c in svc.characteristics) {
          if (c.properties.read || c.properties.notify || c.properties.indicate) {
            _dataChar = c;
            break;
          }
        }
        if (_dataChar != null) break;
      }
    }

    if (_dataChar == null) {
      throw Exception('未找到 BMS 数据特征');
    }

    await _valueSub?.cancel();
    _pollTimer?.cancel();
    _pollTimer = null;

    if (_dataChar!.properties.notify || _dataChar!.properties.indicate) {
      await _dataChar!.setNotifyValue(true);
      _valueSub = _dataChar!.lastValueStream.listen(_onData);
    } else if (_dataChar!.properties.read) {
      _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
        if (_dataChar == null || !(_device?.isConnected ?? false)) return;
        try {
          await _dataChar!.read();
          final v = _dataChar!.lastValue;
          if (v.isNotEmpty) _parseAndEmit(v);
        } catch (_) {}
      });
    }
  }

  void _onData(List<int> value) {
    if (value.isEmpty) return;
    _parseAndEmit(value);
  }

  /// 解析字节为 BMS 数据（按常见格式：电压2字节、电流2字节有符号、SOC 1字节）
  /// 不同 BMS 协议不同，此处为示例，请根据实际 BMS 协议修改
  void _parseAndEmit(List<int> bytes) {
    try {
      double voltage = 0;
      double current = 0;
      int soc = 0;
      if (bytes.length >= 5) {
        voltage = ((bytes[0] << 8) | bytes[1]) / 100.0;
        int c = (bytes[2] << 8) | bytes[3];
        if (c > 32767) c -= 65536;
        current = c / 100.0;
        soc = bytes[4].clamp(0, 100);
      } else if (bytes.length >= 3) {
        voltage = ((bytes[0] << 8) | bytes[1]) / 100.0;
        soc = bytes[2].clamp(0, 100);
      }
      _bmsDataController.add(BmsData(voltageV: voltage, currentA: current, socPercent: soc));
    } catch (_) {
      // 解析失败时忽略
    }
  }

  Future<void> disconnect() async {
    await _valueSub?.cancel();
    _valueSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _dataChar = null;
    if (_device != null) {
      await _device!.disconnect();
      _device = null;
    }
  }

  void dispose() {
    stopScan();
    disconnect();
    _bmsDataController.close();
  }
}
