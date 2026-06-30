import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart'
    show SecretBoxAuthenticationError;
import 'package:tincan_core/tincan_core.dart';
import 'package:test/test.dart';

void main() {
  final aead = XChaCha20Poly1305Aead();
  final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
  // utf8.encode (not String.codeUnits) so non-ASCII becomes real bytes.
  final plaintext = utf8.encode('پیام محرمانه — secret message');

  group('XChaCha20-Poly1305 AEAD', () {
    test('round-trips plaintext', () async {
      final sealed = await aead.seal(plaintext: plaintext, key: key);
      final opened = await aead.open(sealed: sealed, key: key);
      expect(opened, plaintext);
    });

    test('produces nonce(24)+tag(16) overhead and a random nonce', () async {
      expect(aead.nonceLength, 24);
      expect(aead.macLength, 16);

      final a = await aead.seal(plaintext: plaintext, key: key);
      final b = await aead.seal(plaintext: plaintext, key: key);
      expect(a.length, plaintext.length + 24 + 16);
      // Different random nonce => different ciphertext for identical input.
      expect(a, isNot(b));
    });

    test('rejects a wrong key', () async {
      final sealed = await aead.seal(plaintext: plaintext, key: key);
      final wrong = Uint8List.fromList(key)..[0] ^= 0xFF;
      expect(
        () => aead.open(sealed: sealed, key: wrong),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('rejects tampered ciphertext', () async {
      final sealed = await aead.seal(plaintext: plaintext, key: key);
      sealed[sealed.length - 1] ^= 0x01; // flip a tag byte
      expect(
        () => aead.open(sealed: sealed, key: key),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('binds associated data (AAD)', () async {
      final sealed = await aead.seal(
        plaintext: plaintext,
        key: key,
        aad: 'header-v1'.codeUnits,
      );
      // Correct AAD opens.
      expect(
        await aead.open(sealed: sealed, key: key, aad: 'header-v1'.codeUnits),
        plaintext,
      );
      // Wrong AAD fails authentication.
      expect(
        () => aead.open(sealed: sealed, key: key, aad: 'header-v2'.codeUnits),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });
}
