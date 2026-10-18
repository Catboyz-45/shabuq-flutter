import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/utils/image_source.dart';

void main() {
  test('accepts https links, bundled images and empty', () {
    expect(isAllowedImageSource(''), isTrue);
    expect(isAllowedImageSource('https://example.com/shop.jpg'), isTrue);
    expect(isAllowedImageSource('  https://cdn.example.com/a.png  '), isTrue);
    expect(isAllowedImageSource('assets/images/teenoi.jpg'), isTrue);
  });

  test('rejects other links and paths', () {
    expect(isAllowedImageSource('http://example.com/shop.jpg'), isFalse);
    expect(isAllowedImageSource('https://localhost/a.jpg'), isFalse);
    expect(isAllowedImageSource('file:///etc/passwd'), isFalse);
    expect(isAllowedImageSource('assets/images/../pubspec.yaml'), isFalse);
    expect(isAllowedImageSource('shop.jpg'), isFalse);
  });

  test('rejects links over the length limit', () {
    final long = 'https://example.com/${'a' * maxImageSourceLength}';
    expect(isAllowedImageSource(long), isFalse);
    expect(imageSourceError(long), contains('ยาวเกิน'));
  });

  test('explains what is wrong', () {
    expect(imageSourceError('https://example.com/a.jpg'), isNull);
    expect(imageSourceError('example.com/a.jpg'), contains('https://'));
  });
}
