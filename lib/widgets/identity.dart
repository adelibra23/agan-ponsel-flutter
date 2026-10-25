import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import 'store_logo.dart';
import '../services/receivables_service.dart';

class AnimatedBrandMark extends StatefulWidget {
  final double size;
  const AnimatedBrandMark({super.key, this.size = 52});
  @override
  State<AnimatedBrandMark> createState() => _AnimatedBrandMarkState();
}

class _AnimatedBrandMarkState extends State<AnimatedBrandMark> with SingleTickerProviderStateMixin {
  late final AnimationController spin;
  @override
  void initState() {
    super.initState();
    spin = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }
  @override
  void dispose() { spin.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size, height: widget.size,
    child: AnimatedBuilder(animation: spin, builder: (context, _) => Stack(alignment: Alignment.center, children: [
      Container(
        width: widget.size * .80, height: widget.size * .80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.size * .27),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF8CEBFF), Colors.white, Color(0xFFDCE8FF)]),
          boxShadow: [BoxShadow(color: brandCyan.withOpacity(.3), blurRadius: 13, spreadRadius: 0)],
        ),
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.size * .27),
          child: Image.asset('assets/branding/agan_launcher.png',
            width: widget.size * .80, height: widget.size * .80, fit: BoxFit.cover)),
      ),
      Transform.rotate(
        angle: spin.value * math.pi * 2,
        child: CustomPaint(size: Size.square(widget.size), painter: _OrbitPainter()),
      ),
    ])),
  );
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final gradient = SweepGradient(colors: [Colors.transparent, brandCyan.withOpacity(.12),
      Colors.white, Colors.transparent], stops: const [0, .3, .8, 1]);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round..shader = gradient.createShader(rect);
    canvas.drawArc(rect, 0, math.pi * 1.5, false, paint);
    canvas.drawCircle(Offset(size.width - 3, size.height / 2), 2.7, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => false;
}

/// Minimal one-row header: no repeated slogan, decorative rings or duplicate
/// section banners. Search/scan/AI remain available through the quick menu.
class BrandHeader extends StatelessWidget {
  final String section;
  final String subheading;
  final String template;
  final VoidCallback onSearch;
  final VoidCallback onAlerts;
  final VoidCallback onScan;
  final VoidCallback onAgent;
  const BrandHeader({super.key, required this.section, required this.subheading,
    required this.template, required this.onSearch, required this.onAlerts,
    required this.onScan, required this.onAgent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: .75))),
      ),
      child: Row(children: [
        const StoreLogo(size: 36),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('AGAN PONSEL', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurface, fontSize: 16,
              fontWeight: FontWeight.w900, letterSpacing: -.3)),
          Text(section, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
        ])),
        IconButton(icon: const Icon(Icons.search_rounded), tooltip: 'Cari produk',
          onPressed: onSearch),
        FutureBuilder<ReceivableSummary>(
          future: ReceivablesService.summary(), builder: (ctx, snap) {
            final n = snap.data?.alertCount ?? 0;
            return Badge(isLabelVisible: n > 0, label: Text(n > 99 ? '99+' : '$n'),
              child: IconButton(tooltip: 'Notifikasi jatuh tempo',
                onPressed: onAlerts, icon: const Icon(Icons.notifications_none_rounded)));
          }),
        PopupMenuButton<String>(tooltip: 'Aksi cepat',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            if (value == 'scan') onScan();
            if (value == 'ai') onAgent();
            if (value == 'search') onSearch();
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'scan', child: ListTile(
              contentPadding: EdgeInsets.zero, leading: Icon(Icons.qr_code_scanner_rounded),
              title: Text('Scan Barcode'))),
            PopupMenuItem(value: 'ai', child: ListTile(
              contentPadding: EdgeInsets.zero, leading: Icon(Icons.auto_awesome_rounded),
              title: Text('AGANA AI'))),
          ]),
      ]),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _HeaderButton({required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) => IconButton(
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
    padding: const EdgeInsets.all(6),
    style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(.12)),
    color: Colors.white,
    onPressed: onPressed, icon: Icon(icon, size: 20),
  );
}

// BUILD30_MOTION_BOTTOM: sliding selection capsule, spring icons, semantic labels.
// All actual page states remain mounted in the existing IndexedStack.
class AnimatedBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelected;
  const AnimatedBottomBar({super.key, required this.index,
    required this.onSelected});

  static const labels = ['Beranda', 'Kasir', 'Produk', 'Service', 'Lainnya'];
  static const icons = [Icons.home_outlined, Icons.point_of_sale_outlined,
    Icons.inventory_2_outlined, Icons.handyman_outlined,
    Icons.apps_outlined];
  static const selectedIcons = [Icons.home_rounded, Icons.point_of_sale_rounded,
    Icons.inventory_2_rounded, Icons.handyman_rounded, Icons.apps_rounded];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 3),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: .5))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(
          alpha: dark ? .20 : .06), blurRadius: 19,
          offset: const Offset(0, -4))]),
      child: SafeArea(top: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / labels.length;
          return SizedBox(height: 63, child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 390),
              curve: Curves.easeOutCubic,
              left: index * tabWidth + (tabWidth - 54) / 2,
              top: 3, width: 54, height: 35,
              child: DecoratedBox(decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(begin: Alignment.topLeft,
                  end: Alignment.bottomRight, colors: [scheme.primary,
                    Color.lerp(scheme.primary, scheme.secondary, .35)!]),
                boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: .24),
                  blurRadius: 13, offset: const Offset(0, 5))]))),
            Row(children: List.generate(labels.length, (i) {
              final active = i == index;
              return Expanded(child: Semantics(
                button: true, selected: active, label: labels[i],
                child: InkWell(
                  onTap: () {
                    if (i != index) {
                      HapticFeedback.selectionClick();
                      onSelected(i);
                    }
                  },
                  borderRadius: BorderRadius.circular(17),
                  child: SizedBox(height: 63,
                    child: Column(mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: 39, child: Center(
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 310),
                            curve: Curves.easeOutBack,
                            scale: active ? 1.12 : .94,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation,
                                  child: FadeTransition(opacity: animation,
                                    child: child)),
                              child: Icon(active ? selectedIcons[i] : icons[i],
                                key: ValueKey('$i-$active'), size: 22,
                                color: active ? Colors.white
                                  : scheme.onSurfaceVariant))),
                        )),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: TextStyle(fontSize: 10,
                            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                            color: active ? scheme.primary
                              : scheme.onSurfaceVariant),
                          child: Text(labels[i], maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                      ])),
                  ),
                ),
              );
            })),
          ]));
        })),
    );
  }
}
