import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_ultimate_manager/services/idempotency_service.dart';

void main() {
  group('IdempotencyService.generateKey', () {
    test('generates a UUID v4 formatted string', () {
      final key = IdempotencyService.generateKey();
      // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      // where y is 8, 9, a, or b
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(key, matches(pattern));
    });

    test('generates unique keys on each call', () {
      final keys = <String>{};
      for (int i = 0; i < 100; i++) {
        keys.add(IdempotencyService.generateKey());
      }
      expect(keys.length, 100);
    });

    test('version nibble is always 4', () {
      for (int i = 0; i < 50; i++) {
        final key = IdempotencyService.generateKey();
        // The 13th character is the version nibble (0-indexed: position 14)
        expect(key[14], '4');
      }
    });

    test('variant nibble is always 8, 9, a, or b', () {
      for (int i = 0; i < 50; i++) {
        final key = IdempotencyService.generateKey();
        // The 17th character is the variant nibble (0-indexed: position 19)
        final variant = key[19];
        expect(variant, anyOf('8', '9', 'a', 'b'));
      }
    });

    test('key length is 36 characters', () {
      for (int i = 0; i < 10; i++) {
        expect(IdempotencyService.generateKey().length, 36);
      }
    });

    test('key has exactly 4 hyphens', () {
      for (int i = 0; i < 10; i++) {
        final hyphens = IdempotencyService.generateKey().split('').where((c) => c == '-').length;
        expect(hyphens, 4);
      }
    });
  });
}
