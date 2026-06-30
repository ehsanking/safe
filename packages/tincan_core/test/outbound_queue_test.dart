import 'dart:typed_data';

import 'package:tincan_core/tincan_core.dart';
import 'package:test/test.dart';

void main() {
  group('OutboundQueue (hold-on-sender + retry until ACK)', () {
    late InMemoryNetwork net;
    late InMemoryTransport aliceT;
    late OutboundQueue queue;
    var fakeNow = 1000;

    setUp(() async {
      net = InMemoryNetwork();
      aliceT = net.endpoint('alice');
      await aliceT.start();
      queue = OutboundQueue(aliceT, clock: () => fakeNow);
    });

    Uint8List frame(String s) => Uint8List.fromList(s.codeUnits);

    test('holds a message while the peer is offline, delivers when online',
        () async {
      final id = queue.enqueue(const PeerAddress('bob'), frame('hi'));
      expect(queue.stateOf(id), DeliveryState.queued);

      // Bob is offline → send fails, message stays queued and is retried later.
      var handed = await queue.flush();
      expect(handed, isEmpty);
      expect(queue.stateOf(id), DeliveryState.queued);
      expect(queue.pending.single.attempts, 1);

      // Bob comes online and starts listening.
      final received = <Uint8List>[];
      final bobT = net.endpoint('bob');
      await bobT.start();
      bobT.inbound.listen((f) => received.add(f.bytes));

      // Next retry succeeds.
      fakeNow += 300000; // +5 min
      handed = await queue.flush();
      expect(handed, [id]);
      expect(queue.stateOf(id), DeliveryState.sent);
      await Future<void>.delayed(Duration.zero); // let the stream deliver
      expect(received.single, frame('hi'));

      // ACK stops further retries.
      queue.ackDelivered(id);
      expect(queue.stateOf(id), DeliveryState.delivered);
      expect(queue.pending, isEmpty);
    });

    test('does not resend a delivered message', () async {
      final bobT = net.endpoint('bob');
      await bobT.start();
      var count = 0;
      bobT.inbound.listen((_) => count++);

      final id = queue.enqueue(const PeerAddress('bob'), frame('x'));
      await queue.flush();
      await Future<void>.delayed(Duration.zero);
      queue.ackDelivered(id);

      // A later flush round must not re-send it.
      final handed = await queue.flush();
      expect(handed, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(count, 1);
    });

    test('keeps retrying an un-acked message across rounds', () async {
      final bobT = net.endpoint('bob');
      await bobT.start();
      var count = 0;
      bobT.inbound.listen((_) => count++);

      queue.enqueue(const PeerAddress('bob'), frame('y'));
      await queue.flush(); // sent, but no ACK
      await queue.flush(); // still no ACK → re-sent
      await Future<void>.delayed(Duration.zero);
      expect(count, 2, reason: 'at-least-once until ACK');
    });
  });
}
