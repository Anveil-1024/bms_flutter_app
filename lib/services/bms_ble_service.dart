import 'dart:async';
import 'dart:math' show max, min;
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bms_data.dart';
import '../models/history_record.dart';

/// BMS BLE 协议（扩展功能码约定见文件末尾注释）
class BmsProtocol {
  static const int frameHeader = 0x55;
  static const int frameTailHigh = 0xAA;
  static const int frameTailLow = 0xBB;

  static const int cmdQueryBatteryInfo = 0x1001;
  /// SOH 查询（主机数据块为空；从机数据块首字节为 SOH 0~100）
  static const int cmdQuerySoh = 0x1003;
  /// 历史记录（主机：startIndex 2B LE + count 2B LE；从机：若干条 16B 定长记录）
  static const int cmdReadHistory = 0x1004;
  static const int cmdOtaBegin = 0x1005;
  static const int cmdOtaData = 0x1006;
  static const int cmdOtaEnd = 0x1007;

  static const int otaStatusOk = 0x00;
  /// 数据包需重发（约定占位）
  static const int otaDataRetry = 0x01;

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

  static Uint8List buildQueryBatteryInfo() => buildFrame(cmdQueryBatteryInfo);

  static Uint8List buildQuerySoh() => buildFrame(cmdQuerySoh);

  /// startIndex、count 均为小端；单次 count 建议 ≤32
  static Uint8List buildReadHistory(int startIndex, int count) {
    final c = count.clamp(1, 32);
    final payload = <int>[
      startIndex & 0xFF,
      (startIndex >> 8) & 0xFF,
      c & 0xFF,
      (c >> 8) & 0xFF,
    ];
    return buildFrame(cmdReadHistory, payload);
  }

  static Uint8List buildOtaBegin(int imageSize, int crc32) {
    final payload = <int>[
      ..._uint32Le(imageSize),
      ..._uint32Le(crc32),
    ];
    return buildFrame(cmdOtaBegin, payload);
  }

  static Uint8List buildOtaData(int offset, Uint8List chunk) {
    final len = chunk.length;
    final payload = <int>[
      ..._uint32Le(offset),
      len & 0xFF,
      (len >> 8) & 0xFF,
      ...chunk,
    ];
    return buildFrame(cmdOtaData, payload);
  }

  static Uint8List buildOtaEnd({bool confirm = true}) {
    return buildFrame(cmdOtaEnd, confirm ? [0x01] : []);
  }

