import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database.dart';
import '../core/format.dart';

/// Visual presets only: none of these cards represents a bank account.
class CashCardPreset {
  final String id;
  final String title;
  final String subtitle;
  final List<Color> colors;

  const CashCardPreset(this.id, this.title, this.subtitle, this.colors);
}

const cashCardPresets = <CashCardPreset>[
  CashCardPreset('signature', 'Signature Blue', 'Biru elegan',
    [Color(0xFF0A214B), Color(0xFF0759D8), Color(0xFF29A6F1)]),
  CashCardPreset('obsidian', 'Obsidian Black', 'Hitam premium',
    [Color(0xFF101218), Color(0xFF262D3E), Color(0xFF48556A)]),
  CashCardPreset('aurora', 'Aurora Violet', 'Ungu futuristik',
    [Color(0xFF19194E), Color(0xFF563DB4), Color(0xFFB45AD6)]),
  CashCardPreset('emerald', 'Emerald Elite', 'Hijau eksklusif',
    [Color(0xFF083E3C), Color(0xFF08796E), Color(0xFF1EC9A6)]),
  CashCardPreset('ocean', 'Ocean Sapphire', 'Biru laut',
    [Color(0xFF052D46), Color(0xFF087AA7), Color(0xFF37C4CD)]),
  CashCardPreset('rose', 'Rose Gold', 'Mawar mewah',
    [Color(0xFF632948), Color(0xFFA34C75), Color(0xFFDA9A91)]),
  CashCardPreset('royal', 'Royal Indigo', 'Indigo modern',
    [Color(0xFF172250), Color(0xFF3856B5), Color(0xFF658ED6)]),
  CashCardPreset('graphite', 'Graphite Silver', 'Abu-abu minimalis',
    [Color(0xFF262F3A), Color(0xFF485866), Color(0xFF728694)]),
];

CashCardPreset cashCardPreset(String id) {
  for (final preset in cashCardPresets) {
    if (preset.id == id) return preset;
  }
  return cashCardPresets.first;
}

class CashCardAppearance {
  final String style;
  final bool compact;
  final bool visible;

  const CashCardAppearance({
    this.style = 'signature',
    this.compact = false,
    this.visible = false,
  });
}

/// Non-sensitive presentation settings persisted on the device. The balance
/// visibility preference is intentionally excluded from portable backup.
class CashCardSettings {
  static const styleKey = 'cash_card_style';
  static const densityKey = 'cash_card_density';
  static const visibilityKey = 'cash_balance_visible';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Future<CashCardAppearance> read() async {
    final prefs = await SharedPreferences.getInstance();
    return CashCardAppearance(
      style: cashCardPreset(prefs.getString(styleKey) ?? '').id,
      compact: prefs.getString(densityKey) == 'compact',
      visible: prefs.getBool(visibilityKey) ?? false,
    );
  }

  static Future<void> setStyle(String id) async {
    if (!cashCardPresets.any((preset) => preset.id == id)) {
      throw ArgumentError.value(id, 'id', 'Tema kartu tidak tersedia');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(styleKey, id);
    revision.value += 1;
  }

  static Future<void> setCompact(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(densityKey, value ? 'compact' : 'regular');
    revision.value += 1;
  }

  static Future<void> setVisible(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(visibilityKey, value);
    revision.value += 1;
  }
}

/// Miniature theme swatch: deliberately contains no real financial data.
class CashCardThemePreview extends StatelessWidget {
  final CashCardPreset preset;
  final bool selected;
  const CashCardThemePreview({super.key, required this.preset, this.selected = false});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(begin: Alignment.topLeft,
        end: Alignment.bottomRight, colors: preset.colors),
      border: Border.all(color: selected
        ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2.5),
    ),
    child: Padding(padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 16),
          const Spacer(),
          Icon(selected ? Icons.check_circle_rounded : Icons.auto_awesome_rounded,
            size: 16, color: Colors.white),
        ]),
        const Spacer(),
        const Text('Rp ••••••••', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 4),
        Text(preset.title.toUpperCase(), maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 9,
            fontWeight: FontWeight.w800, letterSpacing: .6)),
      ])),
  );
}

