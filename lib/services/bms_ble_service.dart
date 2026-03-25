import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bms_data.dart';

class BmsProtocol {
  static const int frameHeader = 0x55;
  static const int frameTailHigh = 0xAA;
  static const int frameTailLow = 0xBB;
  static const int cmdQueryBatteryInfo = 0x1001;

  /// 构建协议帧: 0x55 + 功能码(2B) + 数据长度(2B) + 数据块(NB) + XOR(2B) + 0xAABB
  static Uint8List buildFrame(int functionCode, [List<int>? data]) {
    final payload = data ?? [];
    final len = payload.length;
    final frame = <int>[
      frameHeader,
      (functionCode >> 8) & 0xFF,
      functionCode & 0xFF,
      (len >> 8) & 0xFF,
      len & 0xFF,
      ...payload,
    ];
    final xor = _calcXor(frame);
    frame.add((xor >> 8) & 0xFF);
    frame.add(xor & 0xFF);
    frame.add(frameTailHigh);
    frame.add(frameTailLow);
    return Uint8List.fromList(frame);
  }

  /// 构建查询电池信息命令帧 (0x1001, 无数据块)
  static Uint8List buildQueryBatteryInfo() {
    return buildFrame(cmdQueryBatteryInfo);
  }

  /// XOR校验: 对所有字节逐字节异或，结果扩展为2字节 (高8位=0, 低8位=xor结果)
  static int _calcXor(List<int> bytes) {
    int xor = 0;
    for (final b in bytes) {
      xor ^= (b & 0xFF);
    }
    return xor & 0xFFFF;
  }

  /// 校验完整帧是否合法
  static bool validateFrame(List<int> frame) {
    if (frame.length < 7) return false;
    if (frame.first != frameHeader) return false;
    if (frame[frame.length - 2] != frameTailHigh ||
        frame[frame.length - 1] != frameTailLow) {
      return false;
    }

    final xorHigh = frame[frame.length - 4];
    final xorLow = frame[frame.length - 3];
    final receivedXor = (xorHigh << 8) | xorLow;

    final checkPart = frame.sublist(0, frame.length - 4);
    final calcXor = _calcXor(checkPart);

    return receivedXor == calcXor;
  }

