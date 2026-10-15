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

class QuickIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback action;
  const QuickIcon({super.key, required this.icon, required this.color, required this.label, required this.action});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: action,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(18)),
          child: Icon(icon, color: color, size: 25),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, maxLines: 2,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
            fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

/// Dashboard metric card. Values always use the theme's onSurface color
/// rather than the accent shade, so they stay readable in either mode.
class StatTile extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  const StatTile({super.key, required this.title, required this.value,
    required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tintedSurface = Color.alphaBlend(
      color.withValues(alpha: dark ? .15 : .075), palette.surface);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: tintedSurface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: palette.outlineVariant.withValues(alpha: dark ? .7 : .65)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.onSurfaceVariant, fontSize: 11.7,
              fontWeight: FontWeight.w700, height: 1.2))),
          const SizedBox(width: 5),
          Container(width: 34, height: 34,
            decoration: BoxDecoration(
              color: Color.alphaBlend(color.withValues(alpha: dark ? .20 : .13), palette.surface),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: dark ? palette.onSurface : color, size: 19)),
        ]),
        SizedBox(width: double.infinity, child: FittedBox(
          alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
          child: Text(value, maxLines: 1,
            style: TextStyle(color: palette.onSurface, fontSize: 21,
              fontWeight: FontWeight.w900, letterSpacing: -.65)))),
      ]),
    );
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
