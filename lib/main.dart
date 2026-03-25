import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'models/bms_data.dart';
import 'services/bms_ble_service.dart';
import 'screens/bluetooth_scan_screen.dart';
import 'screens/battery_info_screen.dart';
import 'screens/battery_detail_screen.dart';
import 'screens/about_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLocalizations _loc = AppLocalizations();

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF4DA8DA);
    const lightBlue = Color(0xFFE8F4FD);

    return MaterialApp(
      title: _loc.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
          primary: primaryBlue,
          surface: const Color(0xFFF5FAFF),
          onSurface: const Color(0xFF1A2B3C),
        ),
        scaffoldBackgroundColor: lightBlue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A2B3C),
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2B3C),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: primaryBlue.withValues(alpha: 0.12),
          elevation: 3,
          shadowColor: primaryBlue.withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryBlue,
              );
            }
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.grey[500],
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: primaryBlue, size: 24);
            }
            return IconThemeData(color: Colors.grey[400], size: 24);
          }),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      home: HomeScreen(loc: _loc, onLanguageChanged: () => setState(() {})),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final AppLocalizations loc;
  final VoidCallback onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.loc,
    required this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final BmsBleService _bleService = BmsBleService();
  BmsData _bmsData = const BmsData();

  AppLocalizations get loc => widget.loc;

  void _onDataUpdate(BmsData data) {
    if (mounted) setState(() => _bmsData = data);
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }

  String get _currentTitle {
    switch (_currentIndex) {
      case 0: return loc.navBluetooth;
      case 1: return loc.navBatteryInfo;
      case 2: return loc.navBatteryDetail;
      case 3: return loc.navAbout;
      default: return loc.appTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_currentTitle)),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          BluetoothScanScreen(
            bleService: _bleService,
            loc: loc,
            onDataUpdate: _onDataUpdate,
          ),
          BatteryInfoScreen(bmsData: _bmsData, loc: loc),
          BatteryDetailScreen(bmsData: _bmsData, loc: loc),
          AboutScreen(
            loc: loc,
            onLanguageChanged: () {
              widget.onLanguageChanged();
              setState(() {});
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.bluetooth_searching),
            selectedIcon: const Icon(Icons.bluetooth_connected),
            label: loc.navBluetooth,
          ),
          NavigationDestination(
            icon: const Icon(Icons.battery_std_outlined),
            selectedIcon: const Icon(Icons.battery_std),
            label: loc.navBatteryInfo,
          ),
          NavigationDestination(
            icon: const Icon(Icons.analytics_outlined),
            selectedIcon: const Icon(Icons.analytics),
            label: loc.navBatteryDetail,
          ),
          NavigationDestination(
            icon: const Icon(Icons.info_outline),
            selectedIcon: const Icon(Icons.info),
            label: loc.navAbout,
          ),
        ],
      ),
    );
  }
}
