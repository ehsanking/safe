import 'dart:async';
import 'dart:typed_data';

import 'package:dart_libp2p/dart_libp2p.dart';
import 'package:tincan_core/tincan_core.dart'
    show Transport, PeerAddress, InboundFrame;

/// A [Transport] backed by a libp2p [Host]: it maps Tincan's frame-based
/// send/inbound model onto libp2p streams over a single application protocol.
///
/// Each frame travels on its own short-lived stream (open → length-prefixed
/// write → close). That keeps delivery simple and dovetails with the
/// at-least-once retry policy in tincan_core's `OutboundQueue`.
///
/// PeerAddress encoding: `"<peerIdBase58>|<multiaddr1,multiaddr2,...>"` — enough
/// for [send] to dial, and produced for inbound frames so the receiver can
/// address a reply.
class Libp2pTransport implements Transport {
  Libp2pTransport(this._host);

  /// The single application protocol id all Tincan frames are sent over.
  static const String protocolId = '/tincan/msg/1.0.0';

  final Host _host;
  final StreamController<InboundFrame> _inbound =
      StreamController<InboundFrame>.broadcast();

  @override
  PeerAddress get localAddress =>
      // network.listenAddresses carries the concrete bound addresses (with the
      // resolved port); host.addrs can be empty until identify/observed-address
      // processing runs.
      PeerAddress(_encode(_host.id, _host.network.listenAddresses));

  @override
  Stream<InboundFrame> get inbound => _inbound.stream;

  @override
  Future<void> start() async {
    _host.setStreamHandler(protocolId, (stream, remotePeer) async {
      try {
        final frame = await _readFrame(stream);
        final from =
            PeerAddress(_encode(remotePeer, [stream.conn.remoteMultiaddr]));
        if (!_inbound.isClosed) {
          _inbound.add(InboundFrame(from, frame));
        }
      } finally {
        await stream.close();
      }
    });
  }

  @override
  Future<void> send(PeerAddress to, Uint8List frame) async {
    final target = _decode(to.value);
    // Register the peer's addresses directly. connect() also adds them, but
    // through an addrs factory that filters loopback/private addresses — which
    // would leave nothing to dial on a LAN or in tests.
    await _host.peerStore.addrBook
        .addAddrs(target.id, target.addrs, const Duration(hours: 1));
    await _host.connect(AddrInfo(target.id, target.addrs));
    final stream = await _host.newStream(target.id, [protocolId], Context());
    try {
      await _writeFrame(stream, frame);
    } finally {
      await stream.close();
    }
  }

  @override
  Future<void> close() async {
    _host.removeStreamHandler(protocolId);
    if (!_inbound.isClosed) {
      await _inbound.close();
    }
    await _host.close();
  }

  // --- wire framing: a 4-byte big-endian length prefix, then the bytes ---

  Future<void> _writeFrame(P2PStream stream, Uint8List frame) async {
    final header = Uint8List(4);
    ByteData.view(header.buffer).setUint32(0, frame.length, Endian.big);
    await stream.write(header);
    await stream.write(frame);
  }

  Future<Uint8List> _readFrame(P2PStream stream) async {
    final header = await _readExactly(stream, 4);
    final length = ByteData.view(header.buffer, header.offsetInBytes, 4)
        .getUint32(0, Endian.big);
    return _readExactly(stream, length);
  }

  Future<Uint8List> _readExactly(P2PStream stream, int n) async {
    final builder = BytesBuilder(copy: false);
    while (builder.length < n) {
      final chunk = await stream.read(n - builder.length);
      if (chunk.isEmpty) {
        throw StateError('Stream closed after ${builder.length}/$n bytes');
      }
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  String _encode(PeerId id, List<MultiAddr> addrs) =>
      '${id.toBase58()}|${addrs.map((a) => a.toString()).join(',')}';

  _Target _decode(String value) {
    final sep = value.indexOf('|');
    final idPart = sep < 0 ? value : value.substring(0, sep);
    final addrPart = sep < 0 ? '' : value.substring(sep + 1);
    final addrs = addrPart
        .split(',')
        .where((s) => s.isNotEmpty)
        .map((s) => MultiAddr(s))
        .toList();
    return _Target(PeerId.fromString(idPart), addrs);
  }
}

class _Target {
  _Target(this.id, this.addrs);

  final PeerId id;
  final List<MultiAddr> addrs;
}
