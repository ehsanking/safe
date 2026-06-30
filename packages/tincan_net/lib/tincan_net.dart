/// Tincan networking: a peer-to-peer [Transport] implementation built on
/// dart_libp2p (TCP today; UDX/mDNS/DHT/NAT-traversal layered on next).
///
/// Kept in its own package so the heavy, single-author libp2p dependency — and
/// its protobuf-3 constraint — stays isolated from and swappable behind the
/// crypto core in `tincan_core`.
library;

export 'src/libp2p_host.dart';
export 'src/libp2p_transport.dart';
