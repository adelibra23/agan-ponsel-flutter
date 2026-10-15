import 'dart:convert';

import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database.dart';
import '../core/format.dart';

class AganPrinter {
  AganPrinter._();
  static const String addressKey = 'printer_mac';
  static const String paperKey = 'printer_paper_mm';

  static Future<bool> requestAccess() async {
    if (await PrintBluetoothThermal.isPermissionBluetoothGranted) return true;
    final permission = await Permission.bluetoothConnect.request();
    return permission.isGranted;
  }

  static Future<List<BluetoothInfo>> paired() async {
    if (!await requestAccess()) throw StateError('Izin perangkat Bluetooth belum diberikan');
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw StateError('Aktifkan Bluetooth di pengaturan Android');
    }
    return PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<bool> connect(String mac) async {
    if (!await requestAccess()) throw StateError('Izin Bluetooth ditolak');
    if (!await PrintBluetoothThermal.bluetoothEnabled) throw StateError('Bluetooth HP belum aktif');
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(addressKey, mac);
    }
    return ok;
  }

  static Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }

  static Future<bool> get connected async => PrintBluetoothThermal.connectionStatus;

  static Future<int> get paperSize async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(paperKey) ?? 58;
  }

  static Future<void> setPaperSize(int millimeters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(paperKey, millimeters == 80 ? 80 : 58);
  }

  static String _latinSafe(String value) => value
      .replaceAll('•', '-')
      .replaceAll('×', 'x')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('é', 'e')
      .replaceAll(RegExp(r'[^\x20-\x7E\n\r]'), '?');

  static String _center(String value, int width) {
    final text = _latinSafe(value);
    if (text.length >= width) return text;
    final pad = (width - text.length) ~/ 2;
    return '${' ' * pad}$text';
  }

  static String _pair(String left, String right, int width) {
    final a = _latinSafe(left);
    final b = _latinSafe(right);
    if (a.length + b.length + 1 > width) {
      return '$a\n${' ' * (width - b.length > 0 ? width - b.length : 0)}$b';
    }
    return '$a${' ' * (width - a.length - b.length)}$b';
  }

  static String _wrap(String text, int width) {
    final s = _latinSafe(text).trim();
    if (s.isEmpty) return '';
    final out = <String>[];
    var current = '';
    for (final word in s.split(RegExp(r'\s+'))) {
      if (word.length > width) {
        if (current.isNotEmpty) { out.add(current); current = ''; }
        for (var i = 0; i < word.length; i += width) {
          out.add(word.substring(i, i + width < word.length ? i + width : word.length));
        }
        continue;
      }
      if (current.isEmpty) { current = word; }
      else if (current.length + 1 + word.length <= width) { current = '$current $word'; }
      else { out.add(current); current = word; }
    }
    if (current.isNotEmpty) out.add(current);
    return out.join('\n');
  }

  static Future<void> printText(String content) async {
    if (!await connected) {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString(addressKey);
      if (address == null || !await connect(address)) {
        throw StateError('Printer belum terhubung. Pilih printer di Pengaturan.');
      }
    }
    // ESC @, left align, safe text, feed paper. No cutter command: not all
    // cheap Bluetooth thermal printers implement automatic cutting.
    final bytes = <int>[
      27, 64, 27, 97, 0,
      ...latin1.encode(_latinSafe(content)),
      10, 10, 10,
    ];
    if (!await PrintBluetoothThermal.writeBytes(bytes)) {
      throw StateError('Printer tidak mengonfirmasi pengiriman data');
    }
  }

  static Future<String> _header() async {
    final prefs = await SharedPreferences.getInstance();
    final shop = prefs.getString('local_shop_name') ?? 'AGAN PONSEL';
    final address = prefs.getString('local_shop_address') ?? '';
    final footer = prefs.getString('local_receipt_footer') ?? 'Terima kasih sudah berbelanja!';
    final width = (await paperSize) == 80 ? 48 : 32;
    return '${_center(shop, width)}\n${_center(address, width)}\n${'-' * width}\n'
        '__FOOTER__${_latinSafe(footer)}';
  }

  static Future<void> printSale(SaleResult sale) async {
    final h = await _header();
    final split = h.split('__FOOTER__');
    final width = (await paperSize) == 80 ? 48 : 32;
    final out = StringBuffer(split.first)
      ..writeln('STRUK PENJUALAN')
      ..writeln('No: ${sale.code}')
      ..writeln('${dateLabel(sale.createdAt)} ${timeLabel(sale.createdAt)}')
      ..writeln('-' * width);
    for (final line in sale.items) {
      out.writeln(_wrap(line.product.name, width));
      out.writeln(_pair('${line.quantity} x ${rupiah(line.product.price)}', rupiah(line.total), width));
    }
    out..writeln('-' * width)
      ..writeln(_pair('Subtotal', rupiah(sale.subtotal), width))
      ..writeln(_pair('Diskon', rupiah(sale.discount), width))
      ..writeln(_pair('TOTAL', rupiah(sale.total), width))
      ..writeln(_pair('Bayar', rupiah(sale.paid), width))
      ..writeln(_pair('Kembali', rupiah(sale.change), width))
      ..writeln('Metode: ${sale.method}')
      ..writeln('-' * width)
      ..writeln(_center(split.last, width));
    await printText(out.toString());
  }

  static Future<void> printService(Map<String, Object?> service) async {
    final h = await _header();
    final split = h.split('__FOOTER__');
    final width = (await paperSize) == 80 ? 48 : 32;
    final cost = (service['fee'] as num?)?.toInt() ?? 0;
    final deposit = (service['deposit'] as num?)?.toInt() ?? 0;
    final out = StringBuffer(split.first)
      ..writeln(_center('TIKET SERVICE HP', width))
      ..writeln('Tiket: SRV-${service['id']}')
      ..writeln('Tanggal: ${dateLabel('${service['created_at']}')}')
      ..writeln('-' * width)
      ..writeln(_wrap('Pelanggan: ${service['customer']}', width))
      ..writeln(_wrap('Telepon: ${service['phone']}', width))
      ..writeln(_wrap('Perangkat: ${service['device']}', width))
      ..writeln(_wrap('IMEI: ${service['imei'] ?? '-'}', width))
      ..writeln(_wrap('Keluhan: ${service['issue']}', width))
      ..writeln(_wrap('Kelengkapan: ${service['accessories'] ?? '-'}', width))
      ..writeln(_wrap('Status: ${service['status']}', width))
      ..writeln('-' * width)
      ..writeln(_pair('Estimasi', rupiah(cost), width))
      ..writeln(_pair('DP / Bayar', rupiah(deposit), width))
      ..writeln(_pair('Sisa', rupiah(cost - deposit), width))
      ..writeln('-' * width)
      ..writeln(_wrap('Harap simpan tiket ini sebagai bukti penerimaan.', width))
      ..writeln(_center(split.last, width));
    await printText(out.toString());
  }
}
