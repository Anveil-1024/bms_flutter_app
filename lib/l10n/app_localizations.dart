import 'package:flutter/material.dart';

enum AppLanguage { zh, en }

class AppLocalizations extends ChangeNotifier {
  AppLanguage _language = AppLanguage.zh;

  AppLanguage get language => _language;

  void setLanguage(AppLanguage lang) {
    _language = lang;
    notifyListeners();
  }

  String get appTitle => _t('BMS 电池管理', 'BMS Battery Manager');

  // Bottom nav
  String get navBluetooth => _t('蓝牙搜索', 'Bluetooth');
  String get navBatteryInfo => _t('电池信息', 'Battery');
  String get navBatteryDetail => _t('详细信息', 'Details');
  String get navAbout => _t('关于', 'About');

  // Bluetooth scan
  String get btStatusInit => _t('请开启蓝牙并点击扫描', 'Turn on Bluetooth and tap scan');
  String get btTurnOn => _t('请先打开手机蓝牙', 'Please turn on Bluetooth');
  String get btReady => _t('点击「扫描」搜索 BMS 设备', 'Tap "Scan" to search BMS devices');
  String get btScanning => _t('正在扫描…', 'Scanning…');
  String get btNoDevice => _t('未发现设备，可重试', 'No devices found, try again');
  String get btSelectDevice => _t('请选择要连接的 BMS 设备', 'Select a BMS device to connect');
  String get btConnecting => _t('正在连接…', 'Connecting…');
  String get btConnected => _t('已连接，正在查询数据…', 'Connected, querying data…');
  String get btDisconnected => _t('已断开，可重新扫描', 'Disconnected, scan again');
  String get btScanBtn => _t('扫描 BMS 设备', 'Scan BMS Devices');
  String get btScanningBtn => _t('扫描中…', 'Scanning…');
  String get btDeviceList => _t('扫描到的设备', 'Discovered Devices');
  String get btSignal => _t('信号', 'Signal');
  String get btConnect => _t('连接', 'Connect');
  String get btDisconnect => _t('断开', 'Disconnect');
  String get btDevice => _t('设备', 'Device');
  String btConnectingTo(String name) => _t('正在连接 $name…', 'Connecting to $name…');
  String btScanError(String e) => _t('扫描异常: $e', 'Scan error: $e');
  String btConnectError(String e) => _t('连接失败: $e', 'Connection failed: $e');
  String btUnavailable(String e) => _t('蓝牙不可用: $e', 'Bluetooth unavailable: $e');

  // Battery info - basic
  String get deviceSerial => _t('设备序列号', 'Device Serial');
  String get totalVoltage => _t('总电压', 'Total Voltage');
  String get currentLabel => _t('电流', 'Current');
  String get soc => _t('电量 SOC', 'SOC');
  String get workState => _t('工作状态', 'Work State');
  String get workStateStandby => _t('待机', 'Standby');
  String get workStateCharging => _t('充电中', 'Charging');
  String get workStateDischarging => _t('放电中', 'Discharging');

  // Battery info - cell voltage
  String get maxCellVoltage => _t('最高单体电压', 'Max Cell Voltage');
  String get minCellVoltage => _t('最低单体电压', 'Min Cell Voltage');
  String get cellVoltageDiff => _t('单体压差', 'Cell Voltage Diff');

  // Battery info - temperature
  String get temperatureSection => _t('温度信息', 'Temperature');
  String get maxTemp => _t('最高温度', 'Max Temp');
  String get minTemp => _t('最低温度', 'Min Temp');
  String get mosTemp => _t('MOS 温度', 'MOS Temp');

  // Battery info - capacity
  String get remainCapacity => _t('剩余容量', 'Remain Cap.');
  String get ratedCapacity => _t('额定容量', 'Rated Cap.');
  String get cycleCount => _t('循环次数', 'Cycle Count');
  String get cellCount => _t('电芯串数', 'Cell Count');

  // Battery info - MOS
  String get switchStatusSection => _t('开关状态', 'Switch Status');
  String get chargeMos => _t('充电 MOS', 'Charge MOS');
  String get dischargeMos => _t('放电 MOS', 'Discharge MOS');
  String get preDischargeMos => _t('预放 MOS', 'Pre-dis MOS');
  String get mosOn => _t('导通', 'ON');
  String get mosOff => _t('断开', 'OFF');

