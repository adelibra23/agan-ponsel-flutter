import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../services/printer_service.dart';
import '../services/receivable_receipt_service.dart';
import '../services/store_brand.dart';
import '../widgets/kit.dart';

/// Template PNG yang dapat disimpan dan dibagikan ke WhatsApp. Capture selalu
/// dilakukan dari widget yang benar-benar sudah dirender, bukan gambar palsu.
class ReceivableReceiptPreviewScreen extends StatefulWidget {
  final int receivableId;
  const ReceivableReceiptPreviewScreen({super.key, required this.receivableId});

  @override
  State<ReceivableReceiptPreviewScreen> createState() => _ReceivableReceiptPreviewScreenState();
}

class _ReceivableReceiptPreviewScreenState extends State<ReceivableReceiptPreviewScreen> {
  final previewKey = GlobalKey();
  ReceivableReceiptData? receipt;
  Uint8List? logo;
  ReceivableReceiptTemplate template = ReceivableReceiptTemplate.orbit;
  bool busy = false;
  String? problem;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final results = await Future.wait<Object?>([
        ReceivableReceiptService.load(widget.receivableId),
        ReceivableReceiptService.selectedTemplate(),
        StoreBrand.backupBytes(),
      ]);
      if (!mounted) return;
      final loadedLogo = results[2] as List<int>?;
      if (loadedLogo != null) {
        await precacheImage(MemoryImage(Uint8List.fromList(loadedLogo)), context);
      }
      if (!mounted) return;
      setState(() {
        receipt = results[0] as ReceivableReceiptData;
        template = results[1] as ReceivableReceiptTemplate;
        logo = loadedLogo == null ? null : Uint8List.fromList(loadedLogo);
      });
    } catch (e) {
      if (mounted) setState(() => problem = '$e');
    }
  }

  Future<void> chooseTemplate(ReceivableReceiptTemplate next) async {
    if (busy) return;
    setState(() => template = next);
    await ReceivableReceiptService.setTemplate(next);
  }

  Future<Uint8List> capturePng() async {
    // Biarkan rendering template selesai sebelum menangkap gambar PNG.
    await WidgetsBinding.instance.endOfFrame;
    final boundary = previewKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('Pratinjau nota belum siap. Coba lagi setelah gambar muncul.');
    }
    // Batasi dimensi gambar supaya nota panjang tidak kehabisan memori GPU.
    final ratio = (6200 / boundary.size.height).clamp(1.0, 2.3).toDouble();
    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Gagal membuat gambar nota');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  Future<void> savePng() async {
    final data = receipt;
    if (data == null || busy) return;
    setState(() => busy = true);
    try {
      final png = await capturePng();
      final result = await FilePicker.saveFile(
        dialogTitle: 'Simpan Gambar Nota Piutang',
        fileName: '${data.number}-${DateTime.now().millisecondsSinceEpoch}.png',
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: png,
      );
      if (result != null) {
        await ReceivableReceiptService.logAction(data.receivable.id, 'image_saved', template);
        if (mounted) notify(context, 'Nota PNG berhasil disimpan ke lokasi pilihan');
      }
    } catch (e) {
      if (mounted) notify(context, 'Gagal menyimpan gambar: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> shareImage() async {
    final data = receipt;
    if (data == null || busy) return;
    setState(() => busy = true);
    try {
      final png = await capturePng();
      final temporary = await getTemporaryDirectory();
      final file = File(p.join(temporary.path, '${data.number}-${DateTime.now().millisecondsSinceEpoch}.png'));
      await file.writeAsBytes(png, flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(
        title: 'Nota Piutang ${data.number}',
        text: 'Nota piutang ${data.shopName} untuk ${data.receivable.customer}. '
          'Sisa tagihan ${rupiah(data.receivable.remaining)}. '
          'Silakan simpan gambar sebagai arsip pembayaran.',
        files: [XFile(file.path, mimeType: 'image/png')],
      ));
      // Hanya mencatat layar Bagikan sudah dibuka, bukan WA sudah mengirim.
      await ReceivableReceiptService.logAction(data.receivable.id,
        'share_sheet_opened', template);
    } catch (e) {
      if (mounted) notify(context, 'Gagal membuka menu Bagikan: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> printThermal() async {
    final data = receipt;
    if (data == null || busy) return;
    setState(() => busy = true);
    try {
      await AganPrinter.printReceivable(data);
      await ReceivableReceiptService.logAction(data.receivable.id,
        'print_dispatched', template);
      if (mounted) notify(context, 'Perintah cetak dikirim. Periksa hasil pada printer thermal.');
    } catch (e) {
      if (mounted) notify(context, 'Gagal mengirim nota ke printer: $e. Hubungkan printer lewat Pengaturan.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = receipt;
    return Scaffold(
      appBar: AppBar(title: const Text('Nota Digital Piutang')),
      body: problem != null
        ? EmptyView(icon: Icons.error_outline, title: 'Nota gagal dimuat', subtitle: problem!)
        : data == null
          ? const ScreenLoading()
          : SafeArea(child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 3),
              child: SizedBox(height: 43, child: ListView(scrollDirection: Axis.horizontal,
                children: [
                  for (final t in ReceivableReceiptTemplate.values) Padding(
                    padding: const EdgeInsets.only(right: 9),
                    child: ChoiceChip(
                      selected: template == t,
                      label: Text(t.label),
                      onSelected: busy ? null : (_) => chooseTemplate(t),
                    ),
                  ),
                ],
              )),
            ),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
              child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 390),
                child: RepaintBoundary(
                  key: previewKey,
                  child: ReceiptCanvas(data: data, template: template, logoBytes: logo),
                ),
              )),
            )),
            Material(elevation: 7, color: Theme.of(context).colorScheme.surface,
              child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: busy ? null : savePng,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Simpan PNG'),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton.icon(
                      onPressed: busy ? null : shareImage,
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Bagikan Gambar'),
                    )),
                  ]),
                  const SizedBox(height: 7),
                  SizedBox(width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : printThermal,
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Print Thermal Bluetooth (58 / 80 mm)'),
                    ),
                  ),
                  if (busy) const LinearProgressIndicator(minHeight: 2),
                ]),
              ),
            ),
          ])),
    );
  }
}

