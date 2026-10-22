import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'core/database.dart';
import 'services/background_jobs.dart';
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
import 'screens/agana_agent.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Do not leave the screen permanently blank if preferences fail to load.
  try {
    final prefs = await SharedPreferences.getInstance();
    final family = prefs.getString('app_font_family') ?? 'Roboto';
    aganFontFamily.value = appFontChoices.containsKey(family) ? family : 'Roboto';
    runApp(AganApp(initialDark: prefs.getBool('dark_mode') ?? false,
      initialTemplate: prefs.getString('app_template_style') ?? 'Biru Orbit'));
    // Scheduling must never block login/PIN or crash startup on failure.
    BackgroundJobs.init().catchError((Object _) {});
  } catch (error) {
    runApp(MaterialApp(debugShowCheckedModeBanner: false,
      home: Scaffold(body: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, size: 50),
          const SizedBox(height: 15),
          const Text('AGAN PONSEL belum bisa dibuka',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Pengaturan keamanan Android tidak dapat dibaca. '
            'Jangan hapus data aplikasi. Tutup dan buka kembali, '
            'lalu kirim laporan error jika masih gagal.',
            textAlign: TextAlign.center),
          const SizedBox(height: 14),
          SelectableText('$error', textAlign: TextAlign.center),
        ],
      )))))));
  }
}

class AganApp extends StatefulWidget {
  final bool initialDark;
  final String initialTemplate;
  const AganApp({super.key, required this.initialDark, required this.initialTemplate});
  @override
  State<AganApp> createState() => _AganAppState();
}

class _AganAppState extends State<AganApp> {
  @override
  void initState() {
    super.initState();
    aganFontFamily.addListener(_onFontChanged);
  }

  void _onFontChanged() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    aganFontFamily.removeListener(_onFontChanged);
    super.dispose();
  }

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
    home: AganStartupGate(dark: dark, template: template,
      onThemeChanged: changeTheme, onTemplateChanged: changeTemplate),
  );
}

/// Startup guard: check and repair the additive database schema before the
/// main dashboard starts querying it. Never deletes user records or resets PIN.
class AganStartupGate extends StatefulWidget {
  final bool dark;
  final String template;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<String> onTemplateChanged;
  const AganStartupGate({super.key, required this.dark, required this.template,
    required this.onThemeChanged, required this.onTemplateChanged});

  @override
  State<AganStartupGate> createState() => _AganStartupGateState();
}

class _AganStartupGateState extends State<AganStartupGate> {
  late Future<void> preparation;

  @override
  void initState() {
    super.initState();
    preparation = prepare();
  }

  Future<void> prepare() async {
    await AppDatabase.instance;
  }

  void retry() => setState(() => preparation = prepare());

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: preparation,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text('Menyiapkan AGAN PONSEL...'),
          ],
        )));
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Pemulihan AGAN PONSEL')),
          body: SafeArea(child: Center(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24), child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.storage_rounded, size: 48),
              const SizedBox(height: 16),
              Text('Data toko belum bisa dimuat',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text('Aplikasi tidak menghapus database maupun piutang. '
                'Coba lagi, dan jangan uninstall atau hapus data sebelum membuat cadangan.',
                textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi')),
              const SizedBox(height: 18),
              const Text('Rincian teknis (untuk laporan error):'),
              const SizedBox(height: 7),
              SelectableText('${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
              TextButton.icon(onPressed: () => Clipboard.setData(
                  ClipboardData(text: 'AGAN PONSEL database startup: ${snapshot.error}')),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Salin Error')),
            ],
          )))),
        );
      }
      return SplashGate(dark: widget.dark, template: widget.template,
        onThemeChanged: widget.onThemeChanged,
        onTemplateChanged: widget.onTemplateChanged);
    },
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
  // Keep all tab widgets mounted; switching tabs must not recreate their states.
  void select(int tab) {
    if (tab != selected) setState(() => selected = tab);
  }
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
      DashboardScreen(key: const PageStorageKey('tab-dashboard'),
        dataRevision: refresh, navigate: select, open: open),
      PosScreen(key: const PageStorageKey('tab-pos')),
      InventoryScreen(key: const PageStorageKey('tab-inventory')),
      ServicesScreen(key: const PageStorageKey('tab-services')),
      MoreScreen(key: const PageStorageKey('tab-more'), open: open, dark: isDark,
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
            onAgent: () => open(const AganaAgentScreen()),
            template: widget.template,
          ),
          // IndexedStack retains every tab State and its scroll position.
          // Transition of the bottom bar remains animated independently.
          Expanded(child: IndexedStack(index: selected, children: pages)),
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

