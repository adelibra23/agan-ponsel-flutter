import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One locally stored shop logo. No image is uploaded or shared automatically.
class StoreBrand {
  StoreBrand._();
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static const maxBytes = 2 * 1024 * 1024;

  static Future<File> _target() async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(root.path, 'agan_brand'));
    if (!await folder.exists()) await folder.create(recursive: true);
    return File(p.join(folder.path, 'logo.image'));
  }

  static Future<File?> get logo async {
    final f = await _target();
    return await f.exists() ? f : null;
  }

  static Future<List<int>?> backupBytes() async {
    final current = await logo;
    if (current == null) return null;
    if (await current.length() > maxBytes) throw StateError('Logo toko melebihi 2 MB');
    return current.readAsBytes();
  }

  static Future<bool> pickLogo() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 900, maxHeight: 900, imageQuality: 75);
    if (image == null) return false;
    final bytes = await File(image.path).readAsBytes();
    await restoreBytes(bytes);
    return true;
  }

  static bool validBytes(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) return false;
    // Do not accept arbitrary files disguised as images.
    final isPng = bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e && bytes[3] == 0x47;
    final isJpg = bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    final isWebp = bytes.length >= 12 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF'
      && String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    return isPng || isJpg || isWebp;
  }

  static Future<void> restoreBytes(List<int> bytes) async {
    if (!validBytes(bytes)) {
      throw const FormatException('Logo harus JPG, PNG atau WebP maksimal 2 MB');
    }
    final target = await _target();
    final staging = File('${target.path}.tmp');
    await staging.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await FileImage(target).evict();
      await target.delete();
    }
    await staging.rename(target.path);
    revision.value++;
  }

  static Future<void> removeLogo() async {
    final target = await _target();
    if (await target.exists()) {
      await FileImage(target).evict();
      await target.delete();
    }
    revision.value++;
  }
}
