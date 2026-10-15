import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/services/pin_security.dart';
import 'package:agan_ponsel/services/product_photos.dart';

void main() {
  test('PIN requires exactly six digits', () {
    expect(PinSecurity.valid('123456'), isTrue);
    expect(PinSecurity.valid('12345'), isFalse);
    expect(PinSecurity.valid('1234567'), isFalse);
    expect(PinSecurity.valid('ABCDEF'), isFalse);
  });

  test('Backup photo names cannot traverse Android filesystem', () {
    expect(ProductPhotos.validName('product_123_abc.jpg'), isTrue);
    expect(ProductPhotos.validName('../private.db'), isFalse);
    expect(ProductPhotos.validName('/sdcard/secret.jpg'), isFalse);
    expect(ProductPhotos.validName('product_abc.txt'), isFalse);
  });
}
