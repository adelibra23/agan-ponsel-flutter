import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agan_ponsel/widgets/premium_cash_card.dart';

void main() {
  test('Eight cash card presets use unique stable IDs and 3 gradient stops', () {
    expect(cashCardPresets.length, 8);
    expect(cashCardPresets.map((preset) => preset.id).toSet().length, 8);
    for (final preset in cashCardPresets) {
      expect(preset.colors.length, 3);
      expect(preset.title.isNotEmpty, true);
    }
    expect(cashCardPreset('unknown').id, 'signature');
  });

  test('Card preferences are persisted and start with balance hidden', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final old = await CashCardSettings.read();
    expect(old.style, 'signature');
    expect(old.compact, false);
    expect(old.visible, false);

    await CashCardSettings.setStyle('obsidian');
    await CashCardSettings.setCompact(true);
    await CashCardSettings.setVisible(true);
    final newSettings = await CashCardSettings.read();
    expect(newSettings.style, 'obsidian');
    expect(newSettings.compact, true);
    expect(newSettings.visible, true);
  });

  test('Unknown card style is rejected', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await expectLater(CashCardSettings.setStyle('nonexistent'),
      throwsArgumentError);
  });
}
