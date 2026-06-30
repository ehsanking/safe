import 'dart:convert';

import 'package:tincan_core/tincan_core.dart';
import 'package:test/test.dart';

void main() {
  const mnemonic = 'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about';
  const other = 'legal winner thank year wave sausage worth useful '
      'legal winner thank yellow';

  group('identity derivation', () {
    test('produces 32-byte Ed25519 and X25519 public keys', () async {
      final id = await Identity.fromMnemonic(mnemonic);
      expect(id.signingPublicKey.length, 32);
      expect(id.agreementPublicKey.length, 32);
      expect(id.fingerprint.length, 32);
      expect(ShortCode.isWellFormed(id.shortCode), isTrue);
    });

    test('is deterministic for the same mnemonic', () async {
      final a = await Identity.fromMnemonic(mnemonic);
      final b = await Identity.fromMnemonic(mnemonic);
      expect(a.signingPublicKey, b.signingPublicKey);
      expect(a.agreementPublicKey, b.agreementPublicKey);
      expect(a.shortCode, b.shortCode);
    });

    test('differs for a different mnemonic', () async {
      final a = await Identity.fromMnemonic(mnemonic);
      final b = await Identity.fromMnemonic(other);
      expect(a.signingPublicKey, isNot(b.signingPublicKey));
      expect(a.shortCode, isNot(b.shortCode));
    });

    test('a passphrase yields a different identity', () async {
      final a = await Identity.fromMnemonic(mnemonic);
      final b = await Identity.fromMnemonic(mnemonic, passphrase: 'second');
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('signing and X25519 keys are independent', () async {
      final id = await Identity.fromMnemonic(mnemonic);
      expect(id.signingPublicKey, isNot(id.agreementPublicKey));
    });
  });

  group('signatures', () {
    test('verifies a genuine signature and rejects tampering', () async {
      final alice = await Identity.fromMnemonic(mnemonic);
      final message = utf8.encode('سلام دنیا');

      final sig = await alice.sign(message);
      expect(
        await Identity.verify(message, sig, alice.signingPublicKey),
        isTrue,
      );

      final tampered = List<int>.from(message)..[0] ^= 0x01;
      expect(
        await Identity.verify(tampered, sig, alice.signingPublicKey),
        isFalse,
      );
    });

    test('rejects a signature from the wrong key', () async {
      final alice = await Identity.fromMnemonic(mnemonic);
      final mallory = await Identity.fromMnemonic(other);
      final message = 'transfer 100'.codeUnits;

      final sig = await alice.sign(message);
      expect(
        await Identity.verify(message, sig, mallory.signingPublicKey),
        isFalse,
      );
    });
  });

  group('ECDH key agreement', () {
    test('both parties derive the same shared secret', () async {
      final alice = await Identity.fromMnemonic(mnemonic);
      final bob = await Identity.fromMnemonic(other);

      final ab = await alice.sharedSecret(bob.agreementPublicKey);
      final ba = await bob.sharedSecret(alice.agreementPublicKey);

      expect(ab, ba);
      expect(ab.length, 32);
    });
  });
}
