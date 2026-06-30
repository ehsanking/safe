import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:tincan_core/tincan_core.dart';
import 'package:tincan_net/tincan_net.dart';
import 'package:test/test.dart';

void main() {
  group('Libp2pTransport (real TCP loopback)', () {
    test('delivers a frame from one host to another', () async {
      final hostA = await createTcpHost(listen: '/ip4/127.0.0.1/tcp/0');
      final hostB = await createTcpHost(listen: '/ip4/127.0.0.1/tcp/0');
      final a = Libp2pTransport(hostA);
      final b = Libp2pTransport(hostB);
      await a.start();
      await b.start();

      final received = Completer<Uint8List>();
      final sub = b.inbound.listen((f) {
        if (!received.isCompleted) received.complete(f.bytes);
      });

      final frame = Uint8List.fromList(utf8.encode('سلام از روی libp2p'));
      await a.send(b.localAddress, frame);

      final got = await received.future.timeout(const Duration(seconds: 25));
      expect(got, frame);

      await sub.cancel();
      await a.close();
      await b.close();
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('works end-to-end with OutboundQueue', () async {
      final hostA = await createTcpHost(listen: '/ip4/127.0.0.1/tcp/0');
      final hostB = await createTcpHost(listen: '/ip4/127.0.0.1/tcp/0');
      final a = Libp2pTransport(hostA);
      final b = Libp2pTransport(hostB);
      await a.start();
      await b.start();

      final received = Completer<Uint8List>();
      final sub = b.inbound.listen((f) {
        if (!received.isCompleted) received.complete(f.bytes);
      });

      final queue = OutboundQueue(a);
      final frame = Uint8List.fromList(utf8.encode('queued and delivered'));
      final id = queue.enqueue(b.localAddress, frame);
      final handed = await queue.flush();
      expect(handed, [id]);
      expect(queue.stateOf(id), DeliveryState.sent);

      expect(await received.future.timeout(const Duration(seconds: 25)), frame);

      await sub.cancel();
      await a.close();
      await b.close();
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('derives a stable peer id from a seed', () async {
      final seed = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      final h1 = await createTcpHost(
          identitySeed: seed, listen: '/ip4/127.0.0.1/tcp/0');
      final h2 = await createTcpHost(
          identitySeed: seed, listen: '/ip4/127.0.0.1/tcp/0');
      expect(h1.id.toBase58(), h2.id.toBase58());
      await h1.close();
      await h2.close();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
