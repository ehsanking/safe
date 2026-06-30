import 'dart:async';
import 'dart:typed_data';

/// Opaque network address of a peer. Concrete transports define the string
/// format (a libp2p multiaddr, an `ip:port`, a relay token, …).
class PeerAddress {
  const PeerAddress(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is PeerAddress && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PeerAddress($value)';
}

/// A frame received from a peer: opaque bytes plus their origin.
class InboundFrame {
  const InboundFrame(this.from, this.bytes);

  final PeerAddress from;
  final Uint8List bytes;
}

/// Pluggable transport seam. The engine speaks only this interface; concrete
/// implementations (`dart_libp2p`, WebRTC data channels, raw UDP, a relay
/// client, …) live in the app/networking layer and stay swappable.
///
/// Delivery *policy* — the "hold on the sender and retry every 5–10 minutes
/// until ACK" behaviour from DESIGN.md §7 — is layered *above* a Transport, not
/// baked into it. A Transport only does best-effort point-to-point sends.
abstract class Transport {
  /// This node's address, valid after [start] completes.
  PeerAddress get localAddress;

  /// Frames received from peers.
  Stream<InboundFrame> get inbound;

  /// Brings the transport online (binds sockets, joins discovery, …).
  Future<void> start();

  /// Best-effort send of one [frame] to [to]. Returns when handed off to the
  /// transport, which is not a delivery guarantee.
  Future<void> send(PeerAddress to, Uint8List frame);

  /// Tears the transport down and releases resources.
  Future<void> close();
}

/// In-process router used by tests and local simulation.
///
/// Lets the full engine be exercised end-to-end (encrypt → send → receive →
/// decrypt) with zero real networking, so the protocol logic is testable on a
/// plain Dart VM.
class InMemoryNetwork {
  final Map<String, InMemoryTransport> _nodes = <String, InMemoryTransport>{};

  /// Creates a transport endpoint bound to [address] on this network.
  InMemoryTransport endpoint(String address) =>
      InMemoryTransport._(this, address);

  void _register(InMemoryTransport node) =>
      _nodes[node.localAddress.value] = node;

  void _unregister(InMemoryTransport node) =>
      _nodes.remove(node.localAddress.value);

  bool _deliver(PeerAddress to, PeerAddress from, Uint8List frame) {
    final node = _nodes[to.value];
    if (node == null) return false;
    node._receive(from, frame);
    return true;
  }
}

/// [Transport] implementation backed by an [InMemoryNetwork]. Test-only.
class InMemoryTransport implements Transport {
  InMemoryTransport._(this._network, String address)
      : localAddress = PeerAddress(address);

  final InMemoryNetwork _network;
  final StreamController<InboundFrame> _inbound =
      StreamController<InboundFrame>.broadcast();

  @override
  final PeerAddress localAddress;

  @override
  Stream<InboundFrame> get inbound => _inbound.stream;

  @override
  Future<void> start() async => _network._register(this);

  @override
  Future<void> send(PeerAddress to, Uint8List frame) async {
    final delivered = _network._deliver(to, localAddress, frame);
    if (!delivered) {
      throw StateError('No in-memory peer at ${to.value}');
    }
  }

  void _receive(PeerAddress from, Uint8List frame) =>
      _inbound.add(InboundFrame(from, frame));

  @override
  Future<void> close() async {
    _network._unregister(this);
    await _inbound.close();
  }
}