class _Palette {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  const _Palette(this.primary, this.secondary, this.background, this.surface,
      this.ink, this.muted);
}

_Palette _palette(ReceivableReceiptTemplate t) => switch (t) {
  ReceivableReceiptTemplate.orbit => const _Palette(Color(0xFF0749B5), Color(0xFF13A5EB),
    Color(0xFFF3F7FF), Colors.white, Color(0xFF1E3048), Color(0xFF64748B)),
  ReceivableReceiptTemplate.white => const _Palette(Color(0xFF203247), Color(0xFF72899E),
    Color(0xFFF8FAFC), Colors.white, Color(0xFF253443), Color(0xFF6F8090)),
  ReceivableReceiptTemplate.midnight => const _Palette(Color(0xFF151D54), Color(0xFF5757C9),
    Color(0xFFEDF0FF), Colors.white, Color(0xFF17203F), Color(0xFF64708B)),
  ReceivableReceiptTemplate.emerald => const _Palette(Color(0xFF08746E), Color(0xFF10BC9F),
    Color(0xFFEAF9F5), Colors.white, Color(0xFF153E40), Color(0xFF547F7B)),
};

/// Seluruh konten nota berada dalam satu RepaintBoundary, termasuk baris
/// rincian dan catatan, sehingga PNG tidak hanya menangkap layar terlihat.
class ReceiptCanvas extends StatelessWidget {
  final ReceivableReceiptData data;
  final ReceivableReceiptTemplate template;
  final Uint8List? logoBytes;
  const ReceiptCanvas({super.key, required this.data, required this.template, this.logoBytes});

