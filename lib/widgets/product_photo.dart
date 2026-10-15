import 'dart:io';
import 'package:flutter/material.dart';
import '../services/product_photos.dart';

class ProductPhoto extends StatelessWidget {
  final String filename;
  final double size;
  final double radius;
  const ProductPhoto({super.key, required this.filename, this.size = 58, this.radius = 15});

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size,
    child: ClipRRect(borderRadius: BorderRadius.circular(radius),
      child: FutureBuilder<File?>(future: ProductPhotos.file(filename), builder: (ctx, snap) {
        final file = snap.data;
        if (file == null) return Container(color: const Color(0xFFE8F1FF),
          child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0875E8)));
        return Image.file(file, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
      })),
  );
}
