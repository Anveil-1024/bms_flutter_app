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
  String get btConnected => _t('已连接，等待数据…', 'Connected, waiting for data…');
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

  // Battery info
  String get cellTemp => _t('电芯温度', 'Cell Temperature');
  String get ambientTemp => _t('环境温度', 'Ambient Temperature');
  String get mosTemp => _t('MOS 温度', 'MOS Temperature');
  String get soc => _t('SOC', 'SOC');
  String get current => _t('电流', 'Current');
  String get voltage => _t('电压', 'Voltage');
  String get cycleCount => _t('循环次数', 'Cycle Count');
  String get chargeMos => _t('充电 MOS', 'Charge MOS');
  String get dischargeMos => _t('放电 MOS', 'Discharge MOS');
  String get mosOn => _t('开启', 'ON');
  String get mosOff => _t('关闭', 'OFF');
  String get temperatureSection => _t('温度信息', 'Temperature');
  String get electricalSection => _t('电气信息', 'Electrical');

  // Battery detail
  String get totalCellVoltage => _t('电芯整组电压', 'Total Cell Voltage');
  String get cellVoltageDiff => _t('电芯压差', 'Cell Voltage Diff');
  String get maxCellVoltage => _t('电芯最大电压', 'Max Cell Voltage');
  String get minCellVoltage => _t('电芯最小电压', 'Min Cell Voltage');
  String get currentChargeInterval => _t('当前充电间隔', 'Current Charge Interval');
  String get maxChargeInterval => _t('最长充电间隔', 'Max Charge Interval');
  String get chargeRemaining => _t('充电剩余时间', 'Charge Remaining');
  String get dischargeRemaining => _t('放电剩余时间', 'Discharge Remaining');
  String get voltageSection => _t('电压信息', 'Voltage Info');
  String get timeSection => _t('时间信息', 'Time Info');

  // About
  String get aboutTitle => _t('关于', 'About');
  String get languageSetting => _t('语言设置', 'Language');
  String get chinese => _t('中文', 'Chinese');
  String get english => _t('英文', 'English');
  String get logoPlaceholder => _t('Logo 展示区域', 'Logo Display Area');
  String get version => _t('版本', 'Version');

  String _t(String zh, String en) => _language == AppLanguage.zh ? zh : en;
}
