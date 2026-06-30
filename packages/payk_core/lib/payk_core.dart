/// Payk core: a pure-Dart cryptography and protocol engine for a serverless,
/// end-to-end-encrypted messenger.
///
/// This package deliberately has **no Flutter dependency**. The Flutter app
/// (Android + Windows) depends on it, but the engine itself is plain Dart so it
/// can be unit-tested in isolation and audited without UI noise.
///
/// See `DESIGN.md` at the repository root for the architecture and threat model.
library;

export 'src/crypto/aead.dart';
export 'src/delivery/outbound_queue.dart';
export 'src/identity/identity.dart';
export 'src/identity/short_code.dart';
export 'src/mnemonic/mnemonic.dart';
export 'src/mnemonic/wordlist_english.dart' show englishWordlist;
export 'src/session/secure_session.dart';
export 'src/session/signal_account.dart';
export 'src/transport/transport.dart';

// Re-export the libsignal types that surface in payk_core's public API, so
// consumers need not import libsignal_protocol_dart directly for the basics.
export 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show
        PreKeyBundle,
        SignalProtocolAddress,
        CiphertextMessage,
        DuplicateMessageException;
