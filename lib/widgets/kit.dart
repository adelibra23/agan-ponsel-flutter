import 'package:flutter/material.dart';
import '../core/theme.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  final String? subtitle;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 1),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 4, height: subtitle == null ? 19 : 31,
          decoration: BoxDecoration(color: colors.primary,
            borderRadius: BorderRadius.circular(5))),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: TextStyle(color: colors.onSurface,
            fontSize: 16.5, fontWeight: FontWeight.w900, letterSpacing: -.25)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: TextStyle(color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500, fontSize: 12.2)),
          ],
        ])),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Surface({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .022), blurRadius: 16, offset: const Offset(0, 5))],
    ),
    child: child,
  );
}

class Pill extends StatelessWidget {
  final String label;
  final Color color;
  const Pill(this.label, {super.key, this.color = brandBlue});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(30)),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
  );
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyView({super.key, required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(21), decoration: BoxDecoration(
        shape: BoxShape.circle, color: brandBlue.withOpacity(.08)),
        child: Icon(icon, size: 35, color: brandBlue),
      ),
      const SizedBox(height: 16),
      Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ])),
  );
}

class PageIntro extends StatelessWidget {
  final String title;
  final String subtitle;
  const PageIntro(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 5),
      Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]),
  );
}

/// Clean Material 3 shortcuts with softer glass depth and feedback.
class QuickIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback action;
  const QuickIcon({super.key, required this.icon, required this.color,
    required this.label, required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: action, borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          Container(width: 55, height: 55,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft,
                end: Alignment.bottomRight, colors: [
                  color.withValues(alpha: .17),
                  color.withValues(alpha: .055)]),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: color.withValues(alpha: .15)),
              boxShadow: [BoxShadow(color: color.withValues(alpha: .08),
                blurRadius: 11, offset: const Offset(0, 5))]),
            child: Icon(icon, color: color, size: 25)),
          const SizedBox(height: 8),
          Text(label, maxLines: 2, textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11, fontWeight: FontWeight.w700)),
        ])),
    );
  }
}

/// Dashboard metric card. Values always use the theme's onSurface color
/// rather than the accent shade, so they stay readable in either mode.
/// BUILD30_DEPTH_TILES: layered translucent surfaces and soft elevation.
/// No tilt sensor, expensive continuous animation or altered financial data.
class StatTile extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  const StatTile({super.key, required this.title, required this.value,
    required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = Color.alphaBlend(
      color.withValues(alpha: dark ? .20 : .10), scheme.surface);
    final glow = Color.alphaBlend(
      color.withValues(alpha: dark ? .11 : .06), scheme.surface);
    return Semantics(label: '$title: $value', child: AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surface, base, glow]),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .65)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: dark ? .10 : .14),
            blurRadius: 20, spreadRadius: -5, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withValues(alpha: dark ? .16 : .045),
            blurRadius: 8, spreadRadius: -3, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(22),
        child: Stack(children: [
          Positioned(right: -20, top: -27, child: Container(width: 103,
            height: 103, decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .11), width: 17)))),
          Positioned(left: 12, right: 12, top: 1,
            child: Container(height: 1, color: Colors.white.withValues(
              alpha: dark ? .12 : .75))),
          Padding(padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant,
                      fontSize: 11.5, fontWeight: FontWeight.w800,
                      height: 1.15))),
                  const SizedBox(width: 5),
                  Container(width: 35, height: 35,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color.withValues(alpha: .92),
                          color.withValues(alpha: .72)]),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [BoxShadow(color: color.withValues(alpha: .22),
                        blurRadius: 8, offset: const Offset(0, 4))]),
                    child: Icon(icon, color: Colors.white, size: 18)),
                ]),
                SizedBox(width: double.infinity,
                  child: FittedBox(fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, maxLines: 1,
                      style: TextStyle(fontSize: 21, letterSpacing: -.6,
                        color: scheme.onSurface, fontWeight: FontWeight.w900)))),
              ])),
        ])),
    ));
  }
}

class ScreenLoading extends StatelessWidget {
  const ScreenLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
}

class SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchBox({super.key, required this.hint, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
    ),
  );
}

Future<T?> showAppSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
        child: SingleChildScrollView(child: child),
      ),
    );
