import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';

import '../crypto/aead.dart';

/// Argon2id work factors used to stretch a backup passphrase into a key.
///
/// Defaults follow OWASP's minimum for Argon2id (m=19 MiB, t=2, p=1). They are
/// stored *inside* every backup blob so a future hardening can raise them
/// without breaking the ability to open older backups.
class Argon2Params {
  const Argon2Params({
    this.memoryKiB = 19456,
    this.iterations = 2,
    this.parallelism = 1,
  });

  /// Lighter parameters for tests / low-power devices. NOT for production data.
  const Argon2Params.light()
      : memoryKiB = 8192,
        iterations = 1,
        parallelism = 1;

  final int memoryKiB;
  final int iterations;
  final int parallelism;
}

/// Client-side-encrypted backup.
///
/// A backup is sealed on the device with a key derived from a user-chosen
/// passphrase (Argon2id) and authenticated encryption (XChaCha20-Poly1305). The
/// resulting blob is indistinguishable from random, so it is safe to store on
/// an untrusted location — Google Drive, an SD card, anywhere. The storage
/// provider only ever holds ciphertext; it cannot read, sell, or hand over the
/// contents.
///
/// Blob layout (all integers big-endian):
/// ```
/// "TCB1" | memKiB(u32) | iters(u32) | par(u8) | saltLen(u8) | salt | aeadSealed
/// ```
class BackupVault {
  BackupVault({AeadCipher? aead, this.params = const Argon2Params()})
      : _aead = aead ?? XChaCha20Poly1305Aead();

  final AeadCipher _aead;
  final Argon2Params params;

  static const List<int> _magic = <int>[0x54, 0x43, 0x42, 0x31]; // "TCB1"
  static const int _saltLength = 16;

  /// Seals [plaintext] under [passphrase], returning the portable blob.
  ///
  /// A fresh random [salt] is generated unless supplied (tests pass a fixed
  /// salt for determinism). [random] is injectable for tests only.
  Future<Uint8List> seal({
    required List<int> plaintext,
    required String passphrase,
    Uint8List? salt,
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    final usedSalt = salt ??
        Uint8List.fromList(
            List<int>.generate(_saltLength, (_) => rng.nextInt(256)));

    final key = await _deriveKey(passphrase, usedSalt, params);
    final sealed = await _aead.seal(plaintext: plaintext, key: key);

    final out = BytesBuilder();
    out.add(_magic);
    out.add(_u32(params.memoryKiB));
    out.add(_u32(params.iterations));
    out.addByte(params.parallelism & 0xff);
    out.addByte(usedSalt.length & 0xff);
    out.add(usedSalt);
    out.add(sealed);
    return out.toBytes();
  }

  /// Opens a [blob] produced by [seal]. Throws on a wrong passphrase, a
  /// truncated/foreign blob, or any tampering.
  Future<Uint8List> open({
    required Uint8List blob,
    required String passphrase,
  }) async {
    var offset = 0;
    Uint8List take(int n) {
      if (offset + n > blob.length) {
        throw const FormatException('Truncated backup blob');
      }
      final slice = blob.sublist(offset, offset + n);
      offset += n;
      return slice;
    }

    final magic = take(4);
    for (var i = 0; i < 4; i++) {
      if (magic[i] != _magic[i]) {
        throw const FormatException('Not a Tincan backup (bad magic)');
      }
    }
    final memoryKiB = _readU32(take(4));
    final iterations = _readU32(take(4));
    final parallelism = take(1)[0];
    final saltLen = take(1)[0];
    final salt = take(saltLen);
    final sealed = blob.sublist(offset);

    final key = await _deriveKey(
      passphrase,
      salt,
      Argon2Params(
        memoryKiB: memoryKiB,
        iterations: iterations,
        parallelism: parallelism,
      ),
    );
    return _aead.open(sealed: sealed, key: key);
  }

  Future<List<int>> _deriveKey(
    String passphrase,
    Uint8List salt,
    Argon2Params p,
  ) async {
    final argon2 = Argon2id(
      parallelism: p.parallelism,
      memory: p.memoryKiB,
      iterations: p.iterations,
      hashLength: 32,
    );
    final key = await argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  static Uint8List _u32(int v) {
    final b = Uint8List(4);
    ByteData.view(b.buffer).setUint32(0, v, Endian.big);
    return b;
  }

  static int _readU32(Uint8List b) =>
      ByteData.view(b.buffer, b.offsetInBytes, 4).getUint32(0, Endian.big);
}