  // Battery info - electrical
  String get electricalSection => _t('电气信息', 'Electrical');
  String get voltageSection => _t('电压信息', 'Voltage Info');
  String get capacitySection => _t('容量信息', 'Capacity Info');
  String get basicInfoSection => _t('基本信息', 'Basic Info');

  // Battery detail - protection params
  String get protectionSection => _t('保护参数', 'Protection Parameters');
  String get dischargeOcp => _t('一级放电过流保护', 'Discharge OCP (Level 1)');
  String get chargeOcp => _t('充电过流保护', 'Charge OCP');
  String get cellOvp => _t('单体过压保护', 'Cell OVP');
  String get cellUvp => _t('单体过放保护', 'Cell UVP');
  String get chargeOtp => _t('充电高温保护', 'Charge OTP');
  String get dischargeOtp => _t('放电高温保护', 'Discharge OTP');
  String get maxChargeCurrent => _t('最大允许充电电流', 'Max Charge Current');
  String get maxDischargeCurrent => _t('最大允许放电电流', 'Max Discharge Current');

  // Battery detail - fault
  String get faultSection => _t('故障信息', 'Fault Info');
  String get noFault => _t('无故障', 'No Fault');
  String get versionSection => _t('版本信息', 'Version Info');
  String get hardwareVersion => _t('硬件版本', 'Hardware Version');
  String get softwareVersion => _t('软件版本', 'Software Version');

  String faultName(String key) {
    const zhMap = {
      'dischargeOverCurrent': '放电过流保护',
      'chargeOverCurrent': '充电过流保护',
      'dischargeHighTemp': '电芯放电高温保护',
      'dischargeMosHighTemp': '放电MOS高温保护',
      'chargeHighTemp': '电芯充电高温保护',
      'chargeLowTemp': '电芯充电低温保护',
      'dischargeLowTemp': '电芯放电低温保护',
      'shortCircuit': '短路保护',
      'cellOverVoltage': '过充保护（单体过压）',
      'cellUnderVoltage': '过放保护（单体欠压）',
      'afeDisabled': 'AFE失效保护',
      'dischargeOverCurrent3': '放电过流3级',
      'totalUnderVoltage': '总压欠压保护',
      'totalOverVoltage': '总压过压保护',
      'dischargeOverCurrent4': '放电过流4级',
      'chargeOverCurrent2': '充电过流2级',
    };
    const enMap = {
      'dischargeOverCurrent': 'Discharge Overcurrent',
      'chargeOverCurrent': 'Charge Overcurrent',
      'dischargeHighTemp': 'Discharge High Temp',
      'dischargeMosHighTemp': 'Discharge MOS High Temp',
      'chargeHighTemp': 'Charge High Temp',
      'chargeLowTemp': 'Charge Low Temp',
      'dischargeLowTemp': 'Discharge Low Temp',
      'shortCircuit': 'Short Circuit',
      'cellOverVoltage': 'Cell Over-voltage',
      'cellUnderVoltage': 'Cell Under-voltage',
      'afeDisabled': 'AFE Disabled',
      'dischargeOverCurrent3': 'Discharge Overcurrent L3',
      'totalUnderVoltage': 'Total Under-voltage',
      'totalOverVoltage': 'Total Over-voltage',
      'dischargeOverCurrent4': 'Discharge Overcurrent L4',
      'chargeOverCurrent2': 'Charge Overcurrent L2',
    };
    final map = _language == AppLanguage.zh ? zhMap : enMap;
    return map[key] ?? key;
  }

  String workStateLabel(String key) {
    switch (key) {
      case 'charging':
        return workStateCharging;
      case 'discharging':
        return workStateDischarging;
      default:
        return workStateStandby;
    }
  }

  // About
  String get aboutTitle => _t('关于', 'About');
  String get languageSetting => _t('语言设置', 'Language');
  String get chinese => _t('中文', 'Chinese');
  String get english => _t('英文', 'English');
  String get logoPlaceholder => _t('Logo 展示区域', 'Logo Display Area');
  String get version => _t('版本', 'Version');

  String _t(String zh, String en) => _language == AppLanguage.zh ? zh : en;
}