/// AG Orbit Holographic: simulated 3D tilt + orbit parallax, fully Flutter.
/// Native Android keeps a matching static icon until the Flutter view is ready.
class _SplashGateState extends State<SplashGate> with TickerProviderStateMixin {
  bool showing = true;
  late final AnimationController intro = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1450))..forward();
  late final AnimationController orbit = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 3050), () {
      if (mounted) setState(() => showing = false);
    });
  }
  @override
  void dispose() { intro.dispose(); orbit.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!showing) return AppShell(dark: widget.dark, template: widget.template,
      onThemeChanged: widget.onThemeChanged,
      onTemplateChanged: widget.onTemplateChanged);
    final enter = CurvedAnimation(parent: intro, curve: Curves.easeOutCubic);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(backgroundColor: const Color(0xFF030A20),
        body: Stack(fit: StackFit.expand, children: [
          const DecoratedBox(decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment(-.15, -.28), radius: 1.2,
              colors: [Color(0xFF143A9E), Color(0xFF081B57), Color(0xFF030A20)]))),
          AnimatedBuilder(animation: orbit, builder: (context, _) => CustomPaint(
            painter: _AganCosmosPainter(orbit.value))),
          SafeArea(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(animation: Listenable.merge([intro, orbit]), builder: (context, _) {
              final rise = Curves.easeOutBack.transform(intro.value.clamp(0.0, 1.0).toDouble());
              return Opacity(opacity: intro.value.clamp(0.0, 1.0).toDouble(),
                child: Transform.translate(offset: Offset(0, 30 * (1 - rise)),
                  child: SizedBox(width: 274, height: 274,
                    child: Stack(alignment: Alignment.center, children: [
                      Container(width: 209, height: 209,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFF1ACBFF)
                            .withValues(alpha: .28 + .10 * math.sin(orbit.value * 2 * math.pi).abs()),
                            blurRadius: 48, spreadRadius: 17)])),
                      Transform(transform: Matrix4.identity()
                        ..setEntry(3, 2, .0010)
                        ..rotateY(math.sin(orbit.value * 2 * math.pi) * .17)
                        ..rotateX(math.cos(orbit.value * 2 * math.pi) * .09),
                        alignment: Alignment.center,
                        child: Image.asset('assets/branding/agan_launcher.png',
                          width: 182 * rise, height: 182 * rise,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) =>
                            const Icon(Icons.storefront_rounded,
                              color: Colors.white, size: 90))),
                      Transform.rotate(angle: orbit.value * math.pi * 2,
                        child: CustomPaint(size: const Size(258, 258),
                          painter: _HolographicRingPainter())),
                    ]))),
              );
            }),
            const SizedBox(height: 18),
            FadeTransition(opacity: enter,
              child: SlideTransition(position: Tween<Offset>(
                begin: const Offset(0, .35), end: Offset.zero).animate(enter),
                child: const Column(children: [
                  Text('AGAN PONSEL', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 29, letterSpacing: 2.1,
                      color: Colors.white, fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text('KASIR  •  SERVICE  •  MANAJEMEN TOKO',
                    style: TextStyle(fontSize: 10, letterSpacing: 1.5,
                      color: Color(0xFFB8D9FF), fontWeight: FontWeight.w700)),
                ]))),
            const SizedBox(height: 35),
            SizedBox(width: 108, child: AnimatedBuilder(animation: intro,
              builder: (context, _) => ClipRRect(borderRadius: BorderRadius.circular(30),
                child: LinearProgressIndicator(value: intro.value,
                  minHeight: 3, backgroundColor: const Color(0xFF294576),
                  color: const Color(0xFF50E9FF))))),
          ]))),
        ])),
    );
  }
}

class _HolographicRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, .39);
    final oval = Rect.fromCenter(center: Offset.zero,
      width: size.width * .99, height: size.height * 1.2);
    final p = Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(colors: [Colors.transparent,
        Color(0xFF05D3FF), Color(0xFFF1F8FF), Color(0xFF8B64FF),
        Colors.transparent]).createShader(oval);
    canvas.drawArc(oval, -.3, math.pi * 1.85, false, p);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _HolographicRingPainter old) => false;
}

class _AganCosmosPainter extends CustomPainter {
  final double frame;
  const _AganCosmosPainter(this.frame);
  @override
  void paint(Canvas canvas, Size size) {
    final star = Paint();
    for (var i = 0; i < 45; i++) {
      final x = (i * 73.47 + 21) % 101 / 101 * size.width;
      final y = (i * 53.17 + 37) % 97 / 97 * size.height;
      final alpha = (.14 + .28 * (1 + math.sin(i * .6 + frame * 2 * math.pi)) / 2);
      star.color = const Color(0xFF83E9FF).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), (i % 4 == 0 ? 1.9 : 1), star);
    }
    final middle = Offset(size.width / 2, size.height * .43);
    final glow = Paint()..color = const Color(0xFF038CFF).withValues(alpha: .07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 85);
    canvas.drawCircle(middle, 150, glow);
  }
  @override
  bool shouldRepaint(covariant _AganCosmosPainter old) => old.frame != frame;
}
