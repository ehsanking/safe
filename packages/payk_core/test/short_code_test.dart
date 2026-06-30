import 'dart:typed_data';

import 'package:payk_core/payk_core.dart';
import 'package:test/test.dart';

void main() {
  // A fixed 32-byte fingerprint for deterministic assertions.
  final fp = Uint8List.fromList(List<int>.generate(32, (i) => i));

  group('short code', () {
    test('is 10 digits and self-consistent (Luhn)', () {
      final code = ShortCode.fromFingerprint(fp);
      expect(code.length, 10);
      expect(RegExp(r'^\d{10}$').hasMatch(code), isTrue);
      expect(ShortCode.isWellFormed(code), isTrue);
    });

    test('is deterministic for the same fingerprint', () {
      expect(ShortCode.fromFingerprint(fp), ShortCode.fromFingerprint(fp));
    });

    test('changes when the fingerprint changes', () {
      final other = Uint8List.fromList(fp)..[0] ^= 0xFF;
      expect(
        ShortCode.fromFingerprint(fp),
        isNot(ShortCode.fromFingerprint(other)),
      );
    });

    test('Luhn rejects a single-digit typo', () {
      final code = ShortCode.fromFingerprint(fp);
      final digits = code.split('');
      // Flip the first digit to something different.
      digits[0] = ((int.parse(digits[0]) + 1) % 10).toString();
      final typo = digits.join();
      expect(ShortCode.isWellFormed(typo), isFalse);
    });

    test('rejects malformed inputs', () {
      expect(ShortCode.isWellFormed('123'), isFalse);
      expect(ShortCode.isWellFormed('abcdefghij'), isFalse);
      expect(ShortCode.isWellFormed('12345678901'), isFalse);
    });

    test('format groups as 3-3-3-1', () {
      expect(ShortCode.format('1234567890'), '123 456 789 0');
    });
  });

  group('safety number', () {
    final fpA = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final fpB = Uint8List.fromList(List<int>.generate(32, (i) => 31 - i));

    test('is 60 digits in 12 groups of 5', () {
      final sn = ShortCode.safetyNumber(fpA, fpB);
      final groups = sn.split(' ');
      expect(groups.length, 12);
      for (final g in groups) {
        expect(RegExp(r'^\d{5}$').hasMatch(g), isTrue);
      }
    });

    test('is symmetric (order-independent)', () {
      expect(
        ShortCode.safetyNumber(fpA, fpB),
        ShortCode.safetyNumber(fpB, fpA),
      );
    });

    test('differs for different peer pairs', () {
      final fpC =
          Uint8List.fromList(List<int>.generate(32, (i) => i * 7 % 256));
      expect(
        ShortCode.safetyNumber(fpA, fpB),
        isNot(ShortCode.safetyNumber(fpA, fpC)),
      );
    });
  });
}
