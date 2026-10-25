import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/services/store_plus_service.dart';

void main() {
  test('notes have bounded category and priority presets', () {
    expect(StorePlusService.categories, contains('Service'));
    expect(StorePlusService.categories, contains('Operasional'));
    expect(StorePlusService.priorities, ['Rendah', 'Normal', 'Tinggi']);
  });
  test('digital statuses are explicit and exclude arbitrary values', () {
    expect(StorePlusService.statuses, containsAll(['Selesai', 'Menunggu', 'Gagal']));
    expect(StorePlusService.statuses, isNot(contains('Terkirim otomatis')));
  });
}
