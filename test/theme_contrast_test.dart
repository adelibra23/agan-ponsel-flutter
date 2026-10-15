import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/core/theme.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + .05) / (darker + .05);
}

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    test('AGAN PONSEL text contrast $brightness', () {
      final theme = aganTheme(brightness);
      final colors = theme.colorScheme;
      expect(contrast(colors.onSurface, colors.surface), greaterThan(4.5));
      expect(contrast(colors.onSurfaceVariant, colors.surface), greaterThan(4.5));
      expect(theme.textTheme.titleLarge?.color, colors.onSurface);
      expect(theme.textTheme.bodySmall?.color, colors.onSurfaceVariant);
    });
  }
}