  /// 解析0x1001回复的数据块为 BmsData
  static BmsData? parseBatteryInfo(List<int> frame) {
    if (!validateFrame(frame)) return null;

    final funcCode = (frame[1] << 8) | frame[2];
    if (funcCode != cmdQueryBatteryInfo) return null;

    final dataLen = (frame[3] << 8) | frame[4];
    if (frame.length < 5 + dataLen + 4) return null;

    final d = frame.sublist(5, 5 + dataLen);
    if (d.length < 52) return null;

    int pos = 0;

    // 1. 设备序列号 16 Byte ASCII
    final serialBytes = d.sublist(pos, pos + 16);
    final serial = String.fromCharCodes(
      serialBytes.where((b) => b != 0x00),
    );
    pos += 16;

    // 2. 总电压 2B 小端 0.1V
    final rawVoltage = _readUint16LE(d, pos);
    pos += 2;

    // 3. 电流 2B 小端 有符号 0.1A
    final rawCurrent = _readInt16LE(d, pos);
    pos += 2;

    // 4. SOC 1B
    final soc = d[pos] & 0xFF;
    pos += 1;

    // 5. 电池工作状态 1B
    final workState = d[pos] & 0xFF;
    pos += 1;

    // 6. 最高单体电压 2B 小端 mV
    final maxCellV = _readUint16LE(d, pos);
    pos += 2;

    // 7. 最低单体电压 2B 小端 mV
    final minCellV = _readUint16LE(d, pos);
    pos += 2;

    // 8. 最高温度 1B offset+40
    final maxTemp = d[pos] & 0xFF;
    pos += 1;

    // 9. 最低温度 1B offset+40
    final minTemp = d[pos] & 0xFF;
    pos += 1;

    // 10. MOS温度 1B offset+40
    final mosTemp = d[pos] & 0xFF;
    pos += 1;

    // 11. 剩余容量 2B 小端 mAh
    final remainCap = _readUint16LE(d, pos);
    pos += 2;

    // 12. 额定容量 2B 小端 0.1Ah
    final ratedCap = _readUint16LE(d, pos);
    pos += 2;

    // 13. 循环次数 2B 小端
    final cycleCount = _readUint16LE(d, pos);
    pos += 2;

    // 14. 电芯串数 1B
    final cellCount = d[pos] & 0xFF;
    pos += 1;

    // 15. 开关信号状态 1B
    final switchStatus = d[pos] & 0xFF;
    pos += 1;

    // 16. 故障标志位 4B 小端
    final faultFlags = _readUint32LE(d, pos);
    pos += 4;

    // 17. 一级放电过流保护值 2B 小端 0.1A
    final dischargeOcp = _readUint16LE(d, pos);
    pos += 2;

    // 18. 充电过流保护值 2B 小端 0.1A
    final chargeOcp = _readUint16LE(d, pos);
    pos += 2;

    // 19. 单体过压保护电压 2B 小端 mV
    final cellOvp = _readUint16LE(d, pos);
    pos += 2;

    // 20. 单体过放保护电压 2B 小端 mV
    final cellUvp = _readUint16LE(d, pos);
    pos += 2;

    // 21. 充电高温保护值 1B 1°C offset+40
    final chargeOtp = d[pos] & 0xFF;
    pos += 1;

    // 22. 放电高温保护值 1B 1°C offset+40
    final dischargeOtp = d[pos] & 0xFF;
    pos += 1;

    // 23. 最大允许充电电流 2B 小端 1A
    final maxChargeCur = _readUint16LE(d, pos);
    pos += 2;

    // 24. 最大允许放电电流 2B 小端 1A
    final maxDischargeCur = _readUint16LE(d, pos);
    pos += 2;

    // 25. 硬件版本 1B
    final hwVer = d[pos] & 0xFF;
    pos += 1;

    // 26. 软件版本 1B
    final swVer = d[pos] & 0xFF;

    return BmsData(
      deviceSerial: serial,
      totalVoltage: rawVoltage * 0.1,
      current: rawCurrent * 0.1,
      soc: soc.clamp(0, 100),
      workState: workState,
      maxCellVoltage: maxCellV,
      minCellVoltage: minCellV,
      maxTemp: maxTemp,
      minTemp: minTemp,
      mosTemp: mosTemp,
      remainCapacity: remainCap,
      ratedCapacity: ratedCap,
      cycleCount: cycleCount,
      cellCount: cellCount,
      switchStatus: switchStatus,
      faultFlags: faultFlags,
      dischargeOcp: dischargeOcp,
      chargeOcp: chargeOcp,
      cellOvp: cellOvp,
      cellUvp: cellUvp,
      chargeOtp: chargeOtp,
      dischargeOtp: dischargeOtp,
      maxChargeCurrent: maxChargeCur,
      maxDischargeCurrent: maxDischargeCur,
      hardwareVersion: hwVer,
      softwareVersion: swVer,
    );
  }

  static int _readUint16LE(List<int> data, int offset) {
    return (data[offset] & 0xFF) | ((data[offset + 1] & 0xFF) << 8);
  }

  static int _readInt16LE(List<int> data, int offset) {
    int val = _readUint16LE(data, offset);
    if (val > 32767) val -= 65536;
    return val;
  }

  static int _readUint32LE(List<int> data, int offset) {
    return (data[offset] & 0xFF) |
        ((data[offset + 1] & 0xFF) << 8) |
        ((data[offset + 2] & 0xFF) << 16) |
        ((data[offset + 3] & 0xFF) << 24);
  }
}