  static List<int> _uint32Le(int v) => [
        v & 0xFF,
        (v >> 8) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 24) & 0xFF,
      ];

  /// 标准 CRC32（IEEE 802.3），用于 OTA 镜像校验
  static int crc32(Uint8List bytes) {
    int crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc = (crc ^ (b & 0xFF)) & 0xFFFFFFFF;
      for (var i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = ((crc >>> 1) ^ 0xEDB88320) & 0xFFFFFFFF;
        } else {
          crc = (crc >>> 1) & 0xFFFFFFFF;
        }
      }
    }
    return (~crc) & 0xFFFFFFFF;
  }

  static int _calcXor(List<int> bytes) {
    int xor = 0;
    for (final b in bytes) {
      xor ^= (b & 0xFF);
    }
    return xor & 0xFFFF;
  }

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

  /// 返回完整帧中的数据块（不含帧头功能码长度及校验尾）
  static List<int>? extractPayload(List<int> frame) {
    if (!validateFrame(frame)) return null;
    final dataLen = (frame[3] << 8) | frame[4];
    if (frame.length < 5 + dataLen + 4) return null;
    return frame.sublist(5, 5 + dataLen);
  }

  static int funcCodeOf(List<int> frame) {
    if (frame.length < 3) return 0;
    return (frame[1] << 8) | frame[2];
  }

  static BmsData? parseBatteryInfo(List<int> frame) {
    if (!validateFrame(frame)) return null;

    final funcCode = funcCodeOf(frame);
    if (funcCode != cmdQueryBatteryInfo) return null;

    final dataLen = (frame[3] << 8) | frame[4];
    if (frame.length < 5 + dataLen + 4) return null;

    final d = frame.sublist(5, 5 + dataLen);
    if (d.length < 52) return null;

    int pos = 0;

    final serialBytes = d.sublist(pos, pos + 16);
    final serial = String.fromCharCodes(
      serialBytes.where((b) => b != 0x00),
    );
    pos += 16;

    final rawVoltage = _readUint16LE(d, pos);
    pos += 2;

    final rawCurrent = _readInt16LE(d, pos);
    pos += 2;

    final soc = d[pos] & 0xFF;
    pos += 1;

    final workState = d[pos] & 0xFF;
    pos += 1;

    final maxCellV = _readUint16LE(d, pos);
    pos += 2;

    final minCellV = _readUint16LE(d, pos);
    pos += 2;

    final maxTemp = d[pos] & 0xFF;
    pos += 1;

    final minTemp = d[pos] & 0xFF;
    pos += 1;

    final mosTemp = d[pos] & 0xFF;
    pos += 1;

    final remainCap = _readUint16LE(d, pos);
    pos += 2;

    final ratedCap = _readUint16LE(d, pos);
    pos += 2;

    final cycleCount = _readUint16LE(d, pos);
    pos += 2;

    final cellCount = d[pos] & 0xFF;
    pos += 1;

    final switchStatus = d[pos] & 0xFF;
    pos += 1;

    final faultFlags = _readUint32LE(d, pos);
    pos += 4;

    final dischargeOcp = _readUint16LE(d, pos);
    pos += 2;

    final chargeOcp = _readUint16LE(d, pos);
    pos += 2;

    final cellOvp = _readUint16LE(d, pos);
    pos += 2;

    final cellUvp = _readUint16LE(d, pos);
    pos += 2;

    final chargeOtp = d[pos] & 0xFF;
    pos += 1;

    final dischargeOtp = d[pos] & 0xFF;
    pos += 1;

    final maxChargeCur = _readUint16LE(d, pos);
    pos += 2;

    final maxDischargeCur = _readUint16LE(d, pos);
    pos += 2;

    final hwVer = d[pos] & 0xFF;
    pos += 1;

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

  static List<HistoryRecord> parseHistoryPayload(List<int> data) {
    final list = <HistoryRecord>[];
    for (var off = 0; off + HistoryRecord.recordSize <= data.length; off += HistoryRecord.recordSize) {
      list.add(HistoryRecord.fromBytes(data, off));
    }
    return list;
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

  /// 默认 OTA 分包大小（字节）；升级前可尝试 requestMtu 后略增大
  static const int defaultOtaChunkSize = 128;

  StreamSubscription<List<int>>? _notifySub;
  Timer? _queryTimer;
  final _bmsDataController = StreamController<BmsData>.broadcast();
  Stream<BmsData> get bmsDataStream => _bmsDataController.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _writeChar;

  final List<int> _rxBuffer = [];

  Completer<List<int>>? _pendingCompleter;
  int? _pendingFuncCode;

  int _periodicPauseRef = 0;

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
    _startPeriodicQueryIfIdle();
  }

  void _onNotifyData(List<int> value) {
    if (value.isEmpty) return;
    _rxBuffer.addAll(value);
    _tryParseFrames();
  }

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
      final totalLen = 5 + dataLen + 4;

      if (_rxBuffer.length < totalLen) return;

      final frame = _rxBuffer.sublist(0, totalLen);
      _rxBuffer.removeRange(0, totalLen);

      if (frame[totalLen - 2] != BmsProtocol.frameTailHigh ||
          frame[totalLen - 1] != BmsProtocol.frameTailLow) {
        continue;
      }

      final funcCode = BmsProtocol.funcCodeOf(frame);

      if (funcCode == BmsProtocol.cmdQueryBatteryInfo) {
        final data = BmsProtocol.parseBatteryInfo(frame);
        if (data != null) {
          _bmsDataController.add(data);
        }
        continue;
      }

      if (_pendingCompleter != null &&
          !_pendingCompleter!.isCompleted &&
          funcCode == _pendingFuncCode) {
        final payload = BmsProtocol.extractPayload(frame);
        if (payload != null) {
          _pendingCompleter!.complete(payload);
          _pendingCompleter = null;
          _pendingFuncCode = null;
        }
      }
    }
  }

  Future<void> sendQueryBatteryInfo() async {
    if (_writeChar == null || !isConnected) return;
    final frame = BmsProtocol.buildQueryBatteryInfo();
    await _writeChar!.write(frame.toList(), withoutResponse: false);
  }

  /// 读取 SOH（0~100）；失败或空应答返回 null
  Future<int?> readSoh({Duration timeout = const Duration(seconds: 5)}) async {
    final payload = await _sendCommandAndWait(
      BmsProtocol.cmdQuerySoh,
      BmsProtocol.buildQuerySoh(),
      timeout: timeout,
    );
    if (payload.isEmpty) return null;
    return (payload[0] & 0xFF).clamp(0, 100);
  }

  /// 分页读取历史记录；[count] 将被限制在 1~32
  Future<List<HistoryRecord>> readHistoryPage(
    int startIndex,
    int count, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final payload = await _sendCommandAndWait(
      BmsProtocol.cmdReadHistory,
      BmsProtocol.buildReadHistory(startIndex, count),
      timeout: timeout,
    );
    return BmsProtocol.parseHistoryPayload(payload);
  }

  /// OTA：发送完整镜像；升级期间暂停周期查询，结束后恢复
  Future<void> runOta(
    Uint8List image, {
    void Function(double progress)? onProgress,
    int chunkSize = defaultOtaChunkSize,
    Duration stepTimeout = const Duration(seconds: 30),
  }) async {
    if (_writeChar == null || !isConnected) {
      throw StateError('Not connected');
    }
    if (image.isEmpty) {
      throw OtaException('Empty firmware image');
    }

    try {
      await _device?.requestMtu(247);
    } catch (_) {
      /* 部分平台可能不支持，使用默认分包大小 */
    }

    final crc = BmsProtocol.crc32(image);
    final effectiveChunk = max(8, chunkSize);

    _pausePeriodicQuery();
    try {
      final beginResp = await _sendCommandAndWait(
        BmsProtocol.cmdOtaBegin,
        BmsProtocol.buildOtaBegin(image.length, crc),
        timeout: stepTimeout,
        managePeriodic: false,
      );
      if (beginResp.isEmpty || beginResp[0] != BmsProtocol.otaStatusOk) {
        throw OtaException(
          'OTA begin rejected',
          beginResp.isNotEmpty ? beginResp[0] & 0xFF : null,
        );
      }

      var offset = 0;
      while (offset < image.length) {
        final len = min(effectiveChunk, image.length - offset);
        Uint8List chunk = image.sublist(offset, offset + len);

        while (true) {
          final dataResp = await _sendCommandAndWait(
            BmsProtocol.cmdOtaData,
            BmsProtocol.buildOtaData(offset, chunk),
            timeout: stepTimeout,
            managePeriodic: false,
          );
          if (dataResp.isEmpty) {
            throw OtaException('OTA data: empty response');
          }
          final st = dataResp[0] & 0xFF;
          if (st == BmsProtocol.otaStatusOk) {
            offset += len;
            onProgress?.call(offset / image.length);
            break;
          }
          if (st == BmsProtocol.otaDataRetry) {
            continue;
          }
          throw OtaException('OTA data failed', st);
        }
      }

      final endResp = await _sendCommandAndWait(
        BmsProtocol.cmdOtaEnd,
        BmsProtocol.buildOtaEnd(),
        timeout: stepTimeout,
        managePeriodic: false,
      );
      if (endResp.isEmpty || endResp[0] != BmsProtocol.otaStatusOk) {
        throw OtaException(
          'OTA end failed',
          endResp.isNotEmpty ? endResp[0] & 0xFF : null,
        );
      }
      onProgress?.call(1.0);
    } finally {
      _resumePeriodicQuery();
    }
  }

  Future<List<int>> _sendCommandAndWait(
    int expectedFuncCode,
    Uint8List frame, {
    Duration timeout = const Duration(seconds: 5),
    bool managePeriodic = true,
  }) async {
    if (_writeChar == null || !isConnected) {
      throw StateError('Not connected');
    }
    if (_pendingCompleter != null) {
      throw StateError('Another command is in progress');
    }

    if (managePeriodic) _pausePeriodicQuery();
    final completer = Completer<List<int>>();
    _pendingCompleter = completer;
    _pendingFuncCode = expectedFuncCode;

    try {
      await _writeChar!.write(frame.toList(), withoutResponse: false);
      return await completer.future.timeout(timeout);
    } on TimeoutException catch (e) {
      _failPendingCommand(e);
      rethrow;
    } catch (e) {
      _failPendingCommand(e);
      rethrow;
    } finally {
      if (managePeriodic) _resumePeriodicQuery();
    }
  }

  /// 取消等待中的指令（超时、断开或写入失败时调用，避免迟到的应答污染后续请求）
  void _failPendingCommand([Object? error]) {
    final c = _pendingCompleter;
    _pendingCompleter = null;
    _pendingFuncCode = null;
    if (c != null && !c.isCompleted) {
      c.completeError(error ?? StateError('Command cancelled'));
    }
  }

  void _pausePeriodicQuery() {
    _periodicPauseRef++;
    if (_periodicPauseRef == 1) {
      _queryTimer?.cancel();
      _queryTimer = null;
    }
  }

  void _resumePeriodicQuery() {
    if (_periodicPauseRef > 0) _periodicPauseRef--;
    _startPeriodicQueryIfIdle();
  }

  void _startPeriodicQueryIfIdle() {
    if (_periodicPauseRef > 0) return;
    _queryTimer?.cancel();
    _queryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (isConnected && _periodicPauseRef == 0) {
        sendQueryBatteryInfo();
      }
    });
  }

  Future<void> disconnect() async {
    _failPendingCommand(StateError('Disconnected'));
    _periodicPauseRef = 0;
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
