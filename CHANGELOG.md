# Changelog

All notable changes to Tincan are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and the project aims to follow
[Semantic Versioning](https://semver.org/) once it reaches 1.0.

## [Unreleased]

### Added

- **Cryptographic core (`tincan_core`)**
  - BIP-0039 mnemonic generation, validation, and seed derivation, implemented
    against a vendored, checksum-verified English wordlist and the official
    Trezor test vectors.
  - Self-sovereign `Identity`: Ed25519 (signing) and X25519 (key agreement)
    derived deterministically from the seed via HKDF.
  - `ShortCode`: a human-friendly 10-digit handle (with a Luhn check digit) and
    a 60-digit safety number for out-of-band key verification.
  - `AeadCipher` abstraction with an XChaCha20-Poly1305 implementation.
  - `SignalAccount` + `SecureSession`: X3DH + Double Ratchet end-to-end
    encryption (forward secrecy, post-compromise security), with the libsignal
    identity also derived deterministically from the recovery phrase.
  - `OutboundQueue`: the "hold on the sender, retry until ACK" delivery policy.
  - `BackupVault` + `BackupArchive`: client-side-encrypted backups (Argon2id +
    XChaCha20-Poly1305) that are safe to store on an untrusted host such as
    Google Drive.
- **Transport (`tincan_net`)**
  - `Libp2pTransport`: a peer-to-peer transport on dart_libp2p (TCP + Noise +
    Yamux today), implementing the core `Transport` interface, with a
    deterministic peer id derived from the seed.
- **Application (`app/`)**
  - Flutter app scaffold (Android + Windows) wiring the core and transport, with
    onboarding, contacts, chat, and Google Drive backup settings.
- **Project**
  - Apache-2.0 license, CI (format + analyze + test for both packages), security
    policy, contributing guide, code of conduct, issue/PR templates, and
    English architecture/threat-model/roadmap documentation.

### Notes

- `libsignal_protocol_dart` is pinned to exactly `0.7.2` so it shares
  `protobuf ^3` with `dart_libp2p`; the Signal protocol logic is unchanged
  across that and newer releases.
- The Dart implementations of the cryptographic primitives are **not yet
  independently audited**. Treat Tincan as experimental.
