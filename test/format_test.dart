import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/core/format.dart';

void main() {
  test('Rupiah formatting', () {
    expect(rupiah(15000), 'Rp15.000');
    expect(rupiah(0), 'Rp0');
  });

  test('Nominal validation', () {
    expect(nonNegative('5.000'), 5000);
    expect(nonNegative('0'), 0);
    expect(nonNegative('-1'), isNull);
    expect(nonNegative('abc'), isNull);
  });
}
