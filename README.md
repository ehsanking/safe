<div align="center">

# 🥫 Tincan

**Two tin cans and a string — secured by modern cryptography.**
**No servers. No accounts. No one in the middle.**

[![CI](https://github.com/ehsanking/safe/actions/workflows/ci.yaml/badge.svg)](https://github.com/ehsanking/safe/actions/workflows/ci.yaml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)
[![Tests](https://img.shields.io/badge/tests-61_passing-brightgreen.svg)](#testing)

</div>

---

Humanity has always wanted to pass a message to someone else **without a third
party able to read it, store it, or sell it.** Every messenger that promises
this is, in the end, a *service*: a server that holds your account, your
contacts, and your metadata — a single place to breach, subpoena, or monetize.

**Tincan removes the middle.** Your identity is a key, like a crypto wallet — not
an account on someone's server. Messages travel directly between two devices,
end-to-end encrypted. The only place plaintext ever exists is the two ends of the
conversation. Everything in between — and even the data on your own phone — is
just ciphertext.

> Picture two kids with tin cans and a string. That is the whole architecture.
> Tincan only replaces the string with unbreakable cryptography and makes sure no
> operator is ever holding it.

## Why this exists

- **Your data should never be compromised.** There is no server holding it to
  breach.
- **Your information should never be sold.** There is no account or metadata to
  sell.
- **You shouldn't have to trust an operator.** You trust mathematics instead.

## How it's different

| Typical messenger | Tincan |
|---|---|
| Central server holds messages & accounts | Each device is its own node |
| Sign up with a phone number / email | Identity = a keypair from a recovery phrase |
| Trust the service operator | Trust only the cryptography |
| Central, subpoena-able metadata | No account and no server to subpoena |
| "Encrypted" — but the server still sees who, when | Plaintext exists only at the two endpoints |

## How it works (in one minute)

1. **Register** = generate a 12-word recovery phrase (BIP-0039). From it, Tincan
   derives all your keys — signing, key-agreement, the Signal session identity,
   and even your peer-to-peer network address. One phrase restores *everything*.
2. **Add a contact** by scanning their QR code (or typing their 10-digit short
   code and confirming a safety number). No server lookup, no directory.
3. **Send a message.** It's encrypted with the Signal protocol (X3DH + Double
   Ratchet → forward secrecy), framed, and sent **directly** to your contact's
   device over an authenticated libp2p connection.
4. **If they're offline,** the encrypted message waits on *your* device and
   retries every few minutes until they come online and acknowledge it.
5. **Back up** your identity and contacts to Google Drive — sealed on your device
   first, so Google only ever stores random bytes.

## Status

Tincan is **experimental** and under active construction. The cryptographic
engine and the peer-to-peer transport are implemented and tested; the app and
the decentralized discovery layer are in progress.

| Component | What it is | State |
|---|---|---|
| `packages/tincan_core` | Pure-Dart engine: identity, Signal sessions, AEAD, delivery queue, encrypted backup | ✅ 58 tests |
| `packages/tincan_net` | P2P transport on dart_libp2p (TCP + Noise + Yamux) | ✅ 3 tests |
| `app/` | Flutter app (Android + Windows) | 🚧 scaffold |
| Discovery (mDNS/DHT), NAT traversal (UDX) | Decentralized "phone book" | ⏳ planned |
| Encrypted storage (drift + SQLCipher) | At-rest protection | ⏳ planned |

See [docs/ROADMAP.md](./docs/ROADMAP.md) for the full plan.

## Architecture

```
app/  (Flutter: Android, Windows)
  │  depends on
  ├── tincan_core   pure Dart — identity, sessions, AEAD, delivery, backup,
  │                 and the Transport interface (no Flutter, no networking)
  └── tincan_net    Libp2pTransport implements tincan_core's Transport
                    (dart_libp2p; TCP + Noise + Yamux today)
```

The security-critical code (`tincan_core`) is plain Dart with **no Flutter and no
network dependency**, so it can be unit-tested and audited in isolation. The
transport sits behind an interface so the least-mature dependency stays
quarantined and replaceable.

Deep dives:

- [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) — components, the 12 production
  layers, cryptographic composition, message lifecycle.
- [docs/THREAT_MODEL.md](./docs/THREAT_MODEL.md) — who this protects against, and
  who it doesn't.
- [DESIGN.md](./DESIGN.md) — the original design rationale (in Persian).

## Cryptography

Tincan **does not invent cryptography.** It composes well-reviewed designs:

- **BIP-0039** — recovery-phrase → seed (vendored, checksum-verified wordlist,
  validated against the official test vectors).
- **Ed25519 / X25519** — signing and key agreement, derived from the seed.
- **Signal protocol** — X3DH + Double Ratchet for forward secrecy and
  post-compromise security (via `libsignal_protocol_dart`).
- **Noise Protocol Framework** — authenticated, forward-secret transport (via
  libp2p).
- **XChaCha20-Poly1305** — authenticated encryption.
- **Argon2id** — passphrase stretching for backups.

> ⚠️ The Dart *implementations* of these primitives have not had an independent
> security audit. See [SECURITY.md](./SECURITY.md). Treat Tincan as experimental.

## Getting started

### The engine and transport (Dart)

You need the Dart SDK (3.5+).

```bash
# Cryptographic engine
cd packages/tincan_core
dart pub get
dart test       # 58 tests: BIP39 vectors, identity, sessions, backup, …

# Peer-to-peer transport (spins up real libp2p hosts over TCP)
cd ../tincan_net
dart pub get
dart test       # 3 tests: real frame delivery between two nodes
```

### The app (Flutter)

You need Flutter (with the Android and/or Windows toolchains installed).

```bash
cd app
flutter pub get
flutter run -d windows     # or: flutter run -d android
```

> The app is an early scaffold — it wires the core and transport together and is
> the best place to contribute UI and integration work.

## Testing

CI runs, for every package, the exact three checks you should run locally:

```bash
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

61 tests pass today (58 core + 3 transport), including BIP-0039 known-answer
vectors, Double Ratchet forward-secrecy and replay checks, real libp2p delivery,
and backup tamper-rejection.

## Contributing

Tincan is built to be developed by many hands. Good first issues, the dev setup,
and the bar for cryptographic code are in
[CONTRIBUTING.md](./CONTRIBUTING.md). Be excellent to each other
([Code of Conduct](./CODE_OF_CONDUCT.md)). Found a vulnerability? Please follow
[SECURITY.md](./SECURITY.md) instead of opening a public issue.

If you believe people deserve communication that can't be surveilled or sold,
this is a place to help build it.

## Acknowledgments

Tincan stands on the shoulders of **Signal**, **Briar**, **Tox**, **Jami**,
**Session**, **Nostr**, the **Noise Protocol Framework**, **libp2p**, and the
**BIP-0039** standard.

## License

[Apache License 2.0](./LICENSE) — permissive, with an explicit patent grant, so
anyone can build on Tincan.