  @override
  Widget build(BuildContext context) {
    final pal = _palette(template);
    final debt = data.receivable;
    const white = Colors.white;
    final items = data.lines.isEmpty
      ? [ReceivableLine(description: debt.description, qty: 1, unitPrice: debt.amount)]
      : data.lines;
    final statusColor = debt.isPaid ? const Color(0xFF0A9D74)
      : debt.paid > 0 ? const Color(0xFFEAB050) : const Color(0xFFF36D6D);

    return Container(
      decoration: BoxDecoration(
        color: pal.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: pal.primary.withValues(alpha: .13),
          blurRadius: 18, offset: const Offset(0, 7))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(21, 24, 21, 25),
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [pal.primary, pal.secondary],
          )),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 51, height: 51,
                decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: logoBytes == null
                  ? Center(child: Text('AG', style: TextStyle(
                      fontSize: 23, fontWeight: FontWeight.w900, color: pal.primary)))
                  : Image.memory(logoBytes!, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.shopName.toUpperCase(), maxLines: 2,
                    style: const TextStyle(color: white, fontWeight: FontWeight.w900,
                      fontSize: 18, letterSpacing: -.3)),
                  const SizedBox(height: 2),
                  const Text('NOTA PIUTANG DIGITAL', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2, color: Color(0xFFE1F3FF))),
                ])),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('No. ${data.number}',
                style: const TextStyle(color: white, fontWeight: FontWeight.w800, fontSize: 12))),
              DecoratedBox(decoration: BoxDecoration(
                color: statusColor, borderRadius: BorderRadius.circular(9)),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  child: Text(data.status, style: const TextStyle(
                    color: white, fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(18, 19, 18, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeading('INFORMASI PELANGGAN', pal),
            _caption('Nama pelanggan', debt.customer, pal),
            _caption('Nomor WhatsApp', debt.phone.isEmpty ? '-' : debt.phone, pal),
            _caption('Tanggal transaksi', dateLabel(debt.createdAt), pal),
            _caption('Jatuh tempo', dateLabel(debt.dueDate), pal),
            const SizedBox(height: 15),
            _sectionHeading('RINCIAN BARANG / JASA', pal),
            Container(decoration: BoxDecoration(color: pal.surface,
              borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                Container(color: pal.primary.withValues(alpha: .07),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(children: [
                    Expanded(flex: 5, child: _tableTitle('Barang / Jasa', pal)),
                    Expanded(flex: 2, child: _tableTitle('Qty', pal, center: true)),
                    Expanded(flex: 4, child: _tableTitle('Total', pal, right: true)),
                  ]),
                ),
                for (var i = 0; i < items.length; i++) ...[
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 5, child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(items[i].description, maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: pal.ink,
                              fontWeight: FontWeight.w700, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text('@ ${rupiah(items[i].unitPrice)}',
                            style: TextStyle(color: pal.muted, fontSize: 9)),
                        ])),
                      Expanded(flex: 2, child: Text('${items[i].qty}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: pal.ink, fontSize: 10))),
                      Expanded(flex: 4, child: Text(rupiah(items[i].total),
                        textAlign: TextAlign.right,
                        style: TextStyle(color: pal.ink,
                          fontSize: 10, fontWeight: FontWeight.w800))),
                    ]),
                  ),
                  if (i + 1 < items.length) Divider(height: 1, thickness: .5,
                    color: pal.background),
                ],
              ]),
            ),
            const SizedBox(height: 15),
            Container(padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: pal.surface,
                borderRadius: BorderRadius.circular(13)),
              child: Column(children: [
                _moneyRow('Total tagihan', rupiah(debt.amount), pal),
                const SizedBox(height: 9),
                _moneyRow('Sudah dibayar', rupiah(debt.paid), pal),
                Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: pal.background)),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SISA PIUTANG', style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w900, color: pal.ink)),
                    Flexible(child: Text(rupiah(debt.remaining),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 20, letterSpacing: -.5,
                        fontWeight: FontWeight.w900, color: pal.primary))),
                  ]),
              ]),
            ),
            if (debt.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _sectionHeading('CATATAN', pal),
              Text(debt.notes, maxLines: 5, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: pal.ink, fontSize: 11, height: 1.4)),
            ],
            const SizedBox(height: 19),
            Container(width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pal.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                Text(data.footer, maxLines: 3, textAlign: TextAlign.center,
                  style: TextStyle(color: pal.ink, fontSize: 10, height: 1.4)),
                const SizedBox(height: 7),
                if (data.address.isNotEmpty) Text(data.address,
                  textAlign: TextAlign.center, maxLines: 2,
                  style: TextStyle(color: pal.muted, fontSize: 9)),
                if (data.shopPhone.isNotEmpty) Text('Hubungi: ${data.shopPhone}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.muted, fontSize: 9)),
                const SizedBox(height: 5),
                Text('Petugas: ${data.admin}', style: TextStyle(
                  color: pal.muted, fontSize: 9)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionHeading(String label, _Palette pal) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(label, style: TextStyle(color: pal.primary,
      fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5)),
  );

  Widget _caption(String label, String value, _Palette pal) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 123, child: Text(label, style: TextStyle(
        color: pal.muted, fontSize: 10))),
      Expanded(child: Text(value, textAlign: TextAlign.right,
        style: TextStyle(color: pal.ink, fontSize: 11, fontWeight: FontWeight.w700))),
    ]),
  );

  Widget _tableTitle(String label, _Palette pal, {bool center = false, bool right = false}) =>
    Text(label, textAlign: right ? TextAlign.right : center ? TextAlign.center : TextAlign.left,
      style: TextStyle(color: pal.primary, fontWeight: FontWeight.w800, fontSize: 9));

  Widget _moneyRow(String title, String value, _Palette pal) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: TextStyle(color: pal.muted, fontSize: 11)),
      Text(value, style: TextStyle(color: pal.ink, fontSize: 11,
        fontWeight: FontWeight.w800)),
    ],
  );
}
