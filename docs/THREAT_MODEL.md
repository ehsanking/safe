# Tincan Threat Model

Security claims are meaningless without naming the adversary. This document
states what Tincan protects, against whom, and — just as importantly — what it
does **not** protect against.

## What we protect

- **Confidentiality** of message content.
- **Integrity & authenticity**: messages are unmodified and provably from the
  claimed sender.
- **Confidentiality at rest**: data on a seized device.
- **Self-custody**: no third party holds anything that can read your messages,
  including the backup host.

## Adversaries and defenses

| Adversary | Capability | Defense | Residual risk |
|-----------|-----------|---------|---------------|
| Passive network observer (ISP, Wi-Fi, relay) | Sees all packets | E2E encryption; ciphertext is indistinguishable from random | Traffic timing/size, and **the IPs of both peers** are visible |
| Active machine-in-the-middle during contact add | Substitutes a fake key | QR exchange or 60-digit safety-number verification, bound into the Noise/X3DH handshake | If the user skips verification |
| Device seizure / theft | Physical access | At-rest encryption keyed by PIN/biometric (Argon2id); panic wipe; forward secrecy | Malware on an unlocked device |
| Backup host (e.g. Google Drive) | Holds the backup file | Backup is sealed client-side with Argon2id + XChaCha20-Poly1305 before upload | A weak passphrase + offline brute force |
| Malicious peer | Receives what you send them | Limited to that conversation; optional disappearing messages | They can save/leak what they legitimately receive |
| Global traffic-analysis adversary | Observes the whole network | (Roadmap) onion routing + padding | In base mode, "who talks to whom" is inferable from IPs |

## Explicit non-goals

These are deliberate limitations, not bugs:

1. **A compromised endpoint.** If malware runs on the device with keys unlocked,
   no messenger can save you.
2. **Hiding that communication exists** in base peer-to-peer mode. The content is
   protected; the *existence* of a connection between two IPs is not, until
   onion routing lands.
3. **Recovering a lost recovery phrase.** There is no server to reset it. This is
   the cost of having no one able to impersonate you.
4. **Simultaneous-online not required forever.** Today, direct delivery needs a
   moment of overlap; the optional mailbox (ciphertext-only) is the planned fix.

## Cryptographic assurance status

Tincan composes audited *designs* (BIP-0039, the Signal protocol, the Noise
framework, Argon2id, XChaCha20-Poly1305). However, the **Dart implementations**
of these primitives have not had an independent security audit. Until they do:

- Treat Tincan as **experimental** for high-risk users.
- The architecture keeps AEAD/KDF behind interfaces so high-assurance operations
  can be routed through libsodium (the `sodium` FFI package) as a hardening step.

Responsible disclosure: see [`../SECURITY.md`](../SECURITY.md).
