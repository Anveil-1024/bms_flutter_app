import '../l10n/history_event_labels.dart';

/// 单条历史记录（与固件约定：16 字节定长，见 BmsProtocol）
///
/// 布局（新固件 `ble_pack_history_row`）：unix 4B LE | 总压 u16 LE | 电流 s16 LE |
/// SOC 1B | 事件类型 u16 LE @9~10 | 保留 5B
///
/// 部分设备/旧包为 **record 头字段顺序**：事件类型 u16 **大端** 在 @0~1（如 `00 5A`→0x005A），
/// 此时 @9~10 常为 0；若 @9~10 非 0 则优先采用小端字段。
class HistoryRecord {
  final int unixTime;
  /// 事件类型（`record_save_data_t.event_type`）
  final int eventType;
  /// 总电压，单位 V（协议为 0.1V 小端）
  final double totalVoltage;
  /// 电流 A（协议为 0.1A 有符号）
  final double current;
  final int soc;

  const HistoryRecord({
    required this.unixTime,
    required this.eventType,
    required this.totalVoltage,
    required this.current,
    required this.soc,
  });

  static const int recordSize = 16;

  factory HistoryRecord.fromBytes(List<int> d, int offset) {
    if (offset + recordSize > d.length) {
      throw RangeError('history record out of range');
    }
    final t = _readUint32LE(d, offset);
    final vRaw = _readUint16LE(d, offset + 4);
    final iRaw = _readInt16LE(d, offset + 6);
    final s = d[offset + 8] & 0xFF;
    final evTail = _readUint16LE(d, offset + 9);
    final evHeadBe = _readUint16BE(d, offset);
    final ev = evTail != 0
        ? evTail
        : (isRecognizedHistoryEventCode(evHeadBe) ? evHeadBe : 0);
    return HistoryRecord(
      unixTime: t,
      eventType: ev,
      totalVoltage: vRaw * 0.1,
      current: iRaw * 0.1,
      soc: s.clamp(0, 100),
    );
  }

  static int _readUint16LE(List<int> data, int offset) {
    return (data[offset] & 0xFF) | ((data[offset + 1] & 0xFF) << 8);
  }

  static int _readUint16BE(List<int> data, int offset) {
    return ((data[offset] & 0xFF) << 8) | (data[offset + 1] & 0xFF);
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

/// OTA 流程异常（固件返回非 0 状态等）
class OtaException implements Exception {
  final String message;
  final int? statusCode;

  OtaException(this.message, [this.statusCode]);

  @override
  String toString() => 'OtaException: $message${statusCode != null ? ' ($statusCode)' : ''}';
}