class BmsBleService {
  static const String notifyCharUuid = '0000fff1-0000-1000-8000-00805f9b34fb';
  static const String writeCharUuid = '0000fff2-0000-1000-8000-00805f9b34fb';

  StreamSubscription<List<int>>? _notifySub;
  Timer? _queryTimer;
  final _bmsDataController = StreamController<BmsData>.broadcast();
  Stream<BmsData> get bmsDataStream => _bmsDataController.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _writeChar;

  final List<int> _rxBuffer = [];

  BluetoothDevice? get device => _device;
  bool get isConnected => _device?.isConnected ?? false;

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    await FlutterBluePlus.startScan(timeout: timeout);
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  void stopScan() {
    FlutterBluePlus.stopScan();
  }

  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    _device = device;
    await device.connect();
    await _discoverAndSubscribe(device);
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final notifyGuid = Guid(notifyCharUuid);
    final writeGuid = Guid(writeCharUuid);

    for (final svc in services) {
      for (final c in svc.characteristics) {
        if (c.characteristicUuid == notifyGuid) {
          _notifyChar = c;
        } else if (c.characteristicUuid == writeGuid) {
          _writeChar = c;
        }
      }
    }

    if (_notifyChar == null || _writeChar == null) {
      throw Exception('BMS characteristics not found (FFF1/FFF2)');
    }

    await _notifySub?.cancel();
    _rxBuffer.clear();

    await _notifyChar!.setNotifyValue(true);
    _notifySub = _notifyChar!.lastValueStream.listen(_onNotifyData);

    await Future.delayed(const Duration(milliseconds: 300));
    await sendQueryBatteryInfo();
    _startPeriodicQuery();
  }

  void _onNotifyData(List<int> value) {
    if (value.isEmpty) return;
    _rxBuffer.addAll(value);
    _tryParseFrames();
  }

  /// 从缓冲区中尝试提取完整帧并解析
  void _tryParseFrames() {
    while (_rxBuffer.length >= 7) {
      final headerIdx = _rxBuffer.indexOf(BmsProtocol.frameHeader);
      if (headerIdx < 0) {
        _rxBuffer.clear();
        return;
      }
      if (headerIdx > 0) {
        _rxBuffer.removeRange(0, headerIdx);
      }

      if (_rxBuffer.length < 5) return;

      final dataLen = (_rxBuffer[3] << 8) | _rxBuffer[4];
      final totalLen = 5 + dataLen + 4; // header(1)+func(2)+len(2) + data(N) + xor(2)+tail(2)

      if (_rxBuffer.length < totalLen) return;

      final frame = _rxBuffer.sublist(0, totalLen);
      _rxBuffer.removeRange(0, totalLen);

      if (frame[totalLen - 2] != BmsProtocol.frameTailHigh ||
          frame[totalLen - 1] != BmsProtocol.frameTailLow) {
        continue;
      }

      final funcCode = (frame[1] << 8) | frame[2];
      if (funcCode == BmsProtocol.cmdQueryBatteryInfo) {
        final data = BmsProtocol.parseBatteryInfo(frame);
        if (data != null) {
          _bmsDataController.add(data);
        }
      }
    }
  }

  /// 发送查询电池信息命令
  Future<void> sendQueryBatteryInfo() async {
    if (_writeChar == null || !isConnected) return;
    final frame = BmsProtocol.buildQueryBatteryInfo();
    await _writeChar!.write(frame.toList(), withoutResponse: false);
  }

  void _startPeriodicQuery() {
    _queryTimer?.cancel();
    _queryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (isConnected) {
        sendQueryBatteryInfo();
      }
    });
  }

  Future<void> disconnect() async {
    _queryTimer?.cancel();
    _queryTimer = null;
    await _notifySub?.cancel();
    _notifySub = null;
    _notifyChar = null;
    _writeChar = null;
    _rxBuffer.clear();
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
