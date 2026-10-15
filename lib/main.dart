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
import 'screens/receivables.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(AganApp(initialDark: prefs.getBool('dark_mode') ?? false,
    initialTemplate: prefs.getString('app_template_style') ?? 'Biru Orbit')); 
}

class AganApp extends StatefulWidget {
  final bool initialDark;
  final String initialTemplate;
  const AganApp({super.key, required this.initialDark, required this.initialTemplate});
  @override
  State<AganApp> createState() => _AganAppState();
}

class _AganAppState extends State<AganApp> {
  late bool dark = widget.initialDark;
  late String template = widget.initialTemplate;
  Future<void> changeTemplate(String value) async {
    setState(() => template = value);
    await (await SharedPreferences.getInstance()).setString('app_template_style', value);
  }
  Future<void> changeTheme(bool value) async {
    setState(() => dark = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'AGAN PONSEL',
    theme: aganTheme(Brightness.light, template: template),
    darkTheme: aganTheme(Brightness.dark, template: template),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, navigator) => PinGate(child: navigator ?? const SizedBox.shrink()),
    home: SplashGate(dark: dark, template: template,
      onThemeChanged: changeTheme, onTemplateChanged: changeTemplate),
  );
}

class AppShell extends StatefulWidget {
  final String template;
  final ValueChanged<String> onTemplateChanged;
  final bool dark;
  final ValueChanged<bool> onThemeChanged;
  const AppShell({super.key, required this.dark, required this.template,
    required this.onThemeChanged, required this.onTemplateChanged});
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

  void alerts() => open(const ReminderCenterScreen());

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = <Widget>[
      DashboardScreen(key: ValueKey('dash$refresh'), navigate: select, open: open),
      PosScreen(key: ValueKey('pos$refresh')),
      InventoryScreen(key: ValueKey('inv$refresh')),
      ServicesScreen(key: ValueKey('svc$refresh')),
      MoreScreen(key: ValueKey('more$refresh'), open: open, dark: isDark,
        onThemeChanged: widget.onThemeChanged, template: widget.template,
        onTemplateChanged: widget.onTemplateChanged),
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
            template: widget.template,
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
  final String template;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<String> onTemplateChanged;
  const SplashGate({super.key, required this.dark, required this.template,
    required this.onThemeChanged, required this.onTemplateChanged});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

/// Intro AG Motion: halo berdenyut, logo orbit berputar, wordmark bertahap.
class _SplashGateState extends State<SplashGate> with TickerProviderStateMixin {
  bool shown = true;
  late final AnimationController entrance = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1150))..forward();
  late final AnimationController pulse = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2100))..repeat(reverse: true);
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2450), () {
      if (mounted) setState(() => shown = false);
    });
  }
  @override
  void dispose() { entrance.dispose(); pulse.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!shown) return AppShell(dark: widget.dark, template: widget.template,
      onThemeChanged: widget.onThemeChanged, onTemplateChanged: widget.onTemplateChanged);
    final gradient = templateGradient(widget.template);
    final curved = CurvedAnimation(parent: entrance, curve: Curves.easeOutCubic);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(animation: pulse, builder: (context, child) =>
            Container(width: 215 + pulse.value * 28, height: 215 + pulse.value * 28,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .09 + .08 * pulse.value), width: 2),
                boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: .10 * pulse.value),
                  blurRadius: 60 + pulse.value * 30, spreadRadius: 12)]))),
          AnimatedBuilder(animation: pulse, builder: (context, child) =>
            Container(width: 174 + pulse.value * 14, height: 174 + pulse.value * 14,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .16), width: 1)))),
          FadeTransition(opacity: curved,
            child: ScaleTransition(scale: Tween<double>(begin: .58, end: 1).animate(
              CurvedAnimation(parent: entrance, curve: Curves.elasticOut)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const AnimatedBrandMark(size: 116),
                const SizedBox(height: 35),
                const Text('AGAN PONSEL', style: TextStyle(color: Colors.white,
                  fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                const SizedBox(height: 9),
                const Text('KASIR  •  SERVICE  •  INVENTARIS',
                  style: TextStyle(color: Colors.white70, fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 28),
                AnimatedBuilder(animation: entrance, builder: (context, child) =>
                  ClipRRect(borderRadius: BorderRadius.circular(12),
                    child: SizedBox(width: 110, child: LinearProgressIndicator(
                      value: entrance.value, minHeight: 3,
                      backgroundColor: Colors.white24, color: Colors.white)))),
              ]))),
        ]),
      )),
    );
  }
}