/// Shared between the Beranda dashboard and Dompet Kas Toko. Changing the
/// preset in settings refreshes all live card instances via [revision].
class PremiumCashCard extends StatefulWidget {
  final VoidCallback? onOpen;
  final VoidCallback? onCustomize;
  const PremiumCashCard({super.key, this.onOpen, this.onCustomize});

  @override
  State<PremiumCashCard> createState() => _PremiumCashCardState();
}

class _PremiumCashCardState extends State<PremiumCashCard> {
  late Future<CashCardAppearance> appearance;
  late Future<int> balance;

  @override
  void initState() {
    super.initState();
    appearance = CashCardSettings.read();
    balance = AppDatabase.cashBalance();
    CashCardSettings.revision.addListener(_reloadAppearance);
  }

  void _reloadAppearance() {
    if (mounted) setState(() => appearance = CashCardSettings.read());
  }

  @override
  void dispose() {
    CashCardSettings.revision.removeListener(_reloadAppearance);
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => balance = AppDatabase.cashBalance());
    await balance;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CashCardAppearance>(
    future: appearance,
    builder: (context, snap) {
      final settings = snap.data ?? const CashCardAppearance();
      final preset = cashCardPreset(settings.style);
      final compact = settings.compact;
      return ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 20 : 25),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: preset.colors)),
          child: Stack(children: [
            Positioned(top: -105, right: -74,
              child: IgnorePointer(child: Container(width: 235, height: 235,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: .10), width: 38))))),
            Positioned(bottom: -71, right: 50,
              child: IgnorePointer(child: Container(width: 150, height: 150,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .065))))),
            Padding(padding: EdgeInsets.fromLTRB(19, compact ? 14 : 19,
              17, compact ? 12 : 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: compact ? 31 : 38, height: compact ? 31 : 38,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: .16)),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 21)),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('AGAN PONSEL  /  KAS TOKO',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 10.5,
                      fontWeight: FontWeight.w800, letterSpacing: .65))),
                  IconButton(tooltip: settings.visible ? 'Sembunyikan saldo' : 'Lihat saldo',
                    onPressed: () async {
                      try {
                        await CashCardSettings.setVisible(!settings.visible);
                      } catch (error) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal mengganti tampilan saldo: $error')));
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .12)),
                    icon: Icon(settings.visible ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded, color: Colors.white, size: 19)),
                ]),
                SizedBox(height: compact ? 9 : 15),
                Text('SALDO KAS TERCATAT',
                  style: TextStyle(color: Colors.white.withValues(alpha: .87),
                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                const SizedBox(height: 5),
                FutureBuilder<int>(future: balance, builder: (context, total) {
                  final label = settings.visible
                    ? total.hasError ? 'Saldo tidak tersedia'
                      : total.hasData ? rupiah(total.data!) : 'Menghitung...'
                    : 'Rp ••••••••';
                  return AnimatedSwitcher(duration: const Duration(milliseconds: 240),
                    child: SizedBox(width: double.infinity,
                      key: ValueKey('${settings.visible}-$label'),
                      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 24 : 29,
                          letterSpacing: -.9))));
                }),
                SizedBox(height: compact ? 9 : 14),
                Row(children: [
                  Expanded(child: Text('BUKU KAS  •  BUKAN SALDO BANK',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: .83),
                      fontSize: 9.5, fontWeight: FontWeight.w600))),
                  IconButton(tooltip: 'Muat ulang saldo', onPressed: _refresh,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white)),
                  if (widget.onCustomize != null) IconButton(
                    tooltip: 'Pilih kartu premium', onPressed: widget.onCustomize,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.palette_outlined, size: 19, color: Colors.white)),
                  if (widget.onOpen != null) IconButton(
                    tooltip: 'Buka Dompet Kas', onPressed: widget.onOpen,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 19, color: Colors.white)),
                ]),
              ])),
          ]),
        ),
      );
    },
  );
}
