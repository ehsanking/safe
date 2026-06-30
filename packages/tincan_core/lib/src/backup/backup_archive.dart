import 'dart:convert';
import 'dart:typed_data';

/// A single contact as stored in a backup.
class BackupContact {
  BackupContact({
    required this.shortCode,
    required this.address,
    this.displayName,
  });

  /// The peer's 10-digit short code.
  final String shortCode;

  /// The peer's transport address string (e.g. a libp2p `peerId|multiaddrs`).
  final String address;

  /// Optional local nickname.
  final String? displayName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'shortCode': shortCode,
        'address': address,
        if (displayName != null) 'displayName': displayName,
      };

  factory BackupContact.fromJson(Map<String, dynamic> json) => BackupContact(
        shortCode: json['shortCode'] as String,
        address: json['address'] as String,
        displayName: json['displayName'] as String?,
      );
}

/// The structured contents of a Tincan backup: the recovery phrase plus the
/// contact list. Messages are intentionally NOT included by default — they are
/// large and forward-secret; backing them up is an explicit, separate opt-in.
///
/// This object is serialised to JSON and then sealed by [BackupVault] before it
/// ever leaves the device, so the recovery phrase is only ever written out
/// encrypted.
class BackupArchive {
  BackupArchive({
    required this.createdAtEpochMs,
    required this.mnemonic,
    this.contacts = const <BackupContact>[],
    this.appVersion = 'unknown',
  });

  /// Backup schema version, to allow forward-compatible migrations.
  static const int schemaVersion = 1;

  final int createdAtEpochMs;
  final String mnemonic;
  final List<BackupContact> contacts;
  final String appVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema': schemaVersion,
        'createdAt': createdAtEpochMs,
        'appVersion': appVersion,
        'mnemonic': mnemonic,
        'contacts': contacts.map((c) => c.toJson()).toList(),
      };

  factory BackupArchive.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'] as int?;
    if (schema != null && schema > schemaVersion) {
      throw FormatException(
          'Backup schema $schema is newer than supported $schemaVersion');
    }
    return BackupArchive(
      createdAtEpochMs: json['createdAt'] as int,
      mnemonic: json['mnemonic'] as String,
      appVersion: (json['appVersion'] as String?) ?? 'unknown',
      contacts: ((json['contacts'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => BackupContact.fromJson(
              (e as Map<dynamic, dynamic>).cast<String, dynamic>()))
          .toList(),
    );
  }

  /// UTF-8 JSON bytes, ready to hand to [BackupVault.seal].
  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  /// Parses the bytes returned by [BackupVault.open].
  factory BackupArchive.fromBytes(Uint8List bytes) => BackupArchive.fromJson(
      (jsonDecode(utf8.decode(bytes)) as Map<dynamic, dynamic>)
          .cast<String, dynamic>());
}
