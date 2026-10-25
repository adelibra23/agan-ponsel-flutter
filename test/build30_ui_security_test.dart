import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/widgets/kit.dart';
import 'package:agan_ponsel/widgets/identity.dart';
import 'package:agan_ponsel/services/biometric_security.dart';

void main() {
  testWidgets('Build30 summary cards have layered surfaces and readable metrics',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(
        width: 180, height: 125,
        child: StatTile(title: 'Penjualan', value: 'Rp125.000',
          color: Color(0xFF008F71), icon: Icons.shopping_bag_rounded),
      ))),
    ));
    expect(find.text('Penjualan'), findsOneWidget);
    expect(find.text('Rp125.000'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsWidgets);
  });

  testWidgets('Build30 moving navigation selection retains five destinations',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
      builder: (context, setLocal) => Scaffold(
        body: const Center(child: Text('Aktivitas Toko')),
        bottomNavigationBar: AnimatedBottomBar(index: selected,
          onSelected: (next) => setLocal(() => selected = next)),
      ),
    )));
    expect(find.byType(AnimatedPositioned), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Lainnya'), findsOneWidget);
    await tester.tap(find.text('Produk'));
    await tester.pumpAndSettle();
    expect(selected, 2);
  });

  test('Face preference is an independent device-only setting key', () {
    expect(BiometricSecurity.faceKey, isNot(BiometricSecurity.key));
    expect(BiometricSecurity.faceKey, contains('face'));
  });
}
