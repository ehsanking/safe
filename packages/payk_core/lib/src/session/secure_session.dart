import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

/// A single end-to-end-encrypted conversation with one remote device, built on
/// the Signal protocol (X3DH for the initial agreement, Double Ratchet for
/// ongoing messages → forward secrecy and post-compromise security).
///
/// Wire framing: every encrypted frame is `[typeByte] ‖ libsignalSerialized`,
/// where `typeByte` distinguishes the initial [PreKeySignalMessage] (type 3)
/// from subsequent [SignalMessage]s (type 2). The transport layer carries these
/// opaque frames and never sees plaintext.
class SecureSession {
  SecureSession(this._store, this.remoteAddress)
      : _cipher = SessionCipher.fromStore(_store, remoteAddress);

  final SignalProtocolStore _store;

  /// The remote device this session talks to. The address name should be the
  /// peer's stable identity id (e.g. its short code / fingerprint).
  final SignalProtocolAddress remoteAddress;

  final SessionCipher _cipher;

  /// Initiates a session toward the peer using their published [bundle]
  /// (X3DH). Only the initiator calls this; the responder establishes its side
  /// automatically when it decrypts the first [PreKeySignalMessage].
  Future<void> initiateFromBundle(PreKeyBundle bundle) async {
    final builder = SessionBuilder.fromSignalStore(_store, remoteAddress);
    await builder.processPreKeyBundle(bundle);
  }

  /// Encrypts [plaintext], returning the opaque wire frame to hand to the
  /// transport. Each call advances the ratchet, so identical plaintexts produce
  /// different frames.
  Future<Uint8List> encrypt(List<int> plaintext) async {
    final message = await _cipher.encrypt(Uint8List.fromList(plaintext));
    final body = message.serialize();
    final frame = Uint8List(body.length + 1);
    frame[0] = message.getType();
    frame.setRange(1, frame.length, body);
    return frame;
  }

  /// Decrypts a wire frame produced by a peer's [encrypt], returning the
  /// plaintext bytes.
  ///
  /// Throws [DuplicateMessageException] if the same frame is delivered twice —
  /// callers driving an at-least-once delivery queue should treat that as
  /// "already received" and (re)send the ACK rather than surfacing an error.
  Future<Uint8List> decrypt(Uint8List frame) async {
    if (frame.isEmpty) {
      throw ArgumentError('Empty frame');
    }
    final type = frame[0];
    final body = frame.sublist(1);
    switch (type) {
      case CiphertextMessage.prekeyType:
        return _cipher.decrypt(PreKeySignalMessage(body));
      case CiphertextMessage.whisperType:
        return _cipher.decryptFromSignal(SignalMessage.fromSerialized(body));
      default:
        throw ArgumentError('Unknown ciphertext type: $type');
    }
  }
}
