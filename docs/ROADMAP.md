# Tincan Roadmap

A 10-year project starts by being honest about where it is. This is the path
from "tested foundation" to "something the world can rely on."

## Done

- [x] Architecture: clean core / transport / app split.
- [x] Identity from a BIP-0039 recovery phrase (Ed25519 + X25519).
- [x] Human-friendly short code + safety number for verification.
- [x] X3DH + Double Ratchet end-to-end encryption (forward secrecy).
- [x] Delivery queue: hold-on-sender + retry until ACK.
- [x] Peer-to-peer transport over libp2p (TCP + Noise + Yamux), tested on real
      sockets, with a seed-derived stable peer id.
- [x] Client-side-encrypted backups (Argon2id + XChaCha20-Poly1305).
- [x] Project foundation: license, CI, security policy, docs, contribution flow.

## Next (near term)

- [ ] **Reachability**: UDX transport + STUN/ICE hole-punching, mDNS local
      discovery, and DHT-based peer lookup — the decentralized "phone book."
- [ ] **Encrypted storage**: `drift` + SQLite3MultipleCiphers, keyed by a device
      PIN/biometric, with a panic wipe.
- [ ] **App**: complete onboarding (create/restore), QR contact exchange,
      conversation UI, and Google Drive backup/restore.
- [ ] **Background delivery** within OS limits (foreground service on Android, a
      push wake signal that carries no content).

## Later (medium term)

- [ ] **Optional decentralized mailbox**: ciphertext-only relays so delivery no
      longer requires both peers online at once — without a trusted server.
- [ ] **Onion routing** + padding to hide *who talks to whom*, not just content.
- [ ] **Multi-device**: linked-device key sync from one recovery phrase.
- [ ] **Groups**: sender-key / MLS-style group messaging.
- [ ] **Disappearing messages** and per-conversation retention.

## Foundations (ongoing)

- [ ] **Independent security audit** of the Dart crypto implementations, and a
      libsodium-backed hardening path for AEAD/KDF.
- [ ] **Reproducible builds** and signed releases for Android and Windows.
- [ ] **Localization** of the app and docs.
- [ ] **Accessibility** pass on the UI.

If you want to take one of these on, see [`../CONTRIBUTING.md`](../CONTRIBUTING.md).
Open an issue to claim it so we don't duplicate work.
