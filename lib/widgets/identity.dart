import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

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
  final VoidCallback onSearch;
  final VoidCallback onAlerts;
  const BrandHeader({super.key, required this.section, required this.subheading,
    required this.onSearch, required this.onAlerts});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF0639BA), brandBlue, Color(0xFF048FEE)]),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
    ),
    child: Stack(children: [
      Positioned(right: -25, top: -70, child: Container(height: 185, width: 185,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.08), width: 24)))),
      Positioned(left: 155, bottom: -65, child: Container(height: 128, width: 128,
        decoration: BoxDecoration(shape: BoxShape.circle, color: brandCyan.withOpacity(.09)))),
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 12, 16), child: Row(children: [
        const AnimatedBrandMark(size: 53),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AGAN PONSEL', maxLines: 1, style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -.5, fontSize: 20)),
          const SizedBox(height: 2),
          AnimatedSwitcher(duration: const Duration(milliseconds: 240),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
            child: Text(section == 'Beranda' ? 'HP • SERVICE • DIGITAL' : subheading,
              key: ValueKey(section), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(.84), fontSize: 10.5, letterSpacing: .8))),
        ])),
        _HeaderButton(icon: Icons.search_rounded, onPressed: onSearch),
        const SizedBox(width: 2),
        _HeaderButton(icon: Icons.notifications_none_rounded, onPressed: onAlerts),
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
    style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(.12)),
    color: Colors.white,
    onPressed: onPressed, icon: Icon(icon, size: 23),
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
                gradient: active ? const LinearGradient(colors: [brandBlue, Color(0xFF12A7F3)]) : null,
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
              color: active ? (dark ? const Color(0xFF7BAEFF) : brandBlue) : Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ));
      }))),
    );
  }
}
