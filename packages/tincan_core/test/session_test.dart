import 'dart:convert';

import 'package:tincan_core/tincan_core.dart';
import 'package:test/test.dart';

// Two fixed mnemonics → deterministic identities.
const _aliceMnemonic = 'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';
const _bobMnemonic = 'legal winner thank year wave sausage worth useful '
    'legal winner thank yellow';

Future<List<int>> _seed(String mnemonic) => Bip39.mnemonicToSeed(mnemonic);

void main() {
  group('Signal session (X3DH + Double Ratchet)', () {
    late SignalAccount alice;
    late SignalAccount bob;
    late SignalProtocolAddress aliceAddr;
    late SignalProtocolAddress bobAddr;

    setUp(() async {
      alice = await SignalAccount.fromSeed(await _seed(_aliceMnemonic));
      bob = await SignalAccount.fromSeed(await _seed(_bobMnemonic));
      aliceAddr = const SignalProtocolAddress('alice', 1);
      bobAddr = const SignalProtocolAddress('bob', 1);
    });

    test('establishes a session and exchanges messages both ways', () async {
      // Alice starts a session from Bob's published bundle.
      final aliceToBob = SecureSession(alice.store, bobAddr);
      await aliceToBob.initiateFromBundle(await bob.createBundle());

      // First message is a PreKeySignalMessage; Bob establishes his side on
      // decrypt (no bundle processing needed on the responder).
      final bobFromAlice = SecureSession(bob.store, aliceAddr);

      final m1 = await aliceToBob.encrypt(utf8.encode('سلام باب'));
      expect(utf8.decode(await bobFromAlice.decrypt(m1)), 'سلام باب');

      // Bob replies (SignalMessage) and Alice decrypts.
      final m2 = await bobFromAlice.encrypt(utf8.encode('سلام آلیس'));
      expect(utf8.decode(await aliceToBob.decrypt(m2)), 'سلام آلیس');

      // A longer back-and-forth keeps working.
      for (var i = 0; i < 5; i++) {
        final out = await aliceToBob.encrypt(utf8.encode('ping $i'));
        expect(utf8.decode(await bobFromAlice.decrypt(out)), 'ping $i');
        final back = await bobFromAlice.encrypt(utf8.encode('pong $i'));
        expect(utf8.decode(await aliceToBob.decrypt(back)), 'pong $i');
      }
    });

    test('ratchet advances: identical plaintext → different ciphertext',
        () async {
      final aliceToBob = SecureSession(alice.store, bobAddr);
      await aliceToBob.initiateFromBundle(await bob.createBundle());
      final bobFromAlice = SecureSession(bob.store, aliceAddr);

      // Establish the session first.
      final first = await aliceToBob.encrypt(utf8.encode('hello'));
      await bobFromAlice.decrypt(first);

      final a = await aliceToBob.encrypt(utf8.encode('same'));
      final b = await aliceToBob.encrypt(utf8.encode('same'));
      expect(a, isNot(b), reason: 'forward secrecy: per-message keys differ');

      expect(utf8.decode(await bobFromAlice.decrypt(a)), 'same');
      expect(utf8.decode(await bobFromAlice.decrypt(b)), 'same');
    });

    test('handles out-of-order delivery', () async {
      final aliceToBob = SecureSession(alice.store, bobAddr);
      await aliceToBob.initiateFromBundle(await bob.createBundle());
      final bobFromAlice = SecureSession(bob.store, aliceAddr);

      // Establish session.
      await bobFromAlice.decrypt(await aliceToBob.encrypt(utf8.encode('init')));

      final m3 = await aliceToBob.encrypt(utf8.encode('third'));
      final m4 = await aliceToBob.encrypt(utf8.encode('fourth'));

      // Deliver m4 before m3 — the Double Ratchet stores the skipped key.
      expect(utf8.decode(await bobFromAlice.decrypt(m4)), 'fourth');
      expect(utf8.decode(await bobFromAlice.decrypt(m3)), 'third');
    });

    test('rejects a replayed (duplicate) frame', () async {
      final aliceToBob = SecureSession(alice.store, bobAddr);
      await aliceToBob.initiateFromBundle(await bob.createBundle());
      final bobFromAlice = SecureSession(bob.store, aliceAddr);

      await bobFromAlice.decrypt(await aliceToBob.encrypt(utf8.encode('init')));
      final m = await aliceToBob.encrypt(utf8.encode('once'));
      expect(utf8.decode(await bobFromAlice.decrypt(m)), 'once');

      // Replaying the exact same frame must not silently succeed again.
      expect(
        () => bobFromAlice.decrypt(m),
        throwsA(isA<DuplicateMessageException>()),
      );
    });
  });

  group('deterministic identity from seed', () {
    test('same mnemonic → same Signal identity key', () async {
      final a1 = await SignalAccount.fromSeed(await _seed(_aliceMnemonic));
      final a2 = await SignalAccount.fromSeed(await _seed(_aliceMnemonic));
      expect(await a1.identityPublicKey(), await a2.identityPublicKey());
      expect(a1.registrationId, a2.registrationId);
    });

    test('different mnemonics → different Signal identity keys', () async {
      final a = await SignalAccount.fromSeed(await _seed(_aliceMnemonic));
      final b = await SignalAccount.fromSeed(await _seed(_bobMnemonic));
      expect(await a.identityPublicKey(), isNot(await b.identityPublicKey()));
    });
  });
}
