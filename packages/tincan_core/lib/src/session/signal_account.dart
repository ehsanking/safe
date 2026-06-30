import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart' as cp;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

/// A Signal-protocol account whose long-term identity is derived
/// **deterministically from the BIP39 seed**, so a single recovery phrase
/// restores not just the wallet-style identity but the whole messaging account.
///
/// One-time and signed pre-keys are generated freshly (they are meant to be
/// rotated/consumed), but the identity key and registration id are reproducible
/// from the seed.
///
/// This phase keeps everything in an in-memory store; persisting it to the
/// encrypted database (drift + sqlite3mc) is a later phase.
class SignalAccount {
  SignalAccount._(
    this.store,
    this.registrationId,
    this.deviceId,
    this._preKeys,
    this._signedPreKey,
  );

  /// The libsignal store holding identity, sessions and pre-keys.
  final InMemorySignalProtocolStore store;

  /// Deterministic registration id (1..16380), derived from the seed.
  final int registrationId;

  /// Device id (single-device for now).
  final int deviceId;

  final List<PreKeyRecord> _preKeys;
  final SignedPreKeyRecord _signedPreKey;
  int _nextPreKey = 0;

  static const String _identityLabel = 'tincan/libsignal/identity/v1';
  static const String _regIdLabel = 'tincan/libsignal/regid/v1';
  static const String _hkdfSalt = 'tincan/libsignal/salt/v1';

  /// Builds an account from a [seed] (the 64-byte BIP39 seed).
  ///
  /// [preKeyCount] one-time pre-keys are generated up front; each call to
  /// [createBundle] hands out the next one.
  static Future<SignalAccount> fromSeed(
    List<int> seed, {
    int deviceId = 1,
    int preKeyCount = 100,
  }) async {
    final identityPriv = await _hkdf(seed, _identityLabel, 32);
    final identityKeyPair = generateIdentityKeyPairFromPrivate(identityPriv);

    final regBytes = await _hkdf(seed, _regIdLabel, 4);
    final regValue = ((regBytes[0] << 24) |
            (regBytes[1] << 16) |
            (regBytes[2] << 8) |
            regBytes[3]) &
        0x7fffffff;
    final registrationId = (regValue % 16380) + 1;

    final store = InMemorySignalProtocolStore(identityKeyPair, registrationId);

    final preKeys = generatePreKeys(1, preKeyCount);
    for (final pk in preKeys) {
      await store.storePreKey(pk.id, pk);
    }
    final signedPreKey = generateSignedPreKey(identityKeyPair, 1);
    await store.storeSignedPreKey(signedPreKey.id, signedPreKey);

    return SignalAccount._(
      store,
      registrationId,
      deviceId,
      preKeys,
      signedPreKey,
    );
  }

  /// The Signal identity public key (deterministic from the seed).
  Future<Uint8List> identityPublicKey() async {
    final pair = await store.getIdentityKeyPair();
    return pair.getPublicKey().serialize();
  }

  /// Produces a publishable pre-key bundle for a peer to start a session,
  /// consuming the next available one-time pre-key.
  ///
  /// In the serverless model this bundle travels inside the contact-add
  /// exchange (QR / short code lookup), not via a central key server.
  Future<PreKeyBundle> createBundle() async {
    final identityKeyPair = await store.getIdentityKeyPair();
    final preKey = _preKeys[_nextPreKey++ % _preKeys.length];
    return PreKeyBundle(
      registrationId,
      deviceId,
      preKey.id,
      preKey.getKeyPair().publicKey,
      _signedPreKey.id,
      _signedPreKey.getKeyPair().publicKey,
      _signedPreKey.signature,
      identityKeyPair.getPublicKey(),
    );
  }

  static Future<Uint8List> _hkdf(
      List<int> seed, String label, int length) async {
    final hkdf = cp.Hkdf(hmac: cp.Hmac.sha256(), outputLength: length);
    final key = await hkdf.deriveKey(
      secretKey: cp.SecretKey(seed),
      nonce: utf8.encode(_hkdfSalt),
      info: utf8.encode(label),
    );
    return Uint8List.fromList(await key.extractBytes());
  }
}
