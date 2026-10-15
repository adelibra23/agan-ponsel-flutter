import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'core/database.dart';
import 'core/format.dart';
import 'widgets/identity.dart';
import 'screens/dashboard.dart';
import 'screens/pos.dart';
import 'screens/inventory.dart';
import 'screens/services.dart';
import 'screens/others.dart';
import 'screens/barcode_scanner.dart';
import 'screens/security/pin_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(AganApp(initialDark: prefs.getBool('dark_mode') ?? false));
}

class AganApp extends StatefulWidget {
  final bool initialDark;
  const AganApp({super.key, required this.initialDark});
  @override
  State<AganApp> createState() => _AganAppState();
}

class _AganAppState extends State<AganApp> {
  late bool dark = widget.initialDark;
  Future<void> changeTheme(bool value) async {
    setState(() => dark = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'AGAN PONSEL',
    theme: aganTheme(Brightness.light),
    darkTheme: aganTheme(Brightness.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, navigator) => PinGate(child: navigator ?? const SizedBox.shrink()),
    home: SplashGate(dark: dark, onThemeChanged: changeTheme),
  );
}

class AppShell extends StatefulWidget {
  final bool dark;
  final ValueChanged<bool> onThemeChanged;
  const AppShell({super.key, required this.dark, required this.onThemeChanged});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;
  int refresh = 0;
  static const titles = ['Beranda', 'Kasir', 'Produk & Stok', 'Service HP', 'Menu Lainnya'];
  void select(int tab) => setState(() { selected = tab; refresh++; });
  void open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => page));
    if (mounted) setState(() => refresh++);
  }

  Future<void> quickScan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const BarcodeScannerScreen()));
    if (!mounted || code == null) return;
    final matched = await AppDatabase.byBarcode(code);
    if (!mounted) return;
    if (matched != null) {
      open(Scaffold(appBar: AppBar(title: const Text('Kasir • hasil scan')),
        body: PosScreen(initialBarcode: code)));
    } else {
      open(Scaffold(appBar: AppBar(title: const Text('Produk belum terdaftar')),
        body: InventoryScreen(initialBarcode: code)));
      notify(context, 'Barcode $code belum tersedia, silakan tambah produk.');
    }
  }

  void alerts() async {
    final products = await AppDatabase.products();
    if (!mounted) return;
    final low = products.where((p) => p.stock <= p.minStock).toList();
    if (low.isEmpty) {
      notify(context, 'Semua stok masih di atas batas minimum.');
    } else {
      open(InventoryScreen(lowOnly: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = <Widget>[
      DashboardScreen(key: ValueKey('dash$refresh'), navigate: select, open: open),
      PosScreen(key: ValueKey('pos$refresh')),
      InventoryScreen(key: ValueKey('inv$refresh')),
      ServicesScreen(key: ValueKey('svc$refresh')),
      MoreScreen(key: ValueKey('more$refresh'), open: open, dark: isDark,
        onThemeChanged: widget.onThemeChanged),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Theme.of(context).scaffoldBackgroundColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Theme.of(context).colorScheme.surface,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(bottom: false, child: Column(children: [
          BrandHeader(
            section: titles[selected], subheading: titles[selected],
            onSearch: () => select(2), onAlerts: alerts, onScan: quickScan,
          ),
          Expanded(child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(.045, .025), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey('$selected-$refresh'), child: pages[selected]),
          )),
          AnimatedBottomBar(index: selected, onSelected: select),
        ])),
      ),
    );
  }
}


class SplashGate extends StatefulWidget {
  final bool dark;
  final ValueChanged<bool> onThemeChanged;
  const SplashGate({super.key, required this.dark, required this.onThemeChanged});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  bool shown = true;
  late final AnimationController enter = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 850));
  @override
  void initState() {
    super.initState();
    enter.forward();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => shown = false);
    });
  }
  @override
  void dispose() { enter.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!shown) return AppShell(dark: widget.dark, onThemeChanged: widget.onThemeChanged);
    return AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0635B7), brandBlue, Color(0xFF079FF3)])),
        child: Center(child: FadeTransition(opacity: CurvedAnimation(
          parent: enter, curve: Curves.easeOut),
          child: ScaleTransition(scale: Tween<double>(begin: .8, end: 1).animate(
            CurvedAnimation(parent: enter, curve: Curves.easeOutBack)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const AnimatedBrandMark(size: 106),
              const SizedBox(height: 24),
              const Text('AGAN PONSEL', style: TextStyle(color: Colors.white,
                fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
              const SizedBox(height: 7),
              Text('OFFLINE STORE MANAGER', style: TextStyle(
                color: Colors.white.withOpacity(.8), fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 2.1)),
            ]),
          ),
        )),
      ),
    ),
  );
  }
}
