import 'dart:io';
import 'package:flutter/material.dart';
import '../services/store_brand.dart';
import '../core/theme.dart';

class StoreLogo extends StatelessWidget {
  final double size;
  const StoreLogo({super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: StoreBrand.revision,
    builder: (context, version, _) => FutureBuilder<File?>(
      future: StoreBrand.logo,
      builder: (context, snap) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: Container(key: ValueKey('logo-$version-${snap.data?.path ?? ''}'),
          height: size, width: size,
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(size * .27),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .09), blurRadius: 11)]),
          clipBehavior: Clip.antiAlias,
          child: snap.data == null
            ? Center(child: Text('AG', style: TextStyle(
                color: brandBlue, fontWeight: FontWeight.w900, fontSize: size * .34,
                letterSpacing: -1.7)))
            : Image.file(snap.data!, fit: BoxFit.cover,
                errorBuilder: (ctx, error, stackTrace) => const Icon(Icons.storefront_rounded, color: brandBlue)),
        ),
      ),
    ),
  );
}
