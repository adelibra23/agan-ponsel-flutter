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
        child: Text('AG', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -2,
          fontSize: widget.size * .32, color: brandBlue)),
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

class BrandHeader extends StatelessWidget {
  final String section;
  final String subheading;
  final String template;
  final VoidCallback onSearch;
  final VoidCallback onAlerts;
  final VoidCallback onScan;
  const BrandHeader({super.key, required this.section, required this.subheading, required this.template,
    required this.onSearch, required this.onAlerts, required this.onScan});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: templateGradient(template)),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
    ),
    child: Stack(children: [
      Positioned(right: -50, top: -88, child: Container(height: 188, width: 188,
        decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(.12), width: 31)))),
      Positioned(right: 82, bottom: -65, child: Container(height: 138, width: 138,
        decoration: BoxDecoration(shape: BoxShape.circle, color: brandCyan.withOpacity(.11)))),
      Padding(padding: const EdgeInsets.fromLTRB(15, 12, 12, 13), child: Column(children: [
        Row(children: [
          const StoreLogo(size: 46),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text('AGAN PONSEL', style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w900, letterSpacing: -.65, fontSize: 20))),
            const SizedBox(height: 4),
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 6, color: Color(0xFF5BFFBD)),
              SizedBox(width: 5),
              Text('TOKO DIGITAL • AGAN PONSEL', style: TextStyle(color: Colors.white70,
                fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .45)),
            ]),
          ])),
          _HeaderButton(icon: Icons.qr_code_scanner_rounded, onPressed: onScan),
          const SizedBox(width: 2),
          _HeaderButton(icon: Icons.search_rounded, onPressed: onSearch),
          const SizedBox(width: 2),
          FutureBuilder<ReceivableSummary>(
            future: ReceivablesService.summary(), builder: (context, snap) {
              final count = snap.data?.alertCount ?? 0;
              return Badge(
                isLabelVisible: count > 0,
                label: Text(count > 99 ? '99+' : '$count'),
                child: _HeaderButton(icon: Icons.notifications_none_rounded, onPressed: onAlerts),
              );
            }),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(width: 4, height: 17, decoration: BoxDecoration(
            color: brandCyan, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 9),
          Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 240),
            child: Text(section == 'Beranda' ? 'Dashboard • Kasir • Service • Inventaris' : subheading,
              key: ValueKey(section), style: const TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w700)))),
          const Icon(Icons.shield_rounded, color: Color(0xFF83F4DA), size: 15),
          const SizedBox(width: 4),
          const Text('Data lokal', style: TextStyle(fontSize: 10, color: Colors.white70)),
        ]),
      ])),
    ]),
  );
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

class AnimatedBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelected;
  const AnimatedBottomBar({super.key, required this.index, required this.onSelected});
  static const labels = ['Beranda', 'Kasir', 'Produk', 'Service', 'Lainnya'];
  static const icons = [Icons.space_dashboard_outlined, Icons.point_of_sale_rounded,
    Icons.inventory_2_outlined, Icons.build_outlined, Icons.grid_view_rounded];
  static const selectedIcons = [Icons.space_dashboard_rounded, Icons.point_of_sale_rounded,
    Icons.inventory_2_rounded, Icons.build_rounded, Icons.grid_view_rounded];
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(top: false, child: Row(children: List.generate(labels.length, (i) {
        final active = i == index;
        return Expanded(child: InkWell(
          onTap: () { HapticFeedback.selectionClick(); onSelected(i); },
          borderRadius: BorderRadius.circular(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic, height: 34, width: active ? 55 : 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: active ? LinearGradient(colors: [Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: .8)]) : null,
                color: active ? null : Colors.transparent,
                boxShadow: active ? [BoxShadow(color: brandBlue.withOpacity(.22), blurRadius: 10, offset: const Offset(0, 4))] : null,
              ),
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(active ? selectedIcons[i] : icons[i],
                  key: ValueKey(active), size: 22,
                  color: active ? Colors.white : (dark ? Colors.white60 : const Color(0xFF8894A7)))),
            ),
            const SizedBox(height: 4),
            Text(labels[i], maxLines: 1, style: TextStyle(
              fontSize: 10, fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ));
      }))),
    );
  }
}
