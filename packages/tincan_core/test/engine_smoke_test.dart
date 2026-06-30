import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:tincan_core/tincan_core.dart';
import 'package:test/test.dart';

/// Derives a 32-byte session key from a raw ECDH shared secret via HKDF-SHA256.
/// (Stand-in for the Double Ratchet's root-key step until libsignal is wired.)
Future<List<int>> _sessionKey(List<int> sharedSecret) async {
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final key = await hkdf.deriveKey(
    secretKey: SecretKey(sharedSecret),
    nonce: utf8.encode('tincan/session/salt/v1'),
    info: utf8.encode('tincan/session/v1'),
  );
  return key.extractBytes();
}

void main() {
  test('end-to-end: Alice encrypts and sends a message that Bob decrypts',
      () async {
    final aead = XChaCha20Poly1305Aead();

    final alice = await Identity.fromMnemonic(
        'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon about');
    final bob = await Identity.fromMnemonic(
        'legal winner thank year wave sausage worth useful '
        'legal winner thank yellow');

    final net = InMemoryNetwork();
    final aliceT = net.endpoint('alice');
    final bobT = net.endpoint('bob');
    await aliceT.start();
    await bobT.start();

    final received = Completer<String>();

    // Bob: on inbound, derive the shared key from Alice's public key and open.
    bobT.inbound.listen((frame) async {
      final shared = await bob.sharedSecret(alice.agreementPublicKey);
      final key = await _sessionKey(shared);
      final clear = await aead.open(sealed: frame.bytes, key: key);
      received.complete(utf8.decode(clear));
    });

    // Alice: derive the same shared key, seal a message, send it to Bob.
    const message = 'سلام بهمن، این یک پیام امن است.';
    final shared = await alice.sharedSecret(bob.agreementPublicKey);
    final key = await _sessionKey(shared);
    final sealed = await aead.seal(plaintext: utf8.encode(message), key: key);
    await aliceT.send(bobT.localAddress, Uint8List.fromList(sealed));

    expect(await received.future.timeout(const Duration(seconds: 5)), message);

    await aliceT.close();
    await bobT.close();
  });
}
