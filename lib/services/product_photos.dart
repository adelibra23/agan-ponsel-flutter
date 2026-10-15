import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Files are stored in private Android app documents; only a basename enters SQLite.
/// Never trust an external filesystem path obtained from a backup.
class ProductPhotos {
  ProductPhotos._();
  static final _filename = RegExp(r'^product_[0-9a-z_]+\.(jpg|jpeg|png|webp)$');

  static bool validName(String value) => _filename.hasMatch(value);

  static Future<Directory> directory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'product_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File?> file(String name) async {
    if (!validName(name)) return null;
    final dir = await directory();
    final target = File(p.join(dir.path, name));
    return await target.exists() ? target : null;
  }

  static Future<String?> pick(ImageSource source) async {
    final image = await ImagePicker().pickImage(source: source,
      maxWidth: 1200, maxHeight: 1200, imageQuality: 78);
    if (image == null) return null;
    final dir = await directory();
    final suffix = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    final name = 'product_${DateTime.now().microsecondsSinceEpoch}_$suffix.jpg';
    final dst = File(p.join(dir.path, name));
    await File(image.path).copy(dst.path);
    if (await dst.length() > 3 * 1024 * 1024) {
      await dst.delete();
      throw StateError('Foto melebihi 3 MB; pilih foto berukuran lebih kecil.');
    }
    return name;
  }
}
