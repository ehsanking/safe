# Tincan Architecture

Tincan is a serverless, account-less, end-to-end-encrypted messenger. Its
guiding idea is to **separate security from transport**: the cryptography lives
in a small, auditable, pure-Dart engine, and the network is just a swappable way
to move opaque ciphertext between two devices.

```
┌───────────────────────────────────────────────────────────────┐
│  app/  (Flutter — Android, Windows)                            │
│  onboarding · contacts · chat · backup settings · key UX       │
└───────────────▲───────────────────────────▲───────────────────┘
                │ depends on                │ depends on
┌───────────────┴───────────┐   ┌───────────┴───────────────────┐
│  tincan_core (pure Dart)   │   │  tincan_net                   │
│  identity · sessions ·     │   │  Libp2pTransport implements   │
│  AEAD · delivery · backup  │◄──┤  tincan_core's Transport      │
│  Transport (interface)     │   │  (dart_libp2p: TCP+Noise+Yamux)│
└────────────────────────────┘   └───────────────────────────────┘
```

`tincan_core` has **no Flutter and no networking dependency**. That is the whole
point: the security-critical code can be unit-tested and audited as plain Dart,
and the transport can be replaced (libp2p today, WebRTC or a custom UDP stack
tomorrow) without touching it.

## The 12 production layers

Tincan is organized around twelve concerns that take a privacy app from "demo"
to "something people can trust." Each maps to concrete code or process.

| # | Layer | Where | Status |
|---|-------|-------|--------|
| 1 | **Architecture** — clean separation of core / transport / app | this repo's package split | ✅ |
| 2 | **Cryptography** — vetted primitives, no home-rolled crypto | `tincan_core/src/crypto`, `mnemonic`, `session` | ✅ |
| 3 | **Identity & keys** — wallet-style, seed-derived, no accounts | `tincan_core/src/identity` | ✅ |
| 4 | **Transport** — peer-to-peer, authenticated, swappable | `tincan_net` | ✅ TCP; ⏳ UDX/mDNS/DHT |
| 5 | **Persistence** — encrypted-at-rest local storage | `app/` (drift + SQLite3MultipleCiphers) | ⏳ |
| 6 | **Backup & recovery** — client-side-encrypted, untrusted host | `tincan_core/src/backup` + Google Drive glue in `app/` | ✅ core; app glue |
| 7 | **Testing** — unit + real integration tests | `*/test` | ✅ 61 tests |
| 8 | **CI/CD** — format + analyze + test on every push/PR | `.github/workflows/ci.yaml` | ✅ |
| 9 | **Observability** — structured diagnostics, opt-in, no PII | core hooks + app | ⏳ |
| 10 | **Security process** — threat model + responsible disclosure | `docs/THREAT_MODEL.md`, `SECURITY.md` | ✅ |
| 11 | **Documentation** — English, for contributors | `README.md`, `docs/` | ✅ |
| 12 | **Governance** — license, conduct, contribution flow | `LICENSE`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md` | ✅ |

## Cryptographic composition

Tincan does not invent cryptography; it wires together well-reviewed designs.

```
recovery phrase (BIP-0039, 12 words)
        │  PBKDF2-HMAC-SHA512
        ▼
   64-byte seed ──HKDF──► Ed25519 (sign)   ─┐
                 ──HKDF──► X25519 (agree)    ├─ Identity (fingerprint, short code)
                 ──HKDF──► libsignal identity┘
                 ──HKDF──► libp2p peer identity (stable peer id)

contact exchange:  public keys verified via QR or a 60-digit safety number
session:           X3DH (initial agreement) + Double Ratchet (per-message keys)
message AEAD:      XChaCha20-Poly1305
transport:         Noise-secured, Yamux-muxed libp2p streams
backup:            Argon2id(passphrase) → XChaCha20-Poly1305 (client side)
storage:           SQLite3MultipleCiphers, key from device PIN/biometric
```

A single recovery phrase therefore reconstructs the **entire** account —
identity, sessions, and network address — with no server involved.

## Message lifecycle

```
[compose] → [encrypt: Double Ratchet → AEAD] → [enqueue, encrypted at rest]
   → [OutboundQueue: dial peer, send frame] → [peer ACK] → [delivered]
        ▲                                   │
        └──── offline / no ACK: retry every 5–10 min (with jitter) ──┘
```

There is no store-and-forward server. A message is held on the sender and
retried until the recipient is reachable and acknowledges it. (An optional,
ciphertext-only decentralized mailbox is on the roadmap to remove the
"both online" requirement without reintroducing a trusted server.)

## Why this shape

- **No server** means there is no central place to subpoena, breach, or monetize.
- **No account** means there is no identity to sell and far less metadata.
- **Seed-derived everything** means recovery is self-custodial, like a wallet.
- **Transport behind an interface** means the riskiest, least-mature dependency
  (a P2P stack) is quarantined and replaceable, while the security core stays
  small and stable.

See [`THREAT_MODEL.md`](./THREAT_MODEL.md) for who this does and does not protect
against, and [`../DESIGN.md`](../DESIGN.md) for the original design rationale.
