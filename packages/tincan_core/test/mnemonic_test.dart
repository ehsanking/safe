import 'dart:math';
import 'dart:typed_data';

import 'package:tincan_core/tincan_core.dart';
import 'package:test/test.dart';

/// Minimal hex helpers so the tests carry no extra dependency.
Uint8List _unhex(String s) {
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('BIP39 wordlist', () {
    test('has exactly 2048 words, correct endpoints', () {
      expect(englishWordlist.length, 2048);
      expect(englishWordlist.first, 'abandon');
      expect(englishWordlist[1], 'ability');
      expect(englishWordlist.last, 'zoo');
    });
  });

  group('BIP39 official test vectors (Trezor, passphrase "TREZOR")', () {
    // entropy -> mnemonic -> seed
    const vectors = <List<String>>[
      [
        '00000000000000000000000000000000',
        'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon about',
        'c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e5349553'
            '1f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04',
      ],
      [
        '7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f',
        'legal winner thank year wave sausage worth useful legal winner '
            'thank yellow',
        '2e8905819b8723fe2c1d161860e5ee1830318dbf49a83bd451cfb8440c28bd6f'
            'a457fe1296106559a3c80937a1c1069be3a3a5bd381ee6260e8d9739fce1f607',
      ],
      [
        '0000000000000000000000000000000000000000000000000000000000000000',
        'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon abandon abandon abandon art',
        'bda85446c68413707090a52022edd26a1c9462295029f2e60cd7c4f2bbd30971'
            '70af7a4d73245cafa9c3cca8d561a7c3de6f5d4a10be8ed2a5e608d68f92fcc8',
      ],
    ];

    for (var i = 0; i < vectors.length; i++) {
      final entropyHex = vectors[i][0];
      final mnemonic = vectors[i][1];
      final seedHex = vectors[i][2];

      test('vector $i: entropy -> mnemonic', () {
        expect(Bip39.entropyToMnemonic(_unhex(entropyHex)), mnemonic);
      });

      test('vector $i: mnemonic -> entropy round-trips', () {
        expect(_hex(Bip39.mnemonicToEntropy(mnemonic)), entropyHex);
      });

      test('vector $i: mnemonic -> seed (TREZOR)', () async {
        final seed = await Bip39.mnemonicToSeed(mnemonic, passphrase: 'TREZOR');
        expect(_hex(seed), seedHex);
      });
    }
  });

  group('validation', () {
    test('accepts a valid mnemonic', () {
      expect(
        Bip39.validate('abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon abandon about'),
        isTrue,
      );
    });

    test('rejects a bad checksum (last word changed)', () {
      expect(
        Bip39.validate('abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon abandon abandon'),
        isFalse,
      );
    });

    test('rejects an unknown word', () {
      expect(
        Bip39.validate('notaword abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon abandon about'),
        isFalse,
      );
    });

    test('rejects a wrong word count', () {
      expect(Bip39.validate('abandon abandon abandon'), isFalse);
    });
  });

  group('generation', () {
    test('generates valid 12/24-word mnemonics', () {
      final m12 = Bip39.generate(strengthBits: 128);
      final m24 = Bip39.generate(strengthBits: 256);
      expect(m12.split(' ').length, 12);
      expect(m24.split(' ').length, 24);
      expect(Bip39.validate(m12), isTrue);
      expect(Bip39.validate(m24), isTrue);
    });

    test('rejects non-standard strengths (e.g. a 10-word request)', () {
      // 110 bits would be a "10 word" phrase — not valid BIP39.
      expect(() => Bip39.generate(strengthBits: 110), throwsArgumentError);
    });

    test('is deterministic given a seeded RNG (test-only injection)', () {
      final a = Bip39.generate(random: Random(42));
      final b = Bip39.generate(random: Random(42));
      expect(a, b);
      expect(Bip39.validate(a), isTrue);
    });
  });
}
