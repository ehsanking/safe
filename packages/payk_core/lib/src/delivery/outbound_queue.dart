import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../transport/transport.dart';

/// Delivery state of a queued outbound message.
enum DeliveryState {
  /// Waiting to be (re)sent — peer was unreachable or not yet tried.
  queued,

  /// Handed to the transport, awaiting the peer's ACK.
  sent,

  /// ACK received; will not be retried again.
  delivered,
}

/// One message sitting in the outbound queue.
class OutboundMessage {
  OutboundMessage({
    required this.id,
    required this.to,
    required this.frame,
    required this.createdAt,
  });

  final String id;
  final PeerAddress to;
  final Uint8List frame;
  final int createdAt;

  DeliveryState state = DeliveryState.queued;
  int attempts = 0;
  int? lastAttemptAt;
}

/// Returns the current time in epoch milliseconds (injectable for tests).
typedef Clock = int Function();

/// Implements the project's delivery model (DESIGN.md §7): the message is held
/// on the **sender's** device, encrypted, and retried on an interval until the
/// peer comes online and ACKs it. There is no store-and-forward server.
///
/// This class owns the *policy* (queueing, retry, ACK accounting). It sits on
/// top of a [Transport], which only does best-effort point-to-point sends.
///
/// NOTE: retrying re-sends the identical ciphertext frame. With the Double
/// Ratchet the receiver will reject a duplicate with `DuplicateMessageException`
/// — the receiver must treat that as "already have it" and re-ACK. That keeps
/// delivery at-least-once without breaking the ratchet.
class OutboundQueue {
  OutboundQueue(
    this._transport, {
    Clock? clock,
    this.retryInterval = const Duration(minutes: 5),
    Random? random,
  })  : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _random = random ?? Random.secure();

  final Transport _transport;
  final Clock _clock;
  final Duration retryInterval;
  final Random _random;

  final Map<String, OutboundMessage> _messages = <String, OutboundMessage>{};
  int _seq = 0;
  Timer? _timer;
  bool _autoRetry = false;

  /// Messages not yet delivered (queued or awaiting ACK).
  List<OutboundMessage> get pending => _messages.values
      .where((m) => m.state != DeliveryState.delivered)
      .toList(growable: false);

  /// State of a message by id, or null if unknown/garbage-collected.
  DeliveryState? stateOf(String id) => _messages[id]?.state;

  /// Adds a message to the queue and returns its id. [id] may be supplied to
  /// make ACK correlation deterministic; otherwise one is generated.
  String enqueue(PeerAddress to, Uint8List frame, {String? id}) {
    final mid = id ?? 'm${_seq++}';
    _messages[mid] = OutboundMessage(
      id: mid,
      to: to,
      frame: frame,
      createdAt: _clock(),
    );
    return mid;
  }

  /// Attempts to (re)send every not-yet-delivered message once. Returns the ids
  /// successfully handed to the transport this round. A send failure (peer
  /// offline) leaves the message queued for the next round.
  Future<List<String>> flush() async {
    final handed = <String>[];
    for (final m in _messages.values) {
      if (m.state == DeliveryState.delivered) continue;
      m.attempts++;
      m.lastAttemptAt = _clock();
      try {
        await _transport.send(m.to, m.frame);
        m.state = DeliveryState.sent;
        handed.add(m.id);
      } catch (_) {
        m.state = DeliveryState.queued;
      }
    }
    return handed;
  }

  /// Records the peer's ACK for [id]; the message stops being retried.
  void ackDelivered(String id) {
    _messages[id]?.state = DeliveryState.delivered;
  }

  /// Starts the production retry driver: roughly every [retryInterval] with up
  /// to +20% random jitter, so the cadence is not perfectly predictable and the
  /// network load is spread out. Tests should call [flush] directly instead.
  void startAutoRetry() {
    if (_autoRetry) return;
    _autoRetry = true;
    _scheduleNext();
  }

  void _scheduleNext() {
    if (!_autoRetry) return;
    final base = retryInterval.inMilliseconds;
    final jitter = (base * 0.2 * _random.nextDouble()).round();
    _timer = Timer(Duration(milliseconds: base + jitter), () async {
      await flush();
      _scheduleNext();
    });
  }

  /// Stops the retry driver. Queued messages remain and can be flushed manually.
  void stop() {
    _autoRetry = false;
    _timer?.cancel();
    _timer = null;
  }
}
