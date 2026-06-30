import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart'
    show SecretBoxAuthenticationError;
import 'package:tincan_core/tincan_core.dart';
import 'package:test/test.dart';

/// True if [needle] appears as a contiguous byte run inside [haystack].
bool _containsSubsequence(List<int> haystack, List<int> needle) {
  if (needle.isEmpty) return true;
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

void main() {
  // Light Argon2id params keep the suite fast; production uses the defaults.
  final vault = BackupVault(params: const Argon2Params.light());
  final fixedSalt = Uint8List.fromList(List<int>.generate(16, (i) => i));

  group('BackupVault (client-side encrypted)', () {
    test('round-trips arbitrary bytes', () async {
      final plaintext = utf8.encode('عبارت بازیابی + مخاطبین — secret backup');
      final blob = await vault.seal(
        plaintext: plaintext,
        passphrase: 'correct horse battery staple',
        salt: fixedSalt,
      );
      final opened = await vault.open(
          blob: blob, passphrase: 'correct horse battery staple');
      expect(opened, plaintext);
    });

    test('output is self-describing and not the plaintext', () async {
      final plaintext = utf8.encode('hello');
      final blob = await vault.seal(
          plaintext: plaintext, passphrase: 'pw', salt: fixedSalt);
      // Starts with the "TCB1" magic, and the plaintext bytes appear nowhere in
      // the (random-looking) blob.
      expect(utf8.decode(blob.sublist(0, 4)), 'TCB1');
      expect(_containsSubsequence(blob, plaintext), isFalse);
    });

    test('rejects a wrong passphrase', () async {
      final blob = await vault.seal(
          plaintext: utf8.encode('x'), passphrase: 'right', salt: fixedSalt);
      expect(
        () => vault.open(blob: blob, passphrase: 'wrong'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('rejects a tampered blob', () async {
      final blob = await vault.seal(
          plaintext: utf8.encode('x'), passphrase: 'pw', salt: fixedSalt);
      blob[blob.length - 1] ^= 0x01;
      expect(
        () => vault.open(blob: blob, passphrase: 'pw'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('rejects a foreign blob (bad magic)', () async {
      final notABackup = Uint8List.fromList(List<int>.filled(64, 7));
      expect(
        () => vault.open(blob: notABackup, passphrase: 'pw'),
        throwsA(isA<FormatException>()),
      );
    });

    test('embeds the Argon2 params it was sealed with', () async {
      final strong = BackupVault(
          params: const Argon2Params(
              memoryKiB: 12345, iterations: 3, parallelism: 2));
      final blob = await strong.seal(
          plaintext: utf8.encode('x'), passphrase: 'pw', salt: fixedSalt);
      // A fresh vault with *different* default params still opens it, because
      // the params travel inside the blob.
      final opened = await vault.open(blob: blob, passphrase: 'pw');
      expect(utf8.decode(opened), 'x');
    });
  });

  group('BackupArchive', () {
    test('JSON round-trips with contacts', () {
      final archive = BackupArchive(
        createdAtEpochMs: 1700000000000,
        mnemonic: 'abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon abandon about',
        appVersion: '0.1.0',
        contacts: [
          BackupContact(
              shortCode: '1234567890', address: 'peer|/ip4/1.2.3.4/tcp/9'),
          BackupContact(
              shortCode: '0987654321',
              address: 'peer2|/ip4/5.6.7.8/tcp/9',
              displayName: 'Sara'),
        ],
      );
      final restored = BackupArchive.fromBytes(archive.toBytes());
      expect(restored.mnemonic, archive.mnemonic);
      expect(restored.contacts.length, 2);
      expect(restored.contacts[1].displayName, 'Sara');
      expect(restored.createdAtEpochMs, archive.createdAtEpochMs);
    });

    test('full archive survives a seal/open trip', () async {
      final archive = BackupArchive(
        createdAtEpochMs: 1700000000000,
        mnemonic: 'legal winner thank year wave sausage worth useful '
            'legal winner thank yellow',
      );
      final blob = await vault.seal(
          plaintext: archive.toBytes(), passphrase: 'pw', salt: fixedSalt);
      final opened = await vault.open(blob: blob, passphrase: 'pw');
      expect(BackupArchive.fromBytes(opened).mnemonic, archive.mnemonic);
    });

    test('refuses a newer schema than it understands', () {
      final future = utf8.encode(jsonEncode(<String, dynamic>{
        'schema': BackupArchive.schemaVersion + 1,
        'createdAt': 0,
        'mnemonic': 'x',
        'contacts': <dynamic>[],
      }));
      expect(
        () => BackupArchive.fromBytes(Uint8List.fromList(future)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
