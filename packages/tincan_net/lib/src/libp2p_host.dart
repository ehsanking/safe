import 'dart:typed_data';

import 'package:dart_libp2p/config/config.dart' as p2p_config;
import 'package:dart_libp2p/core/crypto/ed25519.dart' as ed;
import 'package:dart_libp2p/dart_libp2p.dart';
import 'package:dart_libp2p/p2p/host/resource_manager/limiter.dart';
import 'package:dart_libp2p/p2p/host/resource_manager/resource_manager_impl.dart';
import 'package:dart_libp2p/p2p/security/noise/noise_protocol.dart';
import 'package:dart_libp2p/p2p/transport/connection_manager.dart' as p2p_conn;
import 'package:dart_libp2p/p2p/transport/tcp_transport.dart';

/// Builds and starts a libp2p [Host]: TCP transport, Noise-secured connections,
/// and the default Yamux muxer + resource manager that `Libp2p.new_` supplies.
///
/// Pass [identitySeed] (exactly 32 bytes — e.g.
/// `HKDF(bip39Seed, info: 'tincan/libp2p/identity/v1')`) to make the peer id
/// **deterministic**, so a peer's address is stable across restarts and tied to
/// the same recovery phrase that controls the rest of the identity. Omit it for
/// a fresh random identity.
///
/// TCP is used first because it is universal and reliable on Android, Windows
/// and desktop. UDX (for UDP hole-punching / better NAT traversal) is a later
/// addition; because everything sits behind tincan_core's `Transport` seam, call
/// sites do not change when the underlying transport is swapped or extended.
Future<Host> createTcpHost({
  Uint8List? identitySeed,
  String listen = '/ip4/0.0.0.0/tcp/0',
}) async {
  if (identitySeed != null && identitySeed.length < 32) {
    throw ArgumentError.value(
        identitySeed.length, 'identitySeed', 'Must be at least 32 bytes');
  }

  final keyPair = identitySeed != null
      ? await ed.generateEd25519KeyPairFromSeed(
          Uint8List.fromList(identitySeed.sublist(0, 32)))
      : await ed.generateEd25519KeyPair();

  final connManager = p2p_conn.ConnectionManager();
  final resourceManager = ResourceManagerImpl(limiter: FixedLimiter());

  final options = <p2p_config.Option>[
    p2p_config.Libp2p.identity(keyPair),
    p2p_config.Libp2p.connManager(connManager),
    p2p_config.Libp2p.transport(
      TCPTransport(resourceManager: resourceManager, connManager: connManager),
    ),
    p2p_config.Libp2p.security(await NoiseSecurity.create(keyPair)),
    p2p_config.Libp2p.listenAddrs([MultiAddr(listen)]),
  ];

  final host = await p2p_config.Libp2p.new_(options);
  await host.start();
  return host;
}
