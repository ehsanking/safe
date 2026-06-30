# Security Policy

Tincan is a privacy tool. A vulnerability here can put real people at real risk,
so we treat security reports as the highest priority.

## Reporting a vulnerability

**Please do not open a public issue for security vulnerabilities.**

Instead, use GitHub's private vulnerability reporting:

1. Go to the repository's **Security** tab → **Report a vulnerability**.
2. Describe the issue, the affected component, and a proof of concept if you
   have one.

We aim to acknowledge reports within 72 hours and to ship a fix or mitigation as
quickly as the severity warrants. We will credit you in the release notes unless
you prefer to remain anonymous.

## Scope

In scope:

- The cryptographic core (`packages/tincan_core`): identity derivation, the
  Signal session layer, AEAD usage, and the backup vault.
- The transport (`packages/tincan_net`): peer authentication, framing, and any
  way a peer can crash or desync another.
- The application's handling of keys, the recovery phrase, and backups.

Examples of what we care about most:

- Anything that exposes plaintext, the recovery phrase, or key material to a
  third party (a relay, a backup host, a network observer).
- Anything that lets one party impersonate another or perform a
  machine-in-the-middle during contact exchange.
- Weakening of forward secrecy / post-compromise security.
- Backups that are decryptable without the passphrase.

## What Tincan does NOT defend against

These are documented non-goals (see `DESIGN.md` and `docs/THREAT_MODEL.md`), not
vulnerabilities:

- A fully compromised endpoint (malware on the device with the keys unlocked).
- Traffic-analysis of *who talks to whom* by IP in the base peer-to-peer mode
  (mitigated only once onion routing lands — see the roadmap).
- Loss of the recovery phrase: by design there is no server to reset it.

## Cryptography note

Tincan composes well-reviewed designs (BIP39, the Signal protocol, the Noise
framework, Argon2id, XChaCha20-Poly1305) but the **Dart implementations** of
these primitives are not independently audited. Until a third-party audit is
completed, treat Tincan as **experimental** for high-risk users, and prefer the
libsodium-backed hardening path described in the architecture docs.
