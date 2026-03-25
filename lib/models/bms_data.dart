class BmsData {
  final double voltageV;
  final double currentA;
  final int socPercent;

  final double cellTemperature;
  final double ambientTemperature;
  final double mosTemperature;

  final int cycleCount;
  final bool chargeMosOn;
  final bool dischargeMosOn;

  final double totalCellVoltage;
  final double cellVoltageDiff;
  final double maxCellVoltage;
  final double minCellVoltage;

  final Duration currentChargeInterval;
  final Duration maxChargeInterval;
  final Duration chargeRemainingTime;
  final Duration dischargeRemainingTime;

  const BmsData({
    this.voltageV = 0,
    this.currentA = 0,
    this.socPercent = 0,
    this.cellTemperature = 0,
    this.ambientTemperature = 0,
    this.mosTemperature = 0,
    this.cycleCount = 0,
    this.chargeMosOn = false,
    this.dischargeMosOn = false,
    this.totalCellVoltage = 0,
    this.cellVoltageDiff = 0,
    this.maxCellVoltage = 0,
    this.minCellVoltage = 0,
    this.currentChargeInterval = Duration.zero,
    this.maxChargeInterval = Duration.zero,
    this.chargeRemainingTime = Duration.zero,
    this.dischargeRemainingTime = Duration.zero,
  });

  BmsData copyWith({
    double? voltageV,
    double? currentA,
    int? socPercent,
    double? cellTemperature,
    double? ambientTemperature,
    double? mosTemperature,
    int? cycleCount,
    bool? chargeMosOn,
    bool? dischargeMosOn,
    double? totalCellVoltage,
    double? cellVoltageDiff,
    double? maxCellVoltage,
    double? minCellVoltage,
    Duration? currentChargeInterval,
    Duration? maxChargeInterval,
    Duration? chargeRemainingTime,
    Duration? dischargeRemainingTime,
  }) {
    return BmsData(
      voltageV: voltageV ?? this.voltageV,
      currentA: currentA ?? this.currentA,
      socPercent: socPercent ?? this.socPercent,
      cellTemperature: cellTemperature ?? this.cellTemperature,
      ambientTemperature: ambientTemperature ?? this.ambientTemperature,
      mosTemperature: mosTemperature ?? this.mosTemperature,
      cycleCount: cycleCount ?? this.cycleCount,
      chargeMosOn: chargeMosOn ?? this.chargeMosOn,
      dischargeMosOn: dischargeMosOn ?? this.dischargeMosOn,
      totalCellVoltage: totalCellVoltage ?? this.totalCellVoltage,
      cellVoltageDiff: cellVoltageDiff ?? this.cellVoltageDiff,
      maxCellVoltage: maxCellVoltage ?? this.maxCellVoltage,
      minCellVoltage: minCellVoltage ?? this.minCellVoltage,
      currentChargeInterval: currentChargeInterval ?? this.currentChargeInterval,
      maxChargeInterval: maxChargeInterval ?? this.maxChargeInterval,
      chargeRemainingTime: chargeRemainingTime ?? this.chargeRemainingTime,
      dischargeRemainingTime: dischargeRemainingTime ?? this.dischargeRemainingTime,
    );
  }
}
