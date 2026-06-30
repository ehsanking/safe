# Contributing to Tincan

Thank you for wanting to help build private, serverless communication. Tincan is
meant to be developed by many hands, so this guide tries to make contributing as
frictionless as possible.

## Ground rules

- **Be kind.** See the [Code of Conduct](./CODE_OF_CONDUCT.md).
- **Security first.** If you found a vulnerability, follow
  [SECURITY.md](./SECURITY.md) — do not open a public issue.
- **Never roll your own crypto.** Use the vetted designs already in the core
  (BIP39, Signal, Noise, Argon2id, XChaCha20-Poly1305). New cryptographic
  constructions need a written rationale and review.

## Repository layout

```
packages/tincan_core/   Pure-Dart engine: identity, sessions, backup, delivery.
packages/tincan_net/    P2P transport on dart_libp2p (implements core's Transport).
app/                    Flutter app (Android + Windows today).
docs/                   Architecture, threat model, roadmap.
```

`tincan_core` has **no Flutter dependency** on purpose, so it can be tested and
audited as plain Dart. Keep it that way: platform/UI code belongs in `app/`.

## Development setup

You need the Dart SDK (3.5+). For the app you also need Flutter.

```bash
# Core engine
cd packages/tincan_core
dart pub get
dart test          # unit + integration tests
dart analyze
dart format .

# Transport
cd ../tincan_net
dart pub get
dart test          # spins up real libp2p hosts over TCP loopback
```

CI runs exactly these steps (`dart format --set-exit-if-changed`,
`dart analyze --fatal-infos`, `dart test`) for both packages, so run them
locally before opening a PR.

## Pull requests

1. Branch from `main`.
2. Keep PRs focused; one logical change per PR.
3. Add or update tests — new behavior without a test will usually be asked to
   add one. The core is held to a high bar: cryptographic code should have
   round-trip, tamper-rejection, and (where relevant) known-answer tests.
4. Update docs (`README`, `docs/`, `CHANGELOG.md`) when behavior changes.
5. Make sure CI is green.

## Good first issues

- Add a UDX transport alongside TCP in `tincan_net` (better NAT traversal).
- Wire mDNS local discovery so two devices on the same Wi-Fi find each other.
- Implement the encrypted storage layer (`drift` + SQLite3MultipleCiphers).
- Add a QR scanner/generator flow for contact exchange in the app.
- Translate the docs.

See [docs/ROADMAP.md](./docs/ROADMAP.md) for the bigger picture.

## Commit messages

Write clear, present-tense messages explaining *why*. Reference issues where
relevant. We do not require a specific format, only clarity.
