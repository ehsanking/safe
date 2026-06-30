import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography_plus/cryptography_plus.dart';

import 'wordlist_english.dart';

/// BIP-0039 mnemonic generation and seed derivation (English wordlist).
///
/// We implement the standard ourselves (rather than depending on a stale
/// third-party package) so the only trusted input is the vendored, checksum-
/// verified wordlist. Valid strengths are 128/160/192/224/256 bits, which map
/// to 12/15/18/21/24 words.
///
/// Why 12 words and not 10? BIP39's checksum is `ENT/32` bits appended to `ENT`
/// bits of entropy, so the total must be a multiple of 11 with `ENT` a multiple
/// of 32 — only 12/15/18/21/24 satisfy this. A 10-word phrase cannot be valid
/// BIP39. The product-facing "recovery phrase" can still be branded freely; the
/// 10-vs-12 question is tracked as an open product decision in DESIGN.md §4.1.
class Bip39 {
  Bip39._();

  /// The vendored BIP-0039 English wordlist (2048 words).
  static const List<String> wordlist = englishWordlist;

  static final Map<String, int> _wordIndex = <String, int>{
    for (var i = 0; i < englishWordlist.length; i++) englishWordlist[i]: i,
  };

  /// Generates a fresh mnemonic using a cryptographically secure RNG.
  ///
  /// [random] is injectable for deterministic testing only; production code
  /// must use the default [Random.secure].
  static String generate({int strengthBits = 128, Random? random}) {
    if (strengthBits % 32 != 0 || strengthBits < 128 || strengthBits > 256) {
      throw ArgumentError.value(
          strengthBits, 'strengthBits', 'Must be one of 128/160/192/224/256');
    }
    final rng = random ?? Random.secure();
    final entropy = Uint8List(strengthBits ~/ 8);
    for (var i = 0; i < entropy.length; i++) {
      entropy[i] = rng.nextInt(256);
    }
    return entropyToMnemonic(entropy);
  }

  /// Converts raw [entropy] to a mnemonic phrase.
  static String entropyToMnemonic(Uint8List entropy) {
    final ent = entropy.length * 8;
    if (ent % 32 != 0 || ent < 128 || ent > 256) {
      throw ArgumentError('Invalid entropy length: $ent bits');
    }
    final checksumBits = ent ~/ 32;
    final hash = crypto.sha256.convert(entropy).bytes;

    final bits = StringBuffer();
    for (final b in entropy) {
      bits.write(b.toRadixString(2).padLeft(8, '0'));
    }
    for (var i = 0; i < checksumBits; i++) {
      bits.write((hash[i ~/ 8] >> (7 - (i % 8))) & 1);
    }

    final bitStr = bits.toString();
    final words = <String>[];
    for (var i = 0; i < bitStr.length; i += 11) {
      final index = int.parse(bitStr.substring(i, i + 11), radix: 2);
      words.add(englishWordlist[index]);
    }
    return words.join(' ');
  }

  /// Recovers entropy from [mnemonic], verifying the checksum.
  ///
  /// Throws [ArgumentError] on an unknown word, bad length, or bad checksum.
  static Uint8List mnemonicToEntropy(String mnemonic) {
    final words = _split(mnemonic);
    if (words.length % 3 != 0 || words.length < 12 || words.length > 24) {
      throw ArgumentError('Invalid word count: ${words.length}');
    }

    final bits = StringBuffer();
    for (final w in words) {
      final index = _wordIndex[w];
      if (index == null) throw ArgumentError('Unknown word: "$w"');
      bits.write(index.toRadixString(2).padLeft(11, '0'));
    }

    final bitStr = bits.toString();
    final dividerIndex = (bitStr.length ~/ 33) * 32;
    final entropyBits = bitStr.substring(0, dividerIndex);
    final checksumBits = bitStr.substring(dividerIndex);

    final entropy = Uint8List(entropyBits.length ~/ 8);
    for (var i = 0; i < entropy.length; i++) {
      entropy[i] = int.parse(entropyBits.substring(i * 8, i * 8 + 8), radix: 2);
    }

    final hash = crypto.sha256.convert(entropy).bytes;
    final expected = StringBuffer();
    final csLen = entropy.length * 8 ~/ 32;
    for (var i = 0; i < csLen; i++) {
      expected.write((hash[i ~/ 8] >> (7 - (i % 8))) & 1);
    }
    if (expected.toString() != checksumBits) {
      throw ArgumentError('Invalid mnemonic checksum');
    }
    return entropy;
  }

  /// Returns true iff [mnemonic] is well-formed and its checksum matches.
  static bool validate(String mnemonic) {
    try {
      mnemonicToEntropy(mnemonic);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Derives the 64-byte BIP39 seed (PBKDF2-HMAC-SHA512, 2048 iterations).
  ///
  /// NOTE: BIP39 mandates NFKD normalisation of the mnemonic and passphrase.
  /// The English wordlist is pure ASCII, so the mnemonic side is already
  /// normalised; a non-ASCII [passphrase] is currently used as-is. Tracked in
  /// the package README under "Known limitations".
  static Future<Uint8List> mnemonicToSeed(String mnemonic,
      {String passphrase = ''}) async {
    final normalized = _split(mnemonic).join(' ');
    final pbkdf2 =
        Pbkdf2(macAlgorithm: Hmac.sha512(), iterations: 2048, bits: 512);
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(normalized)),
      nonce: utf8.encode('mnemonic$passphrase'),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  static List<String> _split(String mnemonic) => mnemonic
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
}
