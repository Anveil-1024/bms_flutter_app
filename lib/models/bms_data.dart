class BmsData {
  // 1. 设备序列号 (16 Byte ASCII)
  final String deviceSerial;
  // 2. 总电压 (0.1V)
  final double totalVoltage;
  // 3. 电流 (0.1A, 正=充电, 负=放电)
  final double current;
  // 4. SOC (0~100%)
  final int soc;
  // 5. 电池工作状态 (0=待机, 1=充电中, 2=放电中)
  final int workState;
  // 6. 最高单体电压 (mV)
  final int maxCellVoltage;
  // 7. 最低单体电压 (mV)
  final int minCellVoltage;
  // 8. 最高温度 (offset +40)
  final int maxTemp;
  // 9. 最低温度 (offset +40)
  final int minTemp;
  // 10. MOS温度 (offset +40)
  final int mosTemp;
  // 11. 剩余容量 (mAh)
  final int remainCapacity;
  // 12. 额定容量 (0.1Ah)
  final int ratedCapacity;
  // 13. 循环次数
  final int cycleCount;
  // 14. 电芯串数
  final int cellCount;
  // 15. 开关信号状态 bitmask
  final int switchStatus;
  // 16. 故障标志位 (4 byte)
  final int faultFlags;
  // 17. 一级放电过流保护值 (0.1A)
  final int dischargeOcp;
  // 18. 充电过流保护值 (0.1A)
  final int chargeOcp;
  // 19. 单体过压保护电压 (mV)
  final int cellOvp;
  // 20. 单体过放保护电压 (mV)
  final int cellUvp;
  // 21. 充电高温保护值 (1°C, offset +40)
  final int chargeOtp;
  // 22. 放电高温保护值 (1°C, offset +40)
  final int dischargeOtp;
  // 23. 最大允许充电电流 (1A)
  final int maxChargeCurrent;
  // 24. 最大允许放电电流 (1A)
  final int maxDischargeCurrent;
  // 25. 硬件版本
  final int hardwareVersion;
  // 26. 软件版本
  final int softwareVersion;

  const BmsData({
    this.deviceSerial = '',
    this.totalVoltage = 0,
    this.current = 0,
    this.soc = 0,
    this.workState = 0,
    this.maxCellVoltage = 0,
    this.minCellVoltage = 0,
    this.maxTemp = 40,
    this.minTemp = 40,
    this.mosTemp = 40,
    this.remainCapacity = 0,
    this.ratedCapacity = 0,
    this.cycleCount = 0,
    this.cellCount = 0,
    this.switchStatus = 0,
    this.faultFlags = 0,
    this.dischargeOcp = 0,
    this.chargeOcp = 0,
    this.cellOvp = 0,
    this.cellUvp = 0,
    this.chargeOtp = 40,
    this.dischargeOtp = 40,
    this.maxChargeCurrent = 0,
    this.maxDischargeCurrent = 0,
    this.hardwareVersion = 0,
    this.softwareVersion = 0,
  });

  // ---------- 便捷访问方法 ----------

  double get totalVoltageV => totalVoltage;
  double get currentA => current;

  double get maxCellVoltageV => maxCellVoltage / 1000.0;
  double get minCellVoltageV => minCellVoltage / 1000.0;
  int get cellVoltageDiffMv => maxCellVoltage - minCellVoltage;

  double get maxTempC => maxTemp - 40.0;
  double get minTempC => minTemp - 40.0;
  double get mosTempC => mosTemp - 40.0;

  double get remainCapacityAh => remainCapacity / 1000.0;
  double get ratedCapacityAh => ratedCapacity / 10.0;

  bool get chargeMosOn => (switchStatus & 0x01) != 0;
  bool get dischargeMosOn => (switchStatus & 0x02) != 0;
  bool get preDischargeMosOn => (switchStatus & 0x04) != 0;

  double get dischargeOcpA => dischargeOcp / 10.0;
  double get chargeOcpA => chargeOcp / 10.0;
  double get maxChargeCurrentA => maxChargeCurrent.toDouble();
  double get maxDischargeCurrentA => maxDischargeCurrent.toDouble();
  double get cellOvpV => cellOvp / 1000.0;
  double get cellUvpV => cellUvp / 1000.0;
  double get chargeOtpC => (chargeOtp - 40).toDouble();
  double get dischargeOtpC => (dischargeOtp - 40).toDouble();

  String get workStateText {
    switch (workState) {
      case 0x01:
        return 'charging';
      case 0x02:
        return 'discharging';
      default:
        return 'standby';
    }
  }

  String get hardwareVersionStr => 'V${hardwareVersion > 0 ? hardwareVersion : "-"}';
  String get softwareVersionStr => 'V${softwareVersion > 0 ? softwareVersion : "-"}';

  static const Map<int, String> faultBitNames = {
    0: 'dischargeOverCurrent',
    1: 'chargeOverCurrent',
    2: 'dischargeHighTemp',
    3: 'dischargeMosHighTemp',
    4: 'chargeHighTemp',
    5: 'chargeLowTemp',
    6: 'dischargeLowTemp',
    7: 'shortCircuit',
    8: 'cellOverVoltage',
    9: 'cellUnderVoltage',
    13: 'afeDisabled',
    20: 'dischargeOverCurrent3',
    28: 'totalUnderVoltage',
    29: 'totalOverVoltage',
    30: 'dischargeOverCurrent4',
    31: 'chargeOverCurrent2',
  };


  List<String> get activeFaults {
    final faults = <String>[];
    faultBitNames.forEach((bit, key) {
      if ((faultFlags & (1 << bit)) != 0) {
        faults.add(key);
      }
    });
    return faults;
  }

  bool get hasFault => activeFaults.isNotEmpty;
}
