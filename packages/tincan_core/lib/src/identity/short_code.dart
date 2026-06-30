import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// Derives the human-friendly identity handles from public keys.
///
/// IMPORTANT — the 10-digit short code is a CONVENIENCE pointer, not a security
/// anchor. Ten decimal digits carry only ~33 bits, far too few to resist
/// collisions or forgery on their own. Security comes from verifying the full
/// public key out-of-band (QR scan, or a [safetyNumber] comparison). The short
/// code merely makes "add me" speakable, and its Luhn check digit catches
/// typos. See DESIGN.md §4.2 (Zooko's Triangle).
class ShortCode {
  ShortCode._();

  static const String _fingerprintDomain = 'tincan/fingerprint/v1';
  static const String _safetyDomain = 'tincan/safety-number/v1';

  /// Canonical 32-byte identity fingerprint binding both public keys.
  static Uint8List fingerprint(
      List<int> signingPublicKey, List<int> agreementPublicKey) {
    final input = <int>[
      ...utf8.encode(_fingerprintDomain),
      ...signingPublicKey,
      ...agreementPublicKey,
    ];
    return Uint8List.fromList(crypto.sha256.convert(input).bytes);
  }

  /// 10-digit short code: 9 digits from the first 5 bytes of the [fingerprint]
  /// (mod 1e9) plus a trailing Luhn check digit.
  static String fromFingerprint(List<int> fingerprint) {
    if (fingerprint.length < 5) {
      throw ArgumentError('Fingerprint too short');
    }
    var value = 0;
    for (var i = 0; i < 5; i++) {
      value = (value << 8) | fingerprint[i];
    }
    final nine = (value % 1000000000).toString().padLeft(9, '0');
    return nine + _luhnCheckDigit(nine).toString();
  }

  /// Validates the structure and Luhn check digit of a 10-digit [code].
  static bool isWellFormed(String code) {
    if (!RegExp(r'^\d{10}$').hasMatch(code)) return false;
    return _luhnCheckDigit(code.substring(0, 9)) == int.parse(code[9]);
  }

  /// Groups a code for display, e.g. `123 456 789 0`.
  static String format(String code) {
    if (code.length != 10) return code;
    return '${code.substring(0, 3)} ${code.substring(3, 6)} '
        '${code.substring(6, 9)} ${code.substring(9)}';
  }

  /// A Signal-style 60-digit "safety number" for manual key verification.
  ///
  /// Deterministic and symmetric: both peers compute the same value regardless
  /// of who initiates, because the two fingerprints are sorted before hashing.
  static String safetyNumber(List<int> fingerprintA, List<int> fingerprintB) {
    final a = Uint8List.fromList(fingerprintA);
    final b = Uint8List.fromList(fingerprintB);
    final first = _compareBytes(a, b) <= 0 ? a : b;
    final second = identical(first, a) ? b : a;
    // SHA-512 yields 64 bytes — enough for 12 chunks of 4 bytes below.
    final digest = crypto.sha512.convert(<int>[
      ...utf8.encode(_safetyDomain),
      ...first,
      ...second,
    ]).bytes;

    // 60 digits = 12 chunks of 5 decimal digits, each from 4 digest bytes.
    final out = StringBuffer();
    for (var chunk = 0; chunk < 12; chunk++) {
      var v = 0;
      for (var i = 0; i < 4; i++) {
        v = (v << 8) | digest[chunk * 4 + i];
      }
      if (chunk > 0) out.write(' ');
      out.write((v % 100000).toString().padLeft(5, '0'));
    }
    return out.toString();
  }

  static int _luhnCheckDigit(String digits) {
    var sum = 0;
    var double = true; // rightmost body digit is doubled
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = digits.codeUnitAt(i) - 0x30;
      if (double) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      double = !double;
    }
    return (10 - (sum % 10)) % 10;
  }

  static int _compareBytes(Uint8List a, Uint8List b) {
    final n = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final d = a[i] - b[i];
      if (d != 0) return d;
    }
    return a.length - b.length;
  }
}
