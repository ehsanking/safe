import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';

import '../mnemonic/mnemonic.dart';
import 'short_code.dart';

/// A self-sovereign identity derived deterministically from a BIP39 seed.
///
/// There is no account and no server: your identity *is* your key material.
/// Two independent key pairs are derived from the seed via HKDF-SHA256 with
/// distinct, versioned context labels:
///
///  * an **Ed25519** signing pair — proves authenticity of what you send;
///  * an **X25519** key-agreement pair — performs the ECDH that bootstraps an
///    encrypted session.
///
/// Separating the two (rather than reusing one key for both roles) is the
/// cleaner, safer construction.
class Identity {
  Identity({
    required this.signingKeyPair,
    required this.agreementKeyPair,
    required this.signingPublicKey,
    required this.agreementPublicKey,
    required this.fingerprint,
    required this.shortCode,
  });

  /// Ed25519 signing key pair.
  final SimpleKeyPair signingKeyPair;

  /// X25519 key-agreement key pair.
  final SimpleKeyPair agreementKeyPair;

  /// 32-byte Ed25519 public key.
  final Uint8List signingPublicKey;

  /// 32-byte X25519 public key.
  final Uint8List agreementPublicKey;

  /// 32-byte identity fingerprint = SHA-256(domain ‖ signPub ‖ agreePub).
  final Uint8List fingerprint;

  /// Human-friendly 10-digit short code (9 digits + Luhn check digit).
  /// Convenience only — verify [fingerprint] / [shortCode] via QR or a safety
  /// number before trusting it. See [ShortCode].
  final String shortCode;

  static const String _ed25519Info = 'tincan/identity/ed25519/v1';
  static const String _x25519Info = 'tincan/identity/x25519/v1';

  /// Fixed, non-secret HKDF salt. A constant salt is fine here: the inputs are
  /// already high-entropy seeds and the per-key separation comes from the
  /// distinct `info` labels. (An empty salt is rejected by the HKDF backend.)
  static final List<int> _hkdfSalt =
      utf8.encode('tincan/identity/hkdf-salt/v1');

  /// Derives an identity from a mnemonic phrase.
  static Future<Identity> fromMnemonic(String mnemonic,
      {String passphrase = ''}) async {
    final seed = await Bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);
    return fromSeed(seed);
  }

  /// Derives an identity from a raw seed (BIP39 produces 64 bytes; any length
  /// of sufficient entropy is accepted by the HKDF expansion).
  static Future<Identity> fromSeed(List<int> seed) async {
    final signSeed = await _deriveSubSeed(seed, _ed25519Info);
    final agreeSeed = await _deriveSubSeed(seed, _x25519Info);

    final signing = await Ed25519().newKeyPairFromSeed(signSeed);
    final agreement = await X25519().newKeyPairFromSeed(agreeSeed);

    final signPub =
        Uint8List.fromList((await signing.extractPublicKey()).bytes);
    final agreePub =
        Uint8List.fromList((await agreement.extractPublicKey()).bytes);

    final fp = ShortCode.fingerprint(signPub, agreePub);

    return Identity(
      signingKeyPair: signing,
      agreementKeyPair: agreement,
      signingPublicKey: signPub,
      agreementPublicKey: agreePub,
      fingerprint: fp,
      shortCode: ShortCode.fromFingerprint(fp),
    );
  }

  /// Signs [message] with the Ed25519 signing key.
  Future<Uint8List> sign(List<int> message) async {
    final signature = await Ed25519().sign(message, keyPair: signingKeyPair);
    return Uint8List.fromList(signature.bytes);
  }

  /// Verifies an Ed25519 [signature] over [message] against a peer's
  /// [signingPublicKey].
  static Future<bool> verify(
    List<int> message,
    List<int> signature,
    List<int> signingPublicKey,
  ) {
    return Ed25519().verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(signingPublicKey, type: KeyPairType.ed25519),
      ),
    );
  }

  /// Performs the X25519 ECDH against a peer's [agreementPublicKey], returning
  /// the raw 32-byte shared secret. Callers MUST run this through a KDF (e.g.
  /// HKDF) before using it as an encryption key.
  Future<Uint8List> sharedSecret(List<int> agreementPublicKey) async {
    final secret = await X25519().sharedSecretKey(
      keyPair: agreementKeyPair,
      remotePublicKey:
          SimplePublicKey(agreementPublicKey, type: KeyPairType.x25519),
    );
    return Uint8List.fromList(await secret.extractBytes());
  }

  static Future<List<int>> _deriveSubSeed(List<int> seed, String info) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final key = await hkdf.deriveKey(
      secretKey: SecretKey(seed),
      nonce: _hkdfSalt,
      info: utf8.encode(info),
    );
    return key.extractBytes();
  }
}
