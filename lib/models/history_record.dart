/// 单条历史记录（与固件约定：16 字节定长，见 BmsProtocol）
class HistoryRecord {
  final int unixTime;
  /// 总电压，单位 V（协议为 0.1V 小端）
  final double totalVoltage;
  /// 电流 A（协议为 0.1A 有符号）
  final double current;
  final int soc;

  const HistoryRecord({
    required this.unixTime,
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
    return HistoryRecord(
      unixTime: t,
      totalVoltage: vRaw * 0.1,
      current: iRaw * 0.1,
      soc: s.clamp(0, 100),
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

/// OTA 流程异常（固件返回非 0 状态等）
class OtaException implements Exception {
  final String message;
  final int? statusCode;

  OtaException(this.message, [this.statusCode]);

  @override
  String toString() => 'OtaException: $message${statusCode != null ? ' ($statusCode)' : ''}';
}
