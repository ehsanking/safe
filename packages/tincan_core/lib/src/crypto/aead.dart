import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';

/// Authenticated-encryption-with-associated-data abstraction.
///
/// The whole engine talks to *this* interface, never to a concrete cipher. That
/// keeps a clean seam so the high-assurance hardening path — routing AEAD work
/// through audited libsodium via the `sodium` FFI package — can be dropped in
/// later without touching any call site. See DESIGN.md §10 (audit gap).
abstract class AeadCipher {
  /// Nonce length in bytes.
  int get nonceLength;

  /// Authentication tag length in bytes.
  int get macLength;

  /// Encrypts [plaintext] under [key], returning `nonce ‖ ciphertext ‖ tag`.
  ///
  /// A fresh random nonce is generated per call. [key] must be 32 bytes.
  Future<Uint8List> seal({
    required List<int> plaintext,
    required List<int> key,
    List<int> aad = const <int>[],
  });

  /// Inverse of [seal]; throws if authentication fails (tampering, wrong key,
  /// or mismatched [aad]).
  Future<Uint8List> open({
    required List<int> sealed,
    required List<int> key,
    List<int> aad = const <int>[],
  });
}

/// XChaCha20-Poly1305 AEAD — 24-byte random nonce, 16-byte Poly1305 tag.
///
/// The 192-bit nonce makes random per-message nonces safe (negligible reuse
/// risk), which suits a system without a reliable shared message counter.
/// Pure Dart via `cryptography_plus`; no native build step.
class XChaCha20Poly1305Aead implements AeadCipher {
  XChaCha20Poly1305Aead();

  final Cipher _cipher = Xchacha20.poly1305Aead();

  @override
  int get nonceLength => _cipher.nonceLength;

  @override
  int get macLength => _cipher.macAlgorithm.macLength;

  @override
  Future<Uint8List> seal({
    required List<int> plaintext,
    required List<int> key,
    List<int> aad = const <int>[],
  }) async {
    final box = await _cipher.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      aad: aad,
    );
    return Uint8List.fromList(box.concatenation());
  }

  @override
  Future<Uint8List> open({
    required List<int> sealed,
    required List<int> key,
    List<int> aad = const <int>[],
  }) async {
    final box = SecretBox.fromConcatenation(
      sealed,
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    final clear = await _cipher.decrypt(
      box,
      secretKey: SecretKey(key),
      aad: aad,
    );
    return Uint8List.fromList(clear);
  }
}
