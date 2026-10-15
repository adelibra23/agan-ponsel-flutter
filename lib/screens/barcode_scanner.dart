import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera barcode scan returns a SKU / EAN / QR string; no network needed.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});
  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA,
      BarcodeFormat.upcE, BarcodeFormat.code128, BarcodeFormat.code39,
      BarcodeFormat.code93, BarcodeFormat.itf, BarcodeFormat.qrCode],
  );
  final manual = TextEditingController();
  bool busy = false;

  void finish(String? code) {
    final value = code?.trim() ?? '';
    if (busy || !mounted || value.isEmpty) return;
    busy = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() { controller.dispose(); manual.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF071C36),
    appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white,
      title: const Text('Scan barcode produk'),
      actions: [IconButton(tooltip: 'Senter', icon: const Icon(Icons.flash_on_outlined),
        onPressed: () => controller.toggleTorch())]),
    body: SafeArea(child: Column(children: [
      const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Text('Arahkan kamera ke barcode pada kemasan. Pemindaian langsung melalui kamera.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))),
      Expanded(child: Padding(padding: const EdgeInsets.all(18), child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(fit: StackFit.expand, children: [
          MobileScanner(controller: controller, onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final value = barcode.rawValue;
              if (value != null && value.isNotEmpty) { finish(value); return; }
            }
          }),
          IgnorePointer(child: Center(child: Container(width: 235, height: 155,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF75E4FF), width: 3)),
            child: const Center(child: Icon(Icons.qr_code_scanner_rounded,
              color: Colors.white70, size: 51))))),
        ]),
      ))),
      Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 22), child: Row(children: [
        Expanded(child: TextField(controller: manual, keyboardType: TextInputType.text,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: 'Atau masukkan kode manual',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.keyboard, color: Colors.white70),
            filled: true, fillColor: Colors.white12,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))))),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: () => finish(manual.text),
          icon: const Icon(Icons.arrow_forward_rounded)),
      ])),
    ])),
  );
}
